# Project decisions

## Binding decisions

| ID | Decision | Reason |
| --- | --- | --- |
| D001 | Each application folder owns its configuration, deployment, theme mapping, optional apply or reload hook, and app-specific desktop integration. | Ownership should be visible without a second central configuration. |
| D002 | `apply` is the one reconciliation interface. It generates the theme, deploys files, removes obsolete owned links, applies app settings, and reloads supported apps. | Separate link, validate, check, and settings passes duplicated work and made routine use harder. |
| D003 | A manifest deployment defaults to a linked file. `kind` and `install` appear only for directory deployment or copies. | The common case should need only source and target. |
| D004 | The root runner detects KDE and supports `DOTFILES_DESKTOP` for headless use and tests. | Desktop-specific work must be skipped outside its desktop. |
| D005 | `kde/` owns only theme state. KDE settings tied to one app live in that app; generic KDE preferences are not tracked. | The repository must remain portable and app ownership must stay local. |
| D006 | Keep Plasma and KWin. Evaluate Quickshell as a launcher and theme picker before considering a wider replacement. | The launcher can improve without replacing the desktop. |
| D007 | Gruvbox and Gruvbox Light keep their approved palette values but use the same renderer and checks as every theme. | Special golden fixtures duplicate the normal theme system. |
| D008 | Track portable inputs and generators. Ignore generated themes, compiled binaries, credentials, histories, caches, sessions, and device state. | A clone must describe intent without capturing one machine. |
| D009 | Cleanup removes only state with ownership evidence. Package or user-data removal requires review. | Broad cleanup can destroy unrelated state. |
| D010 | Deliver coherent verified commits without sweeping in unrelated work. | Git history is the durable recovery and review path. |
| D011 | Semantic roles are app-neutral. Each app chooses whether its own borders and neighboring surfaces blend or contrast. | VS Code and browser navigation need different separation policies. |
| D012 | Known contrast debt remains explicit. New failures and stale resolved exceptions fail the common renderer validation. | Existing light-theme failures should improve without accepting regressions. |
| D013 | VS Code styles Rainbow CSV and Git Graph through the generated theme itself. It does not track a separate extension-version inventory. | The requested result is integrated color behavior, not extension management. |
| D014 | The project picker uses portable C source and a locally compiled binary. | Generic `fd`, `find`, Bun, and Perl alternatives measured no faster than the pruned Python scanner. |

## Open decisions

- Launcher replacement cutover policy after the prototype.
- Window-zone implementation after hands-on qualification.
- Future non-Arch platform support.

## Superseded decisions

- Per-app `validate.sh`, `check.sh`, and `clean.sh` lifecycle files.
- Separate Gruvbox golden fixtures and JSON schema documents.
- A pinned VS Code extension inventory for theme integration.
