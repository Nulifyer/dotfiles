#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"

if dotfiles_is_kde; then
    dotfiles_kconfig_set \
        kdeglobals General BrowserApplication brave-browser.desktop
fi

preferences="$DOTFILES_TARGET/.config/BraveSoftware/Brave-Browser/Default/Preferences"
[[ -f "$preferences" ]] || exit 0
temporary="$(mktemp "$preferences.tmp.XXXXXX")"
if ! jq '.browser.custom_chrome_frame = false' "$preferences" >"$temporary"; then
    unlink "$temporary"
    exit 1
fi
chmod --reference="$preferences" "$temporary"
mv -f -- "$temporary" "$preferences"
