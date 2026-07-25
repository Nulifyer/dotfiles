# VS Code theme templates

These tracked JSON files define the Nulifyer VS Code theme generation model:

- `workbench.json`: 422 workbench color keys and their palette roles
- `tokens.json`: 790 TextMate scope rules
- `semantic.json`: 62 semantic token rules

They are maintained as part of this repository. `.theme/render.py` resolves
their roles against the selected entry in the root `colors.json`.

`./dotfiles theme NAME` writes the ignored local extension into the `vscode`
Stow package. `package.json` is its tracked template; the other three files are
renderer inputs.
