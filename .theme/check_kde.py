#!/usr/bin/env python3
"""Compare generated KDE color keys with the active kdeglobals file."""

from __future__ import annotations

import configparser
import sys
from pathlib import Path


def read_config(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    with path.open(encoding="utf-8") as stream:
        parser.read_file(stream)
    return parser


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: check_kde.py EXPECTED.colors KDEGLOBALS", file=sys.stderr)
        return 2

    expected_path = Path(sys.argv[1])
    actual_path = Path(sys.argv[2])
    expected = read_config(expected_path)
    actual = read_config(actual_path)
    failed = False

    for section in expected.sections():
        for key, expected_value in expected[section].items():
            if section == "General" and key == "Name":
                continue
            actual_value = actual.get(section, key, fallback="")
            if actual_value != expected_value:
                print(
                    "dotfiles: KDE drift: "
                    f"kdeglobals [{section}] {key} = {actual_value!r}; "
                    f"expected {expected_value!r}",
                    file=sys.stderr,
                )
                failed = True

    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
