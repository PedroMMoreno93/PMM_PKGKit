# -------------------------------------------
# File: scripts/lib/project_utils.sh
# Description: Project/workspace discovery utilities.
# -------------------------------------------
#!/usr/bin/env bash
set -euo pipefail

# Find the first .xcworkspace or .xcodeproj in ROOT_DIR and echo its full path.
detect_project_path() {
  local root_dir="$1"

  if compgen -G "$root_dir"/*.xcworkspace > /dev/null; then
    local f
    f="$(compgen -G "$root_dir"/*.xcworkspace | head -n1)"
    echo "$f"
    return 0
  fi

  if compgen -G "$root_dir"/*.xcodeproj > /dev/null; then
    local f
    f="$(compgen -G "$root_dir"/*.xcodeproj | head -n1)"
    echo "$f"
    return 0
  fi

  echo "ERROR: No .xcworkspace or .xcodeproj found at $root_dir" >&2
  return 1
}

# Infer scheme from the project filename: "MyApp.xcodeproj" -> "MyApp"
infer_scheme_from_project() {
  local project_path="$1"
  local base
  base="$(basename "$project_path")"
  echo "${base%.*}"
}
