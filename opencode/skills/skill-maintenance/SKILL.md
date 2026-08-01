---
name: skill-maintenance
description: Use when creating, editing, compressing, auditing, or deleting opencode skills, agents, commands, or workflow memory. Covers SKILL.md frontmatter, terse procedural writing, and restart requirements.
---

# Skill Maintenance

Use for opencode procedural memory: skills, agents, commands, and related config.

## Scope

Skill paths:

- Global: `~/.config/opencode/skills/<name>/SKILL.md`
- Project: `.opencode/skills/<name>/SKILL.md`

Agent paths:

- Global: `~/.config/opencode/agent/<name>.md` or `agents/<name>.md`
- Project: `.opencode/agent/<name>.md` or `agents/<name>.md`

Command paths:

- Global: `~/.config/opencode/command/<name>.md` or `commands/<name>.md`
- Project: `.opencode/command/<name>.md` or `commands/<name>.md`

## Skill Format

Every skill needs:

```markdown
---
name: lowercase-hyphen-name
description: Use when <clear trigger keywords and task types>.
---

# Title

Instructions...
```

Rules:

- Folder name must match `name`.
- `description` should front-load trigger words users say.
- Use "Use when..." or "Use ONLY when...".
- Keep body procedural: routing, steps, checks, anti-patterns, output.
- Avoid broad philosophy.

## Writing Style

Default skill content: compact professional prose.

For terse operational skills:

- Short sections.
- Bullets over paragraphs.
- Concrete triggers.
- File paths and commands exact.
- State each instruction once.
- Remove filler and motivation prose.
- Keep warnings clear where ambiguity risks damage.

Good skill structure:

```markdown
# Name

One-line purpose.

## Use When

- Trigger A.
- Trigger B.

## Steps

1. Inspect X.
2. Edit Y.
3. Verify Z.

## Output

- What to report.
- What to omit.
```

## Maintenance Workflow

When user asks to create/update a skill:

1. Identify target scope: global or project.
2. Inspect existing nearby skills for style.
3. Draft minimal `SKILL.md`.
4. Preserve readable docs tone; compress only filler.
5. Validate frontmatter and folder/name match.
6. Remind user: restart opencode to load changed skills.

When user asks to compress a skill:

1. Keep exact tool names, paths, commands, and API names.
2. Remove repeated rationale.
3. Merge overlapping bullets.
4. Preserve safety warnings and validation steps.
5. Keep description specific enough for auto-selection.

When user asks to clean up skills:

1. List candidates.
2. Identify duplicates, stale tools, broad descriptions, and unused overlap.
3. Propose delete/merge/update before destructive edits.
4. Never delete without explicit confirmation.

## Periodic Cleanup

Run when skills feel noisy, after several new skills, or on request like "audit skills".

Classify each skill:

- Active: clear trigger, current tools, reusable workflow.
- Merge: overlaps another skill but has useful unique details.
- Compress: useful but verbose or repetitive.
- Stale: old paths, old APIs, obsolete tools, or outdated upstream assumptions.
- Archive: rarely used but might matter later.
- Delete: duplicate with no unique value, broken, or superseded.

Audit checklist:

1. Verify `name` matches folder.
2. Check `description` has narrow trigger words.
3. Find trigger collisions across skills.
4. Remove repeated rationale and examples that do not change behavior.
5. Preserve exact paths, commands, API names, safety warnings, and verification steps.
6. Prefer merge over delete when uncertain.
7. Ask before deleting or archiving.

Cleanup output format:

```text
Active:
- skill-a: keep because ...

Merge:
- skill-b into skill-c because ...

Compress:
- skill-d: remove duplicated sections ...

Stale:
- skill-e: references old path ...

Delete candidates:
- skill-f: duplicate, no unique procedure. Requires confirmation.
```

After approved cleanup:

- Edit only intended skill files.
- Summarize changed files.
- Remind restart required.

## Hot Reload Reality

Current opencode behavior:

- Skills/agents/commands are loaded at startup.
- New or edited skills may not affect current session.
- Restart opencode after edits.

Known upstream work:

- `anomalyco/opencode#8751` hot-reload agents, skills, commands.
- `anomalyco/opencode#34492` unified file watcher/hot reload service.

When hot reload lands, update this skill with exact command or config.

## Output

Report:

- Files changed.
- Validation done.
- Restart requirement.
- Any remaining risks.

Keep response terse.
