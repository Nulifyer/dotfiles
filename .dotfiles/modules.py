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
MANIFEST_KEYS = {"$schema", "version", "name", "when", "dependencies", "deployments"}
WHEN_KEYS = {"desktop"}
DEPENDENCY_KEYS = {"commands", "packages"}
DEPENDENCY_CLASSES = {"required", "managed", "optional"}
PACKAGE_PLATFORMS = {"arch"}
DEPENDENCY_NAME = re.compile(r"^[a-zA-Z0-9@._+-]+$")
HOOKS = {"apply", "check", "reload", "clean", "validate"}
DEPLOYMENT_KEYS = {
    "name",
    "source",
    "target",
    "kind",
    "install",
    "preserve",
    "exclude",
    "generated",
}
KINDS = {"file", "contents", "directory"}
INSTALL_METHODS = {"link", "copy"}
CORE_COMMANDS = {
    "required": ("bash", "git", "jq", "python3", "sha256sum"),
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
    when: dict[str, Any]
    dependencies: dict[str, Any]
    deployments: tuple[dict[str, Any], ...]


@dataclass(frozen=True)
class Deployment:
    module: Module
    name: str
    source: Path
    source_relative: Path
    target: Path
    kind: str
    install: str
    preserve: tuple[Path, ...]
    exclude: tuple[str, ...]
    generated: bool

    @property
    def identifier(self) -> str:
        return f"{self.module.name}/{self.name}"


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
            raise fail(f"visible application folder has no {MANIFEST_NAME}: {directory.name}")
        raw = load_json(manifest)
        if not isinstance(raw, dict):
            raise fail(f"manifest must contain an object: {manifest}")
        unknown = set(raw) - MANIFEST_KEYS
        if unknown:
            raise fail(f"unknown manifest keys in {manifest}: {sorted(unknown)}")
        if raw.get("version") != 1:
            raise fail(f"unsupported manifest version in {manifest}")
        name = raw.get("name")
        if name != directory.name:
            raise fail(f"manifest name must match its folder: {manifest}")
        when = raw.get("when", {})
        if not isinstance(when, dict):
            raise fail(f"when must be an object: {manifest}")
        unknown_when = set(when) - WHEN_KEYS
        if unknown_when:
            raise fail(f"unknown conditions in {manifest}: {sorted(unknown_when)}")
        desktops = string_list(when.get("desktop"), f"{name}.when.desktop")
        if desktops and len({item.casefold() for item in desktops}) != len(desktops):
            raise fail(f"duplicate desktop condition in {manifest}")
        dependencies = raw.get("dependencies", {})
        if not isinstance(dependencies, dict):
            raise fail(f"dependencies must be an object: {manifest}")
        unknown_dependencies = set(dependencies) - DEPENDENCY_KEYS
        if unknown_dependencies:
            raise fail(
                f"unknown dependency groups in {manifest}: {sorted(unknown_dependencies)}"
            )
        if "commands" in dependencies:
            validate_class_map(dependencies["commands"], f"{name}.dependencies.commands")
        packages = dependencies.get("packages", {})
        if not isinstance(packages, dict):
            raise fail(f"{name}.dependencies.packages must be an object")
        unknown_platforms = set(packages) - PACKAGE_PLATFORMS
        if unknown_platforms:
            raise fail(
                f"unknown package platforms in {manifest}: {sorted(unknown_platforms)}"
            )
        for platform, class_map in packages.items():
            validate_class_map(class_map, f"{name}.dependencies.packages.{platform}")
        raw_deployments = raw.get("deployments")
        if not isinstance(raw_deployments, list):
            raise fail(f"deployments must be an array: {manifest}")
        modules.append(
            Module(
                name=name,
                directory=directory,
                manifest=manifest,
                when=when,
                dependencies=dependencies,
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
        local_names: set[str] = set()
        for raw in module.deployments:
            if not isinstance(raw, dict):
                raise fail(f"deployment in {module.manifest} must be an object")
            unknown = set(raw) - DEPLOYMENT_KEYS
            if unknown:
                raise fail(
                    f"unknown deployment keys in {module.manifest}: {sorted(unknown)}"
                )
            name = raw.get("name")
            if not isinstance(name, str) or not name:
                raise fail(f"deployment name is missing in {module.manifest}")
            if name in local_names:
                raise fail(f"duplicate deployment name {module.name}/{name}")
            local_names.add(name)
            identifier = f"{module.name}/{name}"
            if identifier in identifiers:
                raise fail(f"duplicate deployment identifier: {identifier}")
            identifiers.add(identifier)
            source_local = safe_relative(
                raw.get("source"), f"{identifier}.source", allow_dot=True
            )
            target = safe_relative(raw.get("target"), f"{identifier}.target", allow_dot=True)
            source = module.directory / source_local
            kind = raw.get("kind")
            install = raw.get("install")
            if kind not in KINDS:
                raise fail(f"unknown source kind for {identifier}: {kind}")
            if install not in INSTALL_METHODS:
                raise fail(f"unknown install method for {identifier}: {install}")
            if kind == "directory" and install == "copy":
                raise fail(f"directory copies are not supported: {identifier}")
            generated = raw.get("generated", False)
            if not isinstance(generated, bool):
                raise fail(f"generated must be boolean: {identifier}")
            if not generated:
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
                    name=name,
                    source=source,
                    source_relative=source.relative_to(root),
                    target=target,
                    kind=kind,
                    install=install,
                    preserve=preserve,
                    exclude=exclude,
                    generated=generated,
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
    desktops = tuple(item.casefold() for item in module.when.get("desktop", ()))
    if not desktops:
        return True, "no conditions"
    desktop, source = selected_desktop()
    if desktop in desktops:
        return True, f"desktop={desktop} from {source}"
    return False, f"requires desktop={','.join(desktops)}; detected {desktop} from {source}"


def source_files(deployment: Deployment) -> tuple[Path, ...]:
    if deployment.kind == "file":
        return (deployment.source,)
    if deployment.kind == "directory":
        return ()
    if not deployment.source.is_dir():
        if deployment.generated:
            return ()
        raise fail(f"deployment source is missing: {deployment.source}")
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


def find_deployment(root: Path, identifier: str) -> Deployment:
    modules = validate(root)
    for deployment in parse_deployments(root, modules):
        if deployment.identifier == identifier:
            return deployment
    raise fail(f"unknown deployment: {identifier}")


def command_rows(root: Path, include_inactive: bool) -> None:
    modules = validate(root)
    for deployment in parse_deployments(root, modules):
        active, _ = module_status(deployment.module)
        if not active and not include_inactive:
            continue
        print(
            "\t".join(
                (
                    deployment.identifier,
                    deployment.source_relative.as_posix(),
                    deployment.target.as_posix(),
                    deployment.kind,
                    deployment.install,
                    deployment.module.name,
                )
            )
        )


def command_files(root: Path, identifier: str) -> None:
    deployment = find_deployment(root, identifier)
    for path in source_files(deployment):
        sys.stdout.buffer.write(str(path.relative_to(root)).encode() + b"\0")


def command_preserve(root: Path, identifier: str) -> None:
    deployment = find_deployment(root, identifier)
    for path in deployment.preserve:
        print(path.as_posix())


def command_modules(root: Path) -> None:
    for module in validate(root):
        active, reason = module_status(module)
        print(f"{module.name}\t{'enabled' if active else 'skipped'}\t{reason}")


def command_manifests(root: Path) -> None:
    for module in validate(root):
        print(module.manifest)


def command_hooks(root: Path, action: str, include_inactive: bool) -> None:
    for module in validate(root):
        active, _ = module_status(module)
        if not active and not include_inactive:
            continue
        path = module.directory / f"{action}.sh"
        if path.is_file():
            print(f"{module.name}\t{path}")


def dependency_rows(root: Path, dependency_type: str, platform: str | None) -> None:
    modules = validate(root)
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
            class_map = module.dependencies.get("commands", {})
        else:
            class_map = module.dependencies.get("packages", {}).get(platform, {})
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
    subparsers.add_parser("validate")
    rows = subparsers.add_parser("rows")
    rows.add_argument("--all", action="store_true")
    files = subparsers.add_parser("files")
    files.add_argument("identifier")
    preserve = subparsers.add_parser("preserve")
    preserve.add_argument("identifier")
    subparsers.add_parser("modules")
    subparsers.add_parser("manifests")
    dependencies = subparsers.add_parser("dependencies")
    dependencies.add_argument("type", choices=("commands", "packages"))
    dependencies.add_argument("--platform", choices=tuple(sorted(PACKAGE_PLATFORMS)))
    hooks = subparsers.add_parser("hooks")
    hooks.add_argument("action", choices=tuple(sorted(HOOKS)))
    hooks.add_argument("--all", action="store_true")
    arguments = parser.parse_args()
    root = arguments.root.expanduser().resolve()
    try:
        if arguments.command == "validate":
            validate(root)
        elif arguments.command == "rows":
            command_rows(root, arguments.all)
        elif arguments.command == "files":
            command_files(root, arguments.identifier)
        elif arguments.command == "preserve":
            command_preserve(root, arguments.identifier)
        elif arguments.command == "modules":
            command_modules(root)
        elif arguments.command == "manifests":
            command_manifests(root)
        elif arguments.command == "dependencies":
            if arguments.type == "packages" and arguments.platform is None:
                raise fail("package dependency listing requires --platform")
            dependency_rows(root, arguments.type, arguments.platform)
        elif arguments.command == "hooks":
            command_hooks(root, arguments.action, arguments.all)
    except ManifestError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
