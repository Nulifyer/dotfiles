# VS Code role templates

These JSON files preserve the PowerShell theme switcher's VS Code generation
model as data:

- `workbench.json`: 422 workbench color keys and their palette roles
- `tokens.json`: 790 TextMate scope rules
- `semantic.json`: 62 semantic token rules

They were extracted from `Scripts/_lib/TerminalConfig.ps1` at upstream commit
`1fc75fee832328ae28eeac7d92978953f9f3b1f5`. The Linux renderer resolves the
roles against whichever entry is selected from `colors.json`.

`package.json` is copied into the generated local extension. The other three
files are renderer inputs and are not copied.
