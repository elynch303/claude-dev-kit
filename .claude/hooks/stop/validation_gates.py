#!/usr/bin/env python3
"""
Validation Gates - Stop hook that runs project validation before session ends.

Auto-detects the project stack, runs enabled gates (lint/security/typecheck/
build by default; tests/e2e/ui opt-in), and surfaces failures to Claude via
exit code 2 so it can invoke the `validation-gates` agent to fix them.

Design principles:
- stdlib only (no pip dependencies)
- never crashes a session — all exceptions swallowed, exit 0 on unexpected error
- no-ops cleanly when: no changes this session, no tools installed, no stack
- exit 0 = clean/skip, exit 2 = surface failures to Claude
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable

# ANSI color codes (match sibling hooks' conventions)
RED = "\033[0;31m"
YELLOW = "\033[0;33m"
GREEN = "\033[0;32m"
NC = "\033[0m"

SETTINGS_PATH = Path(".claude/settings.json")

# Safe defaults — required gates on, optional gates off
DEFAULT_GATES: dict[str, bool] = {
    "lint": True,
    "security": True,
    "typecheck": True,
    "build": True,
    "tests": False,
    "e2e": False,
    "ui": False,
}

# Truncate tool output to keep stderr compact
MAX_OUTPUT_CHARS = 400

# Cap each gate to avoid hanging the session
GATE_TIMEOUT_SECONDS = 120


# ─── Config ───────────────────────────────────────────────────────────────────

def load_gate_config(settings_path: Path = SETTINGS_PATH) -> dict[str, bool]:
    """Load stopGates config from settings.json, merged over defaults."""
    config = dict(DEFAULT_GATES)
    try:
        if not settings_path.exists():
            return config
        with settings_path.open() as f:
            data = json.load(f)
        user_gates = data.get("stopGates") or {}
        if isinstance(user_gates, dict):
            for key, value in user_gates.items():
                if key in config and isinstance(value, bool):
                    config[key] = value
    except (json.JSONDecodeError, OSError):
        pass
    return config


# ─── Stack Detection ──────────────────────────────────────────────────────────

def detect_stack(root: Path) -> set[str]:
    """Detect recognizable stacks present in the project root."""
    stacks: set[str] = set()
    if (root / "package.json").exists():
        stacks.add("node")
    if (root / "pyproject.toml").exists() or (root / "setup.py").exists() or (root / "requirements.txt").exists():
        stacks.add("python")
    if (root / "go.mod").exists():
        stacks.add("go")
    if (root / "Cargo.toml").exists():
        stacks.add("rust")
    return stacks


def has_typecheck_config(root: Path) -> bool:
    """True if the project has any typechecker config."""
    candidates = ["tsconfig.json", "mypy.ini", "pyrightconfig.json"]
    if any((root / c).exists() for c in candidates):
        return True
    # Check pyproject for [tool.mypy] or [tool.pyright]
    pyproject = root / "pyproject.toml"
    if pyproject.exists():
        try:
            text = pyproject.read_text()
            if "[tool.mypy]" in text or "[tool.pyright]" in text:
                return True
        except OSError:
            pass
    return False


# ─── Change Detection ─────────────────────────────────────────────────────────

def has_changes(root: Path) -> bool:
    """True if the working tree has staged or unstaged changes."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return False
        return bool(result.stdout.strip())
    except (subprocess.SubprocessError, OSError, FileNotFoundError):
        return False


# ─── Gate Runner ──────────────────────────────────────────────────────────────

def tool_available(name: str) -> bool:
    """True if an executable is on PATH."""
    return shutil.which(name) is not None


def run_cmd(cmd: list[str], cwd: Path) -> tuple[int, str]:
    """Run a command, return (exit_code, combined_output). Never raises."""
    try:
        result = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=GATE_TIMEOUT_SECONDS,
        )
        output = (result.stdout or "") + (result.stderr or "")
        return result.returncode, output
    except subprocess.TimeoutExpired:
        return 124, f"timeout after {GATE_TIMEOUT_SECONDS}s"
    except (OSError, subprocess.SubprocessError, FileNotFoundError) as exc:
        return 1, str(exc)


# Each gate runner returns one of:
#   None                       → skipped (no tool / no config)
#   ("ok", tool, summary)      → passed
#   ("fail", tool, summary)    → failed; summary is shown to Claude
GateResult = tuple[str, str, str] | None


def gate_lint(root: Path, stacks: set[str]) -> GateResult:
    """Run the first available linter for any detected stack."""
    if "node" in stacks and tool_available("eslint"):
        code, out = run_cmd(["eslint", "."], root)
        return _classify(code, "eslint", out)
    if "python" in stacks and tool_available("ruff"):
        code, out = run_cmd(["ruff", "check", "."], root)
        return _classify(code, "ruff", out)
    if "go" in stacks and tool_available("golangci-lint"):
        code, out = run_cmd(["golangci-lint", "run"], root)
        return _classify(code, "golangci-lint", out)
    return None


def gate_security(root: Path, stacks: set[str]) -> GateResult:
    """Run the first available security audit for any detected stack."""
    if "node" in stacks and tool_available("npm"):
        code, out = run_cmd(["npm", "audit", "--audit-level=high"], root)
        return _classify(code, "npm audit", out)
    if "python" in stacks and tool_available("pip-audit"):
        code, out = run_cmd(["pip-audit"], root)
        return _classify(code, "pip-audit", out)
    if tool_available("semgrep"):
        code, out = run_cmd(["semgrep", "--error", "--config=auto", "--quiet"], root)
        return _classify(code, "semgrep", out)
    return None


