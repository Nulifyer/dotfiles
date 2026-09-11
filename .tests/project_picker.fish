#!/usr/bin/env fish

function fail --argument-names fixture message
    command rm -rf -- "$fixture"
    printf 'project picker test failed: %s\n' "$message" >&2
    exit 1
end

set -l fixture (command mktemp -d)
or exit 1
set -l fixture_home "$fixture/home"
set -l linked_project "$fixture/linked-project"

command mkdir -p \
    "$linked_project/.git" \
    "$fixture_home/Projects/alpha" \
    "$fixture_home/Projects/bravo" \
    "$fixture_home/.agents/.git" \
    "$fixture_home/work/editor/.git" \
    "$fixture_home/work/editor/.vscode" \
    "$fixture_home/work/outer/.git" \
    "$fixture_home/work/outer/nested/.git" \
    "$fixture_home/unmarked/project/.jj" \
    "$fixture_home/markers/worktree" \
    "$fixture_home/markers/vscode/.vscode" \
    "$fixture_home/markers/hg/.hg" \
    "$fixture_home/markers/svn/.svn" \
    "$fixture_home/markers/idea/.idea" \
    "$fixture_home/markers/devcontainer/.devcontainer" \
    "$fixture_home/node_modules/ignored/.git" \
    "$fixture_home/.cache/ignored/.git" \
    "$fixture_home/.local/ignored/.git" \
    "$fixture_home/.tmp/ignored/.git" \
    "$fixture_home/go/pkg/ignored/.git" \
    "$fixture_home/.git" \
    "$fixture_home/.vscode"
or fail "$fixture" 'could not create fixture'
command touch "$fixture_home/markers/worktree/.git"
or fail "$fixture" 'could not create worktree marker'
command ln -s -- "$linked_project" "$fixture_home/Projects/linked"
or fail "$fixture" 'could not create project symlink'
command ln -s -- "$linked_project" "$fixture_home/Projects/linked-duplicate"
or fail "$fixture" 'could not create duplicate project symlink'

set -gx HOME "$fixture_home"
set -gx Z_PROJECTS_ROOT "$fixture_home/Projects"
set -l test_directory (path dirname (status filename))
set -l scanner_dir "$fixture_home/.local/libexec/nulifyer"
command mkdir -p "$scanner_dir"
or fail "$fixture" 'could not create scanner directory'
command cc -O2 -std=c17 -Wall -Wextra \
    "$test_directory/../fish/tools/project_candidates.c" \
    -o "$scanner_dir/project_candidates"
or fail "$fixture" 'could not compile project scanner'
source (path normalize "$test_directory/../fish/conf.d/projects.fish")

set -l projects (__z_project_paths | string split0)
set -l expected_primary \
    "$fixture_home/Projects/alpha" \
    "$fixture_home/Projects/bravo" \
    "$fixture_home/Projects/linked-duplicate"

test (count $projects) -eq 13
or fail "$fixture" "expected 13 candidates, got "(count $projects)

for index in 1 2 3
    test "$projects[$index]" = "$expected_primary[$index]"
    or fail "$fixture" \
        "primary candidate $index was $projects[$index] instead of $expected_primary[$index]"
end

not contains -- "$fixture_home/Projects/linked" $projects
or fail "$fixture" 'duplicate resolved project was emitted'

for expected in \
        "$fixture_home/.agents" \
        "$fixture_home/work/editor" \
        "$fixture_home/work/outer" \
        "$fixture_home/unmarked/project" \
        "$fixture_home/markers/worktree" \
        "$fixture_home/markers/vscode" \
        "$fixture_home/markers/hg" \
        "$fixture_home/markers/svn" \
        "$fixture_home/markers/idea" \
        "$fixture_home/markers/devcontainer"
    contains -- "$expected" $projects
    or fail "$fixture" "missing candidate: $expected"
end

for unexpected in \
        "$fixture_home" \
        "$fixture_home/work/outer/nested" \
        "$fixture_home/node_modules/ignored" \
        "$fixture_home/.cache/ignored" \
        "$fixture_home/.local/ignored" \
        "$fixture_home/.tmp/ignored" \
        "$fixture_home/go/pkg/ignored"
    not contains -- "$unexpected" $projects
    or fail "$fixture" "unexpected candidate: $unexpected"
end

command rm -rf -- "$fixture"
printf 'Project picker tests passed.\n'
