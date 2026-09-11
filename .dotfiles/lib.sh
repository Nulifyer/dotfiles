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

dotfiles_kconfig_set() {
    local file=$1
    local group=$2
    local key=$3
    local value=$4
    file="$DOTFILES_TARGET/.config/$file"
    mkdir -p -- "$(dirname -- "$file")"
    kwriteconfig6 --file "$file" --group "$group" --key "$key" -- "$value"
}

dotfiles_kconfig_add() {
    local file=$1
    local group=$2
    local key=$3
    local value=$4
    local current item
    local -a items=()
    file="$DOTFILES_TARGET/.config/$file"
    current="$(kreadconfig6 --file "$file" --group "$group" --key "$key" 2>/dev/null)"
    IFS=',' read -ra items <<<"$current"
    for item in "${items[@]}"; do
        [[ "$item" == "$value" ]] && return
    done
    [[ -z "$current" ]] || current+=,
    mkdir -p -- "$(dirname -- "$file")"
    kwriteconfig6 --file "$file" --group "$group" --key "$key" -- "$current$value"
}
