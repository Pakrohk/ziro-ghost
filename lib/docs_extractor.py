#!/usr/bin/env python3
"""
ziro-ghost — Documentation Extractor
Layer: Lib / Cold-path · Spec: 009 v0.2.0 (FR-009) · Version: 0.8.0

Extracts command documentation from tldr, man pages, or --help.
Results are cached with configurable TTL in ~/.cache/ziro/ghost/docs/.
Strict 3-second subprocess timeout prevents hanging.
"""

import sys
import os
import re
import time
import subprocess
from pathlib import Path


def get_cache_dir() -> Path:
    cache_base = os.environ.get("XDG_CACHE_HOME")
    if cache_base:
        p = Path(cache_base) / "ziro" / "ghost" / "docs"
    else:
        p = Path.home() / ".cache" / "ziro" / "ghost" / "docs"
    p.mkdir(parents=True, exist_ok=True)
    return p


def safe_cache_filename(cmd_str: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_\.-]", "_", cmd_str.strip())
    if len(cleaned) > 40:
        cleaned = cleaned[:40]
    return f"{cleaned}.txt"


def extract_docs(cmd: str, max_lines: int = 15) -> str:
    parts = cmd.strip().split()
    if not parts:
        return "No command specified."

    primary = parts[0]
    subcmd = f"{parts[0]}-{parts[1]}" if len(parts) > 1 else None

    # 1. Try tldr
    for target in filter(None, [subcmd, primary]):
        try:
            res = subprocess.run(
                ["tldr", target],
                capture_output=True,
                text=True,
                timeout=3.0,
                check=False,
            )
            if res.returncode == 0 and res.stdout.strip():
                lines = [line for line in res.stdout.splitlines() if line.strip()]
                return "\n".join(lines[:max_lines])
        except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
            pass

    # 2. Try man (using cat as pager)
    for target in filter(None, [subcmd, primary]):
        try:
            env = dict(os.environ, PAGER="cat")
            res = subprocess.run(
                ["man", "-P", "cat", target],
                capture_output=True,
                text=True,
                timeout=3.0,
                env=env,
                check=False,
            )
            if res.returncode == 0 and res.stdout.strip():
                lines = [line for line in res.stdout.splitlines() if line.strip()]
                return "\n".join(lines[:max_lines])
        except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
            pass

    # 3. Try --help on primary command
    try:
        res = subprocess.run(
            [primary, "--help"],
            capture_output=True,
            text=True,
            timeout=3.0,
            check=False,
        )
        out = res.stdout if res.stdout.strip() else res.stderr
        if out.strip():
            lines = [line for line in out.splitlines() if line.strip()]
            return "\n".join(lines[:max_lines])
    except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError):
        pass

    return f"No documentation found for: {cmd}"


def main() -> None:
    ttl = 86400  # Default 24 hours
    max_lines = 15
    args = sys.argv[1:]

    # Parse optional flags
    cmd_tokens = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--ttl" and i + 1 < len(args):
            try:
                ttl = int(args[i + 1])
            except ValueError:
                pass
            i += 2
        elif arg == "--max-lines" and i + 1 < len(args):
            try:
                max_lines = int(args[i + 1])
            except ValueError:
                pass
            i += 2
        else:
            cmd_tokens.append(arg)
            i += 1

    if not cmd_tokens:
        print("Usage: docs_extractor.py [--ttl SECONDS] [--max-lines N] <command>")
        sys.exit(1)

    cmd_str = " ".join(cmd_tokens)
    cache_dir = get_cache_dir()
    cache_file = cache_dir / safe_cache_filename(cmd_str)

    # Check cache hit
    if cache_file.exists():
        try:
            mtime = cache_file.stat().st_mtime
            age = time.time() - mtime
            if age < ttl:
                cached_text = cache_file.read_text(encoding="utf-8")
                print(cached_text)
                return
        except OSError:
            pass

    # Cold extract
    docs = extract_docs(cmd_str, max_lines=max_lines)

    # Cache write
    try:
        cache_file.write_text(docs, encoding="utf-8")
    except OSError:
        pass

    print(docs)


if __name__ == "__main__":
    main()
