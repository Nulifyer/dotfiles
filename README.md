# dotfiles

Linux configuration managed with Git and a repository-local deployment script.

## Packages

- `alacritty` contains the Alacritty terminal configuration.
- `applications` contains desktop launchers and KDE global shortcuts.
- `bash` contains a Bash-native setup with Bash history, completion, and prompt.
- `fish` contains self-contained Fish features under `conf.d`.
- `kde` contains locally generated KDE color schemes.
- `kitty` contains the Kitty terminal configuration.
- `opencode` contains the global OpenCode configuration and extensions.
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
./dotfiles link         Resolve conflicts and refresh configured links
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

`link-config.json` declares every source and destination, so repository paths
stay shallow and application-oriented instead of mirroring the home directory.
The `file` strategy links one file, `contents` links the files below a source
directory, and `directory` links the source directory itself. OpenCode uses a
directory link so its tools and locally installed JavaScript dependencies share
one real module-resolution tree.

`unlink` removes only links that still point into this repository. It leaves
regular files and unrelated application state untouched.

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

Layer-one deployment directories are listed in `link-config.json`; visible
directories without a deployment are rejected by `check`. `.theme` contains
the renderer and VS Code role templates. The root `colors.json` catalog,
`link-config.json`, and `packages.arch` are repository inputs. Generated
palette files are ignored by Git and must be created locally with
`./dotfiles theme NAME`.

## KDE

Mutable files such as `kdeglobals` and `kwinrc` are deliberately not linked,
because they also contain device and display state. Their portable desired
state lives directly in `./dotfiles`: `apply` writes the managed keys and
`check` reports drift without touching unrelated KDE or hardware settings.

```sh
./dotfiles apply
```

## Project picker

Press `Ctrl+Alt+P` in Plasma or run `zpick` from Fish to search the direct
children of `$Z_PROJECTS_ROOT`, which defaults to `~/Projects`. Candidates are
streamed into `fzf` as they are enumerated.

- Press `Enter` to open the selected project with `code`.
- Press `Ctrl+E` to open the selected project in KDE's default terminal.
- Press `Esc` to close the picker without opening anything.

The popup uses the managed Kitty configuration for a centered, titlebarless
window. `Ctrl+E` still honors KDE's configured default terminal. The global
`fzf` palette, focused-window outline, and picker highlights follow the shared
theme accent; Gruvbox uses its yellow accent.

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
owning deployment directory and is ignored by Git. Repository-local selection
state lives under `.theme/local`. The catalog, renderer, templates, and
application configurations remain visible in repository diffs.

Generated output is organized by owner:

- `alacritty/theme.generated.toml`
- `bash/theme.generated.sh`
- `fish/themes/current.fish`
- `kde/*.colors`
- `kitty/theme.generated.conf`
- `opencode/themes/nulifyer.json`
- `vscode/extension`
- `zsh/theme.generated.zsh`

`link` and `check` require current generated output and report how to create it
when it is missing. `update` regenerates the locally selected theme after
pulling.

When the packages are already linked, Kitty and Alacritty watch their generated
includes and KDE is reapplied immediately. New Bash and Zsh sessions load the
selected prompt colors. VS Code and OpenCode may require a reload after their
generated themes change.
