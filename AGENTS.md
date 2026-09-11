# Repository agent instructions

## Ownership

- Each top-level application folder owns its configuration, deployment
  declarations, theme mapping, app-specific desktop integration, and optional
  `apply.sh` or `reload.sh`.
- Keep the root `dotfiles` command generic. `apply` is the single reconciliation
  path for theme generation, deployment, cleanup, app settings, and reloads.
- Declare deployed paths in the owner's `dotfiles.json`. A deployment defaults
  to a linked file; declare copies and directory deployments explicitly.
- `.theme` owns shared color resolution and catalog validation. App-specific
  property maps stay flat in the owning app folder.
- `kde/` owns only theme configuration. Generic KDE preferences do not belong
  in this repository. KDE behavior for one app belongs to that app.

## Portability and delivery

- Preserve Gruvbox and Gruvbox Light palette values unless the user changes
  that decision. Test them through the same path as every other theme.
- Track portable inputs and generators. Do not track compiled output, generated
  themes, mutable session or device state, caches, histories, or credentials.
- Cleanup may remove only state whose repository ownership can be proved.
- Preserve unrelated work. Stage and commit only the verified logical batch.

## Project continuity

For long-running work, read `.agents/README.md` and keep its indexed files
current. Use `project-continuity` when resuming or closing a batch. When commits
are authorized, implement one coherent result, update its records, test it,
inspect and stage only that result, commit it, then continue from one next
action.
