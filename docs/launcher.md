# Launcher review and implementation plan

## Decision

Adopt Omarchy 4's interaction architecture, not its desktop-management scope.
Build one focused, resident Quickshell launcher alongside Plasma and KWin. Its
only routes are `all`, `apps`, `projects`, and `themes`; its only external
runtime interface is opening or toggling one of those routes.

Do not build a Plasmoid, a full Quickshell desktop, a generic command menu, or a
plugin system. Keep KRunner available until the replacement passes the
acceptance gates below.

## What the Omarchy review established

The review used Omarchy's `quattro` branch at commit
[`b5589fa`](https://github.com/omacom/omarchy/tree/b5589faaf80c6f87c07d4560fca37c4a81722f28).

- Omarchy's menu lives in its long-running Quickshell process and is summoned
  over IPC. Its documentation reports about 30 ms from keybind to visible
  because parsing and guard evaluation are kept off the open path.
- The same menu supports direct routes, desktop-entry-backed applications, and
  generic select/input modes. Its data files are watched and reloaded without
  restarting the shell.
- The useful UX details are direct keyboard routes, one searchable model,
  clear selected-row contrast, secondary detail only when useful, and a
  partially visible next row that signals overflow.
- Omarchy's large hierarchical system menu, shell-command guards, install and
  remove actions, image-picker tempfile protocol, and plugin registry solve
  distribution-management problems this repository does not have.

Primary references: [menu design](https://github.com/omacom/omarchy/blob/quattro/docs/menu.md),
[menu implementation](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/menu/Menu.qml),
[default menu data](https://github.com/omacom/omarchy/blob/quattro/default/omarchy/omarchy-menu.jsonc),
and [navigation](https://github.com/omacom/omarchy/blob/quattro/manual/04-navigation.md).

## Why this shape fits Plasma

Quickshell supplies the three facilities needed here: a resident process with
typed IPC, desktop-entry discovery, and a regular top-level
[`FloatingWindow`](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/).
Using a top-level window lets the launcher own a narrow KWin rule without
depending on Hyprland layer-shell behavior.

A Plasma widget would be resident, but its normal interface is a panel or
desktop containment. Reusing Plasma's application model also commonly reaches
the private Kicker QML module, which KDE warns may break across Plasma updates.
That creates more Plasma coupling and makes portable setup depend on mutable
panel layout. References: [Plasma widget setup](https://develop.kde.org/docs/plasma/widget/setup/)
and [KDE's private Kicker warning](https://develop.kde.org/docs/plasma/widget/c-api/).

## Ownership

`launcher/` will be one deep module. It owns the QML, search/ranking logic,
project scanner source, flat theme mapping, ignored generated palette,
autostart entry, desktop entry, and launcher-specific KDE shortcut and window
rule. The root `./dotfiles` command discovers and applies it like every other
app module.

After parity is proven:

- move `fish/tools/project_candidates.c` into `launcher/`;
- keep `z`, `zopen`, and `zlink` in `fish/`, but make `zpick` delegate to the
  launcher or retire it;
- move the project-picker desktop entry and its KDE settings out of
  `applications/`;
- remove the old Kitty/fzf picker only in the same cutover batch.

No generated QML theme data, compiled scanner, history, favorites, usage rank,
or recent-project state is tracked.

## UX contract

- `Meta+Space`: toggle the universal route. With an empty query it offers
  Apps, Projects, and Themes; typing searches their rows in one list.
- `Ctrl+Alt+P`: open Projects directly, preserving the current muscle memory.
- `Escape`: clear the query, then close. Arrow keys move, Page Up/Down jump,
  Enter activates, and Left/Backspace returns from a route.
- Apps show icon, name, and useful desktop-entry detail. Projects show name and
  shortened path. Themes show name, light/dark variant, and semantic swatches.
- The selected row is unmistakable; unselected structure stays restrained.
  The launcher maps colors from `colors.json` through a flat app-owned mapping.
- Project results are preloaded after session start. Opening the window always
  displays cached results first and refreshes asynchronously.
- Choosing a theme invokes `DOTFILES_THEME=<name> ./dotfiles`; it does not
  create a second theme-application path. The visible launcher palette reloads
  after a successful apply.

The app launch adapter needs explicit qualification. Quickshell documents that
`DesktopEntry.execute()` currently ignores terminal handling and field codes,
so the prototype must prove a KDE-correct launch path before cutover:
[DesktopEntry limitations](https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntry/).

## Delivery gates

1. **Resident-window spike.** Prove one instance, IPC toggle, keyboard focus,
   active-screen placement, click-away close, and an app-owned KWin rule on
   Plasma Wayland. Target warm keypress-to-visible p95 below 100 ms.
2. **Application MVP.** Add desktop entries, icons, deterministic ranking, and
   correct `NoDisplay`, desktop visibility, working-directory, field-code, and
   terminal behavior. Keep KRunner as the fallback.
3. **Project migration.** Move the C scanner to its owner, preload it off the
   visible path, add editor/terminal actions, and prove result parity with the
   current picker before removing the Kitty/fzf path.
4. **Theme integration.** Generate the app-owned palette/catalog input, render
   swatches, apply only through `./dotfiles`, report failures, and prove live
   palette reload across dark and light themes.
5. **Cutover.** Bind `Meta+Space`, preserve `Alt+F2` for KRunner, rerun
   `./dotfiles` to remove only proven old launcher state, and keep the fallback
   until every acceptance check passes.

Acceptance also requires near-zero idle CPU, measured memory, reliable repeated
toggle, useful multi-monitor behavior, a clean Git worktree after normal use
and theme changes, and no machine-specific paths or state in tracked files.
