# Repository agent instructions

## Ownership

- Each top-level application folder owns that application's tracked
  configuration, deployment declarations, theme adapter, lifecycle hooks, and
  checks.
- Keep the root `dotfiles` command a generic orchestrator. Do not add
  application-specific settings or package lists to it.
- Keep shared desktop behavior under the desktop owner. KDE-specific behavior
  for one application belongs to that application's folder, not `kde/`.
- Declare deployed paths in the owning folder's `dotfiles.json`. Use the
  standard optional lifecycle names `validate.sh`, `apply.sh`, `check.sh`,
  `reload.sh`, and `clean.sh`.
- Keep app-specific theme property maps under the owning app folder. `.theme`
  owns only shared color resolution, validation, audits, and protected
  fixtures.

## Safety and delivery

- Preserve the existing Gruvbox and Gruvbox Light palette values and approved
  visual behavior unless the user explicitly changes that decision.
- Track portable desired state and generators. Do not track mutable session,
  device, cache, history, credential, or generated theme state.
- Cleanup must be scoped to state that a module can prove it owns. Report
  removal candidates before deleting packages or user data.
- Preserve unrelated worktree changes. Stage and commit only the verified
  logical batch being delivered.

## Project continuity

For long-running work, read `.agents/README.md` and keep its indexed files current. Use `project-continuity` when resuming, closing a verified batch, recovering after compaction, or preparing a handoff. When autonomous commits are authorized, repeat one logical batch: implement and update owning records, validate and test, stage only that batch, commit, then continue from one next action.
