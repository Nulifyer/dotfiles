#!/usr/bin/env bash

set -euo pipefail
desktop_file="$DOTFILES_ROOT/applications/nulifyer-project-picker.desktop"
grep -qx 'Type=Application' "$desktop_file"
grep -qx 'Exec=kitty --class nulifyer-project-picker --title "Project Picker" --override remember_window_size=no --override initial_window_width=72c --override initial_window_height=13c fish -c zpick' "$desktop_file"
grep -qx 'X-KDE-Shortcuts=Ctrl+Alt+P' "$desktop_file"

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$desktop_file"
fi
