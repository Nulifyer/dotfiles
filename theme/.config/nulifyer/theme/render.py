#!/usr/bin/env python3
"""Render the selected shared color theme for Linux applications."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


THEME_ROOT = Path(__file__).resolve().parent
CATALOG_PATH = THEME_ROOT.parent / "themes" / "colors.json"
VSCODE_TEMPLATE_ROOT = THEME_ROOT / "vscode"
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")

ROLE_DEFAULTS = {
    "accent": "cyan",
    "link": "green",
    "match": "green",
    "find": "yellow",
    "bracket": "yellow",
    "success": "green",
    "warning": "yellow",
    "error": "red",
    "info": "blue",
    "conflict": "magenta",
    "gitAdded": "success",
    "gitModified": "warning",
    "gitDeleted": "error",
    "gitUntracked": "success",
    "gitIgnored": "fgMuted",
    "gitConflict": "conflict",
    "gitStageModified": "success",
    "gitStageDeleted": "error",
    "gitRenamed": "info",
    "gitSubmodule": "cyan",
}


def xdg_path(variable: str, fallback: Path) -> Path:
    value = os.environ.get(variable)
    return Path(value).expanduser() if value else fallback


HOME = Path.home()
STATE_ROOT = xdg_path("XDG_STATE_HOME", HOME / ".local/state") / "nulifyer/theme"
DATA_ROOT = xdg_path("XDG_DATA_HOME", HOME / ".local/share")
VSCODE_EXTENSIONS = Path(
    os.environ.get("VSCODE_EXTENSIONS", HOME / ".vscode/extensions")
).expanduser()
VSCODE_EXTENSION = VSCODE_EXTENSIONS / "nulifyer.nulifyer-theme-1.2.0"


def atomic_write(path: Path, content: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def normalize_hex(value: str) -> str:
    if not HEX_COLOR.fullmatch(value):
        raise ValueError(f"invalid color: {value}")
    return value.upper()


def adjust_hex(value: str, percent: int) -> str:
    value = normalize_hex(value)
    channels = [int(value[index : index + 2], 16) for index in (1, 3, 5)]
    adjusted = []
    for channel in channels:
        if percent < 0:
            result = channel * (100 + percent) / 100
        else:
            result = channel + (255 - channel) * percent / 100
        adjusted.append(max(0, min(255, round(result))))
    return "#" + "".join(f"{channel:02X}" for channel in adjusted)


def rgb(value: str) -> tuple[int, int, int]:
    value = normalize_hex(value)
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def rgb_csv(value: str) -> str:
    return ",".join(str(channel) for channel in rgb(value))


def rgb_escape(value: str) -> str:
    return ";".join(str(channel) for channel in rgb(value))


def scheme_context(theme: dict[str, Any]) -> dict[str, str]:
    terminal = theme["terminal"]
    normal = terminal["normal"]
    bright = terminal["bright"]
    is_light = theme["variant"] == "light"

    context = {
        "black": normalize_hex(normal["black"]),
        "red": normalize_hex(normal["red"]),
        "green": normalize_hex(normal["green"]),
        "yellow": normalize_hex(normal["yellow"]),
        "blue": normalize_hex(normal["blue"]),
        "magenta": normalize_hex(normal["magenta"]),
        "purple": normalize_hex(normal["magenta"]),
        "cyan": normalize_hex(normal["cyan"]),
        "white": normalize_hex(normal["white"]),
        "brightBlack": normalize_hex(bright["black"]),
        "brightRed": normalize_hex(bright["red"]),
        "brightGreen": normalize_hex(bright["green"]),
        "brightYellow": normalize_hex(bright["yellow"]),
        "brightBlue": normalize_hex(bright["blue"]),
        "brightMagenta": normalize_hex(bright["magenta"]),
        "brightPurple": normalize_hex(bright["magenta"]),
        "brightCyan": normalize_hex(bright["cyan"]),
        "brightWhite": normalize_hex(bright["white"]),
        "foreground": normalize_hex(terminal["fg"]),
        "fg": normalize_hex(terminal["fg"]),
        "fgDim": normalize_hex(normal["white"]),
        "fgMuted": normalize_hex(bright["black"]),
        "background": normalize_hex(terminal["bg"]),
        "bgBase": normalize_hex(terminal["bg"]),
        "cursor": normalize_hex(terminal["cursor"]),
        "selection": normalize_hex(terminal["selection"]),
    }
    context["bgMid"] = adjust_hex(context["bgBase"], 5 if is_light else -15)
    context["bgDarkest"] = adjust_hex(
        context["bgBase"], 10 if is_light else -30
    )
    context["bgSurface"] = adjust_hex(
        context["bgBase"], -5 if is_light else 8
    )
    context["bgBorder"] = adjust_hex(
        context["bgBase"], -8 if is_light else 12
    )
    context["bgHover"] = context["fg"] + "15"

    role_spec = theme.get("vscode", {})
    resolved: dict[str, str] = {}

    def resolve_role(role: str, stack: tuple[str, ...] = ()) -> str:
        if role in resolved:
            return resolved[role]
        if role in stack:
            raise ValueError(f"circular VS Code role: {' -> '.join((*stack, role))}")
        token = str(role_spec.get(role, ROLE_DEFAULTS[role]))
        if HEX_COLOR.fullmatch(token):
            value = normalize_hex(token)
        elif token in context:
            value = context[token]
        elif token in ROLE_DEFAULTS:
            value = resolve_role(token, (*stack, role))
        else:
            fallback = ROLE_DEFAULTS[role]
            value = (
                context[fallback]
                if fallback in context
                else resolve_role(fallback, (*stack, role))
            )
        resolved[role] = value
        return value

    for role in ROLE_DEFAULTS:
        context[role] = resolve_role(role)
    return context


def resolve_expression(expression: str, context: dict[str, str]) -> str:
    if expression.startswith("#"):
        return expression.upper()
    if expression.startswith("adjust:"):
        _, role, percent = expression.split(":")
        return adjust_hex(context[role], int(percent))
    role, separator, alpha = expression.partition("+")
    value = context[role]
    return value + alpha if separator else value


def render_vscode(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> None:
    workbench = load_json(VSCODE_TEMPLATE_ROOT / "workbench.json")
    tokens = load_json(VSCODE_TEMPLATE_ROOT / "tokens.json")
    semantic = load_json(VSCODE_TEMPLATE_ROOT / "semantic.json")

    color_theme = {
        "$schema": "vscode://schemas/color-theme",
        "name": f"Nulifyer — {theme['name']}",
        "type": theme["variant"],
        "semanticHighlighting": True,
        "colors": {
            name: resolve_expression(expression, context)
            for name, expression in workbench.items()
        },
        "tokenColors": [
            {
                "scope": token["scope"],
                "settings": {
                    "foreground": resolve_expression(
                        token["foreground"], context
                    ),
                    **(
                        {"fontStyle": token["fontStyle"]}
                        if "fontStyle" in token
                        else {}
                    ),
                },
            }
            for token in tokens
        ],
        "semanticTokenColors": {
            name: (
                {
                    "foreground": resolve_expression(
                        expression["foreground"], context
                    ),
                    "fontStyle": expression["fontStyle"],
                }
                if isinstance(expression, dict)
                else resolve_expression(expression, context)
            )
            for name, expression in semantic.items()
        },
    }

    package = load_json(VSCODE_TEMPLATE_ROOT / "package.json")
    package["description"] = (
        "Theme generated from Nulifyer's shared colors catalog"
    )
    package["version"] = "1.2.0"
    package["contributes"]["themes"][0]["uiTheme"] = (
        "vs" if theme["variant"] == "light" else "vs-dark"
    )

    atomic_write(
        VSCODE_EXTENSION / "package.json",
        json.dumps(package, indent=2) + "\n",
    )
    atomic_write(
        VSCODE_EXTENSION / "themes/nulifyer.json",
        json.dumps(color_theme, indent=2) + "\n",
    )


def render_fish(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> str:
    prompt = theme["prompt"]
    without_hash = lambda value: value.removeprefix("#").upper()
    lines = [
        "# Generated by `theme`; do not edit.",
        f"set -g nulifyer_theme_name {key}",
        f"set -g nulifyer_theme_display_name {json.dumps(theme['name'])}",
        f"set -g nulifyer_theme_variant {theme['variant']}",
        f"set -gx BAT_THEME {json.dumps(theme['bat_theme'])}",
        f"set -g nulifyer_prompt_os {prompt['os'].upper()}",
        f"set -g nulifyer_prompt_user {prompt['user'].upper()}",
        f"set -g nulifyer_prompt_path {prompt['path'].upper()}",
        f"set -g nulifyer_prompt_git {prompt['git'].upper()}",
        f"set -g nulifyer_prompt_ok {prompt['ok'].upper()}",
        f"set -g nulifyer_prompt_err {prompt['err'].upper()}",
        f"set -g nulifyer_prompt_duration {prompt['duration'].upper()}",
        f"set -g nulifyer_prompt_end {without_hash(context['fgMuted'])}",
        f"set -g fish_color_normal {without_hash(context['fg'])}",
        f"set -g fish_color_command {prompt['ok'].upper()}",
        f"set -g fish_color_builtin {prompt['ok'].upper()}",
        f"set -g fish_color_function {prompt['ok'].upper()}",
        f"set -g fish_color_keyword {without_hash(context['red'])}",
        f"set -g fish_color_quote {without_hash(context['brightGreen'])}",
        f"set -g fish_color_redirection {without_hash(context['blue'])}",
        f"set -g fish_color_end {without_hash(context['red'])}",
        f"set -g fish_color_error {without_hash(context['error'])}",
        f"set -g fish_color_param {without_hash(context['fg'])}",
        f"set -g fish_color_option {without_hash(context['cyan'])}",
        "set -g fish_color_valid_path --underline",
        f"set -g fish_color_comment {without_hash(context['fgMuted'])}",
        (
            "set -g fish_color_selection --background="
            f"{without_hash(context['selection'])}"
        ),
        (
            "set -g fish_color_search_match --background="
            f"{without_hash(context['bgBorder'])}"
        ),
        f"set -g fish_color_operator {without_hash(context['brightRed'])}",
        f"set -g fish_color_escape {without_hash(context['brightRed'])}",
        f"set -g fish_color_autosuggestion {without_hash(context['fgMuted'])}",
        f"set -g fish_color_cwd {without_hash(context['magenta'])}",
        f"set -g fish_color_cwd_root {without_hash(context['error'])}",
        f"set -g fish_color_user {prompt['user'].upper()}",
        f"set -g fish_color_host {without_hash(context['blue'])}",
        f"set -g fish_color_host_remote {without_hash(context['yellow'])}",
        f"set -g fish_color_status {without_hash(context['error'])}",
        f"set -g fish_color_cancel {without_hash(context['error'])}",
        "set -g fish_color_history_current --bold",
        f"set -g fish_pager_color_progress {without_hash(context['accent'])}",
        f"set -g fish_pager_color_prefix {without_hash(context['match'])}",
        f"set -g fish_pager_color_completion {without_hash(context['fg'])}",
        f"set -g fish_pager_color_description {without_hash(context['fgMuted'])}",
        (
            "set -g fish_pager_color_selected_background --background="
            f"{without_hash(context['selection'])}"
        ),
    ]
    if palette := theme.get("lutgen_palette"):
        lines.append(f"set -gx LUTGEN_PALETTE {json.dumps(palette)}")
    else:
        lines.append("set -e LUTGEN_PALETTE")
    return "\n".join(lines) + "\n"


def render_shell(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> str:
    prompt = theme["prompt"]
    variables = {
        "NULIFYER_THEME": key,
        "NULIFYER_THEME_VARIANT": theme["variant"],
        "BAT_THEME": theme["bat_theme"],
        "NULIFYER_PROMPT_OS_RGB": rgb_escape("#" + prompt["os"]),
        "NULIFYER_PROMPT_USER_RGB": rgb_escape("#" + prompt["user"]),
        "NULIFYER_PROMPT_PATH_RGB": rgb_escape("#" + prompt["path"]),
        "NULIFYER_PROMPT_GIT_RGB": rgb_escape("#" + prompt["git"]),
        "NULIFYER_PROMPT_END_RGB": rgb_escape(context["fgMuted"]),
        "NULIFYER_PROMPT_OS_HEX": "#" + prompt["os"].upper(),
        "NULIFYER_PROMPT_USER_HEX": "#" + prompt["user"].upper(),
        "NULIFYER_PROMPT_PATH_HEX": "#" + prompt["path"].upper(),
        "NULIFYER_PROMPT_GIT_HEX": "#" + prompt["git"].upper(),
        "NULIFYER_PROMPT_END_HEX": context["fgMuted"],
    }
    unset_palette = not (palette := theme.get("lutgen_palette"))
    if palette:
        variables["LUTGEN_PALETTE"] = palette
    content = (
        "# Generated by `theme`; do not edit.\n"
        + "\n".join(f"{name}='{value}'" for name, value in variables.items())
        + "\nexport "
        + " ".join(variables)
        + "\n"
    )
    if unset_palette:
        content += "unset LUTGEN_PALETTE\n"
    return content


def render_kitty(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> str:
    terminal = theme["terminal"]
    normal = terminal["normal"]
    bright = terminal["bright"]
    values = [
        ("foreground", terminal["fg"]),
        ("background", terminal["bg"]),
        ("selection_foreground", bright["white"]),
        ("selection_background", terminal["selection"]),
        ("cursor", terminal["cursor"]),
        ("url_color", context["link"]),
        ("active_border_color", context["accent"]),
        ("inactive_border_color", context["bgBorder"]),
        ("bell_border_color", context["warning"]),
        ("active_tab_foreground", terminal["bg"]),
        ("active_tab_background", context["accent"]),
        ("inactive_tab_foreground", terminal["fg"]),
        ("inactive_tab_background", context["bgSurface"]),
        ("tab_bar_background", context["bgMid"]),
    ]
    ansi = [
        normal["black"],
        normal["red"],
        normal["green"],
        normal["yellow"],
        normal["blue"],
        normal["magenta"],
        normal["cyan"],
        normal["white"],
        bright["black"],
        bright["red"],
        bright["green"],
        bright["yellow"],
        bright["blue"],
        bright["magenta"],
        bright["cyan"],
        bright["white"],
    ]
    lines = [
        f"# Generated from {key} ({theme['name']}); do not edit.",
        *(f"{name:<26} {value}" for name, value in values),
        *(f"color{index:<20} {value}" for index, value in enumerate(ansi)),
    ]
    return "\n".join(lines) + "\n"


def render_alacritty(key: str, theme: dict[str, Any]) -> str:
    terminal = theme["terminal"]
    normal = terminal["normal"]
    bright = terminal["bright"]

    def color_table(name: str, values: dict[str, str]) -> list[str]:
        return [
            f"[colors.{name}]",
            *(f'{color} = "{value}"' for color, value in values.items()),
            "",
        ]

    lines = [
        f"# Generated from {key} ({theme['name']}); do not edit.",
        "",
        "[colors.primary]",
        f'background = "{terminal["bg"]}"',
        f'foreground = "{terminal["fg"]}"',
        "",
        "[colors.cursor]",
        'text = "CellBackground"',
        f'cursor = "{terminal["cursor"]}"',
        "",
        "[colors.selection]",
        'text = "CellBackground"',
        f'background = "{terminal["selection"]}"',
        "",
        *color_table("normal", normal),
        *color_table("bright", bright),
    ]
    return "\n".join(lines).rstrip() + "\n"


def render_kde(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> tuple[str, str]:
    compact = "".join(part.capitalize() for part in key.split("_"))
    scheme_id = f"Nulifyer{compact}"
    display_name = f"Nulifyer — {theme['name']}"
    common = {
        "BackgroundAlternate": rgb_csv(context["selection"]),
        "BackgroundNormal": rgb_csv(context["bgBase"]),
        "DecorationFocus": rgb_csv(context["accent"]),
        "DecorationHover": rgb_csv(context["link"]),
        "ForegroundActive": rgb_csv(context["success"]),
        "ForegroundInactive": rgb_csv(context["fgMuted"]),
        "ForegroundLink": rgb_csv(context["link"]),
        "ForegroundNegative": rgb_csv(context["error"]),
        "ForegroundNeutral": rgb_csv(context["warning"]),
        "ForegroundNormal": rgb_csv(context["fg"]),
        "ForegroundPositive": rgb_csv(context["success"]),
        "ForegroundVisited": rgb_csv(context["magenta"]),
    }
    selection = dict(common)
    selection.update(
        {
            "BackgroundAlternate": rgb_csv(context["find"]),
            "BackgroundNormal": rgb_csv(context["accent"]),
            "ForegroundActive": rgb_csv(context["bgBase"]),
            "ForegroundInactive": rgb_csv(context["selection"]),
            "ForegroundLink": rgb_csv(context["bgBase"]),
            "ForegroundNormal": rgb_csv(context["bgBase"]),
        }
    )

    def section(name: str, values: dict[str, str]) -> list[str]:
        return [f"[{name}]", *(f"{key}={value}" for key, value in values.items()), ""]

    lines = [
        *section(
            "ColorEffects:Disabled",
            {
                "Color": rgb_csv(context["fgMuted"]),
                "ColorAmount": "0",
                "ColorEffect": "0",
                "ContrastAmount": "0.65",
                "ContrastEffect": "1",
                "IntensityAmount": "0.1",
                "IntensityEffect": "2",
            },
        ),
        *section(
            "ColorEffects:Inactive",
            {
                "ChangeSelectionColor": "true",
                "Color": rgb_csv(context["fgMuted"]),
                "ColorAmount": "0.025",
                "ColorEffect": "2",
                "ContrastAmount": "0.1",
                "ContrastEffect": "2",
                "Enable": "true",
                "IntensityAmount": "0",
                "IntensityEffect": "0",
            },
        ),
    ]
    for name in ("Button", "Tooltip", "View", "Window"):
        lines.extend(section(f"Colors:{name}", common))
    lines.extend(section("Colors:Selection", selection))
    lines.extend(
        section(
            "General",
            {
                "ColorScheme": scheme_id,
                "Name": display_name,
                "shadeSortColumn": "true",
            },
        )
    )
    lines.extend(section("KDE", {"contrast": "4"}))
    lines.extend(
        section(
            "WM",
            {
                "activeBackground": rgb_csv(context["selection"]),
                "activeBlend": rgb_csv(context["fg"]),
                "activeForeground": rgb_csv(context["fg"]),
                "inactiveBackground": rgb_csv(context["bgBase"]),
                "inactiveBlend": rgb_csv(context["fgMuted"]),
                "inactiveForeground": rgb_csv(context["fgMuted"]),
            },
        )
    )
    return scheme_id, "\n".join(lines).rstrip() + "\n"


def validate_theme(key: str, theme: dict[str, Any]) -> None:
    if theme.get("variant") not in {"dark", "light"}:
        raise ValueError(f"{key}: variant must be dark or light")
    required_prompt = {"os", "user", "path", "git", "ok", "err", "duration"}
    if set(theme.get("prompt", {})) != required_prompt:
        raise ValueError(f"{key}: prompt schema is incomplete")
    terminal = theme.get("terminal", {})
    for field in ("bg", "fg", "cursor", "selection"):
        normalize_hex(terminal[field])
    ansi = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
    for group in ("normal", "bright"):
        if set(terminal.get(group, {})) != ansi:
            raise ValueError(f"{key}: terminal.{group} schema is incomplete")
        for value in terminal[group].values():
            normalize_hex(value)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: render.py THEME_NAME", file=sys.stderr)
        return 2

    catalog = load_json(CATALOG_PATH)
    key = sys.argv[1]
    if key not in catalog:
        print(f"theme: unknown theme: {key}", file=sys.stderr)
        return 2

    theme = catalog[key]
    validate_theme(key, theme)
    context = scheme_context(theme)
    kde_scheme, kde_content = render_kde(key, theme, context)

    atomic_write(STATE_ROOT / "fish.fish", render_fish(key, theme, context))
    atomic_write(STATE_ROOT / "shell.sh", render_shell(key, theme, context))
    atomic_write(STATE_ROOT / "kitty.conf", render_kitty(key, theme, context))
    atomic_write(STATE_ROOT / "alacritty.toml", render_alacritty(key, theme))
    atomic_write(STATE_ROOT / "variant", theme["variant"] + "\n")
    atomic_write(STATE_ROOT / "kde-scheme", kde_scheme + "\n")
    atomic_write(
        DATA_ROOT / "color-schemes" / f"{kde_scheme}.colors", kde_content
    )
    render_vscode(key, theme, context)
    atomic_write(STATE_ROOT / "current", key + "\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"theme: {error}", file=sys.stderr)
        raise SystemExit(1)
