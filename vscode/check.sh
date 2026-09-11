#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
if dotfiles_is_kde; then
    dotfiles_kconfig check "$DOTFILES_ROOT/vscode/kde.json"
fi

if dotfiles_is_live_target && command -v code >/dev/null 2>&1; then
    installed="$(code --list-extensions --show-versions 2>/dev/null)"
    while IFS=$'\t' read -r extension version; do
        if ! grep -Fqx "$extension@$version" <<<"$installed"; then
            printf 'dotfiles: VS Code extension drift: expected %s@%s\n' \
                "$extension" "$version" >&2
            exit 1
        fi
    done < <(
        jq -r '.extensions[] | [.id, .tested_version] | @tsv' \
            "$DOTFILES_ROOT/vscode/extensions.json"
    )
fi
