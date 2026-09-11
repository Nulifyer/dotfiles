#!/usr/bin/env bash

set -uo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_is_kde || exit 0

failed=false
dotfiles_kconfig check "$DOTFILES_ROOT/applications/kde.json" || failed=true

breeze="$DOTFILES_TARGET/.config/breezerc"
exception_group=''
for ((index = 0; index < 100; index++)); do
    group="Windeco Exception $index"
    pattern="$(kreadconfig6 --file "$breeze" --group "$group" \
        --key ExceptionPattern 2>/dev/null)"
    if [[ "$pattern" == nulifyer-project-picker ]]; then
        exception_group=$group
        break
    fi
done
if [[ -z "$exception_group" ]]; then
    printf 'dotfiles: Breeze project picker exception is missing\n' >&2
    failed=true
else
    for entry in 'Enabled|true' 'ExceptionType|0' 'HideTitleBar|true' 'Mask|0'; do
        IFS='|' read -r key expected <<<"$entry"
        actual="$(kreadconfig6 --file "$breeze" --group "$exception_group" \
            --key "$key" 2>/dev/null)"
        if [[ "$actual" != "$expected" ]]; then
            printf 'dotfiles: KDE drift: breezerc [%s] %s = %q; expected %q\n' \
                "$exception_group" "$key" "$actual" "$expected" >&2
            failed=true
        fi
    done
fi

if dotfiles_is_live_target && command -v qdbus6 >/dev/null 2>&1 && \
    qdbus6 org.kde.kglobalaccel >/dev/null 2>&1; then
    actions="$(
        qdbus6 --literal org.kde.kglobalaccel /kglobalaccel \
            org.kde.KGlobalAccel.allActionsForComponent \
            nulifyer-project-picker.desktop 2>/dev/null
    )" || true
    if [[ "$actions" != *'"_launch"'* ]]; then
        printf 'dotfiles: KDE project picker shortcut is not registered\n' >&2
        failed=true
    fi
fi

[[ "$failed" == false ]]
