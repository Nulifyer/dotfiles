# dotfiles

Linux configuration managed with Git and GNU Stow.

## Packages

- `fish` contains the Fish shell configuration.
- `kitty` contains the Kitty terminal configuration.

## Install

From this repository, create file-level links in the home directory:

```sh
stow --target="$HOME" --no-folding fish kitty
```

Preview changes without modifying the filesystem:

```sh
stow --simulate --verbose --target="$HOME" --no-folding fish kitty
```

Remove the managed links:

```sh
stow --delete --target="$HOME" --no-folding fish kitty
```

Fish's generated `fish_variables` file remains local and is not tracked.
