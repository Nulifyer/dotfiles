# Nulifyer Fish configuration, based on CachyOS defaults.
# Kept here so local behavior does not change when the distro config changes.

# Desktop notification support for long-running commands.
source /usr/share/cachyos-fish-config/conf.d/done.fish

# No startup banner or fastfetch greeting.
function fish_greeting
end

# Format man pages with bat.
set -gx MANROFFOPT "-c"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Settings for the done notification helper.
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# Apply Fish-compatible profile settings when present.
if test -f ~/.fish_profile
    source ~/.fish_profile
end

fish_add_path ~/.local/bin ~/.cargo/bin ~/Applications/depot_tools

# Support !! and !$ from oh-my-fish/plugin-bang-bang.
function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

if test "$fish_key_bindings" = fish_vi_key_bindings
    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

# Include timestamps in explicit history output.
function history
    builtin history --show-time='%F %T ' $argv
end

function backup --argument filename
    cp -- $filename $filename.bak
end

# Copy a file, or recursively copy a directory.
function copy
    if test (count $argv) -eq 2; and test -d "$argv[1]"
        set -l from (string trim --right --chars=/ -- "$argv[1]")
        command cp -r -- $from "$argv[2]"
    else
        command cp -- $argv
    end
end

# Listings.
alias ls='eza -al --color=always --group-directories-first --icons=always'
alias la='eza -a --color=always --group-directories-first --icons=always'
alias ll='eza -l --color=always --group-directories-first --icons=always'
alias lt='eza -aT --color=always --group-directories-first --icons=always'
function l.
    eza -a | grep -e '^\.'
end

# Navigation and common utilities.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Jump to the projects directory or to a named project within it.
function z --description 'Jump to a project in ~/Projects'
    set -l projects_root ~/Projects

    if test (count $argv) -eq 0
        cd $projects_root
    else if test (count $argv) -eq 1; and test -d "$projects_root/$argv[1]"
        cd "$projects_root/$argv[1]"
    else
        printf 'z: project not found: %s\n' (string join ' ' -- $argv) >&2
        return 1
    end
end

function __z_complete_projects
    for project in ~/Projects/*/
        path basename $project
    end
end

complete --command z --no-files --arguments '(__z_complete_projects)'

alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias wget='wget -c '
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias hw='hwinfo --short'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
alias mirror='sudo cachyos-rate-mirrors'
alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias fixpacman='sudo rm /var/lib/pacman/db.lck'
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'
alias jctl='journalctl -p 3 -xb'
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias apt='man pacman'
alias apt-get='man pacman'
alias tb='nc termbin.com 9999'

# Gruvbox syntax colors mirrored from the VS Code terminal palette.
set -g fish_color_normal DDC7A1
set -g fish_color_command D8A657
set -g fish_color_keyword EA6962
set -g fish_color_quote A9B665
set -g fish_color_redirection 7DAEA3
set -g fish_color_end EA6962
set -g fish_color_error EA6962
set -g fish_color_param DDC7A1
set -g fish_color_comment 746A62
set -g fish_color_selection --background=2A2827
set -g fish_color_search_match --background=3B3B3B
set -g fish_color_operator EA6962
set -g fish_color_escape EA6962
set -g fish_color_autosuggestion 746A62
set -g fish_color_cwd D3869B
set -g fish_color_user 7DAEA3
set -g fish_color_host 7DAEA3
set -g fish_pager_color_progress D8A657
set -g fish_pager_color_prefix A9B665
set -g fish_pager_color_completion DDC7A1
set -g fish_pager_color_description 746A62
set -g fish_pager_color_selected_background --background=2A2827

# Match the PowerShell profile's compact, transient prompt.
set -g fish_transient_prompt 1

function fish_mode_prompt
end

function fish_prompt
    if contains -- --final-rendering $argv
        set_color 746A62
        printf '\uf105 '
        set_color normal
        return
    end

    # Arch/CachyOS icon.
    set_color 746A62
    printf '\uf303 '

    # user@host
    set_color D8A657
    printf '%s@%s ' (whoami) (prompt_hostname)

    # Fish abbreviates intermediate path components like the PowerShell prompt.
    set_color E78A4E
    printf '%s ' (prompt_pwd)

    # Current Git branch or detached commit.
    set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    if test -n "$branch"
        set_color A9B665
        printf '\ue725 %s ' $branch
    end

    set_color 746A62
    printf '\uf105 '
    set_color normal
end
