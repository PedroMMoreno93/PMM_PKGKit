# -------------------------------------------
# File: scripts/main.sh
# Description: Main script to archive, package, sign, and clean up in one command
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Shared colors
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_DIR="$BUILD_DIR/archive"
PKG_DIR="$BUILD_DIR/pkg"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Helpers
source "$SCRIPT_DIR/lib/config_utils.sh"
source "$SCRIPT_DIR/lib/identity_utils.sh"
source "$SCRIPT_DIR/lib/project_utils.sh"

echo -e "${COLOR_STEP}[init] Loading config…${COLOR_RESET}"
ensure_config_exists "$CONFIG_FILE"
load_config "$CONFIG_FILE"

# Resolve identities (prompt + persist if needed)
TEAM_ID="${TEAM_ID:-}"
SIGN_ID_APP="${SIGN_ID_APP:-}"
SIGN_ID_INSTALLER="${SIGN_ID_INSTALLER:-}"

if [ -z "$SIGN_ID_APP" ]; then
  SIGN_ID_APP="$(resolve_identity "SIGN_ID_APP" "$SIGN_ID_APP" "Developer ID Application" "$TEAM_ID" "$CONFIG_FILE")" || {
    echo -e "${COLOR_WARN}Proceeding with CODE_SIGN_STYLE=Automatic for archive (no app identity).${COLOR_RESET}"
    SIGN_ID_APP=""
  }
fi

if [ -z "$SIGN_ID_INSTALLER" ]; then
  SIGN_ID_INSTALLER="$(resolve_identity "SIGN_ID_INSTALLER" "$SIGN_ID_INSTALLER" "Developer ID Installer" "$TEAM_ID" "$CONFIG_FILE")"
fi

echo -e "${COLOR_INFO}    → TEAM_ID: ${TEAM_ID:-"(not set)"}${COLOR_RESET}"
echo -e "${COLOR_INFO}    → APP ID: ${SIGN_ID_APP:-"(empty → Automatic)"}${COLOR_RESET}"
echo -e "${COLOR_INFO}    → INSTALLER ID: ${SIGN_ID_INSTALLER}${COLOR_RESET}"

echo -e "${COLOR_STEP}[0/6] Detecting Xcode project in root…${COLOR_RESET}"
PROJECT_PATH="$(detect_project_path "$ROOT_DIR")"
SCHEME="$(infer_scheme_from_project "$PROJECT_PATH")"
echo -e "${COLOR_INFO}    → Project: $(basename "$PROJECT_PATH"), scheme: $SCHEME${COLOR_RESET}"

echo -e "${COLOR_STEP}[1/6] Archiving macOS app…${COLOR_RESET}"
mkdir -p "$ARCHIVE_DIR"
bash "$SCRIPT_DIR/build_archive.sh" "$PROJECT_PATH" "$SCHEME" "$ARCHIVE_DIR" "${SIGN_ID_APP:-}"
ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"

echo -e "${COLOR_STEP}[2/6] Extracting .app for packaging…${COLOR_RESET}"
mkdir -p "$PKG_DIR"
bash "$SCRIPT_DIR/extract_app.sh" "$ARCHIVE_PATH" "$PKG_DIR"
APP_PATH="$PKG_DIR/$SCHEME.app"

echo -e "${COLOR_STEP}[3/6] Reading bundle ID & version…${COLOR_RESET}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo -e "${COLOR_INFO}    → Bundle ID: $BUNDLE_ID, Version: $VERSION${COLOR_RESET}"

echo -e "${COLOR_STEP}[4/6] Using Developer ID Installer…${COLOR_RESET}"
echo -e "${COLOR_INFO}    → ${SIGN_ID_INSTALLER}${COLOR_RESET}"

echo -e "${COLOR_STEP}[5/6] Building and signing .pkg…${COLOR_RESET}"
bash "$SCRIPT_DIR/build_pkg.sh" "$APP_PATH" "$BUNDLE_ID" "$VERSION" "$SIGN_ID_INSTALLER" "$PKG_DIR"
SIGNED_PKG="$PKG_DIR/${SCHEME}-signed.pkg"

echo -e "${COLOR_STEP}[6/6] Cleaning up extracted .app…${COLOR_RESET}"
bash "$SCRIPT_DIR/clean_up.sh" "$APP_PATH"

echo -e "\n${COLOR_SUCCESS}Done!${COLOR_RESET}"
echo -e "${COLOR_INFO}Archive: $ARCHIVE_PATH${COLOR_RESET}"
echo -e "${COLOR_INFO}Signed PKG: $SIGNED_PKG${COLOR_RESET}"

echo -e "${COLOR_PROMPT}Open the signed installer now? [y/N] ${COLOR_RESET}\c"
read -r answer
if [[ "$answer" =~ ^[Yy] ]]; then
  open "$SIGNED_PKG"
fi
