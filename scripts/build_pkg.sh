# -------------------------------------------
# File: scripts/build_pkg.sh
# Description: Packages a .app into a signed .pkg
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Load shared ANSI color palette
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Usage: build_pkg.sh <app-path> <bundle-identifier> <version> <installer-sign-identity> <output-dir>
if [ $# -lt 5 ]; then
  echo -e "${COLOR_ERROR}Usage: $0 <app-path> <bundle-identifier> <version> <installer-sign-identity> <output-dir>${COLOR_RESET}"
  exit 1
fi

APP_PATH="$1"
BUNDLE_ID="$2"
VERSION="$3"
SIGN_IDENTITY="$4"
OUTPUT_DIR="$5"
APP_NAME="$(basename "$APP_PATH" .app)"
COMPONENT_PKG="$OUTPUT_DIR/${APP_NAME}.pkg"
SIGNED_PKG="$OUTPUT_DIR/${APP_NAME}-signed.pkg"

echo -e "${COLOR_STEP}[1/2] Packaging .app into .pkg...${COLOR_RESET}"
mkdir -p "$OUTPUT_DIR"
pkgbuild \
  --component "$APP_PATH" \
  --install-location "/Applications" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  "$COMPONENT_PKG"

echo -e "${COLOR_STEP}[2/2] Signing .pkg as '$SIGN_IDENTITY'...${COLOR_RESET}"
productsign \
  --sign "$SIGN_IDENTITY" \
  "$COMPONENT_PKG" \
  "$SIGNED_PKG"

echo -e "${COLOR_SUCCESS}Signed package available at $SIGNED_PKG${COLOR_RESET}"
