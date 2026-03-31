---
description: "Write or audit Storybook stories for UI components. Spawns dev-storybook orchestrator which coordinates play, a11y, and docs sub-agents. Skips cleanly if Storybook is not detected."
argument-hint: [component-file | issue-number | "audit"]
---

# /dev:storybook

Write or audit Storybook stories for UI components using the `dev-storybook` orchestrator.

## Steps

### 1. Detect Storybook

```bash
ls .storybook/ 2>/dev/null || { echo "No Storybook config found in this project."; exit 0; }
```

If Storybook is not present, stop and inform the user.

### 2. Parse the arguments

- **Number** (e.g., `/dev:storybook 42`) → `gh issue view 42` to get component files from the issue
- **File path** (e.g., `/dev:storybook src/components/Button.tsx`) → use that file directly
- **"audit"** → find all components that lack story files:
  ```bash
  # Find component files with no corresponding .stories.* file
  find src/components -name "*.tsx" ! -name "*.stories.*" ! -name "*.test.*" | while read f; do
    base="${f%.tsx}"
    ls "${base}.stories."* 2>/dev/null || echo "MISSING STORY: $f"
  done
  ```
- **No arguments** → ask the user which components to target

### 3. Determine request type

Based on arguments and context, classify as one of:
- `new-stories` — component files provided that have no stories yet
- `audit` — find and fix gaps in existing stories
- `interaction-tests` — add play functions to existing stories
- `a11y` — run accessibility checks and annotate
- `docs` — fill argTypes and prop documentation

### 4. Spawn dev-storybook orchestrator

Use the Task tool:

```
description: "Write/audit Storybook stories"
agent: dev-storybook
prompt: |
  ## Task
  [new-stories | audit | interaction-tests | a11y | docs]

  ## Component files
  [list of component file paths]

  ## Story files (existing, if any)
  [list of existing .stories.* file paths]

  ## Framework
  [React | Vue | Svelte — detected from .storybook/main.*]

  ## Request type
  [from step 3 — determines which sub-agents to spawn]
```

### 5. Report results

Output the `FILES_CREATED`, `FILES_MODIFIED`, and any `REVIEW_NOTES` from the orchestrator.

If Storybook build failed, surface the error and ask the user whether to fix it now.
