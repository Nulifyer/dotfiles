# Testing and evidence

## Evidence standard

- `apply` must work in a temporary target home and a second run must converge.
- Cleanup tests prove only repository-owned links are removed and unrelated
  files remain.
- Theme validation renders every catalog theme through every adapter and checks
  the shared contrast baseline plus VS Code extension color mappings.
- Visual theme completion still requires direct inspection or screenshots.

## Fast checks

```text
bash -n dotfiles .dotfiles/lib.sh */apply.sh */reload.sh
python3 .theme/render.py --validate
python3 .tests/modules.py
fish .tests/project_picker.fish
git diff --check
```

## Full checks

```text
bash .tests/setup.sh
```

## Environment

- Primary target: CachyOS or Arch, Plasma, KWin, and Wayland.
- Baseline commands: Bash, Python 3, and a C compiler.
- Apply hooks must tolerate an absent live desktop bus for temporary homes.

## Known gaps

- There is no visual screenshot harness.
- Live reload has not been qualified for VS Code, OpenCode, or Brave.
- There is no disposable VM qualification.
