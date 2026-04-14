---
description: "Sync Figma variables ↔ code design tokens. Spawns designer (researcher + system-manager path)."
argument-hint: [figma-file-key] [direction=figma-to-code|code-to-figma]
---

# /design:tokens

Synchronize design tokens between Figma variables and the code token module.

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
`<figma-file-key> <direction>` — default direction is `figma-to-code`.

## 2. Spawn designer (tokens classification)

```
description: "Token sync for <key>"
agent: designer
prompt: |
  ## Task
  Token sync. Classification: token-sync-only.

  ## Figma file key
  <key>

  ## Direction
  <direction>

  ## Sub-agent sequence
  design-researcher → design-system-manager

  ## Return
  TOKENS_SYNCED, FILES_MODIFIED (if code-to-figma produced no writes, list []),
  REVIEW_NOTES
```

## 3. Report
Print the synced token list. If direction was `figma-to-code`, surface the modified token file paths for commit.
