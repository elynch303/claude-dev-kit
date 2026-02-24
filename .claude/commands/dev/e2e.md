---
description: "Write E2E tests for a user flow. Pass a description of the flow or an issue number. Spawns dev-e2e via dev-lead."
argument-hint: [flow description | issue-number]
---

# /dev:e2e

Write Playwright or Cypress E2E tests for a user journey.

## Steps

### 1. Parse the task

If `$ARGUMENTS` is an issue number → `gh issue view <N>` to get acceptance criteria
Otherwise → use the text as the flow description

### 2. Find existing E2E spec as pattern

```bash
find . -name "*.spec.ts" -path "*/e2e/*" -o -name "*.cy.ts" 2>/dev/null | head -2
```

### 3. Detect E2E runner

```bash
ls playwright.config.* cypress.config.* 2>/dev/null
```

### 4. Spawn dev-lead with e2e-only flag

Use the Task tool:
```
description: "Write E2E tests for flow"
agent: dev-lead
prompt: |
  ## Task (e2e-only)
  Write E2E tests for this user journey:
  [acceptance criteria or flow description]

  ## Scope: e2e-only
  Spawn: dev-e2e → dev-reviewer

  ## E2E runner: [playwright | cypress]
  ## Pattern reference: [existing spec file path]
  ## Base URL: [from CLAUDE.md or ask]
```

### 5. Report
Return test files created and selector additions.
