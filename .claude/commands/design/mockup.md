---
description: "Wireframe + Figma frame creation for a feature. Spawns designer (wireframer + system-manager path)."
argument-hint: [figma-file-key] [feature-slug]
---

# /design:mockup

Produce wireframes and create Figma frames for a feature — skips the review step.

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
`<figma-file-key> <feature-slug>` — prompt for missing pieces plus acceptance criteria.

## 2. Spawn designer (mockup-only scope)

```
description: "Mockup: wireframe + Figma frames for <slug>"
agent: designer
prompt: |
  ## Task
  Mockup only. Classification: single-component if <slug> is a single component,
  otherwise new-feature without the final reviewer step.

  ## Figma file key
  <key>

  ## Feature slug
  <slug>

  ## Acceptance Criteria
  <ac>

  ## Sub-agent sequence
  design-researcher → design-wireframer → design-system-manager

  ## Return
  WIREFRAME_PATH, FIGMA_FRAME_URLS, COMPONENTS_CREATED
```

## 3. Report
Print the wireframe path and Figma frame URLs.
