# Project decisions

## Binding decisions

| ID | Decision | Reason | Evidence |
| --- | --- | --- | --- |
| D001 | Each application folder owns its configuration, deployment, lifecycle hooks, theme mapping, fixtures, and app-specific desktop integration. | Ownership must be visible and local so the root runner does not become a second configuration repository. | User direction, 2026-09-11. |
| D002 | Use a visible `dotfiles.json` manifest and standard optional `validate.sh`, `apply.sh`, `check.sh`, `reload.sh`, and `clean.sh` lifecycle files in application folders. | A consistent contract makes placement, install behavior, and maintenance discoverable without reading the root implementation. | User requested a standard app-local setup; interface selected during inception. |
| D003 | Declare source kind separately from install method. Kinds are `file`, `contents`, and `directory`; methods are `link` and `copy`. | The existing `file` and `contents` strategies imply linking and cannot plainly express an atomic installed copy. | Current `link-config.json` and user direction. |
| D004 | The root runner detects capabilities and explains why modules are enabled or skipped. Explicit profile overrides support headless setup and tests. | Live desktop environment variables are useful evidence but cannot be the only setup mechanism. | User requested KDE-gated behavior. |
| D005 | Shared KDE settings belong to `kde/`; KDE behavior specific to one app belongs to that app. | The VS Code focus rule is VS Code behavior even though KWin applies it. | User direction, 2026-09-11. |
| D006 | Keep Plasma and KWin as the primary desktop. Evaluate Quickshell first as a focused launcher and theme picker. | Current machine is Plasma 6.7.4 on Wayland; a complete shell replacement would add a large QML codebase before the ownership and theme work is stable. | Local environment inspection and approved plan. |
| D007 | Freeze Gruvbox and Gruvbox Light palette values and preserve approved visual behavior with golden fixtures. | The user explicitly likes the existing Gruvbox themes. | User direction. |
| D008 | Track portable intent, inputs, manifests, hooks, and tests. Ignore generated theme output and mutable machine or session state. | Theme selection must not dirty Git, and wholesale application state includes unrelated and machine-specific data. | Existing repository model and approved plan. |
| D009 | Cleanup is evidence-based and staged. Inventory first; delete packages or user data only after explicit review. | Installed KDE state may contain user data and unrelated configuration. | User requested strong cleanup; repository safety agreement. |
| D010 | Deliver logical verified batches as focused commits without staging the existing unrelated worktree changes. | The project must remain recoverable and its history reviewable. | User requested proper Git tracking; existing dirty worktree observed on 2026-09-11. |

## Open decisions

- Launcher replacement cutover policy after the prototype.
- Window-zone implementation after hands-on qualification.
- Future non-Arch platform support.
- Whether KDE should manage the file-dialog decoration position, hidden-file
  default, and task-switcher layout. The live values differ from the retired
  central registry, so the ownership foundation deliberately leaves them
  untouched until the KDE inventory is reviewed.

## Superseded decisions

- None.

## Project notes

- The root must not contain new application-specific arrays comparable to the
  current KDE settings and package lists.
