# dotfiles

Linux configuration managed with Git and GNU Stow.

## Packages

- `alacritty` contains the Alacritty terminal configuration.
- `bash` contains a Bash-native setup with Bash history, completion, and prompt.
- `fish` contains self-contained Fish features under `conf.d`.
- `kde` contains locally generated KDE color schemes.
- `kitty` contains the Kitty terminal configuration.
- `spectacle` contains stable Spectacle preferences.
- `vscode` contains VS Code settings and a locally generated Nulifyer extension.
- `zsh` contains a Zsh-native setup using Zsh completion, path arrays, and
  `vcs_info`.

## Install

Run the repository-local task script:

```sh
./dotfiles doctor
./dotfiles theme gruvbox
./dotfiles link
./dotfiles apply
./dotfiles check
```

The task runner is not linked into `~/.local/bin`; it only exists in this
repository. It is a small Bash dispatcher, so Make is not required.

```text
./dotfiles link         Resolve conflicts and refresh Stow links
./dotfiles apply        Apply KDE and other non-linkable settings
./dotfiles theme NAME   Regenerate local theme files from colors.json
./dotfiles check        Validate files, generated output, links, and active state
./dotfiles doctor       Report required and optional dependencies
./dotfiles update       Pull, link, apply, and validate
./dotfiles status       Show repository and package status
./dotfiles unlink       Remove managed links
```

When a managed target file conflicts with the repository, `link` prompts you to
keep either version. Keeping the target imports it into the repository before
linking, while keeping the repository replaces the target. A directory at a
managed file path aborts instead of being deleted recursively.

Preview the complete Stow layout without modifying the filesystem:

```sh
stow --simulate --verbose --target="$HOME" --no-folding \
    alacritty bash fish kde kitty spectacle vscode zsh opencode
```

Remove the managed links:

```sh
stow --delete --target="$HOME" --no-folding \
    alacritty bash fish kde kitty spectacle vscode zsh opencode
```

Fish's generated `fish_variables` file remains local and is not tracked.

## Dependencies

`packages.arch` is the auditable Arch package manifest. Entries are classified
as:

- `required`: needed by the repository task runner or validation
- `managed`: applications and platform components with tracked configuration
- `optional`: enhancements used when installed

Run `./dotfiles doctor` to report missing commands and Arch packages. Missing
required dependencies fail the command. `./dotfiles doctor --strict` also fails
for missing managed and optional packages. On another distribution, command
checks still run and the Arch package portion is skipped.

## Repository internals

Layer-one directories without a leading dot are Stow packages. Any future
repository-only directory must use a leading dot and is never passed to Stow.
`.theme` contains the renderer and VS Code role templates. The root
`colors.json` catalog and `packages.arch` manifest are repository inputs rather
than Stow packages. Generated palette files are ignored by Git and must be
created locally with `./dotfiles theme NAME`.

## KDE

Mutable files such as `kdeglobals` and `kwinrc` are deliberately not linked,
because they also contain device and display state. Their portable desired
state lives directly in `./dotfiles`: `apply` writes the managed keys and
`check` reports drift without touching unrelated KDE or hardware settings.

```sh
./dotfiles apply
```

## Shared themes

The tracked root `colors.json` catalog is the local source of truth and
currently contains 40 themes. Generate one by its catalog key:

```sh
./dotfiles theme gruvbox
./dotfiles theme catppuccin_latte
```

Run the command without a name for an `fzf` picker, or use the inspection
commands:

```sh
./dotfiles theme --list
./dotfiles theme --current
./dotfiles theme --reload
```

One selection locally generates Fish, Bash, Zsh, Kitty, Alacritty, KDE, VS Code,
and OpenCode files from the same palette. Each generated file lives in its
owning Stow package and is ignored by Git. Repository-local selection state
lives under `.theme/local`. The catalog, renderer, templates, and application
configurations remain visible in repository diffs.

Generated output is organized by owner:

- `alacritty/.config/alacritty/theme.generated.toml`
- `bash/.config/bash/theme.generated.sh`
- `fish/.config/fish/themes/current.fish`
- `kde/.local/share/color-schemes`
- `kitty/.config/kitty/theme.generated.conf`
- `opencode/.config/opencode/themes/nulifyer.json`
- `vscode/.vscode/extensions/nulifyer.nulifyer-theme-1.2.0`
- `zsh/.config/zsh/theme.generated.zsh`

`link` and `check` require current generated output and report how to create it
when it is missing. `update` regenerates the locally selected theme after
pulling.

When the packages are already linked, Kitty and Alacritty watch their generated
includes and KDE is reapplied immediately. New Bash and Zsh sessions load the
selected prompt colors. VS Code and OpenCode may require a reload after their
generated themes change.
