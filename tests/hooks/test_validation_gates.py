"""Tests for .claude/hooks/stop/validation_gates.py

AAA pattern, stdlib-only (unittest). Each test has one clear concern.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Load the hook module by path (it lives outside any package)
_REPO_ROOT = Path(__file__).resolve().parents[2]
_MODULE_PATH = _REPO_ROOT / ".claude" / "hooks" / "stop" / "validation_gates.py"
_spec = importlib.util.spec_from_file_location("validation_gates", _MODULE_PATH)
assert _spec and _spec.loader
vg = importlib.util.module_from_spec(_spec)
sys.modules["validation_gates"] = vg
_spec.loader.exec_module(vg)


class StackDetectionTests(unittest.TestCase):
    def test_detects_node_from_package_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "package.json").write_text("{}")

            stacks = vg.detect_stack(root)

            self.assertIn("node", stacks)

    def test_detects_python_from_pyproject(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pyproject.toml").write_text("")

            stacks = vg.detect_stack(root)

            self.assertIn("python", stacks)

    def test_detects_go_from_gomod(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "go.mod").write_text("module x")

            self.assertIn("go", vg.detect_stack(root))

    def test_detects_rust_from_cargo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Cargo.toml").write_text("")

            self.assertIn("rust", vg.detect_stack(root))

    def test_empty_directory_has_no_stacks(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(vg.detect_stack(Path(tmp)), set())

    def test_multi_stack_project_detects_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "package.json").write_text("{}")
            (root / "pyproject.toml").write_text("")

            stacks = vg.detect_stack(root)

            self.assertEqual(stacks, {"node", "python"})


class TypecheckConfigTests(unittest.TestCase):
    def test_tsconfig_counts_as_typecheck_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "tsconfig.json").write_text("{}")

            self.assertTrue(vg.has_typecheck_config(root))

    def test_pyproject_mypy_section_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pyproject.toml").write_text("[tool.mypy]\nstrict = true\n")

            self.assertTrue(vg.has_typecheck_config(root))

    def test_no_config_returns_false(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertFalse(vg.has_typecheck_config(Path(tmp)))


class ConfigLoadingTests(unittest.TestCase):
    def test_missing_settings_returns_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "nope.json"

            config = vg.load_gate_config(missing)

            self.assertEqual(config, vg.DEFAULT_GATES)

    def test_user_overrides_merge_over_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text(json.dumps({"stopGates": {"tests": True, "lint": False}}))

            config = vg.load_gate_config(settings)

            self.assertTrue(config["tests"])         # opted in
            self.assertFalse(config["lint"])         # opted out
            self.assertTrue(config["security"])      # default preserved

    def test_malformed_settings_falls_back_to_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text("{not json")

            config = vg.load_gate_config(settings)

            self.assertEqual(config, vg.DEFAULT_GATES)

    def test_non_bool_values_are_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            settings = Path(tmp) / "settings.json"
            settings.write_text(json.dumps({"stopGates": {"lint": "yes"}}))

            config = vg.load_gate_config(settings)

            self.assertTrue(config["lint"])  # default preserved


class SummarizeTests(unittest.TestCase):
    def test_empty_output_returns_empty_string(self):
        self.assertEqual(vg._summarize(""), "")

    def test_returns_last_nonempty_line(self):
        out = "starting...\n\nFound 3 errors\n"

        self.assertEqual(vg._summarize(out), "Found 3 errors")

    def test_truncates_long_lines(self):
        long_line = "x" * (vg.MAX_OUTPUT_CHARS + 50)

        summary = vg._summarize(long_line)

        self.assertLessEqual(len(summary), vg.MAX_OUTPUT_CHARS)
        self.assertTrue(summary.endswith("..."))


class ClassifyTests(unittest.TestCase):
    def test_zero_exit_code_is_ok(self):
        result = vg._classify(0, "ruff", "All checks passed")

        self.assertEqual(result[0], "ok")
        self.assertEqual(result[1], "ruff")

    def test_nonzero_exit_code_is_fail(self):
        result = vg._classify(1, "eslint", "2 errors")

        self.assertEqual(result[0], "fail")


class OrchestrationTests(unittest.TestCase):
    def test_no_changes_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)

            with patch.object(vg, "has_changes", return_value=False):
                self.assertEqual(vg.run_validation_gates(root), 0)

    def test_no_recognizable_stack_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)

            with patch.object(vg, "has_changes", return_value=True):
                self.assertEqual(vg.run_validation_gates(root), 0)

    def test_no_tools_installed_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "package.json").write_text("{}")

            with patch.object(vg, "has_changes", return_value=True), \
                 patch.object(vg, "tool_available", return_value=False):
                self.assertEqual(vg.run_validation_gates(root), 0)

    def test_all_passing_gates_exits_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pyproject.toml").write_text("")

            def fake_runner(_root, _stacks):
                return ("ok", "ruff", "clean")

            with patch.object(vg, "has_changes", return_value=True), \
                 patch.dict(vg.GATE_RUNNERS, {"lint": fake_runner}, clear=False), \
                 patch.object(vg, "load_gate_config", return_value={
                     "lint": True, "security": False, "typecheck": False,
                     "build": False, "tests": False, "e2e": False, "ui": False,
                 }):
                self.assertEqual(vg.run_validation_gates(root), 0)

    def test_failing_gate_exits_two_and_writes_stderr(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pyproject.toml").write_text("")

            def fake_runner(_root, _stacks):
                return ("fail", "ruff", "3 errors")

            captured: list[str] = []

            def fake_print(msg, file=None):
                captured.append(msg)

            with patch.object(vg, "has_changes", return_value=True), \
                 patch.dict(vg.GATE_RUNNERS, {"lint": fake_runner}, clear=False), \
                 patch.object(vg, "load_gate_config", return_value={
                     "lint": True, "security": False, "typecheck": False,
                     "build": False, "tests": False, "e2e": False, "ui": False,
                 }), \
                 patch("builtins.print", side_effect=fake_print):
                exit_code = vg.run_validation_gates(root)

            self.assertEqual(exit_code, 2)
            combined = "\n".join(captured)
            self.assertIn("Validation Gates", combined)
            self.assertIn("FAIL", combined)
            self.assertIn("ruff", combined)

    def test_runner_exception_is_swallowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pyproject.toml").write_text("")

            def boom(_root, _stacks):
                raise RuntimeError("unexpected")

            with patch.object(vg, "has_changes", return_value=True), \
                 patch.dict(vg.GATE_RUNNERS, {"lint": boom}, clear=False), \
                 patch.object(vg, "load_gate_config", return_value={
                     "lint": True, "security": False, "typecheck": False,
                     "build": False, "tests": False, "e2e": False, "ui": False,
                 }):
                self.assertEqual(vg.run_validation_gates(root), 0)


class FormatReportTests(unittest.TestCase):
    def test_report_contains_failure_count_and_tool_names(self):
        results = [
            ("lint", ("fail", "ruff", "3 errors")),
            ("typecheck", ("ok", "mypy", "clean")),
        ]

        report = vg.format_failure_report(results)

        self.assertIn("1 failure", report)
        self.assertIn("ruff", report)
        self.assertIn("mypy", report)
        self.assertIn("/validate", report)

    def test_skipped_gates_are_hidden_from_report(self):
        results = [
            ("lint", ("fail", "ruff", "err")),
            ("ui", None),
        ]

        report = vg.format_failure_report(results)

        self.assertNotIn("ui", report.lower().split("validation")[1] if "validation" in report.lower() else report)


if __name__ == "__main__":
    unittest.main()
