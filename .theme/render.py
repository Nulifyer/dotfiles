#!/usr/bin/env python3
"""Render local Linux application themes from the shared color catalog."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


THEME_ROOT = Path(__file__).resolve().parent
CATALOG_PATH = THEME_ROOT.parent / "colors.json"
VSCODE_TEMPLATE_ROOT = THEME_ROOT / "vscode"
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
VSCODE_EXTENSION_PATH = Path(
    "vscode/extension"
)
OPENCODE_THEME_PATH = Path(
    "opencode/themes/nulifyer.json"
)

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


def blend_hex(background: str, foreground: str, percent: int) -> str:
    if not 0 <= percent <= 100:
        raise ValueError(f"invalid blend percentage: {percent}")
    background_channels = rgb(background)
    foreground_channels = rgb(foreground)
    blended = [
        round(
            background_channel
            + (foreground_channel - background_channel) * percent / 100
        )
        for background_channel, foreground_channel in zip(
            background_channels, foreground_channels
        )
    ]
    return "#" + "".join(f"{channel:02X}" for channel in blended)


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


def fzf_default_opts(context: dict[str, str]) -> str:
    colors = {
        "fg": context["fg"],
        "bg": context["bgBase"],
        "hl": context["match"],
        "fg+": context["fg"],
        "bg+": context["selection"],
        "hl+": context["accent"],
        "info": context["fgMuted"],
        "prompt": context["accent"],
        "pointer": context["accent"],
        "marker": context["success"],
        "spinner": context["accent"],
        "header": context["fgMuted"],
        "footer": context["fgMuted"],
        "border": context["accent"],
        "label": context["accent"],
        "query": context["fg"],
        "gutter": context["bgBase"],
        "separator": context["bgBorder"],
        "scrollbar": context["bgBorder"],
    }
    color_spec = ",".join(f"{name}:{value}" for name, value in colors.items())
    return " ".join(
        (
            f"--color={color_spec}",
            "--pointer=›",
            "--marker=✓",
            "--scrollbar=│",
            "--info=inline-right",
        )
    )


def render_vscode(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> tuple[str, str]:
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

    return (
        json.dumps(package, indent=2) + "\n",
        json.dumps(color_theme, indent=2) + "\n",
    )


def render_opencode(context: dict[str, str]) -> str:
    theme = {
        "primary": context["accent"],
        "secondary": context["link"],
        "accent": context["accent"],
        "error": context["error"],
        "warning": context["warning"],
        "success": context["success"],
        "info": context["info"],
        "text": context["fg"],
        "textMuted": context["fgMuted"],
        "background": context["bgBase"],
        "backgroundPanel": context["bgMid"],
        "backgroundElement": context["bgSurface"],
        "border": context["bgBorder"],
        "borderActive": context["fgMuted"],
        "borderSubtle": context["bgBorder"],
        "diffAdded": context["success"],
        "diffRemoved": context["error"],
        "diffContext": context["fgMuted"],
        "diffHunkHeader": context["link"],
        "diffHighlightAdded": context["success"],
        "diffHighlightRemoved": context["error"],
        "diffAddedBg": blend_hex(
            context["bgBase"], context["success"], 18
        ),
        "diffRemovedBg": blend_hex(
            context["bgBase"], context["error"], 18
        ),
        "diffContextBg": context["bgSurface"],
        "diffLineNumber": context["fgMuted"],
        "diffAddedLineNumberBg": blend_hex(
            context["bgBase"], context["success"], 12
        ),
        "diffRemovedLineNumberBg": blend_hex(
            context["bgBase"], context["error"], 12
        ),
        "markdownText": context["fg"],
        "markdownHeading": context["accent"],
        "markdownLink": context["link"],
        "markdownLinkText": context["link"],
        "markdownCode": context["success"],
        "markdownBlockQuote": context["fgMuted"],
        "markdownEmph": context["error"],
        "markdownStrong": context["accent"],
        "markdownHorizontalRule": context["bgBorder"],
        "markdownListItem": context["accent"],
        "markdownListEnumeration": context["cyan"],
        "markdownImage": context["link"],
        "markdownImageText": context["cyan"],
        "markdownCodeBlock": context["fg"],
        "syntaxComment": context["fgMuted"],
        "syntaxKeyword": context["error"],
        "syntaxFunction": context["accent"],
        "syntaxVariable": context["fg"],
        "syntaxString": context["success"],
        "syntaxNumber": context["magenta"],
        "syntaxType": context["success"],
        "syntaxOperator": context["error"],
        "syntaxPunctuation": context["accent"],
    }
    return json.dumps(
        {
            "$schema": "https://opencode.ai/theme.json",
            "theme": theme,
        },
        indent=2,
    ) + "\n"


def render_fish(
    key: str, theme: dict[str, Any], context: dict[str, str]
) -> str:
    prompt = theme["prompt"]
    without_hash = lambda value: value.removeprefix("#").upper()
    lines = [
        "# Generated by `./dotfiles theme`; do not edit.",
        f"set -g nulifyer_theme_name {key}",
        f"set -g nulifyer_theme_display_name {json.dumps(theme['name'])}",
        f"set -g nulifyer_theme_variant {theme['variant']}",
        f"set -gx BAT_THEME {json.dumps(theme['bat_theme'])}",
        (
            "set -gx FZF_DEFAULT_OPTS "
            f"{json.dumps(fzf_default_opts(context), ensure_ascii=False)}"
        ),
        f"set -g nulifyer_fzf_fg {without_hash(context['fg'])}",
        f"set -g nulifyer_fzf_muted {without_hash(context['fgMuted'])}",
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
        "FZF_DEFAULT_OPTS": fzf_default_opts(context),
    }
    unset_palette = not (palette := theme.get("lutgen_palette"))
    if palette:
        variables["LUTGEN_PALETTE"] = palette
    content = (
        "# Generated by `./dotfiles theme`; do not edit.\n"
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
    foregrounds = {
        "DecorationFocus": rgb_csv(context["accent"]),
        "DecorationHover": rgb_csv(context["link"]),
        "ForegroundActive": rgb_csv(context["accent"]),
        "ForegroundInactive": rgb_csv(context["fgMuted"]),
        "ForegroundLink": rgb_csv(context["link"]),
        "ForegroundNegative": rgb_csv(context["error"]),
        "ForegroundNeutral": rgb_csv(context["warning"]),
        "ForegroundNormal": rgb_csv(context["fg"]),
        "ForegroundPositive": rgb_csv(context["success"]),
        "ForegroundVisited": rgb_csv(context["magenta"]),
    }
    kde_spec = theme.get("kde", {})

    def color_set(
        name: str, default_background: str, default_alternate: str
    ) -> dict[str, str]:
        overrides = kde_spec.get(name, {})
        return {
            "BackgroundAlternate": rgb_csv(
                overrides.get("alternate", default_alternate)
            ),
            "BackgroundNormal": rgb_csv(
                overrides.get("background", default_background)
            ),
            **foregrounds,
        }

    color_sets = {
        "Button": color_set(
            "button", context["bgSurface"], context["selection"]
        ),
        "Complementary": color_set(
            "complementary", context["bgMid"], context["bgDarkest"]
        ),
        "Header": color_set(
            "header", context["bgSurface"], context["bgBase"]
        ),
        "Header][Inactive": color_set(
            "header_inactive", context["bgBase"], context["bgSurface"]
        ),
        "Tooltip": color_set(
            "tooltip", context["bgSurface"], context["selection"]
        ),
        "View": color_set(
            "view", context["bgBase"], context["selection"]
        ),
        "Window": color_set(
            "window", context["bgBase"], context["selection"]
        ),
    }
    selection = color_set("selection", context["accent"], context["find"])
    selection.update(
        {
            "ForegroundActive": rgb_csv(context["bgBase"]),
            "ForegroundInactive": rgb_csv(context["bgBase"]),
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
    for name, values in color_sets.items():
        lines.extend(section(f"Colors:{name}", values))
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
                "frame": rgb_csv(context["accent"]),
                "inactiveBackground": rgb_csv(context["bgBase"]),
                "inactiveBlend": rgb_csv(context["fgMuted"]),
                "inactiveForeground": rgb_csv(context["fgMuted"]),
                "inactiveFrame": rgb_csv(context["bgBase"]),
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
    kde_sets = {
        "button",
        "complementary",
        "header",
        "header_inactive",
        "selection",
        "tooltip",
        "view",
        "window",
    }
    kde_spec = theme.get("kde", {})
    unknown_sets = set(kde_spec) - kde_sets
    if unknown_sets:
        raise ValueError(f"{key}: unknown KDE color sets: {sorted(unknown_sets)}")
    for set_name, values in kde_spec.items():
        if not isinstance(values, dict):
            raise ValueError(f"{key}: kde.{set_name} must be an object")
        unknown_roles = set(values) - {"background", "alternate"}
        if unknown_roles:
            raise ValueError(
                f"{key}: unknown kde.{set_name} roles: {sorted(unknown_roles)}"
            )
        for value in values.values():
            normalize_hex(value)


def main() -> int:
    if sys.argv[1:] == ["--validate"]:
        catalog = load_json(CATALOG_PATH)
        for key, theme in catalog.items():
            validate_theme(key, theme)
            context = scheme_context(theme)
            render_fish(key, theme, context)
            render_shell(key, theme, context)
            render_kitty(key, theme, context)
            render_alacritty(key, theme)
            render_kde(key, theme, context)
            render_vscode(key, theme, context)
            render_opencode(context)
        return 0

    check_only = len(sys.argv) == 4 and sys.argv[1] == "--check"
    if (check_only and len(sys.argv) != 4) or (
        not check_only and len(sys.argv) != 3
    ):
        print(
            "Usage: render.py --validate\n"
            "       render.py [--check] OUTPUT_ROOT THEME_NAME",
            file=sys.stderr,
        )
        return 2

    argument_offset = 2 if check_only else 1
    output_root = Path(sys.argv[argument_offset]).expanduser().resolve()
    catalog = load_json(CATALOG_PATH)
    key = sys.argv[argument_offset + 1]
    if key not in catalog:
        print(f"theme: unknown theme: {key}", file=sys.stderr)
        return 2

    theme = catalog[key]
    validate_theme(key, theme)
    context = scheme_context(theme)
    kde_scheme, _ = render_kde(key, theme, context)
    vscode_package, vscode_theme = render_vscode(key, theme, context)
    local_state_root = output_root / ".theme/local"
    vscode_root = output_root / VSCODE_EXTENSION_PATH
    kde_root = output_root / "kde"

    outputs = {
        output_root / "fish/themes/current.fish": (
            render_fish(key, theme, context)
        ),
        output_root / "bash/theme.generated.sh": (
            render_shell(key, theme, context)
        ),
        output_root / "zsh/theme.generated.zsh": (
            render_shell(key, theme, context)
        ),
        output_root / "kitty/theme.generated.conf": (
            render_kitty(key, theme, context)
        ),
        output_root / "alacritty/theme.generated.toml": (
            render_alacritty(key, theme)
        ),
        local_state_root / "variant": theme["variant"] + "\n",
        local_state_root / "kde-scheme": kde_scheme + "\n",
        vscode_root / "package.json": vscode_package,
        vscode_root / "themes/nulifyer.json": vscode_theme,
        output_root / OPENCODE_THEME_PATH: render_opencode(context),
        local_state_root / "current": key + "\n",
    }
    for catalog_key, catalog_theme in catalog.items():
        validate_theme(catalog_key, catalog_theme)
        catalog_context = scheme_context(catalog_theme)
        catalog_scheme, catalog_content = render_kde(
            catalog_key, catalog_theme, catalog_context
        )
        outputs[kde_root / f"{catalog_scheme}.colors"] = catalog_content

    expected_kde_paths = {
        path for path in outputs if path.parent == kde_root
    }
    obsolete_kde_paths = set(kde_root.glob("Nulifyer*.colors")) - (
        expected_kde_paths
    )

    if check_only:
        stale = False
        for path, expected in outputs.items():
            try:
                actual = path.read_text(encoding="utf-8")
            except OSError:
                actual = None
            if actual != expected:
                print(
                    f"theme: generated file is stale: "
                    f"{path.relative_to(output_root)}",
                    file=sys.stderr,
                )
                stale = True
        for path in sorted(obsolete_kde_paths):
            print(
                f"theme: obsolete generated file: "
                f"{path.relative_to(output_root)}",
                file=sys.stderr,
            )
            stale = True
        return int(stale)

    for path in obsolete_kde_paths:
        path.unlink()
    for path, content in outputs.items():
        atomic_write(path, content)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"theme: {error}", file=sys.stderr)
        raise SystemExit(1)
