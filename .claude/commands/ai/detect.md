---
description: "Detect which AI CLI tools are installed and update providers.json with availability status."
argument-hint: []
---

# /ai:detect — AI Provider Detection

Scan the system for installed AI CLI tools, update `.claude/providers.json` with current availability, and report what's ready to use.

## Steps

### 1. Read current providers.json

```bash
cat .claude/providers.json
```

Extract the list of providers and their `cli` fields.

### 2. Check each CLI's availability

Run these checks **in parallel**:

```bash
# Claude (always available inside Claude Code — check for standalone CLI too)
which claude 2>/dev/null && claude --version 2>/dev/null | head -1 || echo "NOT_FOUND"

# Gemini
which gemini 2>/dev/null && gemini --version 2>/dev/null | head -1 || echo "NOT_FOUND"

# OpenCode (covers Codex, Grok, Kimi via --model flag)
which opencode 2>/dev/null && opencode --version 2>/dev/null | head -1 || echo "NOT_FOUND"

# Ollama (local LLMs)
which ollama 2>/dev/null && ollama --version 2>/dev/null | head -1 || echo "NOT_FOUND"

# GLM wrapper
which cczy 2>/dev/null || echo "NOT_FOUND"

# MiniMax wrapper
which ccmy 2>/dev/null || echo "NOT_FOUND"
```

### 2b. If Ollama is found, list available models

```bash
ollama list 2>/dev/null | tail -n +2 | awk '{print $1}'
```

Use this list to:
- Confirm Ollama is running (if the command fails with a connection error, set a warning that `ollama serve` may not be running)
- Set the `model` field in providers.json to the first available coding model found, using this preference order: `qwen2.5-coder`, `codellama`, `deepseek-coder-v2`, `llama3.2`, `llama3.1`, `mistral`, `gemma3` — or the first model in the list if none match

### 3. Build detection results

For each provider, mark:
- `"available": true` — CLI found and responds
- `"available": false` — CLI not found
- Note: `opencode` covers codex, grok, kimi, and opencode providers

Special rules:
- `claude`: always `true` (we are running inside Claude Code)
- `codex`, `grok`, `kimi`: set to `true` if `opencode` is available
- `glm`: set to `true` if `cczy` is available
- `minimax`: set to `true` if `ccmy` is available
- `ollama`: set to `true` if `ollama` binary found AND at least one model is installed; also update the `model` field with the best available model (see step 2b)

### 4. Update providers.json

Read the current providers.json and update each provider's `"available"` field with the detection results.

Write the updated JSON back to `.claude/providers.json`.

### 5. Report results

Print a table:

```
## AI Provider Detection Results

| Provider    | CLI        | Available | Strengths                         |
|-------------|------------|-----------|-----------------------------------|
| claude      | claude     | ✓         | reasoning, agents, coding         |
| gemini      | gemini     | ✓ / ✗     | large-context, web-search         |
| codex       | opencode   | ✓ / ✗     | coding, code-completion           |
| grok        | opencode   | ✓ / ✗     | speed, reasoning                  |
| kimi        | opencode   | ✓ / ✗     | coding, math                      |
| ollama      | ollama     | ✓ / ✗     | privacy, offline, no-cost [LOCAL] |
| glm         | cczy       | ✓ / ✗     | multilingual                      |
| minimax     | ccmy       | ✓ / ✗     | multimodal                        |
| opencode    | opencode   | ✓ / ✗     | coding, multi-model               |

## Ollama Models Installed
<list from `ollama list`, or "none" if not installed>
Active model: <value of providers.ollama.model>

## Current Default: <value of "default" field>

## Routing Configuration
Large context tasks → <routing.large_context>
Speed tasks → <routing.speed>
Coding tasks → <routing.coding>
Privacy/offline tasks → ollama (if available)

## Tips
- Install Gemini CLI: https://github.com/google-gemini/gemini-cli
- Install OpenCode: https://opencode.ai/docs/installation
- Install Ollama (local LLMs): https://ollama.ai — then run `ollama pull llama3.2`
- Switch Ollama model: /ai:switch ollama:codellama
- Run /ai:switch <provider> to change the default provider
```

## Notes

- This command is safe to re-run at any time
- providers.json is updated in-place with only the `available` fields changed
- Other fields (run_cmd, strengths, notes) are preserved exactly
