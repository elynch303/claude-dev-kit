---
description: "Size stories for sprint planning. Adds t-shirt size labels (size:XS/S/M/L/XL) and confidence scores. Pass a milestone name, issue numbers, or leave empty for all groomed issues."
argument-hint: [milestone-name | issue-numbers | empty]
---

# /pm:size

Invoke the `project-manager` orchestrator to size stories. The PM will internally spawn `pm-sizer`.

## Steps

### 1. Fetch stories to size

```bash
# If $ARGUMENTS is a milestone:
gh issue list --state open --milestone "$ARGUMENTS" --limit 50 --json number,title,body,labels

# If $ARGUMENTS is issue numbers (space-separated):
# Fetch each: gh issue view <N>

# If empty — all groomed issues (have "Acceptance Criteria"):
gh issue list --state open --limit 100 --json number,title,body,labels
```

Filter for issues that have "Acceptance Criteria" in body (groomed) but do NOT already have a `size:*` label.

### 2. Get sprint capacity
Ask the user: "What is your sprint capacity in days?" (default: 10)

### 3. Spawn project-manager

Use the Task tool:
```
Goal: "Size the following groomed stories and produce a sprint plan"
Context: [full issue bodies + sprint capacity]
```

The project-manager will spawn `pm-sizer`.

### 4. Present sizing table
Show the sizing table and sprint plan. Ask: "Apply size labels to GitHub?"

If confirmed, run the `gh issue edit --add-label` commands returned by the sizer.

### 5. Flag L/XL stories
For any L or XL story, suggest: "Run `/pm:plan-epic` for issue #N to generate a PRP before scheduling."
