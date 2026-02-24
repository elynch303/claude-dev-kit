# Dev Epic Pipeline

Implement all stories in the next priority epic. One branch, one commit per story, one PR for the whole epic. Designed for the **ralph-loop** — each loop iteration implements one story via the `dev-lead` orchestrator.

## Steps

### 1. Detect state — are we mid-epic?

```bash
git branch --show-current
```

- If branch matches `epic/*` → **mid-epic, skip to step 3**
- Otherwise → need to select the epic (step 2)

### 2. Select the next priority epic (only when NOT mid-epic)

```bash
git checkout master && git pull origin master
gh issue list --state open --limit 100 --json number,title,milestone | \
  jq 'group_by(.milestone.title) | map({epic: .[0].milestone.title, lowest: map(.number) | min}) | sort_by(.lowest)'
```

Pick the milestone whose lowest issue number is smallest (highest priority).
Create branch: `epic/<slugified-milestone-name>`

```bash
git checkout -b epic/<slug>
```

### 3. List stories for this epic

```bash
gh issue list --state open --milestone "<milestone-name>" --limit 50 --json number,title
```

Sort by issue number ascending.

### 4. Find the next unimplemented story

```bash
git log --oneline
```

Extract all `(#NNN)` references already committed. Pick the **lowest-numbered** story NOT yet committed. If all stories committed → go to step 6 (create PR).

### 5. Implement the story (one story per loop iteration)

Read `CLAUDE.md` for validation commands, then spawn `dev-lead` via Task tool:

```
description: "Implement story #<number> for epic"
agent: dev-lead
prompt: |
  ## Story #<number>: <title>

  ### Acceptance Criteria
  [from gh issue view output]

  ## PRP
  [content of PRPs/<slug>.md if it exists, otherwise "research the codebase"]

  ## Branch
  epic/<slug> (already checked out)

  ## Validation Commands
  - Lint:  [from CLAUDE.md]
  - Test:  [from CLAUDE.md]
  - E2E:   [from CLAUDE.md or "none"]
  - Build: [from CLAUDE.md]

  ## Key Conventions
  [from CLAUDE.md]

  ## Important
  Do NOT create a PR. Do NOT push. Implement, validate all gates, then commit only:
    git add <feature files only>
    git commit -m "feat: <description> (#<story-number>)"

  Return: FILES_CREATED, FILES_MODIFIED, GATE_RESULTS, COMMIT_HASH
```

After dev-lead returns with successful gates and commit hash, the story is done.
**The ralph loop will re-invoke this command for the next story.**

### 6. Create the epic PR (only when all stories committed)

```bash
git push -u origin epic/<slug>
gh pr create \
  --title "epic: <milestone name>" \
  --body "$(cat <<'EOF'
## Epic: <milestone name>

Closes #NNN
Closes #NNN
[one Closes per story]

## Summary
[brief description of what the epic delivers]

## Stories Implemented
| # | Title | Size |
|---|-------|------|
[table from story list]

🤖 Generated with Claude Dev Kit
EOF
)"
```

Output the PR URL, then output exactly:
```
epic pr created
```

## Important
- **One branch per epic, one commit per story, one PR per epic**
- Do NOT commit `.claude/`, `.env`, or settings files
- If a story depends on another story in the same epic — implement anyway (the branch satisfies the dependency)
- Never create a per-story PR
