#!/usr/bin/env python3
"""Context monitor - warns when context usage is high."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

THRESHOLD_WARN = 65
THRESHOLD_STOP = 85
CONTEXT_LIMIT = 200000

CACHE_DIR = Path("/tmp/.claude_context_cache")
CACHE_TTL = 30

RED = "\033[0;31m"
YELLOW = "\033[0;33m"
NC = "\033[0m"


def get_current_session_id() -> str:
    """Get current session ID from history."""
    history = Path.home() / ".claude" / "history.jsonl"
    if not history.exists():
        return ""
    try:
        with history.open() as f:
            lines = f.readlines()
            if lines:
                return json.loads(lines[-1]).get("sessionId", "")
    except (json.JSONDecodeError, OSError):
        pass
    return ""


def find_session_file(session_id: str) -> Path | None:
    """Find session file for given session ID."""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.exists():
        return None
    for project_dir in projects_dir.iterdir():
        if project_dir.is_dir():
            session_file = project_dir / f"{session_id}.jsonl"
            if session_file.exists():
                return session_file
    return None


def get_actual_token_count(session_file: Path) -> int | None:
    """Get actual token count from the most recent API usage data."""
    last_usage = None

    try:
        with session_file.open() as f:
            for line in f:
                try:
                    msg = json.loads(line)
                    if msg.get("type") != "assistant":
                        continue

                    message = msg.get("message", {})
                    if not isinstance(message, dict):
                        continue

                    usage = message.get("usage")
                    if usage:
                        last_usage = usage
                except (json.JSONDecodeError, KeyError):
                    continue
    except OSError:
        return None

    if not last_usage:
        return None

    input_tokens = last_usage.get("input_tokens", 0)
    cache_creation = last_usage.get("cache_creation_input_tokens", 0)
    cache_read = last_usage.get("cache_read_input_tokens", 0)

    return input_tokens + cache_creation + cache_read


def get_cache_file(session_id: str) -> Path:
    """Get cache file path for a session."""
    return CACHE_DIR / f"{session_id}.json"


def get_cached_context(session_id: str) -> tuple[int, bool]:
    """Get cached context value if fresh enough."""
    cache_file = get_cache_file(session_id)
    if cache_file.exists():
        try:
            with cache_file.open() as f:
                cache = json.load(f)
                if time.time() - cache.get("timestamp", 0) < CACHE_TTL:
                    return cache.get("tokens", 0), True
        except (json.JSONDecodeError, OSError):
            pass
    return 0, False


def save_cache(session_id: str, tokens: int) -> None:
    """Save context calculation to cache."""
    try:
        CACHE_DIR.mkdir(exist_ok=True)
        cache_file = get_cache_file(session_id)
        with cache_file.open("w") as f:
            json.dump({"tokens": tokens, "timestamp": time.time()}, f)
    except OSError:
        pass


def run_context_monitor() -> int:
    """Run context monitoring and return exit code."""
    session_id = get_current_session_id()
    if not session_id:
        return 0

    cached_tokens, is_cached = get_cached_context(session_id)
    if is_cached:
        total_tokens = cached_tokens
    else:
        session_file = find_session_file(session_id)
        if not session_file:
            return 0

        actual_tokens = get_actual_token_count(session_file)
        if actual_tokens is None:
            return 0

        total_tokens = actual_tokens
        save_cache(session_id, total_tokens)

    percentage = (total_tokens / CONTEXT_LIMIT) * 100

    if percentage >= THRESHOLD_STOP:
        print("", file=sys.stderr)
        print(f"{RED}CONTEXT LIMIT: {percentage:.0f}% ({total_tokens:,}/{CONTEXT_LIMIT//1000}k){NC}", file=sys.stderr)
        print(f"{RED}Ask user to run /clear to reset context.{NC}", file=sys.stderr)
        return 2

    if percentage >= THRESHOLD_WARN:
        print("", file=sys.stderr)
        print(f"{YELLOW}Context: {percentage:.0f}% ({total_tokens:,}/{CONTEXT_LIMIT//1000}k){NC}", file=sys.stderr)
        print(f"{YELLOW}   Complete current task, wrap up at {THRESHOLD_STOP}% maximum{NC}", file=sys.stderr)
        # Return 0 for warning - shows info without "error" label
        # Only return 2 at THRESHOLD_STOP for actual blocking

    return 0


if __name__ == "__main__":
    sys.exit(run_context_monitor())
