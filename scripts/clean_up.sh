# -------------------------------------------
# File: scripts/clean_up.sh
# Description: Cleans up extracted .app after packaging
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Load shared ANSI color palette
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Usage: clean_up.sh <app-path>
if [ $# -lt 1 ]; then
  echo -e "${COLOR_ERROR}Usage: $0 <app-path>${COLOR_RESET}"
  exit 1
fi

APP_PATH="$1"
if [ -d "$APP_PATH" ]; then
  echo -e "${COLOR_STEP}[cleanup] Removing extracted app at $APP_PATH...${COLOR_RESET}"
  rm -rf "$APP_PATH"
  echo -e "${COLOR_SUCCESS}[cleanup] Done.${COLOR_RESET}"
else
  echo -e "${COLOR_WARN}[cleanup] No app found at $APP_PATH, nothing to clean.${COLOR_RESET}"
fi
