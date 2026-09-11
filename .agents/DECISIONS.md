# Project decisions

## Binding decisions

| ID | Decision | Reason |
| --- | --- | --- |
| D001 | Each application folder owns its configuration, deployment, theme mapping, optional apply or reload hook, and app-specific desktop integration. | Ownership should be visible without a second central configuration. |
| D002 | Running `./dotfiles` is the only public command. It generates the theme, deploys files, removes obsolete owned links, applies app settings, and reloads supported apps. A launcher may choose a theme with `DOTFILES_THEME` and invoke the same command. | Separate subcommands duplicated work and made routine use harder. |
| D003 | A manifest deployment defaults to a linked file. `kind` and `install` appear only for directory deployment or copies. | The common case should need only source and target. |
| D004 | The root runner detects KDE and supports `DOTFILES_DESKTOP` for headless use and tests. | Desktop-specific work must be skipped outside its desktop. |
| D005 | `kde/` owns only theme state. KDE settings tied to one app live in that app; generic KDE preferences are not tracked. | The repository must remain portable and app ownership must stay local. |
| D006 | Keep KWin and Plasma Shell during the launcher and window-zone prototypes. After both pass, evaluate replacing Plasma Shell surfaces one at a time inside the same Quickshell process. | Quickshell can replace visible shell UI, but it does not own window placement and a full shell creates a much larger maintenance obligation. |
| D007 | Gruvbox and Gruvbox Light keep their approved palette values but use the same renderer and checks as every theme. | Special golden fixtures duplicate the normal theme system. |
| D008 | Track portable inputs and generators. Ignore generated themes, compiled binaries, credentials, histories, caches, sessions, and device state. | A clone must describe intent without capturing one machine. |
| D009 | Cleanup removes only state with ownership evidence. Package or user-data removal requires review. | Broad cleanup can destroy unrelated state. |
| D010 | Deliver coherent verified commits without sweeping in unrelated work. | Git history is the durable recovery and review path. |
| D011 | Semantic roles are app-neutral. Each app chooses whether its own borders and neighboring surfaces blend or contrast. | VS Code and browser navigation need different separation policies. |
| D012 | Known contrast debt remains explicit. New failures and stale resolved exceptions fail the common renderer validation. | Existing light-theme failures should improve without accepting regressions. |
| D013 | VS Code styles Rainbow CSV and Git Graph through the generated theme itself. It does not track a separate extension-version inventory. | The requested result is integrated color behavior, not extension management. |
| D014 | The project picker uses portable C source and a locally compiled binary. | Generic `fd`, `find`, Bun, and Perl alternatives measured no faster than the pruned Python scanner. |
| D015 | Build one resident Quickshell host whose first surface is a launcher with `all`, `apps`, `projects`, and `themes` routes. Use a regular top-level window and app-owned KWin integration; the first batch does not include a Plasmoid, full shell, command menu, Settings application, or plugin framework. | This keeps Omarchy 4's fast IPC and unified picker UX while leaving one process that can later own more shell UI without importing either reference project's distribution-management scope. |
| D016 | Keep KRunner available on `Alt+F2` through launcher qualification. Bind the new launcher to `Meta+Space` only after the resident-window and application-launch gates pass. | The fallback makes cutover reversible while focus, desktop-entry semantics, and multi-monitor behavior are proven on Plasma. |
| D017 | `quickshell/` owns its shell source, project scanner, launcher desktop/autostart entries, theme mapping, and launcher-specific KDE rules after cutover. Fish retains shell navigation commands; `applications/` does not retain launcher behavior. | The complete Quickshell lifecycle and any later shell surfaces should remain maintainable in one app folder. |
| D018 | Keep window placement in a separate KWin-owned module. Quickshell may draw a zone overlay, but DWM or Hyprland will not replace KWin unless hands-on qualification proves the required fixed zones, spanning, and independent manual resizing. | Both reviewed window managers use dynamic tiling and do not provide the requested FancyZones model. |

## Open decisions

- Window-zone implementation after hands-on qualification.
- Future non-Arch platform support.

## Superseded decisions

- Public `apply`, `theme`, `doctor`, `update`, `status`, and `unlink` subcommands.
- Command and package dependency inventories in application manifests.
- Per-app `validate.sh`, `check.sh`, and `clean.sh` lifecycle files.
- Separate Gruvbox golden fixtures and JSON schema documents.
- A pinned VS Code extension inventory for theme integration.
