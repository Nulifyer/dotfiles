# Nulifyer Bash configuration.

[[ $- == *i* ]] || return

# Environment -----------------------------------------------------------------

export MANROFFOPT='-c'
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/bash/theme.generated.sh"
if [[ -r "$theme_file" ]]; then
    # Locally generated prompt colors and optional BAT/LUTGEN theme values.
    source "$theme_file"
fi
unset theme_file

export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

_nulifyer_prepend_path() {
    [[ -d $1 ]] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

_nulifyer_prepend_path "$HOME/Applications/depot_tools"
_nulifyer_prepend_path "$HOME/.cargo/bin"
_nulifyer_prepend_path "$HOME/.local/bin"
_nulifyer_prepend_path "$ANDROID_HOME/cmdline-tools/latest/bin"
_nulifyer_prepend_path "$ANDROID_HOME/emulator"
export PATH

# History and interactive behavior --------------------------------------------

shopt -s checkwinsize histappend
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT='%F %T '
PROMPT_DIRTRIM=3

# Helpers ---------------------------------------------------------------------

backup() {
    if (($# != 1)); then
        printf 'Usage: backup FILE\n' >&2
        return 2
    fi
    command cp -- "$1" "$1.bak"
}

copy() {
    if (($# == 2)) && [[ -d $1 ]]; then
        command cp -r -- "${1%/}" "$2"
    else
        command cp -- "$@"
    fi
}

_nulifyer_projects_root() {
    printf '%s\n' "${Z_PROJECTS_ROOT:-$HOME/Projects}"
}

_nulifyer_resolve_project() {
    local project=${1-}
    local projects_root
    projects_root=$(_nulifyer_projects_root)

    if [[ -z $project ]]; then
        [[ -d $projects_root ]] && realpath -- "$projects_root" && return
    elif [[ -d $projects_root/$project ]]; then
        realpath -- "$projects_root/$project"
        return
    elif [[ $project == /* || $project == ./* || $project == ../* ]] &&
        [[ -d $project ]]; then
        realpath -- "$project"
        return
    fi

    printf 'z: project not found: %s\n' "${project:-$projects_root}" >&2
    return 1
}

z() {
    if (($# > 1)); then
        printf 'Usage: z [NAME|PATH]\n' >&2
        return 2
    fi

    local project
    project=$(_nulifyer_resolve_project "${1-}") || return
    builtin cd -- "$project"
}

zopen() {
    if (($# > 1)); then
        printf 'Usage: zopen [NAME|PATH]\n' >&2
        return 2
    fi

    local editor=${Z_PROJECT_EDITOR:-code}
    local project
    project=$(_nulifyer_resolve_project "${1-}") || return

    if ! command -v "$editor" >/dev/null 2>&1; then
        printf 'zopen: editor not found: %s\n' "$editor" >&2
        return 1
    fi
    command "$editor" "$project"
}

zlink() {
    if (($# != 2)); then
        printf 'Usage: zlink PROJECT PATH\n' >&2
        return 2
    fi

    local name=$1
    local link_path=${2%/}
    local projects_root project link_parent

    if [[ -z $name || $name == . || $name == .. || $name == */* ]]; then
        printf 'zlink: project name must be a single directory name\n' >&2
        return 2
    fi

    projects_root=$(_nulifyer_projects_root)
    project="$projects_root/$name"
    if [[ ! -d $project || -L $project ]]; then
        printf 'zlink: real project directory not found: %s\n' "$project" >&2
        return 1
    fi
    project=$(realpath -- "$project") || return

    link_parent=$(dirname -- "$link_path")
    command mkdir -p -- "$link_parent" || return
    link_parent=$(realpath -- "$link_parent") || return
    link_path="$link_parent/$(basename -- "$link_path")"

    if [[ -e $link_path || -L $link_path ]]; then
        if [[ -L $link_path ]] &&
            [[ $(realpath -- "$link_path" 2>/dev/null) == "$project" ]]; then
            printf 'zlink: %s already links to %s\n' "$link_path" "$project"
            return
        fi
        printf 'zlink: path already exists: %s\n' "$link_path" >&2
        return 1
    fi

    command ln -s -- "$project" "$link_path" || return
    printf 'zlink: linked %s -> %s\n' "$link_path" "$project"
}

# Bash-native project completion.
_nulifyer_complete_projects() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local projects_root
    projects_root=$(_nulifyer_projects_root)

    COMPREPLY=()
    while IFS= read -r project; do
        [[ $project == "$current"* ]] && COMPREPLY+=("$project")
    done < <(
        find "$projects_root" -mindepth 1 -maxdepth 1 -type d \
            -printf '%f\n' 2>/dev/null | sort
    )
}

_nulifyer_complete_zlink() {
    if ((COMP_CWORD == 1)); then
        _nulifyer_complete_projects
    else
        mapfile -t COMPREPLY < <(compgen -d -- "${COMP_WORDS[COMP_CWORD]}")
    fi
}

complete -F _nulifyer_complete_projects z zopen
complete -F _nulifyer_complete_zlink zlink

# Listings and aliases --------------------------------------------------------

if command -v eza >/dev/null 2>&1; then
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

_nulifyer_bash_git_prompt() {
    local branch
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
        branch=$(command git rev-parse --short HEAD 2>/dev/null) ||
        return
    printf ' %s ' "$branch"
}

: "${NULIFYER_PROMPT_OS_RGB:=116;106;98}"
: "${NULIFYER_PROMPT_USER_RGB:=216;166;87}"
: "${NULIFYER_PROMPT_PATH_RGB:=231;138;78}"
: "${NULIFYER_PROMPT_GIT_RGB:=169;182;101}"
: "${NULIFYER_PROMPT_END_RGB:=116;106;98}"
PS1='\[\e[38;2;'"$NULIFYER_PROMPT_OS_RGB"'m\] \[\e[38;2;'"$NULIFYER_PROMPT_USER_RGB"'m\]\u@\h \[\e[38;2;'"$NULIFYER_PROMPT_PATH_RGB"'m\]\w \[\e[38;2;'"$NULIFYER_PROMPT_GIT_RGB"'m\]$(_nulifyer_bash_git_prompt)\[\e[38;2;'"$NULIFYER_PROMPT_END_RGB"'m\]❯ \[\e[0m\]'

shell-reload() {
    exec bash
}

if [[ -r $HOME/.bashrc.local ]]; then
    source "$HOME/.bashrc.local"
fi
