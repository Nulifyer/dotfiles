#!/usr/bin/env python3

import os
import signal
import sys


PROJECT_MARKERS = {
    ".devcontainer",
    ".git",
    ".hg",
    ".idea",
    ".jj",
    ".svn",
    ".vscode",
}

IGNORED_DIRECTORY_NAMES = {
    ".android",
    ".bun",
    ".cache",
    ".cargo",
    ".devcontainer",
    ".dotnet",
    ".git",
    ".gradle",
    ".hg",
    ".idea",
    ".jj",
    ".local",
    ".npm",
    ".nuget",
    ".pnpm-store",
    ".pki",
    ".pytest_cache",
    ".ruff_cache",
    ".rustup",
    ".ssh",
    ".steam",
    ".svn",
    ".tmp",
    ".tox",
    ".var",
    ".venv",
    ".vscode",
    ".vscode-oss",
    ".vscode-oss-shared",
    ".vscode-shared",
    ".yarn",
    "__pycache__",
    "build",
    "cache",
    "caches",
    "dist",
    "node_modules",
    "out",
    "target",
    "vendor",
    "venv",
}


def child_directories(directory: str) -> tuple[bool, list[str]]:
    children: list[str] = []
    try:
        with os.scandir(directory) as entries:
            for entry in entries:
                if entry.name in PROJECT_MARKERS:
                    return True, []
                try:
                    if entry.is_dir(follow_symlinks=False):
                        children.append(entry.path)
                except OSError:
                    continue
    except OSError:
        return False, []

    return False, children


def home_directories(home: str) -> list[str]:
    children: list[str] = []
    try:
        with os.scandir(home) as entries:
            for entry in entries:
                try:
                    if entry.is_dir(follow_symlinks=False):
                        children.append(entry.path)
                except OSError:
                    continue
    except OSError:
        pass

    return children


def project_candidates(home: str, excluded_roots: set[str]):
    stack = home_directories(home)

    while stack:
        directory = stack.pop()
        if directory in excluded_roots:
            continue
        if os.path.basename(directory) in IGNORED_DIRECTORY_NAMES:
            continue

        is_project, children = child_directories(directory)
        if is_project:
            yield directory
            continue

        stack.extend(children)


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "usage: project_candidates.py HOME [EXCLUDED_ROOT ...]",
            file=sys.stderr,
        )
        return 2

    home = os.path.abspath(os.path.expanduser(sys.argv[1]))
    excluded_roots = {
        os.path.abspath(os.path.expanduser(path)) for path in sys.argv[2:]
    }
    excluded_roots.add(os.path.join(home, "go", "pkg"))

    if not os.path.isdir(home):
        return 0

    output = sys.stdout.buffer
    for candidate in project_candidates(home, excluded_roots):
        output.write(os.fsencode(candidate) + b"\0")
        output.flush()

    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    raise SystemExit(main())
