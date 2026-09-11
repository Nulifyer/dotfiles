#!/usr/bin/env bash

set -uo pipefail

source "$DOTFILES_ROOT/.dotfiles/lib.sh"
failed=false
dotfiles_kconfig check "$DOTFILES_ROOT/kde/settings.json" || failed=true

state_root="$DOTFILES_ROOT/.theme/local"
if [[ ! -r "$state_root/kde-scheme" || ! -r "$state_root/variant" ]]; then
    printf 'dotfiles: generated KDE scheme state is missing\n' >&2
    failed=true
else
    IFS= read -r scheme <"$state_root/kde-scheme"
    IFS= read -r variant <"$state_root/variant"
    scheme_file="$DOTFILES_TARGET/.local/share/color-schemes/$scheme.colors"
    if [[ ! -r "$scheme_file" ]]; then
        printf 'dotfiles: linked KDE color scheme is missing: %s\n' \
            "$scheme_file" >&2
        failed=true
    else
        python3 "$DOTFILES_ROOT/.theme/check_kde.py" \
            "$scheme_file" "$DOTFILES_TARGET/.config/kdeglobals" || failed=true
    fi

    expected_icon=breeze-dark
    [[ "$variant" == light ]] && expected_icon=breeze
    actual_icon="$(
        kreadconfig6 --file "$DOTFILES_TARGET/.config/kdeglobals" \
            --group Icons --key Theme 2>/dev/null
    )"
    if [[ "$actual_icon" != "$expected_icon" ]]; then
        printf 'dotfiles: KDE drift: kdeglobals [Icons] Theme = %q; expected %q\n' \
            "$actual_icon" "$expected_icon" >&2
        failed=true
    fi
fi

[[ "$failed" == false ]]
