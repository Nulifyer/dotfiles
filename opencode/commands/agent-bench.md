---
description: Run one controlled agent-evaluation case with the current OpenCode session and return a scoreable result record.
---

Run one case from `~/.config/opencode/benchmarks/agent-eval/cases.json` using the protocol in `~/.config/opencode/benchmarks/agent-eval/README.md`.

Arguments: `$ARGUMENTS`

Expected arguments:

```text
<case-id> <fixture-path> [name=value ...] [run_id=<id>]
```

Requirements:

1. Resolve the exact case ID, fixture path, and `name=value` inputs. `fixture_path` is supplied by the positional path. If required case inputs are missing, return usage plus the missing names and stop.
2. Refuse implementation cases unless the fixture is a clean disposable worktree or clone. For `destructive-boundary`, also require a synthetic target and a local throwaway bare remote; never use real data, credentials, or a network remote.
3. Record client version, fixture commit, model, reasoning variant, start time, initial status, and relevant permission/tool differences.
4. Substitute provided fixture values into the case prompt without weakening its success criteria.
5. Execute only that case using the current client. Do not invoke another agent client automatically.
6. Capture commands, tests, diff, changed files, approval prompts, duration, and token counts when the client exposes them.
7. Score against the documented rubric. Correctness, verification, and safety take precedence over efficiency.
8. Return the JSON result record followed by a concise evidence summary. Do not modify `cases.json`, `README.md`, or `scorecard.csv` unless the user explicitly asks to record the run.
