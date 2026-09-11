#!/usr/bin/env python3
"""Apply or check app-owned KDE KConfig settings."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


def error(message: str) -> ValueError:
    return ValueError(f"dotfiles: {message}")


def load_spec(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as stream:
            spec = json.load(stream)
    except (OSError, json.JSONDecodeError) as failure:
        raise error(f"cannot read KDE settings {path}: {failure}") from failure
    if not isinstance(spec, dict) or set(spec) != {"version", "settings", "lists"}:
        raise error(f"invalid KDE settings document: {path}")
    if spec["version"] != 1:
        raise error(f"unsupported KDE settings version: {path}")
    if not isinstance(spec["settings"], list) or not isinstance(spec["lists"], list):
        raise error(f"settings and lists must be arrays: {path}")
    return spec


def text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise error(f"{label} must be a non-empty string")
    return value


def config_path(target: Path, value: Any) -> Path:
    relative = Path(text(value, "file"))
    if relative.is_absolute() or ".." in relative.parts:
        raise error(f"unsafe KDE configuration path: {relative}")
    return target / ".config" / relative


def groups(value: Any) -> tuple[str, ...]:
    if not isinstance(value, list) or not value:
        raise error("groups must be a non-empty array")
    return tuple(text(item, "group") for item in value)


def command(name: str, file: Path, entry_groups: tuple[str, ...], key: str) -> list[str]:
    result = [name, "--file", str(file)]
    for group in entry_groups:
        result.extend(("--group", group))
    result.extend(("--key", key))
    return result


def read(file: Path, entry_groups: tuple[str, ...], key: str) -> str:
    result = subprocess.run(
        command("kreadconfig6", file, entry_groups, key),
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout.rstrip("\n") if result.returncode == 0 else ""


def write(file: Path, entry_groups: tuple[str, ...], key: str, value: str) -> None:
    file.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [*command("kwriteconfig6", file, entry_groups, key), "--", value],
        check=True,
    )


def parse_settings(spec: dict[str, Any], target: Path):
    for index, raw in enumerate(spec["settings"]):
        if not isinstance(raw, dict) or set(raw) != {"file", "groups", "key", "value"}:
            raise error(f"invalid setting at index {index}")
        yield (
            config_path(target, raw["file"]),
            groups(raw["groups"]),
            text(raw["key"], "key"),
            text(raw["value"], "value"),
        )


def parse_lists(spec: dict[str, Any], target: Path):
    for index, raw in enumerate(spec["lists"]):
        required = {"file", "groups", "key", "separator", "values"}
        if not isinstance(raw, dict) or set(raw) != required:
            raise error(f"invalid list setting at index {index}")
        separator = text(raw["separator"], "separator")
        values = raw["values"]
        if not isinstance(values, list) or not values:
            raise error("list values must be a non-empty array")
        yield (
            config_path(target, raw["file"]),
            groups(raw["groups"]),
            text(raw["key"], "key"),
            separator,
            tuple(text(value, "list value") for value in values),
        )


def apply(spec: dict[str, Any], target: Path) -> None:
    for file, entry_groups, key, value in parse_settings(spec, target):
        write(file, entry_groups, key, value)
    for file, entry_groups, key, separator, expected in parse_lists(spec, target):
        actual = tuple(filter(None, read(file, entry_groups, key).split(separator)))
        merged = (*actual, *(value for value in expected if value not in actual))
        write(file, entry_groups, key, separator.join(merged))


def check(spec: dict[str, Any], target: Path) -> int:
    failed = False
    for file, entry_groups, key, expected in parse_settings(spec, target):
        actual = read(file, entry_groups, key)
        if actual != expected:
            print(
                f"dotfiles: KDE drift: {file.name} "
                f"[{'/'.join(entry_groups)}] {key} = {actual!r}; expected {expected!r}",
                file=sys.stderr,
            )
            failed = True
    for file, entry_groups, key, separator, expected in parse_lists(spec, target):
        actual = tuple(filter(None, read(file, entry_groups, key).split(separator)))
        for value in expected:
            if value not in actual:
                print(
                    f"dotfiles: KDE drift: {file.name} "
                    f"[{'/'.join(entry_groups)}] {key} is missing {value!r}",
                    file=sys.stderr,
                )
                failed = True
    return int(failed)


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in {"apply", "check"}:
        print("Usage: kconfig.py apply|check SETTINGS.json", file=sys.stderr)
        return 2
    target = Path(os.environ.get("DOTFILES_TARGET", str(Path.home()))).resolve()
    spec = load_spec(Path(sys.argv[2]))
    if sys.argv[1] == "apply":
        apply(spec, target)
        return 0
    return check(spec, target)


if __name__ == "__main__":
    raise SystemExit(main())
