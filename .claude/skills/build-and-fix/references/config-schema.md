# Config Schema Reference

Each `language-configs/{language}.yaml` follows this structure:

```yaml
# Metadata
version: "1.1.0"
name: rust                    # Internal identifier
display_name: Rust (Cargo)    # Human-readable name
priority: 1                   # Detection priority (lower = higher)

# Detection
detection:
  required_files: [Cargo.toml]           # Must exist (any one)
  confidence_boost_files: [Cargo.lock]   # Optional, increases confidence
  workspace_indicators: [members]         # For monorepo detection

# Pre-flight checks
preflight:
  check_tool: cargo --version            # Verify tool exists
  check_deps: test -f Cargo.lock         # Verify deps installed

# Timeouts (seconds)
timeouts:
  build: 120
  fix: 30

# Commands (by package manager if applicable)
commands:
  build: cargo build
  check: cargo check              # Fast pre-build verification
  format: cargo fmt
  test: cargo test

# Error parsing - extract file:line:column from output
error_parsing:
  patterns:
    - regex: 'error.*--> (.+):(\d+):(\d+)'
      file: 1
      line: 2
      column: 3
    - regex: '^error: (.+)$'
      message: 1

# Auto-fixable patterns
fixes:
  - pattern: 'Diff in .+\.rs'    # Regex to match
    action: format               # Command to run
    description: Fix formatting  # Human-readable
    confidence: high             # high, medium, low

# Bail patterns - stop immediately, don't retry
bail_on:
  - pattern: 'error\[E0308\]'
    description: Type mismatch
  - pattern: 'error\[E0597\]'
    description: Lifetime error

# Limits
max_errors: 10
max_retries: 2
```

## Pattern Syntax

- **Patterns use regex** (Python `re` module compatible)
- **Capture groups**: `()` creates groups, referenced as `{1}`, `{2}`, etc.
- **Named groups**: `(?P<file>.+)` can be referenced as `{file}`
- **Bail patterns checked first**, before any fix patterns

## Command Substitution

- `{1}`, `{2}`: Numbered capture groups from pattern match
- `{file}`: Matched filename (if extracted)
- `{line}`: Matched line number (if extracted)

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Config version (e.g., "1.1.0") |
| `name` | string | Internal identifier |
| `display_name` | string | Human-readable name |
| `priority` | int | Detection priority (1 = highest) |
| `detection.required_files` | list | Files that identify this language |
| `commands.build` | string | Build command |
| `max_errors` | int | Error threshold before bailing |
| `max_retries` | int | Maximum retry cycles |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `detection.confidence_boost_files` | list | Additional files that increase confidence |
| `detection.at_least_one` | bool | If true, any required file matches |
| `detection.workspace_indicators` | object | Monorepo detection config |
| `preflight` | object | Pre-build verification commands |
| `timeouts` | object | Timeout values in seconds |
| `error_parsing` | object | Patterns to extract error locations |
| `fixes` | list | Auto-fixable error patterns |
| `bail_on` | list | Patterns that trigger immediate bail |

## Fix Confidence Levels

| Level | Meaning | Example |
|-------|---------|---------|
| `high` | Safe, always works | `cargo fmt`, `black .` |
| `medium` | Usually works, may need verification | `eslint --fix` |
| `low` | Experimental, requires user confirmation | - |

## Error Parsing Groups

| Group Name | Purpose |
|------------|---------|
| `file` | Captured file path |
| `line` | Line number |
| `column` | Column number |
| `message` | Error message text |
| `code` | Error code (e.g., E0308, TS2322) |
| `severity` | error/warning level |
