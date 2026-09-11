#!/usr/bin/env bash

set -euo pipefail
python3 - <<PY
import pathlib
import tomllib

for name in (
    "$DOTFILES_ROOT/alacritty/alacritty.toml",
    "$DOTFILES_ROOT/alacritty/theme.generated.toml",
):
    with pathlib.Path(name).open("rb") as stream:
        tomllib.load(stream)
PY
