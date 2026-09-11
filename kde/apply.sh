#!/usr/bin/env bash

set -euo pipefail

source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_kconfig apply "$DOTFILES_ROOT/kde/settings.json"

state_root="$DOTFILES_ROOT/.theme/local"
IFS= read -r scheme <"$state_root/kde-scheme"
IFS= read -r variant <"$state_root/variant"
scheme_file="$DOTFILES_TARGET/.local/share/color-schemes/$scheme.colors"
if [[ ! -r "$scheme_file" ]]; then
    printf 'dotfiles: linked KDE color scheme is missing: %s\n' \
        "$scheme_file" >&2
    exit 1
fi

icon_theme=breeze-dark
[[ "$variant" == light ]] && icon_theme=breeze
kwriteconfig6 --file "$DOTFILES_TARGET/.config/kdeglobals" \
    --group Icons --key Theme -- "$icon_theme"

if dotfiles_is_live_target; then
    current_scheme="$(
        kreadconfig6 --file "$DOTFILES_TARGET/.config/kdeglobals" \
            --group General --key ColorScheme
    )"
    kwriteconfig6 --file "$DOTFILES_TARGET/.config/kdeglobals" \
        --group General --key ColorScheme -- __nulifyer_refresh__
    if ! plasma-apply-colorscheme "$scheme" >/dev/null; then
        kwriteconfig6 --file "$DOTFILES_TARGET/.config/kdeglobals" \
            --group General --key ColorScheme -- "$current_scheme"
        exit 1
    fi
else
    python3 "$DOTFILES_ROOT/kde/apply_scheme.py" \
        "$scheme_file" "$DOTFILES_TARGET/.config/kdeglobals"
fi
