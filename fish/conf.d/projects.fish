# Project navigation and editor helpers.
#
# Real project directories live below Z_PROJECTS_ROOT, which defaults to
# ~/Projects. zlink creates a symlink elsewhere for software that expects the
# project at a specific path, such as ~/.config/fish.
#
# Commands:
#   z [NAME|PATH]             Change to a project
#   zopen [NAME|PATH]         Open a project in VS Code
#   zpick                     Search projects in a floating fzf picker
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

function __z_project_candidates
    set -l projects_root (__z_projects_root)
    test -d "$projects_root"; or return 1

    set -l name_color (set_color --bold normal)
    set -l path_color (set_color brblack)
    set -l reset_color (set_color normal)
    if set -q nulifyer_fzf_fg
        set name_color (set_color --bold "$nulifyer_fzf_fg")
    end
    if set -q nulifyer_fzf_muted
        set path_color (set_color "$nulifyer_fzf_muted")
    end

    for project in "$projects_root"/*/
        test -d "$project"; or continue

        set -l resolved (path resolve -- "$project")
        test -n "$resolved"; or continue

        set -l display_path "$resolved"
        if test "$resolved" = "$HOME"
            set display_path '~'
        else if string match -q "$HOME/*" -- "$resolved"
            set display_path '~/'(string replace "$HOME/" '' -- "$resolved")
        end

        set -l name (path basename "$project")
        set -l display_name (string replace -ar '[\t\r\n]+' ' ' -- "$name")
        set display_name (string shorten --max 22 -- "$display_name")
        set display_name (string pad --right --width 22 -- "$display_name")
        set display_path (string replace -ar '[\t\r\n]+' ' ' -- "$display_path")
        set display_path (string shorten --max 44 -- "$display_path")
        set -l encoded_name (string escape --style=var -- "$name")
        set -l encoded_path (string escape --style=var -- "$resolved")

        printf '%s%s%s  %s%s%s\t%s\t%s\n' \
            "$name_color" "$display_name" "$reset_color" \
            "$path_color" "$display_path" "$reset_color" \
            "$encoded_name" "$encoded_path"
    end
end

function __z_open_project_terminal --argument-names project
    set -l terminal
    if command -q kreadconfig6
        set terminal (command kreadconfig6 --file kdeglobals --group General \
            --key TerminalApplication 2>/dev/null)
    end
    if test -z "$terminal"; and set -q TERMINAL; and test -n "$TERMINAL"
        set terminal "$TERMINAL"
    end

    if test -z "$terminal"
        printf 'zpick: KDE default terminal is not configured\n' >&2
        return 1
    end
    if not command -q -- "$terminal"
        printf 'zpick: terminal not found: %s\n' "$terminal" >&2
        return 1
    end

    set -l previous_directory "$PWD"
    cd -- "$project"; or return
    if test (path basename "$terminal") = kitty
        command "$terminal" --detach >/dev/null 2>&1
        set -l terminal_status $status
    else
        command "$terminal" >/dev/null 2>&1 &
        set -l terminal_pid $last_pid
        disown "$terminal_pid"
        set -l terminal_status 0
    end
    cd -- "$previous_directory"; or return
    return "$terminal_status"
end

function zpick --description 'Search registered projects with fzf'
    if test (count $argv) -ne 0
        printf 'Usage: zpick\n' >&2
        return 2
    end
    if not command -q fzf
        printf 'zpick: fzf is required\n' >&2
        return 1
    end

    set -l projects_root (__z_projects_root)
    if not test -d "$projects_root"
        printf 'zpick: projects directory not found: %s\n' "$projects_root" >&2
        return 1
    end

    set -l selection (__z_project_candidates | command fzf \
        --delimiter='\t' \
        --ansi \
        --scheme=path \
        --with-nth='{1}' \
        --accept-nth='{3}' \
        --expect=enter,ctrl-e \
        --style=minimal \
        --layout=reverse \
        --highlight-line \
        --no-hscroll \
        --scroll-off=2 \
        --prompt='> ' \
        --info=inline-right \
        --footer='enter code  ·  ctrl-e terminal  ·  esc close' \
        --footer-border=none)
    set -l picker_status $pipestatus[2]

    switch "$picker_status"
        case 0
        case 1 130
            return 0
        case '*'
            printf 'zpick: fzf failed with status %s\n' "$picker_status" >&2
            return "$picker_status"
    end
    if test (count $selection) -lt 2
        return 0
    end

    set -l action "$selection[1]"
    set -l project (string unescape --style=var -- "$selection[2]")
    test -d "$project"; or begin
        printf 'zpick: project directory not found: %s\n' "$project" >&2
        return 1
    end

    switch "$action"
        case enter
            if not command -q code
                printf 'zpick: editor not found: code\n' >&2
                return 1
            end
            command code "$project" >/dev/null 2>&1
        case ctrl-e
            __z_open_project_terminal "$project"
    end
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
complete --command zlink --condition '__fish_is_nth_token 1' \
    --no-files --arguments '(__z_complete_projects)'
