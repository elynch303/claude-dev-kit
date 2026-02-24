---
description: "Run the project-manager orchestrator. Plans, grooms, and sizes the backlog. Pass a specific goal or let PM assess the current state."
argument-hint: [goal description | empty]
---

# /pm — Project Manager

Activate the `project-manager` agent to assess and act on the project backlog.

## Steps

### 1. Gather backlog context
```bash
gh issue list --state open --limit 100 --json number,title,labels,milestone,body | head -200
```

### 2. Read project conventions
Read `CLAUDE.md` to extract stack, test commands, and any project-specific planning conventions.

### 3. Spawn the project-manager agent

Use the Task tool:
```
description: "Assess and act on project backlog"
agent: project-manager
prompt: |
  ## Goal
  [If $ARGUMENTS is provided, use it as the goal. Otherwise: "Assess the backlog and recommend the highest-value next actions."]

  ## Open Issues (from gh issue list)
  [Paste the full JSON output here]

  ## Project Conventions
  - Stack: [from CLAUDE.md]
  - Test command: [from CLAUDE.md]
  - Build command: [from CLAUDE.md]

  ## Available sub-commands
  - /pm:groom  — groom specific issues
  - /pm:size   — size groomed issues
  - /pm:plan-epic — full epic planning

  Return your assessment and recommended next actions.
```

### 4. Present results
Return the project-manager's full report, then ask: "What would you like to do next?"
