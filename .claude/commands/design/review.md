---
description: "Compare Figma frames against the code implementation on the current branch. Returns a PASS/FAIL deviation report. Read-only."
argument-hint: [figma-file-key] [feature-slug]
---

# /design:review

Run a design review: Figma truth vs code reality for the current branch.

## 0. Figma MCP guard

```bash
if ! claude mcp list 2>/dev/null | grep -q "figma"; then
  echo "⚠️   Designer agents require the Figma MCP."
  echo "   Run: bash scripts/install.sh --mcp-only"
  echo "   Select 'Figma' in the Design Tools menu."
  exit 1
fi
```

## 1. Parse arguments
`<figma-file-key> <feature-slug>` — plus optionally a comma-separated list of code paths to review.

## 2. Gather diff context

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
git diff "${DEFAULT_BRANCH:-main}"...HEAD --name-only
```

## 3. Spawn designer (review-only)

```
description: "Design review for <slug>"
agent: designer
prompt: |
  ## Task
  Review only. Classification: review-only.

  ## Figma file key
  <key>

  ## Feature slug
  <slug>

  ## Code paths
  <paths from step 2>

  ## Acceptance Criteria
  <ac>

  ## Sub-agent sequence
  design-researcher → design-reviewer

  ## Return
  REVIEW_RESULT, REVIEW_ISSUES
```

## 4. Report
Surface the deviation table. If FAIL, list BLOCKERs prominently.
