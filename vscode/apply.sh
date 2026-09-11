#!/usr/bin/env bash

set -euo pipefail
source "$DOTFILES_ROOT/.dotfiles/lib.sh"
dotfiles_is_kde || exit 0

rule=visual-studio-code-focus
dotfiles_kconfig_set kwinrulesrc "$rule" Description "Allow VS Code activation"
dotfiles_kconfig_set kwinrulesrc "$rule" Enabled true
dotfiles_kconfig_set kwinrulesrc "$rule" fsplevel 0
dotfiles_kconfig_set kwinrulesrc "$rule" fsplevelrule 2
dotfiles_kconfig_set kwinrulesrc "$rule" types 1
dotfiles_kconfig_set kwinrulesrc "$rule" wmclass '^[Cc]ode$'
dotfiles_kconfig_set kwinrulesrc "$rule" wmclasscomplete false
dotfiles_kconfig_set kwinrulesrc "$rule" wmclassmatch 3
dotfiles_kconfig_add kwinrulesrc General rules "$rule"
