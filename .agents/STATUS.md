# Project status

State: active

## Project state

The repository is being simplified around one idempotent `apply` path. App
folders still own deployment and app-specific settings, but redundant schema,
golden, validation, check, and integration-inventory files are being removed.
KDE owns theme activation only; generic Plasma preferences are no longer
tracked.

## Current batch

The simplified apply path, flat VS Code theme ownership, and native project
scanner are implemented and ready for delivery.

## In progress

- `apply` renders the selected theme, reconciles deployments, removes obsolete
  repository links, applies app settings, and reloads supported apps.
- Manifests omit repeated name, version, schema, file-kind, and link-method
  fields.
- VS Code theme maps live directly under `vscode/`; Rainbow CSV and Git Graph
  remain part of the generated theme.
- The project scanner is generated locally from portable C source.

## Next action

Resume the palette provenance and non-Gruvbox light-theme contrast audit.

## Blockers

- None.

## Verification

- The isolated test ran `apply` twice, removed flat and nested obsolete links,
  then completed `unlink` without leaving managed links.
- Theme validation rendered all catalog entries and checked the shared contrast
  and VS Code integration rules.
- The native scanner matched the previous scanner's output and passed the
  project fixture.
