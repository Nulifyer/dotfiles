#!/usr/bin/env python3
"""Apply a generated KDE color scheme to an isolated kdeglobals file."""

from __future__ import annotations

import configparser
import subprocess
import sys
from pathlib import Path


def read(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    with path.open(encoding="utf-8") as stream:
        parser.read_file(stream)
    return parser


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: apply_scheme.py SCHEME.colors KDEGLOBALS", file=sys.stderr)
        return 2
    scheme_path = Path(sys.argv[1])
    target = Path(sys.argv[2])
    scheme = read(scheme_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    for section in scheme.sections():
        section_groups = section.split("][")
        for key, value in scheme[section].items():
            if section == "General" and key == "Name":
                continue
            command = ["kwriteconfig6", "--file", str(target)]
            for group in section_groups:
                command.extend(("--group", group))
            command.extend(("--key", key, "--", value))
            subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
