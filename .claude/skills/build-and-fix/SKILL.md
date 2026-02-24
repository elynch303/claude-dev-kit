---
version: 1.1.0
name: build-and-fix
description: This skill should be used when the user asks to "build the project", "run build", "build and fix errors", "fix lint errors", "fix formatting", "run cargo build", "npm run build", "pnpm build", "yarn build", "poetry build", "cmake build", "make it compile", "check if code compiles", "verify build", "fix build failures", "validate before commit", "pre-commit validation", or "check compilation". Auto-detects project type (Rust/JS/TS/Python/C++), runs build, and automatically fixes simple errors like formatting and linting. Does NOT fix type errors, logic bugs, or missing dependencies - bails to user for complex issues.
---

# Build & Fix

**Notification:** At skill start, output: "Using build-and-fix to detect and build project..."

## When to Use

- Build a project and ensure it compiles successfully
- Fix simple build errors automatically (formatting, linting)
- Validate changes before committing
- Debug build failures efficiently

## When NOT to Use

- Complex refactoring requiring semantic understanding
- Fixing type errors, logic bugs, or missing imports
- Projects requiring manual build configuration
- When user needs to understand the error (don't hide it)

## Supported Languages

| Language | Build Systems | Priority |
|----------|--------------|----------|
| **Rust** | cargo | 1 (highest) |
| **JavaScript/TypeScript** | npm/yarn/pnpm | 2 |
| **Python** | pip/poetry/pipenv | 3 |
| **C++** | cmake only | 4 (lowest) |

## Workflow

### 1. Pre-flight Checks

Before building, verify environment is ready:

```
[PREFLIGHT] Checking build environment...
```

- **Verify build tool exists**: Run the `preflight` command from config (e.g., `cargo --version`)
- **Check dependencies**: Verify lockfile/node_modules/target directory exists
- **If tool missing (exit 127)**: Bail immediately with installation instructions
- **If deps missing**: Suggest running install command (don't auto-install without permission)

### 2. Detect Project Type

```
[DETECT] Scanning for project manifests...
```

- Search current working directory for manifest files using Glob
- Match against `detection.required_files` in each language config
- If multiple languages detected, use `priority` field (lower = higher priority)
- For monorepos: Check for workspace configs (see Workspace Detection below)

### 3. Load Language Config

- Read `language-configs/{language}.yaml` using Read tool
- Extract commands, fix patterns, bail patterns, and limits
- Determine package manager if applicable (from lockfiles)

### 4. Configure Build (C++ only)

```
[CONFIGURE] Configuring build system...
```

- Run `cmake -S . -B build` before building
- Exit codes: 0 = success, 127 = cmake not found (bail), other = config error (bail)

### 5. Build Project

```
[BUILD] Building project...
```

- Run build command from config via Bash
- Apply timeout from config (default: 300s for C++, 120s for others)
- Capture stdout + stderr for error parsing
- Check exit code:
  - 0 = success
  - 127 = tool not found (bail with install instructions)
  - 130 = user interrupted (stop gracefully)
  - Other = build failure (proceed to error parsing)

### 6. Parse Errors (if build failed)

```
[ANALYZE] Parsing build output...
```

**Error Extraction Process:**

1. **Check bail patterns FIRST** - If any `bail_on` regex matches, stop immediately
2. **Extract error locations** using `error_parsing` patterns from config:
   - Pattern groups: `{file}`, `{line}`, `{column}`, `{message}`
3. **Match fix patterns** - Compare errors against `fixes[]` list
4. **Classify errors**:
   - Auto-fixable: formatting, linting, whitespace
   - Bail immediately: type errors, syntax errors, missing deps

### 7. Apply Fixes

```
[FIX] Applying {count} fixes...
```

- Look up `action` in commands (e.g., 'format' → 'cargo fmt')
- Substitute captured values: `{1}` = first capture group, `{file}` = matched file
- Execute fix via Bash
- Track which fixes were applied

### 8. Retry Build

```
[RETRY] Retrying build (attempt {n}/{max})...
```

- Maximum 2 retry cycles
- **Stop immediately if:**
  - Same errors recur (compare error text, ignore line numbers)
  - Total errors exceed `max_errors` from config
  - Any `bail_on` pattern matches

### 9. Report Results

**Success:**
```
[SUCCESS] Build passed!
- Fixes applied: {list}
- Build time: {duration}
- Retry cycles: {count}
```

**Failure:**
```
[BAIL] Build failed - manual intervention required
- Error: {summary}
- Location: {file}:{line}
- Reason: {why auto-fix stopped}
- Suggestion: {next steps}
```

## Config Schema

See `references/config-schema.md` for the complete schema reference.

**Quick summary:** Each `language-configs/{language}.yaml` contains:
- `detection` - Files that identify the project type
- `preflight` - Pre-build verification commands
- `commands` - Build, format, lint commands
- `fixes` - Auto-fixable error patterns
- `bail_on` - Errors requiring manual intervention
- `max_errors`, `max_retries` - Safety limits

## Workspace Detection

For monorepos with multiple projects:

| Language | Workspace Indicator | Behavior |
|----------|-------------------|----------|
| Rust | `[workspace]` in Cargo.toml | Build from workspace root |
| JavaScript | `workspaces` in package.json | Detect package manager workspace commands |
| Python | `tool.poetry.packages` in pyproject.toml | Build from monorepo root |

If workspace detected:
1. Note it in output: `[DETECT] Rust workspace (3 members)`
2. Build from workspace root, not individual package
3. Errors may reference multiple packages

## Safety Guidelines

**DO auto-fix:**
- Formatting issues (rustfmt, black, prettier)
- Simple linting errors with `--fix` flag
- Trailing whitespace

**DO NOT auto-fix:**
- Dependency changes (npm audit fix, cargo update)
- Auto-upgrades of any kind
- Destructive file operations
- Anything requiring user confirmation

**Always bail on:**
- Type errors
- Syntax errors
- Missing imports/modules
- Linker errors
- Permission errors

## Tool Usage

| Tool | Use For | Never Use For |
|------|---------|---------------|
| **Glob** | Find manifest files | - |
| **Read** | Load configs, examine source | - |
| **Edit** | Apply code fixes | - |
| **Bash** | Run build/fix commands | File operations, sed, awk |
| **Grep** | Parse build output | - |

## Progress Markers

Output these markers during execution:

| Marker | When |
|--------|------|
| `[PREFLIGHT]` | Checking build environment |
| `[DETECT]` | Project type detection |
| `[CONFIGURE]` | CMake configuration (C++ only) |
| `[BUILD]` | Build command execution |
| `[ANALYZE]` | Parsing build errors |
| `[FIX]` | Applying auto-fixes |
| `[RETRY]` | Retrying build after fixes |
| `[SUCCESS]` | Build passed |
| `[BAIL]` | Stopping due to unfixable errors |

## Example Flows

### Success with Auto-Fix
```
User: Build the project and fix errors

[PREFLIGHT] Checking build environment... cargo v1.75.0 found
[DETECT] Rust project (Cargo.toml found)
[BUILD] Building project...
[ANALYZE] Build failed - 2 errors found
[FIX] Applying 2 formatting fixes... Running cargo fmt
[RETRY] Retrying build (attempt 1/2)...
[SUCCESS] Build passed! Fixed 2 formatting issues in 1 retry cycle.
```

### Bail on Complex Error
```
User: Run cargo build

[PREFLIGHT] Checking build environment... cargo v1.75.0 found
[DETECT] Rust project (Cargo.toml found)
[BUILD] Building project...
[ANALYZE] Build failed - 1 error found
[BAIL] Type error detected (E0308) - cannot auto-fix

Error at src/main.rs:15:20
  mismatched types: expected `i32`, found `&str`

This requires manual code changes. The variable is declared as i32 but assigned a string.
```

## Additional Resources

Detailed reference documentation:
- `references/config-schema.md` - Complete configuration schema
- `references/error-patterns.md` - Common error patterns by language
- `references/troubleshooting.md` - Build tool issues and solutions
- `references/extending.md` - How to add new language support

Language configurations in `language-configs/`:
- `rust.yaml`, `javascript.yaml`, `python.yaml`, `cpp.yaml`

Example scenarios in `examples/`:
- `rust-format-fix.md` - Rust formatting fix
- `javascript-lint-fix.md` - ESLint auto-fix
- `python-format-fix.md` - Black formatting
- `bail-on-type-error.md` - Bail on complex error
- `tool-not-found.md` - Missing build tool handling
- `monorepo-detection.md` - Workspace project handling
- `max-errors-exceeded.md` - Error threshold exceeded
- `cpp-clang-format.md` - C++ clang-format fix
