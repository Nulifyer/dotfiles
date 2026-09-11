# Desktop shell review and launcher plan

## Decision

Adopt the shared architectural idea from Omarchy 4 and dwm-titus: one resident
Quickshell process owns the visible shell UI while a separate window manager
owns windows. Start that process with one focused launcher alongside Plasma and
KWin. Its only routes are `all`, `apps`, `projects`, and `themes`; its only
external runtime interface is opening or toggling one of those routes.

The launcher batch does not include a Plasmoid, full desktop, generic command
menu, settings application, or plugin system. Keep Plasma Shell and KRunner
available until the replacement passes the acceptance gates below. A later
decision may add shell surfaces to the same process rather than starting a
second Quickshell instance.

## Full-desktop comparison

This review used Omarchy's `quattro` branch at
[`31bd80d`](https://github.com/omacom/omarchy/tree/31bd80daa4613ffdee995ac27467fce5a2990806)
and dwm-titus `main` at
[`5a511e2`](https://github.com/ChrisTitusTech/dwm-titus/tree/5a511e2897e0f44554e60a87d674240f9a07854f).

| System | Window owner | Quickshell owns | Fit here |
| --- | --- | --- | --- |
| Omarchy 4 | Hyprland on Wayland | Full plugin shell: bar, launcher/menu, notifications, background, lock, OSD, Polkit, and panels | Best interaction and theme reference; its Arch distribution management, plugin platform, and Hyprland integration are out of scope. |
| dwm-titus | Patched dwm on X11 | Full managed shell and Settings experience | Best reference for narrow helpers, explicit capabilities, and runtime configuration; its Fedora-only image, X11 contract, and system-management UI are out of scope. |
| This repository | KWin on Wayland | Launcher first; later shell surfaces only after qualification | Preserves the current applications and Wayland session while leaving room to retire Plasma Shell gradually. |

Neither reference window manager matches the requested FancyZones behavior.
Omarchy uses Hyprland's dynamic dwindle or scrolling layouts. dwm-titus uses a
master/stack tiler with master and per-client size factors. Both recalculate a
tiled layout; neither treats zones as persistent geometry targets that windows
may span while retaining independent manual sizes.

Quickshell therefore does not own zone behavior. A separate KWin-owned module
must implement and test fixed zone geometry, drag selection, spanning, and
manual resize without mutating the saved layout. Replacing Plasma Shell is a
separate decision from replacing KWin.

## What the Omarchy review established

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

## What the dwm-titus review established

- Chris Titus's September 2026 preview describes the same split directly:
  Fedora and X11 underneath, DWM for windows, and Quickshell for the visible
  desktop. The repository now defines that as a supported product rather than
  an informal personal configuration.
- The current project is a complete Fedora 44 X11 desktop, not a small dotfiles
  layer. Its supported product includes DWM, a managed Quickshell tree,
  Settings, system helpers, installer profiles, and offline system images.
- `hotkeys.toml`, `themes.toml`, and `window-rules.toml` reload through DWM.
  Invalid reloads retain the last valid state.
- QML stays unprivileged. Fixed helper interfaces own desktop-entry launching,
  system reads, and confirmed changes. Optional capabilities degrade without
  taking down the session.
- Its shell derives semantic hover, focus, selected, disabled, danger,
  high-contrast, and reduced-motion behavior from the active theme. That state
  model is worth adopting. Its large Settings and system-management layers are
  not.
- The managed Quickshell tree is replaced as one revision during installation
  so helpers and QML cannot drift. Repository links plus repeated `./dotfiles`
  already give this project the same consistency with less copying.

Primary references: [product specification](https://github.com/ChrisTitusTech/dwm-titus/blob/main/SPEC.md),
[runtime themes](https://github.com/ChrisTitusTech/dwm-titus/blob/main/config/themes.toml),
[semantic shell theme](https://github.com/ChrisTitusTech/dwm-titus/blob/main/config/quickshell/core/Theme.qml),
and [Omarchy UI adaptation](https://github.com/ChrisTitusTech/dwm-titus/blob/main/docs/OMARCHY-UI-ADAPTATION.md).
The preview begins discussing this stack at
[13:00](https://www.youtube.com/watch?v=9d9PQ1hrhBk&t=780s).

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

`quickshell/` will be one deep module. It owns the QML, search/ranking logic,
project scanner source, flat theme mapping, ignored generated palette,
autostart entry, desktop entry, and launcher-specific KDE shortcut and window
rule. The root `./dotfiles` command discovers and applies it like every other
app module.

After parity is proven:

- move `fish/tools/project_candidates.c` into `quickshell/`;
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

After the launcher and zone modules pass, inventory the Plasma Shell surfaces
actually used. Replace one surface at a time in the same Quickshell process,
starting with the panel only if its tray, reserved area, multi-monitor behavior,
and crash recovery are at least as reliable as Plasma. Do not disable
`plasmashell` as part of the launcher rollout.
