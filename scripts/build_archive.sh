# -------------------------------------------
# File: scripts/build_archive.sh
# Description: Archives macOS project
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Usage: build_archive.sh <project-path> <scheme> <archive-output-dir> [code-sign-identity-app]
if [ $# -lt 3 ]; then
  echo -e "${COLOR_ERROR}Usage: $0 <project-path> <scheme> <archive-output-dir> [code-sign-identity-app]${COLOR_RESET}"
  exit 1
fi

PROJECT_PATH="$1"
SCHEME="$2"
ARCHIVE_DIR="$3"
SIGN_ID_APP="${4:-}"

ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"

echo -e "${COLOR_STEP}[1/1] Archiving '$SCHEME' (Release, macOS SDK, universal)…${COLOR_RESET}"
mkdir -p "$ARCHIVE_DIR"

COMMON_FLAGS=(
  ARCHS="x86_64 arm64"
  VALID_ARCHS="x86_64 arm64"
  BUILD_ACTIVE_ARCH_ONLY=NO
)

# If identity provided → Manual signing, else → Automatic
if [ -n "$SIGN_ID_APP" ]; then
  COMMON_FLAGS+=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=$SIGN_ID_APP"
    PROVISIONING_PROFILE_SPECIFIER=""
    PROVISIONING_PROFILE=""
  )
else
  COMMON_FLAGS+=(
    CODE_SIGN_STYLE=Automatic
  )
  echo -e "${COLOR_WARN}SIGN_ID_APP is empty → CODE_SIGN_STYLE=Automatic (may require Xcode setup).${COLOR_RESET}"
fi

if [[ "$PROJECT_PATH" == *.xcworkspace ]]; then
  xcodebuild -workspace "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk macosx \
    "${COMMON_FLAGS[@]}" \
    -archivePath "$ARCHIVE_PATH" \
    archive
else
  xcodebuild -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk macosx \
    "${COMMON_FLAGS[@]}" \
    -archivePath "$ARCHIVE_PATH" \
    archive
fi

echo -e "${COLOR_SUCCESS}Archive created: $ARCHIVE_PATH (universal: x86_64 & arm64)${COLOR_RESET}"
