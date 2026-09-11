#!/usr/bin/env python3
"""Validate VS Code extension integrations for every catalog theme."""

from __future__ import annotations

import json
import runpy
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
renderer = runpy.run_path(str(REPOSITORY_ROOT / ".theme/render.py"))
RAINBOW_SCOPES = (
    "rainbow1",
    "keyword.rainbow2",
    "entity.name.function.rainbow3",
    "comment.rainbow4",
    "string.rainbow5",
    "variable.parameter.rainbow6",
    "constant.numeric.rainbow7",
    "entity.name.type.rainbow8",
    "markup.bold.rainbow9",
    "invalid.rainbow10",
)
TRACKING_COLORS = ("rainbowtrack1", "rainbowtrack2", "rainbowtrack3")


def main() -> int:
    catalog = json.loads((REPOSITORY_ROOT / "colors.json").read_text())
    for theme_name, theme in catalog.items():
        renderer["validate_theme"](theme_name, theme)
        context = renderer["scheme_context"](theme)
        package_text, theme_text = renderer["render_vscode"](
            theme_name, theme, context
        )
        package = json.loads(package_text)
        generated = json.loads(theme_text)
        background = generated["colors"]["editor.background"]

        for color_id in TRACKING_COLORS:
            if color_id not in generated["colors"]:
                raise ValueError(f"{theme_name}: missing {color_id}")

        token_colors = {
            entry["scope"]: entry["settings"]["foreground"]
            for entry in generated["tokenColors"]
        }
        for scope in RAINBOW_SCOPES:
            foreground = token_colors.get(scope)
            if foreground is None:
                raise ValueError(f"{theme_name}: missing Rainbow CSV scope {scope}")
            ratio = renderer["contrast_ratio"](foreground, background)
            if ratio < 4.5:
                raise ValueError(
                    f"{theme_name}: Rainbow CSV scope {scope} contrast {ratio:.2f}"
                )

        graph_colors = package["contributes"]["configurationDefaults"][
            "git-graph.graph.colours"
        ]
        if len(graph_colors) != 12:
            raise ValueError(f"{theme_name}: Git Graph requires 12 colors")
        for foreground in graph_colors:
            ratio = renderer["contrast_ratio"](foreground, background)
            if ratio < 3.0:
                raise ValueError(
                    f"{theme_name}: Git Graph color contrast {ratio:.2f}"
                )

    print("VS Code extension theme tests passed for all catalog themes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
