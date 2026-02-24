---
description: "Review the current branch's changes. Returns a structured PASS/FAIL report with security, correctness, pattern, type safety, and test quality checks."
argument-hint: [issue-number for context | empty]
---

# /dev:review

Run a structured code review on the current branch via the `dev-reviewer` sub-agent.

## Steps

### 1. Get fresh diff
```bash
git diff main...HEAD --stat
git diff main...HEAD
```

### 2. Get issue context (optional)
If `$ARGUMENTS` is an issue number → `gh issue view <N>` to get acceptance criteria for correctness review.

### 3. Spawn dev-lead with review-only flag

Use the Task tool:
```
description: "Review current branch changes"
agent: dev-lead
prompt: |
  ## Task (review-only)
  Review the changes on the current branch. Do NOT implement anything.

  ## Scope: review-only
  Spawn ONLY: dev-reviewer

  ## Git diff
  [paste full diff here]

  ## Acceptance Criteria (for correctness check)
  [from issue if available, otherwise "N/A"]

  ## Domain context
  [note if changes touch payments, auth, or data migration — for risk scoring]
```

### 4. Present report
Return the full review report with PASS/FAIL verdict and issue table.

If FAIL: list the BLOCKERs that must be resolved.
If PASS with WARNINGs: show warnings but confirm it is safe to merge.
