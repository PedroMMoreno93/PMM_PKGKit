# -------------------------------------------
# File: scripts/lib/config_utils.sh
# Description: Utilities for reading/writing scripts/config.sh in-place (portable sed).
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Ensure the config file exists.
ensure_config_exists() {
  local config_file="$1"
  if [ ! -f "$config_file" ]; then
    echo "ERROR: Missing ${config_file}. Make sure it's committed." >&2
    exit 1
  fi
}

# Source the config file (shellcheck safe wrapper).
load_config() {
  local config_file="$1"
  # shellcheck disable=SC1090
  source "$config_file"
}

# Save or update KEY="VALUE" in config.sh (handles macOS/BSD sed vs GNU sed).
save_config_value() {
  local config_file="$1"
  local key="$2"
  local value="$3"

  # Escape / and & for sed replacement.
  local esc_value
  esc_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')

  if grep -q "^${key}=" "$config_file"; then
    # Detect sed flavor
    if sed --version >/dev/null 2>&1; then
      # GNU sed
      sed -i -E "s|^(${key}=).*|\1\"${esc_value}\"|" "$config_file"
    else
      # BSD/macOS sed
      sed -i '' -E "s|^(${key}=).*|\1\"${esc_value}\"|" "$config_file"
    fi
  else
    printf '\n%s="%s"\n' "$key" "$value" >> "$config_file"
  fi
}
