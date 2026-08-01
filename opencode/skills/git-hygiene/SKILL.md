---
name: git-hygiene
description: Use when inspecting git status, diffs, commits, branches, pull requests, staging, commit messages, changelogs, or avoiding unrelated user changes.
---

# Git Hygiene

Treat worktree as shared. Never revert or overwrite changes you did not make unless user explicitly asks.

## Before Changes

For commit or PR work, inspect:

- `git status`.
- `git diff`.
- Recent commits.
- Branch and remote tracking if needed.

For ordinary edits, do not require git inspection unless it helps avoid conflicts.

## During Changes

Touch only files needed for task.

If a file has unrelated user changes, preserve them and edit around them.

If unexpected changes conflict with task, stop and ask.

Do not use destructive commands like reset, checkout, clean, or force push without explicit approval.

## Commit Messages

Use repo style when visible. Otherwise:

```text
type: concise summary
```

Common types: `fix`, `feat`, `docs`, `test`, `refactor`, `chore`.

Stage only intended files.

## Commit Workflow

When the assistant performed and verified the work in the current session, a
commit request should stay lightweight: inspect status, confirm the intended
staged diff, and commit. Do not launch a separate full code review solely
because the user requested a commit.

Do not launch `cavecrew-reviewer` during a commit workflow unless the user
explicitly asks for a code review.

## PRs

Review all commits included in PR, not just latest.

Summarize user-visible change, tests run, and risks.
