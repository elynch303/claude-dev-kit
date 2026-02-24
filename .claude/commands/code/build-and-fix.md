---
description: Build project and automatically fix simple errors (formatting, linting)
allowed-tools: Bash(realpath:*), Bash(test:*), Bash(ls:*), Bash(pwd:*)
---

# Build & Fix Project

Invoke the **build-and-fix** skill to automatically build the project and fix simple compilation errors like formatting and linting issues.

## Purpose

- Build the project and ensure successful compilation
- Automatically fix simple build errors (formatting, linting)
- Validate code changes before committing
- Efficiently debug build failures

## Supported Languages

- JavaScript/TypeScript (npm/yarn/pnpm)
- Python (pip/poetry/pipenv)
- Rust (cargo)
- C++ (cmake)

## Process

1. **Parse arguments** (optional)
   - If `$ARGUMENTS` is provided, change to that directory first
   - Otherwise, operate in current working directory
   - Example: `/code:build-and-fix ./backend` or just `/code:build-and-fix`

2. **Change directory if needed**

   ```bash
   if [ -n "$ARGUMENTS" ]; then
     # Resolve to absolute path
     TARGET_DIR=$(realpath "$ARGUMENTS" 2>/dev/null)

     # Verify directory exists
     if [ ! -d "$TARGET_DIR" ]; then
       echo "Error: Directory '$ARGUMENTS' does not exist"
       exit 1
     fi

     cd "$TARGET_DIR"
     echo "Changed to directory: $TARGET_DIR"
   fi
   ```

3. **Invoke the build-and-fix skill**
   - Use the Skill tool to invoke: `skill: "build-and-fix"`
   - The skill will:
     - Auto-detect project type
     - Run build
     - Parse errors and apply auto-fixes (formatting, linting)
     - Retry build until success or max retries reached

4. **Report results**
   - The skill handles all output and reporting
   - Success: Shows fixes applied and build time
   - Failure: Shows remaining errors and suggested manual actions

## Examples

```bash
# Build current directory
/code:build-and-fix

# Build specific project directory
/code:build-and-fix ./backend

# Build relative path
/code:build-and-fix ../api-service
```

## Notes

- Requires build tools to be pre-installed (npm/cargo/cmake/etc.)
- Only fixes simple errors (formatting, linting)
- Cannot fix semantic/logic errors or missing dependencies
- Max 2 retry cycles for efficiency
