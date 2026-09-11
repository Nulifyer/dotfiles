#!/usr/bin/env python3
"""Render the app-owned VS Code theme extension."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable


THEME_ROOT = Path(__file__).resolve().parent


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def render(
    theme: dict[str, Any],
    context: dict[str, str],
    resolve: Callable[[str, dict[str, str]], str],
) -> tuple[str, str]:
    workbench = load_json(THEME_ROOT / "workbench.json")
    tokens = load_json(THEME_ROOT / "tokens.json")
    semantic = load_json(THEME_ROOT / "semantic.json")

    color_theme = {
        "$schema": "vscode://schemas/color-theme",
        "name": f"Nulifyer — {theme['name']}",
        "type": theme["variant"],
        "semanticHighlighting": True,
        "colors": {
            name: resolve(expression, context)
            for name, expression in workbench.items()
        },
        "tokenColors": [
            {
                "scope": token["scope"],
                "settings": {
                    "foreground": resolve(token["foreground"], context),
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
                    "foreground": resolve(expression["foreground"], context),
                    "fontStyle": expression["fontStyle"],
                }
                if isinstance(expression, dict)
                else resolve(expression, context)
            )
            for name, expression in semantic.items()
        },
    }

    package = load_json(THEME_ROOT / "package.json")
    package["description"] = (
        "Theme generated from Nulifyer's shared colors catalog"
    )
    package["version"] = "1.2.0"
    package["contributes"]["themes"][0]["uiTheme"] = (
        "vs" if theme["variant"] == "light" else "vs-dark"
    )
    package["contributes"]["configurationDefaults"] = {
        "git-graph.graph.colours": [
            resolve(f"contrast:{role}:uiBackground:3.0", context)
            for role in (
                "blue",
                "magenta",
                "green",
                "yellow",
                "cyan",
                "red",
                "brightBlue",
                "brightMagenta",
                "brightGreen",
                "brightYellow",
                "brightCyan",
                "brightRed",
            )
        ]
    }

    return (
        json.dumps(package, indent=2) + "\n",
        json.dumps(color_theme, indent=2) + "\n",
    )
