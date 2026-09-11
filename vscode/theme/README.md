# VS Code theme templates

This app-owned directory defines the Nulifyer VS Code theme generation model:

- `workbench.json`: 425 workbench and extension color keys
- `tokens.json`: 800 TextMate scope rules, including Rainbow CSV columns
- `semantic.json`: 62 semantic token rules

They are maintained as part of this repository. `.theme/render.py` resolves
their app-property mappings against the shared semantic `roles` in the selected
root `colors.json` entry. The name is intentional: status, interaction, and
version-control meaning is shared by other adapters and is not owned by VS
Code.

`./dotfiles theme NAME` writes the ignored local extension into the `vscode`
Stow package. `package.json` is its tracked template; the other three files are
renderer inputs.

The generated extension also contributes the current palette as Git Graph's
default 12-color branch cycle. `vscode/extensions.json` pins the extension
versions against which these integration points were inspected.
