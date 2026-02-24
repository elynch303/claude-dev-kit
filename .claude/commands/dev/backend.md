---
description: "Targeted backend work only. API routes, services, DB queries, auth. Spawns dev-backend → dev-test → dev-reviewer via dev-lead. Pass an issue number or free-text task description."
argument-hint: [issue-number | task description]
---

# /dev:backend

Run targeted backend implementation through the dev-lead orchestrator (backend path only).

## Steps

### 1. Parse the task

If `$ARGUMENTS` looks like a number → `gh issue view $ARGUMENTS`
Otherwise → use the text as the task description

### 2. Find relevant backend files

Search for files related to the task domain:
```bash
# Find related route handlers, services, schema
grep -r "<domain-keyword>" app/api/ lib/ prisma/ --include="*.ts" -l 2>/dev/null | head -10
```

### 3. Spawn dev-lead with backend-only flag

Use the Task tool:
```
description: "Backend implementation only"
agent: dev-lead
prompt: |
  ## Task (backend-only)
  [issue body or free-text task]

  ## Scope: backend-only
  Do NOT spawn dev-frontend.
  Spawn: dev-backend → dev-test → dev-reviewer → validate

  ## Relevant files found
  [list from step 2]

  ## Validation commands (from CLAUDE.md)
  [lint, test, build commands]
```

### 4. Report
Return the list of files created/modified and validation gate results.
