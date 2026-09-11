#!/usr/bin/env bash

set -euo pipefail
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$DOTFILES_ROOT/zsh/zshrc"
fi
