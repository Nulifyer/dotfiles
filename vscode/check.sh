#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
if dotfiles_is_kde; then
    dotfiles_kconfig check "$DOTFILES_ROOT/vscode/kde.json"
fi

if dotfiles_is_live_target && command -v code >/dev/null 2>&1; then
    code --list-extensions --show-versions 2>/dev/null |
        grep -q '^nulifyer\.nulifyer-theme@1\.2\.0$'
fi
