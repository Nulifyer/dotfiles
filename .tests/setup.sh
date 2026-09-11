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
"$REPOSITORY_ROOT/dotfiles" link
"$REPOSITORY_ROOT/dotfiles" apply
"$REPOSITORY_ROOT/dotfiles" check
"$REPOSITORY_ROOT/dotfiles" unlink

if find "$test_root" -type l -print -quit | grep -q .; then
    printf 'dotfiles: managed links remained after isolated unlink\n' >&2
    exit 1
fi

printf 'Isolated setup round-trip passed.\n'
