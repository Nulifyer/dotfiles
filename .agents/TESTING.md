# Testing and evidence

## Evidence standard

- Fast checks must validate syntax, schemas, manifest ownership, generated
  output, and isolated deployment behavior without modifying the live home.
- Full checks may inspect live application state. They must identify existing
  drift separately from regressions introduced by the current batch.
- Visual theme completion requires screenshots or direct inspection of the
  named application states. A schema or contrast pass alone does not prove a
  theme looks correct.
- A passing app hook test proves only that hook's declared settings and cleanup
  ownership. It does not prove the rest of the application's mutable state.
- Cleanup tests use a temporary target home and must prove unrelated files are
  preserved.

## Fast checks

```text
git diff --check
python3 .theme/render.py --validate
python3 .theme/test_golden.py
bash -n dotfiles
python3 .tests/modules.py
```

## Full checks

```text
./dotfiles doctor
./dotfiles check
bash .tests/setup.sh
```

## Environment

- Primary environment is CachyOS with Plasma and KWin 6.7.4 on Wayland.
- Required baseline commands are Bash, Git, jq, Python 3, and sha256sum.
- App hooks must tolerate an absent live desktop bus when an isolated target is
  used.
- VS Code theme qualification currently targets 1.136.1 with Rainbow CSV
  3.24.1 and Git Graph 1.30.0.

## Known gaps

- There is no visual screenshot harness yet.
- Live reload has not been qualified for VS Code, OpenCode, or Brave.
- There is no package installation command or disposable VM qualification yet.

## Project notes

- Gruvbox golden fixtures must exist before changing renderer semantics.
