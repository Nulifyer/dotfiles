# Nulifyer Zsh configuration.

[[ -o interactive ]] || return

# Environment -----------------------------------------------------------------

export MANROFFOPT='-c'
if (( $+commands[bat] )); then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/theme.generated.zsh"
if [[ -r $theme_file ]]; then
    # Locally generated prompt colors and optional BAT/LUTGEN theme values.
    source "$theme_file"
fi
unset theme_file

export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

# Zsh keeps PATH and its `path` array synchronized. `typeset -U` removes
# duplicates while retaining the first occurrence.
typeset -U path PATH
for path_entry in \
    "$ANDROID_HOME/emulator" \
    "$ANDROID_HOME/cmdline-tools/latest/bin" \
    "$HOME/.local/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/Applications/depot_tools"
do
    [[ -d $path_entry ]] && path=("$path_entry" $path)
done
unset path_entry

# History, completion, and line editing ---------------------------------------

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=10000
SAVEHIST=20000
command mkdir -p -- "${HISTFILE:h}"

setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt interactive_comments
setopt prompt_subst
setopt share_history

zsh_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
command mkdir -p -- "$zsh_cache"
autoload -Uz compinit
compinit -d "$zsh_cache/zcompdump"
unset zsh_cache
bindkey -e

# Helpers ---------------------------------------------------------------------

backup() {
    if (( $# != 1 )); then
        print -u2 'Usage: backup FILE'
        return 2
    fi
    command cp -- "$1" "$1.bak"
}

copy() {
    if (( $# == 2 )) && [[ -d $1 ]]; then
        command cp -r -- "${1%/}" "$2"
    else
        command cp -- "$@"
    fi
}

_nulifyer_projects_root() {
    print -r -- "${Z_PROJECTS_ROOT:-$HOME/Projects}"
}

_nulifyer_resolve_project() {
    local project=${1-}
    local projects_root=$(_nulifyer_projects_root)

    if [[ -z $project ]]; then
        [[ -d $projects_root ]] && print -r -- "${projects_root:A}" && return
    elif [[ -d $projects_root/$project ]]; then
        print -r -- "${projects_root:A}/$project"
        return
    elif [[ $project == /* || $project == ./* || $project == ../* ]] &&
        [[ -d $project ]]; then
        print -r -- "${project:A}"
        return
    fi

    print -u2 -r -- "z: project not found: ${project:-$projects_root}"
    return 1
}

z() {
    if (( $# > 1 )); then
        print -u2 'Usage: z [NAME|PATH]'
        return 2
    fi

    local project=$(_nulifyer_resolve_project "${1-}") || return
    builtin cd -- "$project"
}

zopen() {
    if (( $# > 1 )); then
        print -u2 'Usage: zopen [NAME|PATH]'
        return 2
    fi

    local editor=${Z_PROJECT_EDITOR:-code}
    local project=$(_nulifyer_resolve_project "${1-}") || return

    if (( ! $+commands[$editor] )); then
        print -u2 -r -- "zopen: editor not found: $editor"
        return 1
    fi
    command "$editor" "$project"
}

zlink() {
    if (( $# != 2 )); then
        print -u2 'Usage: zlink PROJECT PATH'
        return 2
    fi

    local name=$1
    local link_path=${2%/}
    local projects_root project link_parent

    if [[ -z $name || $name == . || $name == .. || $name == */* ]]; then
        print -u2 'zlink: project name must be a single directory name'
        return 2
    fi

    projects_root=$(_nulifyer_projects_root)
    project="$projects_root/$name"
    if [[ ! -d $project || -L $project ]]; then
        print -u2 -r -- "zlink: real project directory not found: $project"
        return 1
    fi
    project=${project:A}

    link_parent=${link_path:h}
    command mkdir -p -- "$link_parent" || return
    link_parent=${link_parent:A}
    link_path="$link_parent/${link_path:t}"

    if [[ -e $link_path || -L $link_path ]]; then
        if [[ -L $link_path && ${link_path:A} == "$project" ]]; then
            print -r -- "zlink: $link_path already links to $project"
            return
        fi
        print -u2 -r -- "zlink: path already exists: $link_path"
        return 1
    fi

    command ln -s -- "$project" "$link_path" || return
    print -r -- "zlink: linked $link_path -> $project"
}

# Zsh-native project completion with descriptions.
_nulifyer_complete_projects() {
    local projects_root=$(_nulifyer_projects_root)
    local -a projects
    local directory

    for directory in "$projects_root"/*(/N); do
        projects+=("${directory:t}:${directory/#$HOME/~}")
    done
    _describe -t projects 'project' projects
}

_nulifyer_complete_zlink() {
    if (( CURRENT == 2 )); then
        _nulifyer_complete_projects
    else
        _directories
    fi
}

compdef _nulifyer_complete_projects z zopen
compdef _nulifyer_complete_zlink zlink

# Listings and aliases --------------------------------------------------------

if (( $+commands[eza] )); then
    alias ls='eza -al --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias tree='eza -aT --git-ignore --color=always --group-directories-first --icons=always'
else
    alias ls='ls -al --color=auto --group-directories-first'
    alias la='ls -A --color=auto --group-directories-first'
    alias ll='ls -l --color=auto --group-directories-first'
    alias lt='ls -al --color=auto --group-directories-first'
fi

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
alias wget='wget -c'
alias tarnow='tar -acf'
alias untar='tar -zxvf'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias hw='hwinfo --short'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i -- "-git" | wc -l'
alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
alias mirror='sudo cachyos-rate-mirrors'
alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias fixpacman='sudo rm /var/lib/pacman/db.lck'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'
alias jctl='journalctl -p 3 -xb'
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias apt='man pacman'
alias apt-get='man pacman'
alias tb='nc termbin.com 9999'

# Prompt ----------------------------------------------------------------------

autoload -Uz add-zsh-hook vcs_info
zstyle ':vcs_info:git:*' formats ' %b '
zstyle ':vcs_info:git:*' actionformats ' %b|%a '

_nulifyer_update_vcs_info() {
    vcs_info
}
add-zsh-hook precmd _nulifyer_update_vcs_info

: "${NULIFYER_PROMPT_OS_HEX:=#746A62}"
: "${NULIFYER_PROMPT_USER_HEX:=#D8A657}"
: "${NULIFYER_PROMPT_PATH_HEX:=#E78A4E}"
: "${NULIFYER_PROMPT_GIT_HEX:=#A9B665}"
: "${NULIFYER_PROMPT_END_HEX:=#746A62}"
PROMPT='%F{'"$NULIFYER_PROMPT_OS_HEX"'} %F{'"$NULIFYER_PROMPT_USER_HEX"'}%n@%m %F{'"$NULIFYER_PROMPT_PATH_HEX"'}%3~ %F{'"$NULIFYER_PROMPT_GIT_HEX"'}${vcs_info_msg_0_}%F{'"$NULIFYER_PROMPT_END_HEX"'}❯ %f'

shell-reload() {
    exec zsh
}

if [[ -r $HOME/.zshrc.local ]]; then
    source "$HOME/.zshrc.local"
fi
