# -------------------------------------------
# File: scripts/main.sh
# Description: Main script to archive, package, sign, and clean up in one command
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_DIR="$BUILD_DIR/archive"
PKG_DIR="$BUILD_DIR/pkg"

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${COLOR_ERROR}Missing $CONFIG_FILE. Make sure it's committed.${COLOR_RESET}"
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# --- Helpers ----------------------------------------------------

# Save/update a key=value pair in config.sh
save_config_value() {
  local key="$1" value="$2"
  local esc_value
  esc_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i '' -E "s|^(${key}=).*|\1\"${esc_value}\"|" "$CONFIG_FILE"
  else
    printf '\n%s="%s"\n' "$key" "$value" >> "$CONFIG_FILE"
  fi
}

# Display a numbered list and let user pick
pick_from_list() {
  local prompt="$1"; shift
  local -a items=("$@")
  if [ ${#items[@]} -eq 0 ]; then
    echo ""
    return 0
  fi
  echo -e "${COLOR_PROMPT}${prompt}${COLOR_RESET}"
  local i=1
  for it in "${items[@]}"; do
    echo "  [$i] $it"
    ((i++))
  done
  echo -ne "${COLOR_PROMPT}Choose [1-${#items[@]}]: ${COLOR_RESET}"
  read -r choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#items[@]} )); then
    echo "${items[$((choice-1))]}"
  else
    echo -e "${COLOR_ERROR}Invalid choice.${COLOR_RESET}" >&2
    return 1
  fi
}

# Detect available identities from Keychain
detect_identities() {
  local pattern="$1" # "Developer ID Application" or "Developer ID Installer"
  local out
  out=$(security find-identity -v -p codesigning 2>/dev/null || true)
  mapfile -t ids < <(echo "$out" | grep "$pattern" | sed -E 's/.*\"([^\"]+)\".*/\1/')
  if [ -n "${TEAM_ID:-}" ]; then
    mapfile -t ids < <(printf "%s\n" "${ids[@]}" | grep "(${TEAM_ID})" || true)
  fi
  printf "%s\n" "${ids[@]}"
}

# --- Resolve identities (from config, or prompt, then persist) ---
if [ -z "${SIGN_ID_APP:-}" ]; then
  echo -e "${COLOR_STEP}Searching for 'Developer ID Application'…${COLOR_RESET}"
  mapfile -t app_ids < <(detect_identities "Developer ID Application")
  if [ ${#app_ids[@]} -eq 0 ]; then
    echo -e "${COLOR_WARN}No 'Developer ID Application' found in keychain.${COLOR_RESET}"
  else
    if ! chosen=$(pick_from_list "Select identity for APP:" "${app_ids[@]}"); then exit 1; fi
    SIGN_ID_APP="$chosen"
    save_config_value "SIGN_ID_APP" "$SIGN_ID_APP"
    echo -e "${COLOR_INFO}Saved in config.sh → SIGN_ID_APP=\"${SIGN_ID_APP}\"${COLOR_RESET}"
  fi
fi

if [ -z "${SIGN_ID_INSTALLER:-}" ]; then
  echo -e "${COLOR_STEP}Searching for 'Developer ID Installer'…${COLOR_RESET}"
  mapfile -t inst_ids < <(detect_identities "Developer ID Installer")
  if [ ${#inst_ids[@]} -eq 0 ]; then
    echo -e "${COLOR_ERROR}No 'Developer ID Installer' found in keychain.${COLOR_RESET}"
    echo -e "${COLOR_ERROR}Add your certificate or edit scripts/config.sh manually.${COLOR_RESET}"
    exit 1
  else
    if ! chosen=$(pick_from_list "Select identity for PKG:" "${inst_ids[@]}"); then exit 1; fi
    SIGN_ID_INSTALLER="$chosen"
    save_config_value "SIGN_ID_INSTALLER" "$SIGN_ID_INSTALLER"
    echo -e "${COLOR_INFO}Saved in config.sh → SIGN_ID_INSTALLER=\"${SIGN_ID_INSTALLER}\"${COLOR_RESET}"
  fi
fi

# Summary
echo -e "${COLOR_INFO}    → TEAM_ID: ${TEAM_ID:-}(not set)${COLOR_RESET}"
echo -e "${COLOR_INFO}    → APP ID: ${SIGN_ID_APP:-(empty)}${COLOR_RESET}"
echo -e "${COLOR_INFO}    → INSTALLER ID: ${SIGN_ID_INSTALLER}${COLOR_RESET}"

# --- Build steps ------------------------------------------------

echo -e "${COLOR_STEP}[0/6] Detecting Xcode project in root...${COLOR_RESET}"
if compgen -G "$ROOT_DIR"/*.xcworkspace > /dev/null; then
  PROJECT_FILE="$(basename "$(compgen -G "$ROOT_DIR"/*.xcworkspace | head -n1)")"
elif compgen -G "$ROOT_DIR"/*.xcodeproj > /dev/null; then
  PROJECT_FILE="$(basename "$(compgen -G "$ROOT_DIR"/*.xcodeproj | head -n1)")"
else
  echo -e "${COLOR_ERROR}Error: No .xcworkspace or .xcodeproj found.${COLOR_RESET}"
  exit 1
fi
PROJECT_PATH="$ROOT_DIR/$PROJECT_FILE"
SCHEME="${PROJECT_FILE%.*}"
echo -e "${COLOR_INFO}    → Project: $PROJECT_FILE, scheme: $SCHEME${COLOR_RESET}"

echo -e "${COLOR_STEP}[1/6] Archiving macOS app...${COLOR_RESET}"
mkdir -p "$ARCHIVE_DIR"
bash "$SCRIPT_DIR/build_archive.sh" "$PROJECT_PATH" "$SCHEME" "$ARCHIVE_DIR" "${SIGN_ID_APP:-}"
ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"

echo -e "${COLOR_STEP}[2/6] Extracting .app for packaging...${COLOR_RESET}"
mkdir -p "$PKG_DIR"
bash "$SCRIPT_DIR/extract_app.sh" "$ARCHIVE_PATH" "$PKG_DIR"
APP_PATH="$PKG_DIR/$SCHEME.app"

echo -e "${COLOR_STEP}[3/6] Reading bundle ID & version...${COLOR_RESET}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo -e "${COLOR_INFO}    → Bundle ID: $BUNDLE_ID, Version: $VERSION${COLOR_RESET}"

echo -e "${COLOR_STEP}[4/6] Using Developer ID Installer...${COLOR_RESET}"
echo -e "${COLOR_INFO}    → ${SIGN_ID_INSTALLER}${COLOR_RESET}"

echo -e "${COLOR_STEP}[5/6] Building and signing .pkg...${COLOR_RESET}"
bash "$SCRIPT_DIR/build_pkg.sh" "$APP_PATH" "$BUNDLE_ID" "$VERSION" "$SIGN_ID_INSTALLER" "$PKG_DIR"
SIGNED_PKG="$PKG_DIR/${SCHEME}-signed.pkg"

echo -e "${COLOR_STEP}[6/6] Cleaning up extracted .app...${COLOR_RESET}"
bash "$SCRIPT_DIR/clean_up.sh" "$APP_PATH"

echo -e "\n${COLOR_SUCCESS}Done!${COLOR_RESET}"
echo -e "${COLOR_INFO}Archive: $ARCHIVE_PATH${COLOR_RESET}"
echo -e "${COLOR_INFO}Signed PKG: $SIGNED_PKG${COLOR_RESET}"

echo -e "${COLOR_PROMPT}Open the signed installer now? [y/N] ${COLOR_RESET}\c"
read -r answer
if [[ "$answer" =~ ^[Yy] ]]; then
  open "$SIGNED_PKG"
fi
