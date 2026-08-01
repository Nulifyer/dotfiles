---
name: debug-workflow
description: Use when diagnosing bugs, errors, failing tests, stack traces, regressions, crashes, unexpected behavior, or root cause analysis.
---

# Debug Workflow

Reproduce or localize before fixing when feasible. Prefer minimal root-cause fix over broad rewrite.

## Steps

1. Capture symptom exactly: command, error line, stack frame, input, environment.
2. Find recent or relevant code path.
3. Form one hypothesis.
4. Check with search, targeted read, focused test, or small reproduction.
5. Fix smallest root cause.
6. Verify with focused test or command.

## Search

Use exact error strings first.

Then search symbols from stack trace, failing test name, endpoint, or component.

Trace data flow across boundary where value changes shape or trust level.

## Anti-Patterns

Do not patch symptoms without explaining cause.

Do not add broad try/catch, sleeps, retries, or null guards unless cause justifies them.

Do not change tests to match broken behavior unless requirements changed.

## Report

Return:

- Root cause.
- Fix.
- Verification.
- Residual risk if not fully verified.
