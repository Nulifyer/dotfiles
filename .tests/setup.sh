#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
    pwd -P
)"
readonly REPOSITORY_ROOT
test_root="$(mktemp -d)"

cleanup() {
    find "$test_root" -depth -type f -exec unlink -- {} + 2>/dev/null || true
    find "$test_root" -depth -type l -exec unlink -- {} + 2>/dev/null || true
    find "$test_root" -depth -type d -empty -exec rmdir -- {} + 2>/dev/null || true
}
trap cleanup EXIT

export DOTFILES_DESKTOP=kde
export DOTFILES_TARGET="$test_root"
"$REPOSITORY_ROOT/dotfiles"

obsolete="$test_root/.config/kitty/obsolete.conf"
ln -s "$REPOSITORY_ROOT/README.md" "$obsolete"
nested_obsolete="$test_root/.vscode/extensions/nulifyer.nulifyer-theme-1.2.0/themes/obsolete.json"
ln -s "$REPOSITORY_ROOT/README.md" "$nested_obsolete"
"$REPOSITORY_ROOT/dotfiles"
if [[ -e "$obsolete" || -L "$obsolete" ||
    -e "$nested_obsolete" || -L "$nested_obsolete" ]]; then
    printf 'dotfiles: apply did not remove an obsolete managed link\n' >&2
    exit 1
fi

if "$REPOSITORY_ROOT/dotfiles" apply >/dev/null 2>&1; then
    printf 'dotfiles: legacy subcommand was accepted\n' >&2
    exit 1
fi
if DOTFILES_THEME=definitely-not-a-theme \
    "$REPOSITORY_ROOT/dotfiles" >/dev/null 2>&1; then
    printf 'dotfiles: invalid theme override was accepted\n' >&2
    exit 1
fi

printf 'Isolated apply convergence and cleanup passed.\n'
