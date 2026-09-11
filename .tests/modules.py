#!/usr/bin/env python3
"""Behavior tests for app-owned manifest discovery."""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / ".dotfiles/modules.py"
SPEC = importlib.util.spec_from_file_location("dotfiles_modules", RUNNER)
assert SPEC and SPEC.loader
modules = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = modules
SPEC.loader.exec_module(modules)


def write_manifest(root: Path, name: str, data: dict[str, object]) -> Path:
    directory = root / name
    directory.mkdir()
    manifest = {"version": 1, "name": name, **data}
    (directory / "dotfiles.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    return directory


def expect_error(action, text: str) -> None:
    try:
        action()
    except modules.ManifestError as error:
        assert text in str(error), error
    else:
        raise AssertionError(f"expected ManifestError containing {text!r}")


def test_current_repository() -> None:
    discovered = modules.validate(ROOT)
    assert {module.name for module in discovered} == {
        "alacritty",
        "applications",
        "bash",
        "brave",
        "fish",
        "kde",
        "kitty",
        "opencode",
        "spectacle",
        "vscode",
        "zsh",
    }


def test_conditions_and_exclusions() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        app = write_manifest(
            root,
            "app",
            {
                "deployments": [
                    {
                        "name": "files",
                        "source": ".",
                        "target": ".config/app",
                        "kind": "contents",
                        "install": "link",
                        "exclude": ["dotfiles.json"],
                    }
                ]
            },
        )
        (app / "config.ini").write_text("value=true\n", encoding="utf-8")
        kde = write_manifest(
            root,
            "kde",
            {
                "when": {"desktop": ["kde"]},
                "deployments": [
                    {
                        "name": "theme",
                        "source": "theme.colors",
                        "target": ".local/share/color-schemes/theme.colors",
                        "kind": "file",
                        "install": "copy",
                    }
                ],
            },
        )
        (kde / "theme.colors").write_text("[General]\n", encoding="utf-8")
        discovered = modules.validate(root)
        deployments = modules.parse_deployments(root, discovered)
        app_deployment = next(item for item in deployments if item.module.name == "app")
        assert [path.name for path in modules.source_files(app_deployment)] == [
            "config.ini"
        ]
        kde_module = next(item for item in discovered if item.name == "kde")
        old_desktop = os.environ.get("DOTFILES_DESKTOP")
        try:
            os.environ["DOTFILES_DESKTOP"] = "gnome"
            assert modules.module_status(kde_module)[0] is False
            os.environ["DOTFILES_DESKTOP"] = "kde"
            assert modules.module_status(kde_module)[0] is True
        finally:
            if old_desktop is None:
                os.environ.pop("DOTFILES_DESKTOP", None)
            else:
                os.environ["DOTFILES_DESKTOP"] = old_desktop


def test_rejects_collisions_and_unsafe_paths() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        first = write_manifest(
            root,
            "first",
            {
                "deployments": [
                    {
                        "name": "config",
                        "source": "one",
                        "target": ".config/shared",
                        "kind": "file",
                        "install": "link",
                    }
                ]
            },
        )
        second = write_manifest(
            root,
            "second",
            {
                "deployments": [
                    {
                        "name": "config",
                        "source": "two",
                        "target": ".config/shared",
                        "kind": "file",
                        "install": "link",
                    }
                ]
            },
        )
        (first / "one").touch()
        (second / "two").touch()
        expect_error(lambda: modules.validate(root), "deployment roots collide")

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        directory = write_manifest(
            root,
            "unsafe",
            {
                "deployments": [
                    {
                        "name": "config",
                        "source": "../outside",
                        "target": ".config/unsafe",
                        "kind": "file",
                        "install": "link",
                    }
                ]
            },
        )
        assert directory
        expect_error(lambda: modules.validate(root), "unsafe relative path")


def main() -> None:
    test_current_repository()
    test_conditions_and_exclusions()
    test_rejects_collisions_and_unsafe_paths()
    print("Application manifest tests passed.")


if __name__ == "__main__":
    main()
