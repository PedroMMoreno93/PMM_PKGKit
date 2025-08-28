# -------------------------------------------
# File: scripts/config.sh
# Description: Per-developer local configuration (COMMITTED with empty placeholders).
# master.sh will read this file. If values are empty, it will prompt you
# and persist the answers back here.
# -------------------------------------------
#!/usr/bin/env bash

# (Optional) Filter identities by TEAM_ID (ABCDE12345)
TEAM_ID=""

# Exact common names as they appear in `security find-identity -v -p codesigning`
SIGN_ID_APP=""       # e.g.: Developer ID Application: Your Name (ABCDE12345)
SIGN_ID_INSTALLER="" # e.g.: Developer ID Installer: Your Name (ABCDE12345)


  
