# -------------------------------------------
# File: scripts/extract_app.sh
# Description: Extracts the .app from a .xcarchive
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Load shared ANSI color palette
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Usage: extract_app.sh <archive-path> <output-dir>
if [ $# -lt 2 ]; then
  echo -e "${COLOR_ERROR}Usage: $0 <archive-path> <output-dir>${COLOR_RESET}"
  exit 1
fi

ARCHIVE_PATH="$1"
OUTPUT_DIR="$2"
APP_NAME="$(basename "$ARCHIVE_PATH" .xcarchive)"
APP_PATH_OUT="$OUTPUT_DIR/$APP_NAME.app"

echo -e "${COLOR_STEP}[1/1] Extracting '$APP_NAME.app' from archive...${COLOR_RESET}"
mkdir -p "$OUTPUT_DIR"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$OUTPUT_DIR"

echo -e "${COLOR_SUCCESS}App extracted to $APP_PATH_OUT${COLOR_RESET}"
