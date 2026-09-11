# dotfiles

Portable application configuration for CachyOS and Plasma.

## Use it

```sh
./dotfiles
```

That is the complete public interface. It generates the selected theme,
reconciles links and copies, removes obsolete links that still point into this
repository, applies app-owned settings, and reloads supported applications.
Run it again after changing or pulling the repository; repeated runs converge
on the same state.

A graphical theme picker can select a theme through the same apply path without
adding another command:

```sh
DOTFILES_THEME=gruvbox ./dotfiles
```

If a target conflicts with a managed file, the command asks whether to keep the
repository version or import the target. It never replaces a directory with a
file. Cleanup removes only links whose destination proves repository ownership.

## Ownership

Each top-level application folder owns its configuration, `dotfiles.json`,
optional `apply.sh` and `reload.sh`, and any theme mapping. The manifest lists
deployments and an optional desktop condition. A deployment defaults to a
linked file, so the common case is only a source and target:

```json
{
  "source": "kitty.conf",
  "target": ".config/kitty/kitty.conf"
}
```

Set `"install": "copy"` for an atomic copy, or `"kind": "contents"` or
`"directory"` for directory deployment. The root script handles mechanics;
application choices stay in their application folders.

The KDE module runs only under KDE or when `DOTFILES_DESKTOP=kde` is set.
Generic Plasma preferences are not managed. `kde/` owns generated color schemes
and theme activation. App-specific KWin rules, shortcuts, and default-app
choices live in the affected app folder.

## Themes

`colors.json` is the source for all 40 themes. `.theme/render.py` validates the
catalog and generates ignored local files for Fish, Bash, Zsh, Kitty,
Alacritty, KDE, VS Code, and OpenCode. Semantic roles describe text, surfaces,
selection, borders, status, and Git colors. Each app decides how those roles map
to its own properties.

VS Code keeps its tracked theme maps directly in `vscode/`. Rainbow CSV scopes
and tracking colors are part of `tokens.json` and `workbench.json`. Git Graph's
branch colors are generated with the same palette. VS Code requires a local
extension wrapper to load a custom theme; `vscode/extension` is generated and
ignored, not a second source of configuration.

Gruvbox and Gruvbox Light use the same validation and generation path as every
other theme. Their palette values remain unchanged by policy.

## Project picker

Press `Ctrl+Alt+P` in Plasma or run `zpick` in Fish. Direct children of
`$Z_PROJECTS_ROOT`, defaulting to `~/Projects`, appear first. The scanner then
finds outermost directories containing `.git`, `.jj`, `.hg`, `.svn`, `.vscode`,
`.idea`, or `.devcontainer` while skipping caches and build trees.

The scanner is portable C source. `./dotfiles` compiles it for the current
machine into `~/.local/libexec/nulifyer`; no compiled binary is committed. Press
Enter to open the selected editor, `Ctrl+E` for a terminal, or Escape to close.

## What Git tracks

Git tracks portable intent: application configuration, manifests, theme data,
renderers, and tests. It does not track generated themes, compiled binaries,
credentials, histories, caches, sessions, display topology, device state, or
whole mutable KDE files.
