---
name: code-review
description: Use when reviewing code, PRs, diffs, branches, files, or asking for bugs, risks, regressions, missing tests, or review findings.
---

# Code Review

Review for behavior, not taste. Findings first. No praise unless user asks for summary.

## Priorities

Check in this order:

- Wrong output or changed behavior.
- Crashes, exceptions, null/undefined cases.
- Security issues and unsafe trust boundaries.
- Data loss, migration, persistence, or compatibility breaks.
- Race conditions, stale state, lifecycle bugs.
- Resource leaks and cleanup failures.
- Performance cliffs on realistic input sizes.
- Missing tests for changed behavior.
- Maintainability only when it creates concrete risk.

## Method

Inspect diff context before judging. Trace inputs, outputs, state mutation, error paths, and call sites.

Prefer exact file and line references. If line is uncertain, cite nearest stable line and explain context.

Do not report speculative issues. If intent is unclear, ask a question instead of inventing a bug.

Skip formatting and naming nits unless they change behavior or user asks for thorough style review.

## Output

For normal review:

```text
Findings
- path/file.ext:42 - Severity: problem. Fix.
```

For cavecrew reviewer, use that agent's compressed format.

If no findings:

```text
No findings. Residual risk: <untested area or not run>.
```

## Severity

High: crash, security hole, data loss, wrong core behavior.

Medium: edge-case bug, race, leak, perf cliff, missing guard.

Low: minor maintainability, naming, or test gap with limited blast radius.
