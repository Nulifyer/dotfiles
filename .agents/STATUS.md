# Project status

Updated: 2026-09-11
State: active

## Project state

The app-ownership foundation is implemented. Each visible application folder
has a validated manifest for deployment, dependencies, desktop conditions, and
optional lifecycle hooks. The root runner is a generic orchestrator, while KDE
integration for individual applications lives with those applications.

The working tree still contains pre-existing Fish, OpenCode, and Spectacle
edits that are outside this project batch and must remain unstaged.

## Current batch

Theme model v2: establish protected Gruvbox fixtures and expand `colors.json`
from a partial palette into a semantic, auditable source for every adapter.

## In progress

- None. The ownership foundation is complete and ready to commit.

## Next action

Add Gruvbox golden fixtures, then define and validate the semantic color roles
needed by KDE, VS Code, terminals, Brave, launchers, and app interaction states.

## Blockers

- None.

## Verification

- `./dotfiles check` passes with source, manifest, generated-theme, dependency,
  deployment, link, and app-owned live-state checks.
- `.tests/setup.sh` passes an isolated KDE-targeted link, apply, check, and
  unlink round trip without leaving managed links behind.
- `DOTFILES_DESKTOP=none` skips KDE-owned modules and dependencies.
- Baseline environment: CachyOS, Wayland, Plasma and KWin 6.7.4, VS Code
  1.136.1.
- Baseline worktree edits to preserve: `fish/conf.d/projects.fish`,
  `fish/config.fish`, `fish/tools/project_candidates.py`,
  `opencode/opencode.jsonc`, and `spectacle/spectaclerc`.

## Project notes

- File-dialog decoration position, hidden-file visibility, and task-switcher
  layout are deliberately unmanaged pending a product decision; see the open
  decisions in `DECISIONS.md`.
