# Nulifyer Fish configuration, based on CachyOS defaults.
# Kept here so local behavior does not change when the distro config changes.

# Desktop notification support for long-running commands.
if test -r /usr/share/cachyos-fish-config/conf.d/done.fish
    source /usr/share/cachyos-fish-config/conf.d/done.fish
end

# No startup banner or fastfetch greeting.
function fish_greeting
end

function fish-reload --description 'Reload the Fish configuration'
    exec fish
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

# Android SDK settings previously persisted in fish_variables.
set -gx ANDROID_HOME /opt/android-sdk
set -gx ANDROID_SDK_ROOT $ANDROID_HOME

fish_add_path \
    $ANDROID_HOME/emulator \
    $ANDROID_HOME/cmdline-tools/latest/bin \
    ~/.local/bin \
    ~/.cargo/bin \
    ~/Applications/depot_tools

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
if type -q eza
    alias ls='eza -al --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias tree='eza -aT --git-ignore --color=always --group-directories-first --icons=always'

    function l.
        eza -a | grep -e '^\.'
    end
else
    alias ls='ls -al --color=auto --group-directories-first'
    alias la='ls -A --color=auto --group-directories-first'
    alias ll='ls -l --color=auto --group-directories-first'
    alias lt='ls -al --color=auto --group-directories-first'
    alias tree='find . -print'

    function l.
        command ls -A | string match -r '^\..+'
    end
end

# Navigation and common utilities.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

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
