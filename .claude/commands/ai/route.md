---
description: "Route a task to the best available AI CLI tool based on task type. Claude orchestrates and returns the result."
argument-hint: [task description]
---

# /ai:route — Intelligent AI Task Routing

Analyze the task, select the optimal AI provider based on available CLIs and task type, execute the task, and return the result. Claude Code always orchestrates — it calls the chosen AI as a subprocess and synthesizes the response.

## Steps

### 1. Get the task

```
TASK = $ARGUMENTS
```

If empty, ask the user: "What task do you want to route to the best AI? Describe the task."

### 2. Read providers configuration

```bash
cat .claude/providers.json
```

Identify:
- `routing` preferences object
- Which providers have `"available": true`

### 3. Determine task type and select provider

Analyze `TASK` against these patterns:

**Large context / full codebase:**
- Keywords: "entire codebase", "all files", "full project scan", "whole repo", "scan everything"
- → Use `routing.large_context` provider (default: gemini)

**Speed-first:**
- Keywords: "quick", "fast", "briefly", "tldr", "one sentence", "just tell me"
- → Use `routing.speed` provider (default: grok)

**Code generation / implementation:**
- Keywords: "implement", "write a function", "create a class", "code that", "build a"
- → Use `routing.coding` provider (default: claude)

**Multi-AI synthesis:**
- Keywords: "brainstorm", "multiple perspectives", "compare approaches", "what do different AIs think"
- → Suggest `/bs:brainstorm_full` instead

**Math / algorithms:**
- Keywords: "algorithm", "complexity", "O(n)", "optimize", "calculate", "math"
- → Use kimi if available, otherwise claude

**Default:** Use the `"default"` provider from providers.json.

If selected provider is unavailable, fall back to claude.

### 4. Show routing decision

```
Routing to: <provider_name> (<reason>)
Context window: <context_window> tokens
```

### 5. Execute with selected provider

Read `run_cmd` from providers.json for the selected provider.
Replace `{prompt}` with the escaped task content.

**For type: cli:**
```bash
<run_cmd with {prompt} substituted>
```

**For type: piped:**
```bash
echo '<escaped_task>' | <run_cmd with {prompt} removed>
```
(The piped CLI reads the prompt from stdin)

Run in background if long-running:
- `run_in_background: true` for tasks that may take > 30 seconds

Wait for completion (no timeout — let it run as long as needed).

### 6. Return result

```
## Result from <provider_name>

<output>

---
Routed by: ai-router | Provider: <provider_name> | Task type: <detected_type>
```

### 7. Optionally compare

If the user's task looks like it would benefit from comparison (e.g., architecture decisions, complex tradeoffs), after returning the primary result ask:

> "Want me to also get a second opinion from [another available provider]?"

## Error Handling

If the selected provider fails (exit non-zero):
1. Report the error clearly
2. Automatically fall back to claude
3. Re-run the task with claude
4. Note which provider failed

## Notes

- Claude Code is always the orchestrator — it never "becomes" another AI
- Other AIs are called as subprocess CLIs and their output is returned here
- Sensitive data (API keys, .env contents) should never be included in the task prompt sent to external providers
- The routing configuration in providers.json can be customized with `/ai:switch`
