#!/usr/bin/env python3
"""Audit semantic theme roles against explicit contrast policy."""

from __future__ import annotations

import importlib.util
import json
import sys
from dataclasses import dataclass
from pathlib import Path


THEME_ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = THEME_ROOT.parent
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location(
    "nulifyer_theme_renderer", THEME_ROOT / "render.py"
)
assert SPEC and SPEC.loader
renderer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(renderer)


@dataclass(frozen=True)
class Check:
    name: str
    foreground: str
    background: str
    minimum: float


CHECKS = (
    Check("text.primary", "textPrimary", "uiBackground", 4.5),
    Check("text.muted", "textMuted", "uiBackground", 3.0),
    Check(
        "selection.foreground",
        "selectionForeground",
        "selectionBackground",
        4.5,
    ),
    Check("accent.nonText", "accent", "uiBackground", 3.0),
    Check("status.error", "error", "uiBackground", 3.0),
    Check("status.warning", "warning", "uiBackground", 3.0),
    Check("status.success", "success", "uiBackground", 3.0),
    Check("status.info", "info", "uiBackground", 3.0),
)


def luminance(value: str) -> float:
    channels = []
    for channel in renderer.rgb(value):
        normalized = channel / 255
        channels.append(
            normalized / 12.92
            if normalized <= 0.04045
            else ((normalized + 0.055) / 1.055) ** 2.4
        )
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(first: str, second: str) -> float:
    lighter, darker = sorted((luminance(first), luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def main() -> int:
    report_only = sys.argv[1:] == ["--report"]
    if sys.argv[1:] not in ([], ["--report"]):
        print("Usage: audit.py [--report]", file=sys.stderr)
        return 2

    catalog = json.loads((REPOSITORY_ROOT / "colors.json").read_text())
    schema = json.loads((THEME_ROOT / "colors.schema.json").read_text())
    schema_roles = set(
        schema["$defs"]["theme"]["properties"]["roles"]["properties"]
    )
    renderer_roles = set(renderer.SEMANTIC_ROLE_DEFAULTS)
    if schema_roles != renderer_roles:
        missing = sorted(renderer_roles - schema_roles)
        extra = sorted(schema_roles - renderer_roles)
        raise ValueError(
            f"schema role mismatch; missing={missing}, extra={extra}"
        )
    baseline = json.loads((THEME_ROOT / "contrast-baseline.json").read_text())
    if baseline.get("version") != 1:
        raise ValueError("unsupported contrast baseline version")
    expected = {
        theme: set(names)
        for theme, names in baseline.get("known_failures", {}).items()
    }
    actual: dict[str, set[str]] = {}
    rows: list[tuple[str, str, float, float]] = []
    for theme_name, theme in catalog.items():
        renderer.validate_theme(theme_name, theme)
        context = renderer.scheme_context(theme)
        for check in CHECKS:
            ratio = contrast(
                context[check.foreground], context[check.background]
            )
            rows.append((theme_name, check.name, ratio, check.minimum))
            if ratio < check.minimum:
                actual.setdefault(theme_name, set()).add(check.name)

    if report_only:
        for theme_name, check_name, ratio, minimum in rows:
            result = "fail" if ratio < minimum else "pass"
            print(
                f"{theme_name}\t{check_name}\t{ratio:.2f}\t{minimum:.1f}\t{result}"
            )
        return 0

    failed = False
    for theme_name in sorted(set(actual) | set(expected)):
        new = actual.get(theme_name, set()) - expected.get(theme_name, set())
        resolved = expected.get(theme_name, set()) - actual.get(theme_name, set())
        for check_name in sorted(new):
            print(
                f"theme audit: new contrast failure: {theme_name} {check_name}",
                file=sys.stderr,
            )
            failed = True
        for check_name in sorted(resolved):
            print(
                f"theme audit: remove resolved baseline: {theme_name} {check_name}",
                file=sys.stderr,
            )
            failed = True
    if failed:
        return 1
    failure_count = sum(len(failures) for failures in actual.values())
    print(
        f"Theme contrast audit passed with {failure_count} known failures "
        f"across {len(actual)} themes."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"theme audit: {error}", file=sys.stderr)
        raise SystemExit(1)
