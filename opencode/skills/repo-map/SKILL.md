---
name: repo-map
description: Use when entering an unfamiliar repository, locating project structure, finding entrypoints, package manager, test commands, architecture, or where work should happen.
---

# Repo Map

Build just enough map to work safely. Do not exhaustively read the repo.

## First Pass

Find:

- Root config: package, workspace, build, language, framework.
- Source directories and app entrypoints.
- Test directories and test framework.
- Scripts for lint, typecheck, test, build.
- Existing conventions near target area.
- Generated files and vendored directories to avoid.

## Search Order

Use file names first:

- `README*`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING*`.
- `package.json`, `pnpm-workspace.yaml`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`, `build.gradle`, `.csproj`.
- `src/**`, `app/**`, `lib/**`, `tests/**`, `test/**`, `spec/**`.

Then search symbols and strings relevant to task.

## Output

Return compact map:

```text
Stack: <languages/frameworks>
Entrypoints: <paths>
Tests: <paths and commands>
Conventions: <observed rules>
Likely files: <paths>
Risk: <unknowns>
```

Prefer file references over broad explanation.
