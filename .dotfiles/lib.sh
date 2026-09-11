#!/usr/bin/env bash

dotfiles_desktop() {
    if [[ -n "${DOTFILES_DESKTOP:-}" ]]; then
        printf '%s\n' "${DOTFILES_DESKTOP,,}"
        return
    fi
    local current=${XDG_CURRENT_DESKTOP:-unknown}
    current="${current,,}"
    if [[ ":$current:" == *:kde:* || ":$current:" == *:plasma:* ]]; then
        printf '%s\n' kde
    else
        printf '%s\n' "${current%%:*}"
    fi
}

dotfiles_is_kde() {
    [[ "$(dotfiles_desktop)" == kde ]]
}

dotfiles_is_live_target() {
    [[ "$(readlink -f -- "$DOTFILES_TARGET")" == "$(readlink -f -- "$HOME")" ]]
}

dotfiles_kconfig() {
    python3 "$DOTFILES_ROOT/.dotfiles/kconfig.py" "$1" "$2"
}
