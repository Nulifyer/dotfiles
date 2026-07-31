---
description: Audit opencode skills for duplicates, stale content, trigger collisions, and compression opportunities.
---

Use the `skill-maintenance` skill if available.

Audit opencode skills in these locations:

- Global: `~/.config/opencode/skills/*/SKILL.md`
- Project: `.opencode/skills/*/SKILL.md`

Do not edit files unless I explicitly approve changes.

Return:

```text
Active:
- skill-name: why keep

Merge:
- source -> target: why

Compress:
- skill-name: what to remove/condense

Stale:
- skill-name: stale path/tool/assumption

Archive candidates:
- skill-name: why archive

Delete candidates:
- skill-name: why delete; requires confirmation

Trigger collisions:
- skill-a / skill-b: overlapping descriptions/triggers

Recommended next edits:
1. ...
```

Check each skill for:

1. Folder name matches frontmatter `name`.
2. `description` starts with concrete trigger terms and is not too broad.
3. Body has reusable procedure, not one-off notes.
4. Exact commands, paths, APIs, safety warnings, and verification steps are preserved.
5. Duplicate or overlapping skills can be merged.
6. Verbose skills can be compressed in cavecrew style.

Extra focus from arguments: `$ARGUMENTS`
