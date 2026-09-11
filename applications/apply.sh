#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_is_kde || exit 0

dotfiles_kconfig apply "$DOTFILES_ROOT/applications/kde.json"

breeze="$DOTFILES_TARGET/.config/breezerc"
exception_group=''
first_free=''
for ((index = 0; index < 100; index++)); do
    group="Windeco Exception $index"
    pattern="$(kreadconfig6 --file "$breeze" --group "$group" \
        --key ExceptionPattern 2>/dev/null)"
    if [[ "$pattern" == nulifyer-project-picker ]]; then
        exception_group=$group
        break
    fi
    enabled="$(kreadconfig6 --file "$breeze" --group "$group" \
        --key Enabled 2>/dev/null)"
    if [[ -z "$first_free" && -z "$enabled" && -z "$pattern" ]]; then
        first_free=$group
    fi
done
exception_group=${exception_group:-$first_free}
if [[ -z "$exception_group" ]]; then
    printf 'dotfiles: no free Breeze window exception slot\n' >&2
    exit 1
fi

for entry in \
    'Enabled|true' \
    'ExceptionPattern|nulifyer-project-picker' \
    'ExceptionType|0' \
    'HideTitleBar|true' \
    'Mask|0'; do
    IFS='|' read -r key value <<<"$entry"
    kwriteconfig6 --file "$breeze" --group "$exception_group" \
        --key "$key" -- "$value"
done

if dotfiles_is_live_target && command -v qdbus6 >/dev/null 2>&1 && \
    qdbus6 org.kde.kglobalaccel >/dev/null 2>&1; then
    action_id="['nulifyer-project-picker.desktop', '_launch', "
    action_id+="'Project Picker', 'Project Picker']"
    # QKeySequence's portable integer encoding for Ctrl+Alt+P.
    gdbus call --session \
        --dest org.kde.kglobalaccel \
        --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcut \
        "$action_id" \
        '[201326672]' >/dev/null
fi
