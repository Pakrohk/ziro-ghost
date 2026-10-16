#!/usr/bin/env python3
"""Project type detection for ziro-ghost.

Cold-path only — never invoked in hot-path.
Layer: Lib (Cold-path enrichment)
Spec: 009 v0.2.0 (R12)
"""

from __future__ import annotations

import json
import os
import sys

MARKERS: dict[str, dict[str, str | list[str]]] = {
    "pyproject.toml": {
        "type": "python",
        "commands": ["uv sync", "uv add", "pytest", "ruff check", "mypy", "python -m"],
    },
    "package.json": {
        "type": "node",
        "commands": ["pnpm dev", "pnpm test", "pnpm build", "npm run", "yarn"],
    },
    "Cargo.toml": {
        "type": "rust",
        "commands": ["cargo build", "cargo test", "cargo run", "cargo clippy", "cargo fmt"],
    },
    "go.mod": {
        "type": "go",
        "commands": ["go build", "go test ./...", "go run", "go mod tidy"],
    },
    "Gemfile": {
        "type": "ruby",
        "commands": ["bundle install", "bundle exec", "rake"],
    },
    "composer.json": {
        "type": "php",
        "commands": ["composer install", "composer require", "composer update"],
    },
    "Makefile": {
        "type": "make",
        "commands": ["make", "make build", "make test"],
    },
    "docker-compose.yml": {
        "type": "docker",
        "commands": ["docker compose up -d", "docker compose down", "docker compose logs"],
    },
    "Dockerfile": {
        "type": "docker",
        "commands": ["docker build -t .", "docker run"],
    },
    "justfile": {
        "type": "just",
        "commands": ["just", "just list"],
    },
    "requirements.txt": {
        "type": "python-legacy",
        "commands": ["pip install -r requirements.txt", "python -m venv"],
    },
}


def detect_project(path: str) -> dict[str, str | list[str]]:
    """Detect project type based on markers in path.

    Returns: {path, types, markers, commands}
    """
    detected: list[str] = []
    all_commands: list[str] = []
    types: set[str] = set()

    for marker, info in MARKERS.items():
        if os.path.exists(os.path.join(path, marker)):
            detected.append(marker)
            types.add(str(info["type"]))
            all_commands.extend(info["commands"])

    # .git directory always adds git commands
    if os.path.isdir(os.path.join(path, ".git")):
        types.add("git")
        all_commands.extend(["git status", "git push", "git pull", "git log", "git branch"])

    return {
        "path": os.path.abspath(path),
        "types": sorted(types),
        "markers": sorted(detected),
        "commands": sorted(set(all_commands)),
    }


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    result = detect_project(target)
    print(json.dumps(result))
