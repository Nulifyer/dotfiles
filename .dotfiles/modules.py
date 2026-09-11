#!/usr/bin/env python3
"""Discover and validate app-owned dotfiles module manifests."""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


MANIFEST_NAME = "dotfiles.json"
MANIFEST_KEYS = {"desktop", "commands", "packages", "deployments"}
DEPENDENCY_CLASSES = {"required", "managed", "optional"}
DEPENDENCY_NAME = re.compile(r"^[a-zA-Z0-9@._+-]+$")
HOOKS = ("apply", "reload")
DEPLOYMENT_KEYS = {
    "source",
    "target",
    "kind",
    "install",
    "preserve",
    "exclude",
}
KINDS = {"file", "contents", "directory"}
INSTALL_METHODS = {"link", "copy"}
CORE_COMMANDS = {
    "required": ("bash", "git", "jq", "python3"),
}
CORE_PACKAGES = {
    "arch": {
        "required": ("bash", "coreutils", "git", "jq", "python"),
    }
}


class ManifestError(ValueError):
    pass


@dataclass(frozen=True)
class Module:
    name: str
    directory: Path
    manifest: Path
    desktop: str | None
    commands: dict[str, Any]
    packages: dict[str, Any]
    deployments: tuple[dict[str, Any], ...]


@dataclass(frozen=True)
class Deployment:
    module: Module
    source: Path
    source_relative: Path
    target: Path
    kind: str
    install: str
    preserve: tuple[Path, ...]
    exclude: tuple[str, ...]

    @property
    def identifier(self) -> str:
        local_source = self.source_relative.relative_to(self.module.name)
        return f"{self.module.name}/{local_source}"


def fail(message: str) -> ManifestError:
    return ManifestError(f"dotfiles: {message}")


def load_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as stream:
            return json.load(stream)
    except (OSError, json.JSONDecodeError) as error:
        raise fail(f"cannot read manifest {path}: {error}") from error


def safe_relative(value: Any, label: str, *, allow_dot: bool = False) -> Path:
    if not isinstance(value, str) or not value:
        raise fail(f"{label} must be a non-empty string")
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise fail(f"unsafe relative path for {label}: {value}")
    if path == Path(".") and not allow_dot:
        raise fail(f"{label} cannot be the module root")
    return path


def string_list(value: Any, label: str) -> tuple[str, ...]:
    if value is None:
        return ()
    if not isinstance(value, list) or not all(
        isinstance(item, str) and item for item in value
    ):
        raise fail(f"{label} must be an array of non-empty strings")
    return tuple(value)


def validate_class_map(value: Any, label: str) -> None:
    if not isinstance(value, dict):
        raise fail(f"{label} must be an object")
    unknown = set(value) - DEPENDENCY_CLASSES
    if unknown:
        raise fail(f"unknown dependency classes in {label}: {sorted(unknown)}")
    seen: set[str] = set()
    for dependency_class, names in value.items():
        values = string_list(names, f"{label}.{dependency_class}")
        if len(set(values)) != len(values):
            raise fail(f"duplicate dependencies in {label}.{dependency_class}")
        for name in values:
            if not DEPENDENCY_NAME.fullmatch(name):
                raise fail(f"invalid dependency name in {label}: {name}")
            if name in seen:
                raise fail(f"dependency appears in multiple classes in {label}: {name}")
            seen.add(name)


def discover(root: Path) -> tuple[Module, ...]:
    modules: list[Module] = []
    for directory in sorted(path for path in root.iterdir() if path.is_dir()):
        if directory.name.startswith("."):
            continue
        manifest = directory / MANIFEST_NAME
        if not manifest.is_file():
            raise fail(
                f"visible application folder has no {MANIFEST_NAME}: "
                f"{directory.name}"
            )
        raw = load_json(manifest)
        if not isinstance(raw, dict):
            raise fail(f"manifest must contain an object: {manifest}")
        unknown = set(raw) - MANIFEST_KEYS
        if unknown:
            raise fail(f"unknown manifest keys in {manifest}: {sorted(unknown)}")
        name = directory.name
        desktop = raw.get("desktop")
        if desktop is not None and (not isinstance(desktop, str) or not desktop):
            raise fail(f"desktop must be a non-empty string: {manifest}")
        commands = raw.get("commands", {})
        packages = raw.get("packages", {})
        validate_class_map(commands, f"{name}.commands")
        validate_class_map(packages, f"{name}.packages")
        raw_deployments = raw.get("deployments", [])
        if not isinstance(raw_deployments, list):
            raise fail(f"deployments must be an array: {manifest}")
        modules.append(
            Module(
                name=name,
                directory=directory,
                manifest=manifest,
                desktop=desktop,
                commands=commands,
                packages=packages,
                deployments=tuple(raw_deployments),
            )
        )
    if not modules:
        raise fail(f"no application modules found under {root}")
    return tuple(modules)


