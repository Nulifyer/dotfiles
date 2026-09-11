#!/usr/bin/env python3
"""Verify that protected themes still render their approved output."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


THEME_ROOT = Path(__file__).resolve().parent
REPOSITORY_ROOT = THEME_ROOT.parent
FIXTURE_PATH = THEME_ROOT / "fixtures/gruvbox.json"


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def digest_json(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return digest_bytes(encoded)


def main() -> int:
    fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
    catalog = json.loads(
        (REPOSITORY_ROOT / "colors.json").read_text(encoding="utf-8")
    )
    if fixture.get("version") != 1 or not isinstance(fixture.get("themes"), dict):
        raise ValueError(f"invalid golden fixture: {FIXTURE_PATH}")

    failures: list[str] = []
    with tempfile.TemporaryDirectory() as temporary:
        temporary_root = Path(temporary)
        for theme_name, expected in fixture["themes"].items():
            actual_catalog = digest_json(catalog[theme_name])
            if actual_catalog != expected["catalog_sha256"]:
                failures.append(f"{theme_name}: colors.json entry changed")

            output_root = temporary_root / theme_name
            subprocess.run(
                [sys.executable, THEME_ROOT / "render.py", output_root, theme_name],
                check=True,
            )
            for relative, expected_digest in expected["outputs"].items():
                path = output_root / relative
                try:
                    actual_digest = digest_bytes(path.read_bytes())
                except OSError as error:
                    failures.append(f"{theme_name}: cannot read {relative}: {error}")
                    continue
                if actual_digest != expected_digest:
                    failures.append(
                        f"{theme_name}: rendered output changed: {relative}"
                    )

    for failure in failures:
        print(f"theme golden: {failure}", file=sys.stderr)
    if failures:
        print(
            "theme golden: update requires explicit approval for Gruvbox behavior",
            file=sys.stderr,
        )
        return 1
    print("Protected Gruvbox theme fixtures passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"theme golden: {error}", file=sys.stderr)
        raise SystemExit(1)
