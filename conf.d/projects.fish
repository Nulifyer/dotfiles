# Project navigation and editor helpers.
#
# Real project directories live below Z_PROJECTS_ROOT, which defaults to
# ~/Projects. zlink creates a symlink elsewhere for software that expects the
# project at a specific path, such as ~/.config/fish.
#
# Commands:
#   z [NAME|PATH]             Change to a project
#   zopen [NAME|PATH]         Open a project in VS Code
#   zlink NAME PATH           Link PATH back to ~/Projects/NAME

function __z_projects_root
    if set -q Z_PROJECTS_ROOT; and test -n "$Z_PROJECTS_ROOT"
        printf '%s\n' (string trim --right --chars=/ -- "$Z_PROJECTS_ROOT")
    else
        printf '%s\n' "$HOME/Projects"
    end
end

function __z_resolve_project --argument-names project
    set -l projects_root (__z_projects_root)

    if test -z "$project"
        if test -d "$projects_root"
            path resolve -- "$projects_root"
            return
        end

        printf 'z: projects directory not found: %s\n' "$projects_root" >&2
        return 1
    end

    if test -d "$projects_root/$project"
        path resolve -- "$projects_root/$project"
        return
    end

    # Paths are accepted directly, but bare names remain project names so a
    # same-named directory in the current working directory cannot shadow one.
    if string match -qr '^(/|\./|\.\./)' -- "$project"; and test -d "$project"
        path resolve -- "$project"
        return
    end

    printf 'z: project not found: %s\n' "$project" >&2
    return 1
end

function z --description 'Jump to a registered project'
    if test (count $argv) -gt 1
        printf 'Usage: z [NAME|PATH]\n' >&2
        return 2
    end

    set -l project (__z_resolve_project "$argv[1]")
    or return
    cd -- "$project"
end

function zopen --description 'Open a registered project in the selected editor'
    if test (count $argv) -gt 1
        printf 'Usage: zopen [NAME|PATH]\n' >&2
        return 2
    end

    set -l project (__z_resolve_project "$argv[1]")
    or return

    set -l editor code
    if set -q Z_PROJECT_EDITOR; and test -n "$Z_PROJECT_EDITOR"
        set editor "$Z_PROJECT_EDITOR"
    end

    if not command -q -- "$editor"
        printf 'zopen: editor not found: %s\n' "$editor" >&2
        return 1
    end

    command "$editor" "$project"
end

function zlink --description 'Link another path back to a real project'
    if test (count $argv) -ne 2
        printf 'Usage: zlink PROJECT PATH\n' >&2
        return 2
    end

    set -l name "$argv[1]"
    set -l link_path (string trim --right --chars=/ -- "$argv[2]")

    if not string match -qr '^[^/]+$' -- "$name"; or contains -- "$name" . ..
        printf 'zlink: project name must be a single directory name\n' >&2
        return 2
    end

    if test -z "$link_path"
        printf 'zlink: link path cannot be empty\n' >&2
        return 2
    end

    set -l projects_root (__z_projects_root)
    set -l project "$projects_root/$name"
    if not test -d "$project"; or test -L "$project"
        printf 'zlink: real project directory not found: %s\n' "$project" >&2
        return 1
    end
    set project (path resolve -- "$project")

    set -l link_parent (path dirname "$link_path")
    command mkdir -p -- "$link_parent"
    or return
    set link_parent (path resolve -- "$link_parent")
    set link_path "$link_parent/"(path basename "$link_path")

    if test -e "$link_path"; or test -L "$link_path"
        if test -L "$link_path"; and \
                test (path resolve -- "$link_path" 2>/dev/null) = "$project"
            printf 'zlink: %s already links to %s\n' "$link_path" "$project"
            return
        end

        printf 'zlink: path already exists: %s\n' "$link_path" >&2
        return 1
    end

    command ln -s -- "$project" "$link_path"
    or return
    printf 'zlink: linked %s -> %s\n' "$link_path" "$project"
end

function __z_complete_projects
    set -l projects_root (__z_projects_root)
    for project in "$projects_root"/*/
        set -l resolved (path resolve -- "$project")
        set -l display_path "$resolved"
        if test "$resolved" = "$HOME"
            set display_path '~'
        else if string match -q "$HOME/*" -- "$resolved"
            set display_path '~/'(string replace "$HOME/" '' -- "$resolved")
        end

        printf '%s\t%s\n' (path basename "$project") "$display_path"
    end
end

complete --command z --no-files --arguments '(__z_complete_projects)'
complete --command zopen --no-files --arguments '(__z_complete_projects)'
