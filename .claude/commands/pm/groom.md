---
description: "Groom GitHub/Linear/Jira issues. Adds acceptance criteria, Definition of Done, and sub-tasks. Pass an issue number, milestone name, or leave empty to groom all ungroomed issues."
argument-hint: [issue-number | milestone-name | empty]
---

# /pm:groom

Invoke the `project-manager` orchestrator to groom issues. The PM will internally spawn `pm-groomer` for each issue.

## Steps

### 1. Identify issues to groom

```bash
# If $ARGUMENTS is an issue number:
gh issue view $ARGUMENTS

# If $ARGUMENTS is a milestone name:
gh issue list --state open --milestone "$ARGUMENTS" --limit 50 --json number,title,body

# If $ARGUMENTS is empty — find ungroomed issues (no "Acceptance Criteria" heading):
gh issue list --state open --limit 50 --json number,title,body
```

Filter for issues whose body does NOT contain "Acceptance Criteria".

### 2. Gather domain context
For each issue, search for 2-3 related source files using Grep on the issue title keywords. These file paths will be passed to the groomer as context.

### 3. Spawn project-manager

Use the Task tool with the `project-manager` agent:
```
Goal: "Groom the following issues and return updated issue bodies"
Context: [issue content + relevant file paths]
```

The project-manager will spawn `pm-groomer` for each issue or batch.

### 4. Present for confirmation
Show all updated issue bodies to the user. Ask: "Apply these updates to GitHub?"

If confirmed, run for each issue:
```bash
gh issue edit <number> --body "<updated-body>"
```

### 5. Report
List all issues groomed with their new titles.
