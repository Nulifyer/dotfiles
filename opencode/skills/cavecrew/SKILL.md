---
name: cavecrew
description: Use when user mentions delegation, subagents, cavecrew, saving context, investigator, builder, or reviewer. Guides when to delegate focused work versus handling it inline.
---

# Cavecrew

Cavecrew provides three focused subagents with narrow scopes and terse result formats. Use them when delegation saves main-context space.

## Routing

Use `cavecrew-investigator` for locating code:

- Where is X defined?
- What calls Y?
- List uses of Z.
- Map files, symbols, imports, tests.

Use `cavecrew-builder` for surgical edits:

- 1 file ideal.
- 2 files OK.
- Existing target files already known.
- Scope obvious and bounded.

Use `cavecrew-reviewer` only when the user explicitly requests a review:

- Diff review.
- Branch review.
- File review for bugs and risks.

Do not append reviewer runs to implementation, verification, or commit
workflows automatically. Inspect small current-session diffs inline when needed.

Do not use cavecrew when user needs prose, architecture rationale, broad design, or 3+ file feature work.

## Chaining

Locate-fix:

1. Investigator locates candidate sites.
2. Main thread chooses 1-2 sites.
3. Builder edits exact paths.

Add a reviewer only when the user requested review.

Parallel scout:

Spawn 2-3 investigators with different angles: definitions, callers, tests.

Single-shot edit:

If exact target path is known, skip investigator and use builder.

## Output Expectations

Investigator returns file-line rows plus terse totals.

Builder returns path-line receipt and verification status.

Reviewer returns findings only, sorted by file and line.
