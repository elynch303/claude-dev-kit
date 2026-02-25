---
version: 1.0.0
name: ai-router
description: Routes tasks to the best available AI CLI tool based on task type and provider strengths. Triggered when user asks to "use gemini for", "run with codex", "ask grok", "route to best AI", "which AI should", or "delegate to".
---

# AI Router

**Notification:** At skill start, output: "Using ai-router to select optimal AI provider..."

## When to Use

- User wants to run a task with a specific non-Claude AI
- Task requires large context (> 100k tokens) → route to Gemini
- Task requires speed over depth → route to Grok
- Task is a coding challenge → consider Codex or Kimi
- User wants multi-AI perspective without full brainstorm
- Routing delegation for specific sub-tasks in a pipeline

## When NOT to Use

- Standard Claude Code tasks (just let Claude handle normally)
- When `/bs:brainstorm_full` is more appropriate (full multi-AI synthesis)
- When the user hasn't asked for a different AI

## Routing Logic

### Decision Tree

```
Is context > 100k tokens OR task = "scan entire codebase"?
  → YES: Use gemini (1M context window)
  → NO: Continue...

Is task = "private", "confidential", "local only", "don't send to cloud", "offline", "sensitive"?
  → YES: Use ollama if available (stays on machine), otherwise warn + use claude
  → NO: Continue...

Is task = "quick answer", "fast check", "brief analysis"?
  → YES: Use grok (fastest)
  → NO: Continue...

Is task = "code generation", "implement function", "write code"?
  → YES: Use claude (default) OR codex if available
  → NO: Continue...

Is task = "multilingual", "translate", "non-English"?
  → YES: Try glm or minimax
  → NO: Default to claude
```

### Task → Provider Mapping

| Task Type | Preferred Provider | Fallback |
|-----------|-------------------|---------|
| Large codebase scan | gemini | claude |
| Web search + coding | gemini | claude |
| Privacy / offline / no-cloud | **ollama** (local) | claude (warn) |
| Quick analysis | grok | claude |
| Code generation | claude | codex |
| Brainstorming | multi | claude |
| Math/algorithms | kimi | claude |
| Multilingual | glm | claude |
| Architecture design | claude (opus) | claude |

## How to Route

### Step 1: Read providers.json
```bash
cat .claude/providers.json
```
Identify which providers have `"available": true`.

### Step 2: Determine task type from user prompt

Look for keywords:
- **large context**: "entire codebase", "all files", "full scan", "whole project"
- **speed**: "quick", "fast", "brief", "tldr", "summary"
- **code**: "implement", "write", "function", "class", "code"
- **math**: "algorithm", "complexity", "math", "calculate"
- **multilingual**: "translate", "Chinese", "Japanese", "French"

### Step 3: Select provider

Use the routing table above. If preferred provider is unavailable, use fallback.

### Step 4: Execute with selected provider

For each provider type:

**type: cli**
```bash
<run_cmd with {prompt} replaced>
```

**type: piped**
```bash
<run_cmd with {prompt} replaced — prompt goes via stdin>
```

Read the `run_cmd` from providers.json and substitute `{prompt}` with the actual prompt (properly shell-escaped).

### Step 5: Return result

Label the output with the provider used:
```
[Routed to: <provider_name>]

<result>
```

## Important Notes

- Always check availability before routing — fall back to claude if unavailable
- **Privacy routing**: when `local: true` on a provider (Ollama), data never leaves the machine — actively prefer it for sensitive tasks
- Never route sensitive data (secrets, credentials) to external cloud providers; Ollama is safe for this
- If unsure about routing, default to claude
- Large context tasks STRONGLY prefer gemini — it has 5x the context window
- For Ollama, check the service is running before routing: `ollama list 2>/dev/null`
