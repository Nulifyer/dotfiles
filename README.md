# dotfiles

Linux configuration managed with Git and GNU Stow.

## Packages

- `alacritty` contains the Alacritty terminal configuration.
- `bash` contains a Bash-native setup with Bash history, completion, and prompt.
- `fish` contains self-contained Fish features under `conf.d`.
- `kitty` contains the Kitty terminal configuration.
- `spectacle` contains stable Spectacle preferences.
- `theme` contains the shared 40-theme catalog and cross-application renderer.
- `vscode` contains cleaned VS Code settings; the Nulifyer theme is generated.
- `zsh` contains a Zsh-native setup using Zsh completion, path arrays, and
  `vcs_info`.

## Install

Run the repository-local task script:

```sh
./dotfiles link
./dotfiles apply
./dotfiles check
```

The task runner is not linked into `~/.local/bin`; it only exists in this
repository. It is a small Bash dispatcher, so Make is not required.

```text
./dotfiles link         Create or refresh Stow links
./dotfiles apply        Apply KDE and other non-linkable settings
./dotfiles check        Run local validation
./dotfiles update       Pull, link, apply, and validate
./dotfiles status       Show repository and package status
./dotfiles unlink       Remove managed links
```

Preview the complete Stow layout without modifying the filesystem:

```sh
stow --simulate --verbose --target="$HOME" --no-folding \
    alacritty bash fish kitty spectacle theme vscode zsh
```

Remove the managed links:

```sh
stow --delete --target="$HOME" --no-folding \
    alacritty bash fish kitty spectacle theme vscode zsh
```

Fish's generated `fish_variables` file remains local and is not tracked.

## Repository internals

Layer-one directories without a leading dot are Stow packages. Any future
repository-only directory must use a leading dot and is never passed to Stow.
The repository currently has no non-Stow implementation directory.

## KDE

Mutable files such as `kdeglobals` and `kwinrc` are deliberately not linked,
because they also contain device and display state. Their portable desired
state lives directly in `./dotfiles`: `apply` writes the managed keys and
`check` reports drift without touching unrelated KDE or hardware settings.

```sh
./dotfiles apply
```

## Shared themes

The tracked `theme/.config/nulifyer/themes/colors.json` catalog is the local
source of truth and currently contains 40 themes. Apply one by its catalog key:

```fish
theme gruvbox
theme catppuccin_latte
```

The command has catalog-backed Fish completions. Run `theme` without arguments
for an `fzf` picker, or use the inspection commands:

```fish
theme --list
theme --current
theme --reload
```

One selection generates Fish, Bash, Zsh, Kitty, Alacritty, KDE, and VS Code
colors from the same palette. Fish and KDE update immediately; Kitty and
Alacritty watch generated color includes; new Bash and Zsh sessions load the
selected prompt colors. The active VS Code extension is generated in
`~/.vscode/extensions`.

Generated files live under `~/.local/state/nulifyer/theme`,
`~/.local/share/color-schemes`, and the VS Code extensions directory. They are
deliberately outside the Stow packages, so changing themes does not dirty the
repository. `./dotfiles apply` regenerates the current selection, with
`gruvbox` as the initial default.