def parse_deployments(root: Path, modules: Iterable[Module]) -> tuple[Deployment, ...]:
    deployments: list[Deployment] = []
    identifiers: set[str] = set()
    for module in modules:
        for raw in module.deployments:
            if not isinstance(raw, dict):
                raise fail(f"deployment in {module.manifest} must be an object")
            unknown = set(raw) - DEPLOYMENT_KEYS
            if unknown:
                raise fail(
                    f"unknown deployment keys in {module.manifest}: {sorted(unknown)}"
                )
            source_local = safe_relative(
                raw.get("source"), f"{module.name}.source", allow_dot=True
            )
            identifier = f"{module.name}/{source_local}"
            if identifier in identifiers:
                raise fail(f"duplicate deployment identifier: {identifier}")
            identifiers.add(identifier)
            target = safe_relative(
                raw.get("target"), f"{identifier}.target", allow_dot=True
            )
            source = module.directory / source_local
            kind = raw.get("kind", "file")
            install = raw.get("install", "link")
            if kind not in KINDS:
                raise fail(f"unknown source kind for {identifier}: {kind}")
            if install not in INSTALL_METHODS:
                raise fail(f"unknown install method for {identifier}: {install}")
            if kind == "directory" and install == "copy":
                raise fail(f"directory copies are not supported: {identifier}")
            if kind == "file" and not (source.is_file() or source.is_symlink()):
                raise fail(f"deployment source is missing: {source}")
            if kind != "file" and not source.is_dir():
                raise fail(f"deployment source is missing: {source}")
            preserve = tuple(
                safe_relative(item, f"{identifier}.preserve")
                for item in string_list(raw.get("preserve"), f"{identifier}.preserve")
            )
            exclude = string_list(raw.get("exclude"), f"{identifier}.exclude")
            deployments.append(
                Deployment(
                    module=module,
                    source=source,
                    source_relative=source.relative_to(root),
                    target=target,
                    kind=kind,
                    install=install,
                    preserve=preserve,
                    exclude=exclude,
                )
            )
    return tuple(deployments)


def selected_desktop() -> tuple[str, str]:
    override = os.environ.get("DOTFILES_DESKTOP", "").strip()
    if override:
        return override.casefold(), "DOTFILES_DESKTOP"
    current = os.environ.get("XDG_CURRENT_DESKTOP", "").strip()
    if current:
        values = [item.casefold() for item in current.replace(";", ":").split(":")]
        if "kde" in values or "plasma" in values:
            return "kde", "XDG_CURRENT_DESKTOP"
        return values[0], "XDG_CURRENT_DESKTOP"
    return "unknown", "no desktop signal"
def module_status(module: Module) -> tuple[bool, str]:
    if module.desktop is None:
        return True, "no conditions"
    desktop, source = selected_desktop()
    required = module.desktop.casefold()
    if desktop == required:
        return True, f"desktop={desktop} from {source}"
    return False, f"requires desktop={required}; detected {desktop} from {source}"


def source_files(deployment: Deployment) -> tuple[Path, ...]:
    if deployment.kind == "file":
        return (deployment.source,)
    if deployment.kind == "directory":
        return ()
    if not deployment.source.is_dir():
        return ()
    files: list[Path] = []
    for path in deployment.source.rglob("*"):
        if not (path.is_file() or path.is_symlink()):
            continue
        relative = path.relative_to(deployment.source).as_posix()
        if any(fnmatch.fnmatch(relative, pattern) for pattern in deployment.exclude):
            continue
        files.append(path)
    return tuple(sorted(files))


def target_paths(deployment: Deployment) -> tuple[Path, ...]:
    if deployment.kind in {"file", "directory"}:
        return (deployment.target,)
    return tuple(
        deployment.target / path.relative_to(deployment.source)
        for path in source_files(deployment)
    )


