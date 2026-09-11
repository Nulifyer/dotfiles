#!/usr/bin/env bash

set -euo pipefail

source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_is_live_target || exit 0

if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi
kbuildsycoca6 >/dev/null
