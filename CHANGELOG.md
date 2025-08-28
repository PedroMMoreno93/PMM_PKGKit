## 🎉 Release v1.0.0

**PMM PKGKit 1.0.0** marks the initial stable release of **PKGKit**. This version includes:
- **Self-contained configuration** via `scripts/config.sh` (committed with empty placeholders). On first run, the tool prompts for missing identities and **persists** your choices back to `config.sh`.
- **Keychain identity discovery** (`Developer ID Application` / `Developer ID Installer`) with interactive selection.
- **Modular helpers** under `scripts/lib/`:
  - `config_utils.sh` – load/save helpers for `config.sh` (GNU & BSD `sed` compatible).
  - `identity_utils.sh` – discover identities and prompt the user.
  - `project_utils.sh` – detect `.xcworkspace` / `.xcodeproj` and infer scheme.
- **Consistent CLI output** via `scripts/colors.sh`.
- **Documentation** overhaul: updated README with step-by-step guide, file-by-file overview, and project placement instructions (scripts folder must live at the project root).
- **Brand assets**: logo artwork (`PKGKit`) for README.
