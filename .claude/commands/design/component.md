---
description: "Design a single component end-to-end: wireframe → Figma frame → review. Spawns designer (single-component path)."
argument-hint: [figma-file-key] [component-name]
---

# /design:component

Design a single component end-to-end.

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
`<figma-file-key> <component-name>` — prompt for variants and states if not supplied.

## 2. Spawn designer (single-component)

```
description: "Design component <name>"
agent: designer
prompt: |
  ## Task
  Single component design.

  ## Figma file key
  <key>

  ## Component name
  <name>

  ## Variants & states
  <list>

  ## Acceptance Criteria
  - All variants represented in Figma
  - All interactive states covered (default, hover, focus, disabled, loading if applicable)
  - Tokens used from existing design system (no hex literals)

  ## Sub-agent sequence
  design-wireframer → design-system-manager → design-reviewer

  ## Return
  WIREFRAME_PATH, FIGMA_FRAME_URLS, COMPONENTS_CREATED, REVIEW_RESULT
```

## 3. Report
Print component URL, variants created, review result.
