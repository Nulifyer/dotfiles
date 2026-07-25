# Shared generated theme and prompt.
#
# `./dotfiles theme NAME` updates the local generated file. Gruvbox values
# below are startup fallbacks for an incomplete installation.

set -g nulifyer_prompt_os 746A62
set -g nulifyer_prompt_user D8A657
set -g nulifyer_prompt_path E78A4E
set -g nulifyer_prompt_git A9B665
set -g nulifyer_prompt_ok A9B665
set -g nulifyer_prompt_err EA6962
set -g nulifyer_prompt_duration D8A657
set -g nulifyer_prompt_end 746A62

set -l nulifyer_theme_file
if set -q XDG_CONFIG_HOME
    set nulifyer_theme_file "$XDG_CONFIG_HOME/fish/themes/current.fish"
else
    set nulifyer_theme_file ~/.config/fish/themes/current.fish
end
if test -r "$nulifyer_theme_file"
    source "$nulifyer_theme_file"
end
set -e nulifyer_theme_file

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
