# Project plan

## Goal

Build a maintainable CachyOS desktop configuration with one semantic color
catalog, app-owned setup and lifecycle behavior, reproducible deployment, and a
coherent Plasma UI. Theme selection, application launch, project launch, and
window placement should be fast and visually consistent without committing
machine-local state.

## Success conditions

- [x] Every managed application has one owning top-level folder and a visible
  `dotfiles.json` that explains where its files go and whether they are linked
  or copied.
- [x] The root runner discovers modules, evaluates their conditions, detects
  target collisions, and explains why each module is enabled or skipped.
- [ ] Setup, apply, check, reload, and cleanup are idempotent and operate only
  on declared owned state.
- [ ] All 40 themes render from a validated semantic schema with documented
  upstream provenance. Gruvbox and Gruvbox Light remain frozen references.
- [ ] VS Code Markdown, installed extension colors, and the agreed language
  fixture set have automated coverage and visual verification.
- [ ] KDE selection, hover, focus, disabled, inactive, and window-decoration
  states have an explicit mapping and visual verification.
- [ ] Theme switching reloads every capable running application and reports an
  accurate restart requirement for the rest.
- [ ] A visual launcher can select themes, launch applications, and open
  projects without requiring KRunner.
- [ ] Window zones support persistent layouts and zone spanning without
  changing the saved layout when one window is resized.
- [ ] A clean-home or VM run proves `doctor`, setup, theme generation,
  deployment, apply, and check.
- [ ] Theme switching and verification leave tracked files clean.

## Scope

### In

- App-owned manifests, deployment, dependencies, lifecycle hooks, and checks.
- Semantic theme catalog, renderer adapters, provenance, contrast policy, and
  application-specific color policy.
- Kitty, Alacritty, Fish, Bash, Zsh, KDE, VS Code, OpenCode, Brave, Spectacle,
  project picker, and application launcher behavior already managed here.
- VS Code Rainbow CSV, Git Graph, Markdown, and language highlighting audits.
- KDE portable preferences, appearance, window rules, launcher replacement,
  and a PowerToys FancyZones-like workflow.
- Omarchy 4 and current dwm-titus research where it informs maintainability,
  theming, launcher UX, setup, checks, and release discipline.
- Installed KDE package and configuration inventory with an approved cleanup
  path.

### Out

- Migrating from CachyOS to Fedora or replacing KWin with dwm during the theme
  and ownership milestones.
- Replacing Plasma with a custom Quickshell desktop before a narrow launcher
  prototype proves that the maintenance cost is justified.
- Tracking secrets, hardware and display topology, window positions, recent
  files, histories, caches, browser profiles, or whole mutable KDE files.
- Destructive package or configuration removal before the user reviews the
  cleanup inventory.

## Product boundaries

- Primary target: CachyOS/Arch Linux, Plasma 6, KWin, and Wayland.
- Other distributions receive clear unsupported or skipped results unless a
  later phase deliberately adds an adapter.
- KDE and application capabilities are detected before applying their state.
  An explicit profile override must support setup outside a live desktop
  session.
- Keep Plasma and KWin as the desktop foundation. Quickshell may own a focused
  launcher or theme picker, but it is not a required desktop replacement.
- Prefer one launcher experience for applications, projects, commands, and
  theme selection. KRunner can remain installed while the replacement is
  evaluated.

## Architecture boundaries

- A top-level application folder is the ownership module. It contains its
  manifest, sources, optional lifecycle hooks, theme adapter, fixtures, and
  app-specific documentation.
- The root `dotfiles` command exposes the small orchestration interface. It
  discovers modules and runs generic deployment and lifecycle operations.
- Each `dotfiles.json` declares module conditions, dependencies, packages,
  deployment source and target, source kind, and install method.
- Deployment keeps source kind and install method separate. Source kind is
  `file`, `contents`, or `directory`; install method is `link` or `copy`.
- The runner rejects duplicate targets, unsafe paths, unknown manifest keys,
  undeclared visible modules, and hooks outside their owning folder.
- Optional lifecycle hooks use `validate.sh`, `apply.sh`, `check.sh`,
  `reload.sh`, and `clean.sh`. Hooks must be idempotent and accept a target
  home so they can run in an isolated test fixture.
- Shared helpers may implement safe KDE key writes, atomic copies, detection,
  and reporting. App modules own the values and decisions passed to them.
- Theme palette values live in `colors.json`; application mappings live with
  the owning app. Generated outputs and local selected-theme state stay
  ignored.
- Cleanup removes only declared links, exact generated artifacts, or settings
  with ownership evidence. Package removal requires an approved inventory.

## Phases

1. **Ownership foundation.** Add durable project records, define the app
   manifest interface, replace the central deployment registry, and move
   application-specific behavior out of the root runner. Exit when isolated
   deployment tests and the existing repository checks pass.
2. **Theme model v2.** Freeze Gruvbox references, add schema and provenance,
   introduce explicit semantic roles, and add contrast and collision audits.
3. **Theme adapters.** Move generation to app owners and audit VS Code,
   Markdown, Rainbow CSV, Git Graph, languages, KDE states, shells, terminals,
   OpenCode, and Brave.
4. **Live reload.** Make theme switching transactional and add per-app reload
   hooks with accurate capability reporting.
5. **Launcher and window UX.** Prototype a Quickshell launcher inspired by
   Omarchy 4, integrate project and theme selection, and qualify KZones or
   PlasmaZones against the required FancyZones behavior.
6. **Cleanup and reproducible setup.** Inventory KDE and package state, remove
   only approved items, split dependency profiles, and verify a clean-home or
   VM setup.
7. **Polish and release.** Capture visual evidence, document daily workflows,
   finish migration cleanup, and deliver a tagged reproducible configuration.

## Open planning questions

- Whether the launcher should fully replace KRunner shortcuts or coexist for a
  probation period after the Quickshell prototype passes.
- Whether PlasmaZones or KZones best matches the required spanning and manual
  resize behavior on this Plasma version.
- Which non-Arch platforms, if any, should become supported after the primary
  setup is reliable.

## Project notes

- The desired aesthetic is clean, restrained, and state-aware. Low-contrast or
  invisible borders are intentional in dense tools such as VS Code when
  neighboring surfaces already communicate structure. Browser tabs and other
  ambiguous navigation require stronger separation.
