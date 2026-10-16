"""ziro-ghost — project marker detection helper.

Layer: Lib (Cold-path enrichment)
Spec: 009 v0.2.0 (R12)
"""

from __future__ import annotations

import os
from pathlib import Path

# Mapping of file markers to project types and standard recipes
PROJECT_MARKERS: dict[str, tuple[str, list[str]]] = {
    "pyproject.toml": ("python", ["uv sync", "uv add", "pytest", "ruff check", "mypy"]),
    "package.json": ("node", ["pnpm run dev", "pnpm test", "npm run build", "yarn start"]),
    "Cargo.toml": ("rust", ["cargo build", "cargo test", "cargo run", "cargo clippy"]),
    "go.mod": ("go", ["go build", "go test ./...", "go run ."]),
    "Gemfile": ("ruby", ["bundle exec", "bundle install"]),
    "composer.json": ("php", ["composer install", "composer require"]),
    "Makefile": ("make", ["make", "make test", "make build", "make clean"]),
    "justfile": ("just", ["just", "just test", "just build"]),
    "docker-compose.yml": ("docker", ["docker compose up -d", "docker compose down", "docker compose logs"]),
    "compose.yaml": ("docker", ["docker compose up -d", "docker compose down"]),
    "Dockerfile": ("docker", ["docker build -t ."]),
    ".git": ("git", ["git status", "git push", "git pull", "git log --oneline", "git branch"]),
}


def detect_project_type(directory: str | Path | None = None) -> str:
    """Identify project language or ecosystem from root marker files."""
    root = Path(directory or os.getcwd()).resolve()
    for marker, (proj_type, _) in PROJECT_MARKERS.items():
        if (root / marker).exists():
            return proj_type
    return "unknown"


def get_commands_for_project(directory: str | Path | None = None) -> list[str]:
    """Return recommended commands for project in given directory."""
    root = Path(directory or os.getcwd()).resolve()
    for marker, (_, commands) in PROJECT_MARKERS.items():
        if (root / marker).exists():
            return commands
    return []


if __name__ == "__main__":
    import json
    import sys

    target_dir = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    print(json.dumps({
        "type": detect_project_type(target_dir),
        "commands": get_commands_for_project(target_dir),
    }))
