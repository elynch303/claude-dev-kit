---
description: "Write unit/integration tests for specific files. Pass file paths or an issue number. Spawns dev-test via dev-lead."
argument-hint: [file-paths | issue-number]
---

# /dev:test

Write tests for existing files that lack coverage.

## Steps

### 1. Identify files to test

If `$ARGUMENTS` looks like file paths → use them directly
If `$ARGUMENTS` is an issue number → `gh issue view <N>`, then find the implementation files
Otherwise → ask: "Which files need tests?"

### 2. Find existing test patterns

```bash
# Find 1-2 representative test files as pattern reference
find . -name "*.test.ts" -o -name "*.spec.ts" -o -name "*_test.py" 2>/dev/null | head -3
```

### 3. Read CLAUDE.md for test command

### 4. Spawn dev-lead with test-only flag

Use the Task tool:
```
description: "Write tests for listed files"
agent: dev-lead
prompt: |
  ## Task (tests-only)
  Write comprehensive unit tests for the following files:
  [file list]

  ## Scope: tests-only
  Do NOT spawn dev-backend or dev-frontend.
  Spawn: dev-test → dev-reviewer

  ## Pattern reference files
  [1-2 example test file paths]

  ## Test command
  [from CLAUDE.md]
```

### 5. Run tests to verify
```bash
[TEST_CMD] --testPathPatterns='<pattern>'
```

Report coverage results.
