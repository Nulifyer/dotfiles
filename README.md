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

Each top-level application folder owns a visible `dotfiles.json`. The manifest
declares every deployment source and destination, whether the source is one
`file`, a directory's `contents`, or the `directory` itself, and whether it is
installed by `link` or atomic `copy`. This keeps an application's configuration
and deployment decisions together without mirroring the home directory in the
repository.

For example, `kitty/dotfiles.json` owns Kitty's configuration, generated theme,
and shared terminal environment deployment. `vscode/dotfiles.json` owns VS
Code's settings and generated local theme extension. The root runner rejects a
visible application folder without a manifest, unsafe relative paths, unknown
manifest fields, and deployments that claim the same target.

Modules may declare conditions. The KDE module runs only when KDE is detected
from the current desktop or selected with `DOTFILES_DESKTOP=kde`. Use
`./dotfiles status` to see which modules are enabled or skipped and why.

An application may also own standard lifecycle hooks:

- `validate.sh` checks tracked source without requiring the application to run.
- `apply.sh` writes portable desired state that cannot be deployed as a file.
- `check.sh` reports drift in the target home.
- `reload.sh` tells a running application to reload after changes.
- `clean.sh` removes only state that the application can prove it owns.

The root runner discovers these hooks and provides `DOTFILES_ROOT`,
`DOTFILES_TARGET`, and `DOTFILES_MODULE`. Shared helpers implement mechanics
such as safe KConfig reads and writes; the owning application supplies the
settings and decisions.

OpenCode uses a directory link so its tools and locally installed JavaScript
dependencies share one real module-resolution tree.

`unlink` removes repository links and copied files that still match their
source. It leaves changed copies, regular files not declared by a module, and
unrelated application state untouched.

## OpenCode Workbench

Install OpenCode Workbench through the Visual Studio Marketplace. The extension
uses the configured `opencode` package and manages its own private server, so
the dotfiles repository does not install a plugin, credentials file, or systemd
service.

Run `opencode` normally for the terminal TUI. Terminal sessions remain
independent from the VS Code Workbench connection. OpenCode remains the owner
of sessions, providers, agents, tools, and transcripts. The global
`skill-development` skill provides the same evidence, proposal, review, and
manual skill-maintenance flow in terminal sessions. Without a Workbench
activation host, approved changes remain pending until the user restarts
OpenCode. Workbench runtime preferences and skill candidates stay under
`~/.local/share/opencode-workbench` and are not committed; terminal instances
do not gain those companion-plugin tools merely by loading the skill.

Fish's generated `fish_variables` file remains local and is not tracked.

## Dependencies

Each application's `dotfiles.json` owns its command and Arch package
dependencies. The runner adds only its own bootstrap requirements and merges
duplicate tools while retaining every owning module. Dependencies are
classified as:

- `required`: needed by the repository task runner or validation
- `managed`: applications and platform components with tracked configuration
- `optional`: enhancements used when installed

Run `./dotfiles doctor` to report missing commands and Arch packages with their
owners. Missing required dependencies fail the command. `./dotfiles doctor
--strict` also fails for missing managed and optional packages. Conditions are
evaluated first, so KDE requirements are not reported when the KDE module is
inactive. On another distribution, command checks still run and the Arch
package portion is skipped.

## Repository internals

Every visible top-level application directory must contain `dotfiles.json`.
`.dotfiles` contains generic module discovery and deployment internals, while
`.theme` contains the renderer and current shared VS Code role templates. The
root `colors.json` catalog and app-owned manifests are repository inputs.
Generated palette files are ignored by Git and must be created locally with
`./dotfiles theme NAME`.

`.theme/colors.schema.json` documents the catalog shape. Palette values remain
theme data in `colors.json`; application folders map their own properties to
shared semantic roles such as accent, link, success, warning, and error. This
keeps a VS Code border decision independent from a Brave tab-separation
decision even when both use the same palette.

## KDE

Mutable files such as `kdeglobals` and `kwinrc` are deliberately not linked,
because they also contain device and display state. Their portable desired
state lives directly in `./dotfiles`: `apply` writes the managed keys and
`check` reports drift without touching unrelated KDE or hardware settings.

```sh
./dotfiles apply
```

## Project picker

Press `Ctrl+Alt+P` in Plasma or run `zpick` from Fish to search for projects.
The direct children of `$Z_PROJECTS_ROOT`, which defaults to `~/Projects`, are
streamed into `fzf` first. The picker then searches the rest of the home
directory for outermost folders containing `.git`, `.jj`, `.hg`, `.svn`,
`.vscode`, `.idea`, or `.devcontainer`.

Once the search finds a project marker, it does not descend farther into that
folder. The home-directory scan does not follow symlinks, and cache,
application-state, dependency, and build-output folders are skipped. This
keeps nested packages and generated trees out of the picker while still
finding projects such as `~/.agents`.

- Press `Enter` to open the selected project with `code`.
- Press `Ctrl+E` to open the selected project in KDE's default terminal.
- Press `Esc` to close the picker without opening anything.

The popup uses the managed Kitty configuration for a centered, titlebarless
window. `Ctrl+E` still honors KDE's configured default terminal. The global
`fzf` palette, focused-window outline, and picker highlights follow the shared
theme accent; Gruvbox uses its yellow accent. A managed KWin rule allows VS
Code to focus an existing project window under Wayland.

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
