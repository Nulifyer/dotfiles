#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_is_kde || exit 0
dotfiles_kconfig apply "$DOTFILES_ROOT/vscode/kde.json"
