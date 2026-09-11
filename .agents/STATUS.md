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

- Gruvbox and Gruvbox Light catalog entries and generated app outputs are
  protected by hash-based golden fixtures before renderer semantics change.
- The old VS Code-named overrides are now application-neutral semantic roles.
  Strict catalog validation rejects missing fields, unknown keys, malformed
  colors, unknown roles, and invalid role references.
- UI background, surface, border, hover, primary/muted text, and selection
  roles are separate from terminal palette names. KDE, VS Code, OpenCode,
  Kitty, and fzf consume those roles without changing current output.
- A contrast baseline identifies 20 known failures across 9 themes without
  changing any generated output.
- VS Code now owns its theme templates and adapter. Rainbow CSV has explicit
  ten-column and tracking colors, Git Graph receives a generated branch cycle,
  and both integrations are checked against pinned inspected versions.

## Next action

Record palette provenance and repair the non-Gruvbox light-theme contrast
failures, then add Markdown and representative-language visual fixtures.

## Blockers

- None.

## Verification

- `./dotfiles check` passes with source, manifest, generated-theme, dependency,
  deployment, link, and app-owned live-state checks.
- `.tests/setup.sh` passes an isolated KDE-targeted link, apply, check, and
  unlink round trip without leaving managed links behind.
- `DOTFILES_DESKTOP=none` skips KDE-owned modules and dependencies.
- A before/after hash comparison proved all 2,040 generated files are unchanged
  by the semantic-role rename and strict validation.
- VS Code adapter tests render all 40 themes and enforce 4.5:1 Rainbow CSV text
  contrast, 3:1 Git Graph line contrast, contributed tracking colors, and the
  expected extension versions.
- A live apply/check cycle exposed and fixed KDE scheme ordering and restored
  the project picker shortcut to `Ctrl+Alt+P`.
- Baseline environment: CachyOS, Wayland, Plasma and KWin 6.7.4, VS Code
  1.136.1.
- Baseline worktree edits to preserve: `fish/conf.d/projects.fish`,
  `fish/config.fish`, `fish/tools/project_candidates.py`,
  `opencode/opencode.jsonc`, and `spectacle/spectaclerc`.

## Project notes

- File-dialog decoration position, hidden-file visibility, and task-switcher
  layout are deliberately unmanaged pending a product decision; see the open
  decisions in `DECISIONS.md`.
