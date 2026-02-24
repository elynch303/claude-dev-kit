---
description: "Run the dev-lead orchestrator for a single GitHub issue. Reads the issue, classifies the work, spawns engineering sub-agents, validates all gates, and ships a PR. The fully automated dev pipeline."
argument-hint: [issue-number]
---

# /dev — Dev Lead Pipeline

Implement a GitHub issue end-to-end using the `dev-lead` orchestrator. Claude spawns the right specialist sub-agents with narrow context, runs all 5 validation gates, and ships.

## Steps

### 1. Identify the issue

If `$ARGUMENTS` is empty:
```bash
gh issue list --state open --limit 10 --json number,title,labels
```
Pick the lowest-numbered issue that is not an epic.

Read the issue:
```bash
gh issue view <number>
```

### 2. Check for existing PRP
```bash
ls PRPs/ 2>/dev/null
```
If a PRP file matches the issue slug, read it — it will be passed to dev-lead.

### 3. Create feature branch
```bash
git checkout master && git pull origin master
git checkout -b feature/#<number>-<slugified-title>
```

### 4. Read CLAUDE.md for project conventions
Extract: stack, lint command, test command, build command, key patterns.

### 5. Spawn dev-lead

Use the Task tool:
```
description: "Implement issue #<number>"
agent: dev-lead
prompt: |
  ## Issue #<number>: <title>

  ### Acceptance Criteria
  [from issue body]

  ### Definition of Done
  [from issue body]

  ## PRP
  [full PRP content if available, otherwise "none"]

  ## Branch
  feature/#<number>-<slugified-title>

  ## Project Validation Commands (from CLAUDE.md)
  - Lint: [LINT_CMD]
  - Test: [TEST_CMD]
  - E2E: [E2E_CMD]
  - Build: [BUILD_CMD]

  ## Key Conventions
  [2-5 bullet points from CLAUDE.md — patterns, naming, file limits]

  ## Instruction
  Implement this issue fully. Classify backend/frontend/fullstack work.
  Spawn the appropriate engineering sub-agents with narrow context.
  Run all validation gates. Return FILES_CREATED, FILES_MODIFIED, and GATE_RESULTS.
```

### 6. Ship after dev-lead confirms success

```bash
git push -u origin feature/#<number>-<slugified-title>
gh pr create \
  --title "feat: <issue-title> (#<number>)" \
  --body "Closes #<number>\n\n## Changes\n[summary from dev-lead]\n\n🤖 Generated with Claude Dev Kit"
```

Output the PR URL.

## Important
- Do not push if dev-lead reports any validation gate failure
- Do not commit `.claude/`, `.env`, or settings files
