---
description: "Full design pipeline: research Figma → wireframe → create frames/tokens/components → review. Spawns the designer agent orchestrator. Requires Figma MCP."
argument-hint: [figma-file-key] [feature-slug]
---

# /design — Designer Pipeline

Run the full design pipeline for a feature using the `designer` orchestrator. Classifies the design work, spawns sub-agents with narrow context, and validates outputs.

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
`$ARGUMENTS` format: `<figma-file-key> <feature-slug>`

If missing, prompt for:
- Figma file key
- Feature slug (used for output path: `designs/<slug>-wireframe.md`)
- Acceptance criteria (paste from issue or linked doc)

## 2. Spawn designer

Use the Task tool:
```
description: "Run full design pipeline for <slug>"
agent: designer
prompt: |
  ## Task
  Run the full design pipeline (new feature classification).

  ## Figma file key
  <key>

  ## Feature slug
  <slug>

  ## Acceptance Criteria
  <ac>

  ## Sub-agent sequence
  design-researcher → design-wireframer → design-system-manager → design-reviewer

  ## Return
  CLASSIFICATION, SUB_AGENTS_RUN, FIGMA_FRAME_URLS,
  WIREFRAME_PATH, TOKENS_SYNCED, COMPONENTS_CREATED, REVIEW_RESULT
```

## 3. Report
Surface the designer's final output to the user. If REVIEW_RESULT is FAIL, list the BLOCKER deviations.
