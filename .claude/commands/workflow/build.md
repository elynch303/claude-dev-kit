---
description: "Generate a complete agent workflow pipeline from a workflow document. Parses the document into an orchestrator + sub-agents + slash command, all organized in a named directory under .claude/workflows/."
argument-hint: <path-to-workflow-document>
---

# /workflow:build — Workflow Builder

Transform any workflow document into a ready-to-run Claude Dev Kit agent pipeline — one orchestrator, one specialist sub-agent per step, a trigger command, and a README — all named and organized by the workflow title.

## What This Command Does

1. Reads your workflow document (Markdown, plain text, SOPs, process notes, workshop guides)
2. Extracts the workflow title, phases, roles, and step-by-step processes
3. Generates a complete agent pipeline in `.claude/workflows/<title>/`:
   - **Orchestrator agent** (`<title>-lead`) — owns the workflow end-to-end
   - **Sub-agent per step** (`<title>-<step>`) — one specialist per phase
   - **Slash command** (`/workflow:<title>`) — triggers the workflow
   - **README.md** — documents what was generated and how to use it

## Usage

Provide a document path:
```
/workflow:build docs/angelic-workshop-process.md
```

Or paste workflow content directly as the argument.

## Steps

### 1. Read the Workflow Document

If `$ARGUMENTS` looks like a file path (contains `/` or ends in `.md`, `.txt`, `.doc`):
```bash
cat "$ARGUMENTS"
```

If `$ARGUMENTS` is raw text, use it directly as the document content.

If `$ARGUMENTS` is empty, ask the user:
> "Please provide the path to your workflow document, or paste the workflow content here. I'll parse it and generate a full agent pipeline from it."

### 2. Spawn the workflow-builder Agent

Use the Task tool with the `workflow-builder` agent. Pass the FULL document content:

```
description: "Parse document and generate workflow pipeline"
agent: workflow-builder
prompt: |
  ## Workflow Document

  [FULL DOCUMENT CONTENT — paste verbatim, do not truncate]

  ## Instructions

  Parse this workflow document and generate the complete agent pipeline.
  Create all files in the standard locations.
  Return the workflow title, slug, directory path, command name, and
  a list of all agents created with their roles.
```

### 3. Report Completion

After workflow-builder returns, output a clean summary:

```
## ✅ Workflow Generated: <Title>

**Directory**: .claude/workflows/<slug>/
**Trigger command**: /workflow:<slug>

### Agents Created
| Agent | Role |
|-------|------|
| `<title>-lead` | Orchestrator — runs the full workflow |
| `<title>-<step1>` | <step 1 description> |
| `<title>-<step2>` | <step 2 description> |

### Next Steps
1. Run `/workflow:<slug>` to start the workflow
2. Review `.claude/workflows/<slug>/README.md` for the full spec
3. Customize agents in `.claude/agents/<slug>-*.md` to refine behavior
```

## Notes

- The builder preserves your domain language (spiritual, clinical, technical, etc.)
- Each sub-agent is self-contained and can be edited independently
- Re-run `/workflow:build` with an updated document to regenerate at any time
- Generated agents follow the same patterns as built-in kit agents
