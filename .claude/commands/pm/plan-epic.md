---
description: "Full epic planning pipeline: groom all stories → size them → write PRPs for L/XL stories. Pass a milestone name."
argument-hint: [milestone-name]
---

# /pm:plan-epic

Run the full planning pipeline for an epic (GitHub milestone). At the end, every story is groomed, sized, and L/XL stories have PRPs.

## Steps

### 0. Rate limit preflight

```bash
gh api rate_limit --jq '.rate | "Remaining: \(.remaining)/\(.limit) (resets \(.reset | strftime("%H:%M")))"' 2>/dev/null || true
```

If remaining < 20, warn: "GitHub API rate limit is low. Epic planning makes many API calls — wait until reset or reduce the epic size."

### 1. Identify the epic

```bash
# List milestones to pick from if $ARGUMENTS is empty
gh api repos/:owner/:repo/milestones --jq '.[].title'
```

If `$ARGUMENTS` is provided, use it as the milestone name.

### 2. List all stories in the epic

```bash
gh issue list --state open --milestone "$ARGUMENTS" --limit 50 --json number,title,body,labels
```

### 3. Grooming pass

For any issue without "Acceptance Criteria" in body:
- Run the `/pm:groom` flow (spawn project-manager with grooming goal)
- Confirm and apply before proceeding to sizing

### 4. Sizing pass

Run `/pm:size` flow for all stories in the epic.
Present sizing table. Confirm before applying labels.

### 5. PRP generation for L/XL stories

For each story sized L or XL, or with confidence < 0.7:

Spawn the `project-manager` with goal:
```
"Write a PRP for issue #<N>. Research the codebase and produce PRPs/<slug>.md"
```

The PM will internally spawn `pm-prp-writer`.

### 6. Epic summary report

```markdown
## Epic Plan: <Milestone Name>

| # | Title | Size | Confidence | PRP |
|---|-------|------|------------|-----|
| #142 | Add pagination | M | 0.9 | — |
| #143 | Fix race condition | S | 0.8 | — |
| #144 | Stripe refunds | L | 0.6 | PRPs/stripe-refunds.md |

### Sprint Allocation
Sprint 1: #142, #143 (3 days total)
Sprint 2: #144 (after PRP review)

### Ready for development
Run: `/dev 142` to begin implementation
```
