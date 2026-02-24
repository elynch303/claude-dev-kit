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

If the `gh` command returns an error containing "API rate limit", stop and inform the user:
> GitHub API rate limit reached. Wait ~60 minutes or check your token scopes at https://github.com/settings/tokens

### 2. Check for existing PRP
```bash
ls PRPs/ 2>/dev/null
```
If a PRP file matches the issue slug:
- Read it — pass to dev-lead as context
- Verify it is non-empty before using it

### 3. Detect default branch and create feature branch
```bash
# Detect the default branch (main, master, or whatever the repo uses)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
# Fallback chain: if the above fails, try common names
if [ -z "$DEFAULT_BRANCH" ]; then
  git fetch origin 2>/dev/null || true
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git branch -r | grep -E '(main|master)' | head -1 | sed 's/.*origin\///' | tr -d ' ')
fi
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH="main"
fi

git checkout "$DEFAULT_BRANCH" && git pull origin "$DEFAULT_BRANCH"
git checkout -b feature/#<number>-<slugified-title>
```

### 4. Verify CLAUDE.md exists
```bash
[ -f CLAUDE.md ] || echo "WARNING: CLAUDE.md not found. Run /init first to configure agents for this stack."
```

### 5. Read CLAUDE.md for project conventions
Extract: stack, lint command, test command, build command, key patterns.

### 6. Spawn dev-lead

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

### 7. Pre-push safety check

Before pushing, scan for accidental secrets or sensitive files in the diff:
```bash
# Warn if any staged file looks like a secrets file
git diff "$DEFAULT_BRANCH"..HEAD --name-only | grep -iE '\.env$|\.env\.|\.key$|\.pem$|credentials|secrets' \
  && echo "WARNING: Sensitive filename detected in diff — review before pushing" || true

# Warn if diff contains likely secret values
git diff "$DEFAULT_BRANCH"..HEAD | grep -iE '(secret|api_key|private_key|password)\s*[:=]\s*["\x27]?[A-Za-z0-9+/]{16,}' \
  && echo "WARNING: Possible secret value detected in diff — review before pushing" || true
```

If warnings appear, surface them to the user and ask for confirmation before proceeding.

### 8. Ship after dev-lead confirms success

```bash
git push -u origin feature/#<number>-<slugified-title>
gh pr create \
  --title "feat: <issue-title> (#<number>)" \
  --body "Closes #<number>

## Changes
[summary from dev-lead]

🤖 Generated with Claude Dev Kit"
```

Output the PR URL.

## Important
- Do not push if dev-lead reports any validation gate failure
- Do not commit `.claude/`, `.env`, or settings files
- Do not proceed if the pre-push safety check flags secrets without user confirmation
