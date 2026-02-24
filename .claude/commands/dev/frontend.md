---
description: "Targeted frontend work only. Components, pages, state, styling. Spawns dev-frontend → dev-test → dev-e2e → dev-reviewer via dev-lead. Pass an issue number or task description."
argument-hint: [issue-number | task description]
---

# /dev:frontend

Run targeted frontend implementation through the dev-lead orchestrator (frontend path only).

## Steps

### 1. Parse the task

If `$ARGUMENTS` looks like a number → `gh issue view $ARGUMENTS`
Otherwise → use the text as the task description

### 2. Find relevant frontend files

```bash
grep -r "<domain-keyword>" app/ components/ src/ --include="*.tsx" --include="*.vue" --include="*.svelte" -l 2>/dev/null | head -10
```

### 3. Spawn dev-lead with frontend-only flag

Use the Task tool:
```
description: "Frontend implementation only"
agent: dev-lead
prompt: |
  ## Task (frontend-only)
  [issue body or free-text task]

  ## Scope: frontend-only
  Do NOT spawn dev-backend.
  Spawn: dev-frontend → dev-test → dev-e2e → dev-reviewer → validate

  ## Relevant files found
  [list from step 2]

  ## Validation commands (from CLAUDE.md)
  [lint, test, E2E, build commands]
```

### 4. Report
Return files created/modified and gate results.
