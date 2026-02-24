#!/usr/bin/env python3
"""
Learning Logger - Stop hook that captures session data for self-improvement.

After each session ends, this hook:
1. Reads the session transcript from ~/.claude/projects/
2. Extracts: commands used, agents spawned, tools called, token usage, errors
3. Appends a structured entry to .claude/learning/sessions/YYYY-MM-DD.jsonl

This data feeds the /improve command for pattern analysis and kit evolution.
"""

from __future__ import annotations

import json
import os
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path


LEARNING_DIR = Path(".claude/learning/sessions")
MAX_SESSIONS_PER_FILE = 50


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


def extract_session_data(session_file: Path) -> dict:
    """Extract structured data from a session transcript."""
    commands_used: list[str] = []
    agents_spawned: list[str] = []
    tools_called: Counter = Counter()
    errors: list[str] = []
    total_input_tokens = 0
    total_output_tokens = 0
    turn_count = 0
    user_prompts: list[str] = []

    try:
        with session_file.open() as f:
            for line in f:
                try:
                    msg = json.loads(line)
                    msg_type = msg.get("type", "")

                    # Count turns
                    if msg_type == "user":
                        turn_count += 1
                        # Capture user prompt text (truncated for privacy)
                        content = msg.get("message", {}).get("content", "")
                        if isinstance(content, str) and len(content) > 10:
                            user_prompts.append(content[:200])
                        elif isinstance(content, list):
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    text = block.get("text", "")
                                    if text:
                                        user_prompts.append(text[:200])
                                        break

                    # Track assistant tool usage
                    if msg_type == "assistant":
                        message = msg.get("message", {})
                        usage = message.get("usage", {})
                        total_input_tokens += usage.get("input_tokens", 0)
                        total_output_tokens += usage.get("output_tokens", 0)

                        content = message.get("content", [])
                        if isinstance(content, list):
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "tool_use":
                                    tool_name = block.get("name", "unknown")
                                    tools_called[tool_name] += 1

                                    # Detect slash commands from user prompts
                                    tool_input = block.get("input", {})

                                    # Detect agent spawning
                                    if tool_name == "Task":
                                        agent = tool_input.get("subagent_type", "unknown")
                                        agents_spawned.append(agent)

                                    # Detect bash commands for pattern learning
                                    if tool_name == "Bash":
                                        cmd = tool_input.get("command", "")
                                        if cmd.startswith("git "):
                                            commands_used.append("git")
                                        elif cmd.startswith("gh "):
                                            commands_used.append("gh")
                                        elif "gemini" in cmd:
                                            commands_used.append("gemini")
                                        elif "opencode" in cmd:
                                            commands_used.append("opencode")

                    # Capture tool result errors
                    if msg_type == "tool":
                        result = msg.get("content", "")
                        if isinstance(result, str) and ("error" in result.lower() or "failed" in result.lower()):
                            errors.append(result[:300])

                except (json.JSONDecodeError, KeyError, TypeError):
                    continue

    except OSError:
        return {}

    # Detect slash commands from user prompts
    slash_commands = []
    for prompt in user_prompts:
        # Look for /command patterns
        words = prompt.split()
        for word in words:
            if word.startswith("/") and len(word) > 1 and not word.startswith("//"):
                slash_commands.append(word.lower())

    return {
        "turn_count": turn_count,
        "tools_called": dict(tools_called.most_common(20)),
        "agents_spawned": agents_spawned,
        "commands_used": list(set(commands_used)),
        "slash_commands": slash_commands,
        "errors": errors[:5],  # Cap at 5 error samples
        "tokens": {
            "input": total_input_tokens,
            "output": total_output_tokens,
            "total": total_input_tokens + total_output_tokens,
        },
        "user_prompts_preview": [p[:100] for p in user_prompts[:3]],
    }


def write_learning_entry(session_id: str, data: dict) -> None:
    """Write a learning entry to the daily log file."""
    try:
        LEARNING_DIR.mkdir(parents=True, exist_ok=True)
        today = datetime.now().strftime("%Y-%m-%d")
        log_file = LEARNING_DIR / f"{today}.jsonl"

        entry = {
            "ts": int(time.time()),
            "session_id": session_id[:16],  # Truncate for privacy
            "date": today,
            **data,
        }

        with log_file.open("a") as f:
            f.write(json.dumps(entry) + "\n")

    except OSError:
        pass  # Non-fatal — never block the session from ending


def check_and_prune_old_logs() -> None:
    """Remove learning logs older than 90 days to keep storage bounded."""
    try:
        if not LEARNING_DIR.exists():
            return
        cutoff = time.time() - (90 * 24 * 3600)
        for log_file in LEARNING_DIR.glob("*.jsonl"):
            try:
                if log_file.stat().st_mtime < cutoff:
                    log_file.unlink()
            except OSError:
                pass
    except OSError:
        pass


def run_learning_logger() -> int:
    """Main entry point — extract session data and write learning log."""
    session_id = get_current_session_id()
    if not session_id:
        return 0

    session_file = find_session_file(session_id)
    if not session_file:
        return 0

    data = extract_session_data(session_file)
    if not data or data.get("turn_count", 0) < 2:
        return 0  # Skip trivially short sessions

    write_learning_entry(session_id, data)
    check_and_prune_old_logs()

    return 0


if __name__ == "__main__":
    sys.exit(run_learning_logger())
