#!/usr/bin/env bash

set -euo pipefail
source_file="$DOTFILES_ROOT/fish/tools/project_candidates.c"
target_dir="$DOTFILES_TARGET/.local/libexec/nulifyer"
target_file="$target_dir/project_candidates"
mkdir -p -- "$target_dir"
temporary="$(mktemp "$target_dir/.project_candidates.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT
cc -O2 -std=c17 -Wall -Wextra "$source_file" -o "$temporary"
chmod 755 "$temporary"
mv -fT -- "$temporary" "$target_file"
trap - EXIT