def gate_typecheck(root: Path, stacks: set[str]) -> GateResult:
    """Run a typechecker if one is configured and installed."""
    if not has_typecheck_config(root):
        return None
    if "node" in stacks and tool_available("tsc"):
        code, out = run_cmd(["tsc", "--noEmit"], root)
        return _classify(code, "tsc", out)
    if "python" in stacks and tool_available("mypy"):
        code, out = run_cmd(["mypy", "."], root)
        return _classify(code, "mypy", out)
    if "python" in stacks and tool_available("pyright"):
        code, out = run_cmd(["pyright"], root)
        return _classify(code, "pyright", out)
    return None


def gate_build(root: Path, stacks: set[str]) -> GateResult:
    """Run the project build to catch compile-time errors."""
    if "node" in stacks and (root / "tsconfig.json").exists() and tool_available("tsc"):
        code, out = run_cmd(["tsc", "--noEmit"], root)
        return _classify(code, "tsc build", out)
    if "rust" in stacks and tool_available("cargo"):
        code, out = run_cmd(["cargo", "build", "--quiet"], root)
        return _classify(code, "cargo build", out)
    if "go" in stacks and tool_available("go"):
        code, out = run_cmd(["go", "build", "./..."], root)
        return _classify(code, "go build", out)
    return None


def gate_tests(root: Path, stacks: set[str]) -> GateResult:
    """Run the unit test suite (opt-in via config)."""
    if "node" in stacks and tool_available("jest"):
        code, out = run_cmd(["jest", "--silent", "--passWithNoTests"], root)
        return _classify(code, "jest", out)
    if "python" in stacks and tool_available("pytest"):
        code, out = run_cmd(["pytest", "-q"], root)
        return _classify(code, "pytest", out)
    if "go" in stacks and tool_available("go"):
        code, out = run_cmd(["go", "test", "./..."], root)
        return _classify(code, "go test", out)
    return None


def gate_e2e(root: Path, stacks: set[str]) -> GateResult:
    """Run E2E suite (opt-in via config)."""
    if tool_available("playwright"):
        code, out = run_cmd(["playwright", "test"], root)
        return _classify(code, "playwright", out)
    if tool_available("cypress"):
        code, out = run_cmd(["cypress", "run"], root)
        return _classify(code, "cypress", out)
    return None


def gate_ui(root: Path, stacks: set[str]) -> GateResult:
    """Run Storybook test runner (opt-in via config)."""
    if tool_available("test-storybook"):
        code, out = run_cmd(["test-storybook"], root)
        return _classify(code, "storybook", out)
    return None


def _classify(code: int, tool: str, output: str) -> GateResult:
    """Translate a command result into a GateResult tuple."""
    summary = _summarize(output)
    if code == 0:
        return ("ok", tool, summary or "clean")
    return ("fail", tool, summary or f"exit {code}")


def _summarize(output: str) -> str:
    """Trim tool output to a short one-line summary."""
    text = output.strip()
    if not text:
        return ""
    # Prefer the last non-empty line (most runners put the summary last)
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    last = lines[-1] if lines else ""
    if len(last) > MAX_OUTPUT_CHARS:
        last = last[: MAX_OUTPUT_CHARS - 3] + "..."
    return last


# Gate name → (runner, is_required)
GATE_RUNNERS: dict[str, Callable[[Path, set[str]], GateResult]] = {
    "lint": gate_lint,
    "security": gate_security,
    "typecheck": gate_typecheck,
    "build": gate_build,
    "tests": gate_tests,
    "e2e": gate_e2e,
    "ui": gate_ui,
}

# Preserve a deterministic display order
GATE_ORDER = ["lint", "typecheck", "security", "build", "tests", "e2e", "ui"]


# ─── Output Formatting ────────────────────────────────────────────────────────

def format_failure_report(results: list[tuple[str, GateResult]]) -> str:
    """Build the stderr message shown to Claude when gates fail."""
    failures = [r for r in results if r[1] and r[1][0] == "fail"]
    lines: list[str] = [""]
    lines.append(f"{YELLOW}Validation Gates — {len(failures)} failure(s){NC}")
    lines.append("")
    for name, result in results:
        if result is None:
            continue  # skipped gates are silent
        status, tool, summary = result
        if status == "ok":
            lines.append(f"  {GREEN}PASS{NC} {name:<10} ({tool})  {summary}")
        else:
            lines.append(f"  {RED}FAIL{NC} {name:<10} ({tool})  {summary}")
    lines.append("")
    lines.append("Run /validate or ask Claude to invoke the validation-gates agent to fix these before finishing.")
    return "\n".join(lines)


# ─── Orchestration ────────────────────────────────────────────────────────────

def run_validation_gates(root: Path | None = None) -> int:
    """Main entry point. Returns exit code (0 or 2)."""
    root = root or Path.cwd()

    # Skip if no changes were made this session
    if not has_changes(root):
        return 0

    # Skip if no recognizable stack
    stacks = detect_stack(root)
    if not stacks:
        return 0

    config = load_gate_config()

    results: list[tuple[str, GateResult]] = []
    for name in GATE_ORDER:
        if not config.get(name, False):
            continue
        runner = GATE_RUNNERS.get(name)
        if runner is None:
            continue
        try:
            result = runner(root, stacks)
        except Exception:  # never crash the session
            result = None
        results.append((name, result))

    executed = [r for r in results if r[1] is not None]
    if not executed:
        return 0  # nothing ran (no tools installed)

    failures = [r for r in executed if r[1][0] == "fail"]
    if not failures:
        return 0

    print(format_failure_report(executed), file=sys.stderr)
    return 2


def main() -> int:
    try:
        return run_validation_gates()
    except Exception:  # absolute last-resort safety net
        return 0


if __name__ == "__main__":
    sys.exit(main())
