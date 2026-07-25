# Shared theme state, prompt, and `theme` command.
#
# The palette is generated outside the repository so switching themes does not
# modify tracked files. Gruvbox values below are startup fallbacks only.

set -g nulifyer_prompt_os 746A62
set -g nulifyer_prompt_user D8A657
set -g nulifyer_prompt_path E78A4E
set -g nulifyer_prompt_git A9B665
set -g nulifyer_prompt_ok A9B665
set -g nulifyer_prompt_err EA6962
set -g nulifyer_prompt_duration D8A657
set -g nulifyer_prompt_end 746A62

set -l nulifyer_theme_state
if set -q XDG_STATE_HOME
    set nulifyer_theme_state "$XDG_STATE_HOME/nulifyer/theme"
else
    set nulifyer_theme_state ~/.local/state/nulifyer/theme
end
if test -r "$nulifyer_theme_state/fish.fish"
    source "$nulifyer_theme_state/fish.fish"
end

function __theme_catalog
    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME ~/.config
    printf '%s\n' "$XDG_CONFIG_HOME/nulifyer/themes/colors.json"
end

function __theme_state_root
    if set -q XDG_STATE_HOME
        printf '%s\n' "$XDG_STATE_HOME/nulifyer/theme"
    else
        printf '%s\n' ~/.local/state/nulifyer/theme
    end
end

function __theme_current
    set -l current_file (__theme_state_root)/current
    if test -r "$current_file"
        string trim <"$current_file"
    else
        printf '%s\n' gruvbox
    end
    return 0
end

function __theme_apply_desktop --argument-names state_root
    if set -q KITTY_PID
        command kill -USR1 "$KITTY_PID" 2>/dev/null
    end

    set -l scheme_file "$state_root/kde-scheme"
    if test -r "$scheme_file"; and type -q plasma-apply-colorscheme
        set -l scheme (string trim <"$scheme_file")
        plasma-apply-colorscheme "$scheme" >/dev/null

        if type -q kwriteconfig6
            set -l variant (string trim <"$state_root/variant")
            set -l icon_theme breeze-dark
            if test "$variant" = light
                set icon_theme breeze
            end
            kwriteconfig6 --file kdeglobals --group Icons --key Theme \
                -- "$icon_theme"
        end

        if type -q qdbus6
            qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
        end
    end
end

function theme --description 'Apply a shared terminal, editor, shell, and KDE theme'
    set -l catalog (__theme_catalog)
    set -l state_root (__theme_state_root)
    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME ~/.config
    set -l renderer "$XDG_CONFIG_HOME/nulifyer/theme/render.py"

    if not test -r "$catalog"
        printf 'theme: catalog not found: %s\n' "$catalog" >&2
        return 1
    end
    if not type -q jq
        printf 'theme: required command not found: jq\n' >&2
        return 1
    end

    if test (count $argv) -gt 1
        printf 'Usage: theme [NAME|--list|--current|--reload]\n' >&2
        return 2
    end

    set -l requested $argv[1]
    switch "$requested"
        case -h --help
            printf '%s\n' \
                'Usage: theme [NAME|--list|--current|--reload]' \
                '' \
                'With no name, choose a theme interactively with fzf.' \
                '  --list     List available theme names' \
                '  --current  Print the selected theme name' \
                '  --reload   Regenerate and reapply the selected theme'
            return
        case --list
            set -l IFS \x09
            jq -r 'to_entries[] | [.key, .value.name, .value.variant] | @tsv' \
                "$catalog" |
                while read -l key display variant
                    printf '%-24s %-30s %s\n' \
                        "$key" "$display" "$variant"
                end
            return
        case --current
            __theme_current
            return
        case --reload
            set requested (__theme_current)
        case ''
            if not type -q fzf
                printf 'theme: fzf is required for the interactive picker\n' >&2
                printf 'Run `theme --list`, then `theme NAME`.\n' >&2
                return 1
            end

            set -l choice (
                jq -r \
                    'to_entries[] | [.key, .value.name, .value.variant] | @tsv' \
                    "$catalog" |
                    fzf --height=60% --layout=reverse --border \
                        --delimiter=(printf '\t') --with-nth=2,3 \
                        --prompt='theme › ' \
                        --header='name / variant'
            )
            test -n "$choice"; or return
            set requested (string split (printf '\t') -- "$choice")[1]
    end

    if not jq -e --arg name "$requested" 'has($name)' "$catalog" >/dev/null
        printf 'theme: unknown theme: %s\n' "$requested" >&2
        printf 'Run `theme --list` to see available names.\n' >&2
        return 2
    end
    if not test -x "$renderer"
        printf 'theme: renderer is missing or not executable: %s\n' \
            "$renderer" >&2
        return 1
    end

    command "$renderer" "$requested"; or return
    source "$state_root/fish.fish"
    __theme_apply_desktop "$state_root"

    set -l display (
        jq -r --arg name "$requested" '.[$name].name' "$catalog"
    )
    printf 'Applied %s (%s).\n' "$display" "$requested"
end

# Match the PowerShell profile's compact, transient prompt.
set -g fish_transient_prompt 1

function fish_mode_prompt
end

function fish_prompt
    set -l last_status $status

    if contains -- --final-rendering $argv
        set_color $nulifyer_prompt_end
        printf '\uf105 '
        set_color normal
        return
    end

    set_color $nulifyer_prompt_os
    printf '\uf303 '

    set_color $nulifyer_prompt_user
    printf '%s@%s ' (whoami) (prompt_hostname)

    set_color $nulifyer_prompt_path
    printf '%s ' (prompt_pwd)

    set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    if test -n "$branch"
        set_color $nulifyer_prompt_git
        printf '\ue725 %s ' $branch
    end

    if test $last_status -eq 0
        set_color $nulifyer_prompt_ok
    else
        set_color $nulifyer_prompt_err
    end
    printf '\uf105 '
    set_color normal
end

function __theme_complete_names
    set -l catalog (__theme_catalog)
    test -r "$catalog"; or return

    jq -r \
        'to_entries[] | [.key, (.value.name + " (" + .value.variant + ")")] | @tsv' \
        "$catalog"
end

complete --command theme --no-files
complete --command theme \
    --condition 'test (count (commandline -opc)) -eq 1' \
    --arguments '(__theme_complete_names)'
complete --command theme --short-option h --long-option help \
    --description 'Show usage'
complete --command theme --long-option list \
    --description 'List available themes'
complete --command theme --long-option current \
    --description 'Print the selected theme'
complete --command theme --long-option reload \
    --description 'Regenerate and reapply the selected theme'
