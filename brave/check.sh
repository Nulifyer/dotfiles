#!/usr/bin/env bash

set -uo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
failed=false

if dotfiles_is_kde; then
    dotfiles_kconfig check "$DOTFILES_ROOT/brave/kde.json" || failed=true
fi

preferences="$DOTFILES_TARGET/.config/BraveSoftware/Brave-Browser/Default/Preferences"
if [[ -f "$preferences" ]] && \
    ! jq -e '.browser.custom_chrome_frame == false' "$preferences" >/dev/null; then
    printf 'dotfiles: Brave drift: browser.custom_chrome_frame is not false\n' >&2
    failed=true
fi

[[ "$failed" == false ]]