def validate(root: Path) -> tuple[Module, ...]:
    modules = discover(root)
    deployments = parse_deployments(root, modules)
    roots: dict[Path, Deployment] = {}
    owners: dict[Path, str] = {}
    for deployment in deployments:
        if deployment.target in roots:
            raise fail(
                f"deployment roots collide at {deployment.target}: "
                f"{roots[deployment.target].identifier} and {deployment.identifier}"
            )
        roots[deployment.target] = deployment
        for target in target_paths(deployment):
            if target in owners:
                raise fail(
                    f"deployment target collision at {target}: "
                    f"{owners[target]} and {deployment.identifier}"
                )
            owners[target] = deployment.identifier
    for path, deployment in roots.items():
        if deployment.kind != "directory":
            continue
        for other_path, other in roots.items():
            if other is deployment:
                continue
            if path in other_path.parents:
                raise fail(
                    f"directory deployment {deployment.identifier} contains "
                    f"the root of {other.identifier}: {other_path}"
                )
    return modules


def command_modules(root: Path) -> None:
    for module in discover(root):
        active, reason = module_status(module)
        print(f"{module.name}\t{'enabled' if active else 'skipped'}\t{reason}")


def plan_field(value: object) -> str:
    text = str(value)
    if "\0" in text or "\n" in text or "\t" in text:
        raise fail(f"unsupported control character in deployment plan: {text!r}")
    return text


def plan_record(*fields: object) -> None:
    record = "\t".join(plan_field(field) for field in fields)
    sys.stdout.buffer.write(record.encode() + b"\0")


def command_plan(root: Path) -> None:
    modules = validate(root)
    deployments = parse_deployments(root, modules)
    for deployment in deployments:
        active, _ = module_status(deployment.module)
        plan_record(
            "deployment",
            int(active),
            deployment.identifier,
            deployment.source_relative.as_posix(),
            deployment.target.as_posix(),
            deployment.kind,
            deployment.install,
            deployment.module.name,
        )
        for path in source_files(deployment):
            plan_record("file", deployment.identifier, path.relative_to(root))
        for path in deployment.preserve:
            plan_record("preserve", deployment.identifier, path)
    for module in modules:
        active, _ = module_status(module)
        for action in HOOKS:
            path = module.directory / f"{action}.sh"
            if path.is_file():
                plan_record("hook", int(active), action, module.name, path)


def dependency_rows(root: Path, dependency_type: str, platform: str | None) -> None:
    modules = discover(root)
    priorities = {"optional": 0, "managed": 1, "required": 2}
    collected: dict[str, tuple[str, set[str]]] = {}

    def add(dependency_class: str, name: str, owner: str) -> None:
        if name in collected:
            current_class, owners = collected[name]
            if priorities[dependency_class] > priorities[current_class]:
                current_class = dependency_class
            owners.add(owner)
            collected[name] = current_class, owners
        else:
            collected[name] = dependency_class, {owner}

    if dependency_type == "commands":
        for dependency_class, names in CORE_COMMANDS.items():
            for name in names:
                add(dependency_class, name, "runner")
    else:
        assert platform is not None
        for dependency_class, names in CORE_PACKAGES.get(platform, {}).items():
            for name in names:
                add(dependency_class, name, "runner")

    for module in modules:
        active, _ = module_status(module)
        if not active:
            continue
        if dependency_type == "commands":
            class_map = module.commands
        else:
            class_map = module.packages
        for dependency_class, names in class_map.items():
            for name in names:
                add(dependency_class, name, module.name)

    for name in sorted(collected):
        dependency_class, owners = collected[name]
        print(f"{dependency_class}\t{name}\t{','.join(sorted(owners))}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("modules")
    subparsers.add_parser("plan")
    dependencies = subparsers.add_parser("dependencies")
    dependencies.add_argument("type", choices=("commands", "packages"))
    dependencies.add_argument("--platform", choices=("arch",))
    arguments = parser.parse_args()
    root = arguments.root.expanduser().resolve()
    try:
        if arguments.command == "modules":
            command_modules(root)
        elif arguments.command == "plan":
            command_plan(root)
        elif arguments.command == "dependencies":
            if arguments.type == "packages" and arguments.platform is None:
                raise fail("package dependency listing requires --platform")
            dependency_rows(root, arguments.type, arguments.platform)
    except ManifestError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
