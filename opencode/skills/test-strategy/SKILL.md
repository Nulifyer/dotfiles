---
name: test-strategy
description: Use when adding, updating, selecting, or running tests; when user asks for verification, regression coverage, test gaps, failing tests, lint, typecheck, or CI commands.
---

# Test Strategy

Test changed behavior with smallest useful scope. Avoid slow broad runs unless needed.

## Discover

Find test framework and commands from repo config before inventing commands.

Check nearby tests for style, fixtures, naming, mocks, and assertions.

Prefer existing helper patterns over new helpers.

## Add Tests

Add regression test when fixing a bug and test harness exists.

Test public behavior, not implementation details, unless code has no public seam.

Keep test narrow but meaningful:

- One success path if new behavior.
- One failure or edge path for bug fix.
- One authorization/security path when relevant.

Do not add flaky time, network, or sleeps when deterministic alternative exists.

## Run Tests

Run focused tests first:

- Specific test file.
- Specific test name.
- Package-level test.

Then run broader lint/typecheck/test only if change risk justifies it or user asks.

## Report

Report:

- What was run.
- Pass/fail result.
- If not run, exact reason.
- Residual risk.
