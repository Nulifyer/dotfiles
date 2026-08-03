---
name: skill-maintenance
description: Use when user explicitly requests creating, editing, auditing, merging, archiving, or deleting OpenCode skills, agents, commands, prompts, or workflow memory, or when skill-development delegates package authoring and validation. Applies local conventions while deferring current schema and path rules to OpenCode's built-in customization skill.
---

# Skill Maintenance

Maintain reusable OpenCode instructions with minimal duplication and clear triggers.

## Source Of Truth

Load the built-in `customize-opencode` skill for current schema, supported fields, discovery paths, permissions, and restart behavior. Fetch `https://opencode.ai/config.json` before writing any uncertain config shape.

This skill owns only local organization, writing style, and audit decisions.

## Coordination

For evidence-backed proposals, repeated workflows, recurring failures, candidate lifecycles, or autonomous improvement suggestions, load `skill-development`. It owns proposal rationale, evidence thresholds, change classification, review boundaries, and activation state.

When `skill-development` delegates here, perform only requested package inspection, drafting, editing, validation, or retirement. Do not duplicate candidate state, infer approval, activate an unreviewed draft, or restart OpenCode from inside a tool call.

## Create Or Update

1. Choose global or project scope.
2. Inspect nearby definitions and avoid duplicate IDs.
3. Put non-trivial agents, commands, and skills in separate files instead of expanding `opencode.jsonc`.
4. Keep each definition focused on one reusable workflow.
5. Validate the resolved config and loaded skill list.
6. After an approved config-time change, call `vscode_request_opencode_reload` once when available. Otherwise mark change pending restart and tell user to quit and restart OpenCode.

For `SKILL.md`:

- Match folder name and frontmatter `name`.
- Use lowercase hyphenated names.
- Put concrete user triggers and task types in `description`.
- Keep the body procedural: routing, steps, safety, verification, and output.
- State each instruction once. Assume the model already knows general software engineering.
- Keep exact commands, paths, APIs, and safety boundaries.
- Move large or optional detail into directly linked references only when needed.

For agents:

- Use narrow descriptions and explicit `mode`.
- Restrict tools and permissions to the role's actual work.
- Pin model and variant only when the role needs a stable cost, latency, or quality tier.
- Keep delegation policy in one place; do not duplicate full routing rules across the primary agent and skills.

## Audit

Classify every definition:

- **Active:** narrow trigger, current tools, reusable procedure.
- **Merge:** overlapping trigger with useful unique content.
- **Compress:** useful but repeats general behavior or another prompt.
- **Stale:** obsolete path, field, tool, package, or upstream assumption.
- **Archive:** valid but rarely needed.
- **Delete:** broken or fully superseded; require confirmation.

Check:

1. Folder and frontmatter names match.
2. Descriptions distinguish neighboring skills.
3. Bodies contain non-obvious procedure rather than generic advice.
4. Primary-agent instructions do not duplicate skill catalogs or bodies.
5. Specialized safety and verification rules survive compression.
6. Package versions and external commands are reproducible.
7. Config resolves and skills load after edits.

Never archive or delete without explicit approval.

## Output

Report changed files, validation performed, restart requirement, and remaining risks. For audits, list Active, Merge, Compress, Stale, Archive, Delete, trigger collisions, and recommended edits.
