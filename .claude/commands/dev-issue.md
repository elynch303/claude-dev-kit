# Dev Issue Pipeline

Implement a GitHub issue end-to-end using the `dev-lead` orchestrator. This command is equivalent to `/dev` and delegates all work to specialist sub-agents with clean context windows.

## Arguments
- `$ARGUMENTS` — GitHub issue number (optional, defaults to next open issue)

## Steps

### 1. Identify the issue
If no issue number: `gh issue list --state open --limit 10 --json number,title` → pick the lowest-numbered non-epic issue.

```bash
gh issue view <number>
```

### 2. Check for PRP
```bash
ls PRPs/ 2>/dev/null
```
Read PRP if a matching slug file exists.

### 3. Create branch
```bash
git checkout master && git pull origin master
git checkout -b feature/#<number>-<slugified-title>
```

### 4. Read CLAUDE.md
Extract: lint command, test command, E2E command, build command, key conventions.

### 5. Spawn dev-lead via Task tool

```
description: "Implement issue #<number>"
agent: dev-lead
prompt: |
  ## Issue #<number>: <title>

  ### Acceptance Criteria
  [extracted from issue body]

  ### Definition of Done
  [extracted from issue body]

  ## PRP
  [full PRP content, or "none — research the codebase"]

  ## Branch
  feature/#<number>-<slugified-title>

  ## Validation Commands
  - Lint:  [LINT_CMD from CLAUDE.md]
  - Test:  [TEST_CMD from CLAUDE.md]
  - E2E:   [E2E_CMD from CLAUDE.md, or "none"]
  - Build: [BUILD_CMD from CLAUDE.md]

  ## Key Conventions
  [3-5 bullet points from CLAUDE.md — patterns, naming, file limits]

  Classify the work (backend/frontend/fullstack), spawn appropriate sub-agents,
  run all validation gates, return FILES_CREATED, FILES_MODIFIED, GATE_RESULTS.
```

### 6. Ship
After dev-lead reports all gates passing:
```bash
git push -u origin feature/#<number>-<slugified-title>
gh pr create \
  --title "feat: <title> (#<number>)" \
  --body "Closes #<number>\n\n[summary from dev-lead]\n\n🤖 Generated with Claude Dev Kit"
```

Output the PR URL.

## Important
- Never commit `.claude/`, `.env`, or settings files
- Do not push if any validation gate failed
- One branch per issue, one PR per issue
