#!/usr/bin/env bash

set -euo pipefail
fish -n \
    "$DOTFILES_ROOT/fish/config.fish" \
    "$DOTFILES_ROOT/fish/conf.d/"*.fish \
    "$DOTFILES_ROOT/.tests/project_picker.fish"
python3 - "$DOTFILES_ROOT/fish/tools/project_candidates.py" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
compile(path.read_text(), path.name, "exec")
PY
fish "$DOTFILES_ROOT/.tests/project_picker.fish"
