# Project status

State: active

## Project state

The repository is being simplified around one idempotent `./dotfiles` path. App
folders still own deployment and app-specific settings, but redundant schema,
golden, validation, check, and integration-inventory files are being removed.
KDE owns theme activation only; generic Plasma preferences are no longer
tracked.

## Current batch

The current Omarchy 4 and dwm-titus setups have been compared. Both validate a
single resident Quickshell process over a separate window manager, but neither
window manager matches the required fixed-zone workflow. The chosen first step
is one Quickshell-owned launcher while KWin, Plasma Shell, and KRunner remain.

## In progress

- `./dotfiles` renders the selected theme, reconciles deployments, removes
  obsolete repository links, applies app settings, and reloads supported apps.
- `DOTFILES_THEME=name ./dotfiles` is the narrow integration seam for the
  future graphical theme picker.
- Manifests contain only deployments and an optional desktop condition.
- VS Code theme maps live directly under `vscode/`; Rainbow CSV and Git Graph
  remain part of the generated theme.
- The project scanner is generated locally from portable C source.

## Next action

Implement the resident-window spike in `docs/launcher.md`: create the
`quickshell/` module with one process, a regular top-level launcher window,
route IPC, focus, active-screen placement, and an app-owned KWin rule. Do not
migrate the current project picker or disable Plasma Shell until the spike
passes.

## Blockers

- None.

## Verification

- The isolated setup test ran `./dotfiles` twice and removed flat and nested
  obsolete repository links. It also rejected the retired `apply` subcommand.
- Theme validation rendered the full catalog successfully.
- Shell syntax, application manifest tests, project picker tests, and
  `git diff --check` passed.
