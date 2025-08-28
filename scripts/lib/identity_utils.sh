# -------------------------------------------
# File: scripts/lib/identity_utils.sh
# Description: Keychain identity discovery + interactive selection.
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Print a numbered list and return the selected item on stdout.
pick_from_list() {
  local prompt="$1"; shift
  local -a items=("$@")
  if [ ${#items[@]} -eq 0 ]; then
    echo ""
    return 0
  fi

  echo -e "$prompt"
  local i=1
  for it in "${items[@]}"; do
    echo "  [$i] $it"
    ((i++))
  done

  printf "Choose [1-%s]: " "${#items[@]}"
  read -r choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#items[@]} )); then
    echo "${items[$((choice-1))]}"
  else
    echo "Invalid choice." >&2
    return 1
  fi
}

# Detect identities from Keychain filtered by a pattern and optional TEAM_ID.
# Usage: detect_identities "Developer ID Application" "$TEAM_ID"
detect_identities() {
  local pattern="$1"
  local team_id="${2:-}"

  local out
  out=$(security find-identity -v -p codesigning 2>/dev/null || true)

  mapfile -t ids < <(echo "$out" | grep "$pattern" | sed -E 's/.*\"([^\"]+)\".*/\1/')
  if [ -n "$team_id" ] && [ ${#ids[@]} -gt 0 ]; then
    mapfile -t ids < <(printf "%s\n" "${ids[@]}" | grep "(${team_id})" || true)
  fi

  printf "%s\n" "${ids[@]}"
}

# Resolve a signing identity:
# - If current_value is empty, discover, prompt, and persist to config file.
# - Echo the final value to stdout (so caller can capture it).
# Usage: resolve_identity "KEY_IN_CONFIG" "$CURRENT_VALUE" "PATTERN" "$TEAM_ID" "$CONFIG_FILE"
resolve_identity() {
  local config_key="$1"
  local current_value="$2"
  local pattern="$3"
  local team_id="$4"
  local config_file="$5"

  if [ -n "$current_value" ]; then
    echo "$current_value"
    return 0
  fi

  mapfile -t found < <(detect_identities "$pattern" "$team_id")
  if [ ${#found[@]} -eq 0 ]; then
    echo "ERROR: No '$pattern' identity found in Keychain." >&2
    return 1
  fi

  local chosen
  chosen=$(pick_from_list "Select identity for $pattern:" "${found[@]}") || return 1

  # Persist to config
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/config_utils.sh"
  save_config_value "$config_file" "$config_key" "$chosen"

  echo "$chosen"
}
