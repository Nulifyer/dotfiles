#!/usr/bin/env bash

set -euo pipefail

theme_root="$DOTFILES_ROOT/vscode/theme"
jq -e 'length == 425' "$theme_root/workbench.json" >/dev/null
jq -e 'length == 800' "$theme_root/tokens.json" >/dev/null
jq -e 'length == 62' "$theme_root/semantic.json" >/dev/null
jq -e '
    .version == 1 and
    (.extensions | length) == 3 and
    all(.extensions[];
        (.id | test("^[a-z0-9-]+\\.[a-z0-9-]+$")) and
        (.tested_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        (.purpose | length) > 0)
' "$DOTFILES_ROOT/vscode/extensions.json" >/dev/null

python3 - "$theme_root/render.py" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
compile(path.read_text(), path.name, "exec")
PY
python3 "$theme_root/test.py"
