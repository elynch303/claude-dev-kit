---
description: "Switch the default AI provider used for tasks. Run /ai:detect first to see available providers."
argument-hint: [claude | gemini | codex | grok | kimi | glm | minimax | opencode]
---

# /ai:switch — Switch Default AI Provider

Change which AI CLI tool is used as the default for tasks. This updates the `"default"` field in `.claude/providers.json`.

## Steps

### 1. Parse the requested provider

```
REQUESTED = $ARGUMENTS (trimmed, lowercased)
```

If `$ARGUMENTS` is empty, skip to the listing step below.

### 2. Read providers.json

```bash
cat .claude/providers.json
```

### 3. Validate the requested provider

Check that `REQUESTED` is a key in the `providers` object.

If not found:
```
Unknown provider: "<REQUESTED>"

Available providers:
  claude, gemini, codex, grok, kimi, glm, minimax, opencode

Run /ai:detect to check which are installed.
```
Stop.

### 4. Check availability

If `providers[REQUESTED].available` is `false`:
```
Warning: <REQUESTED> is not currently available (CLI not detected).
Run /ai:detect to refresh availability, or install the CLI first.

Continue anyway? (Note: tasks will fail at runtime if the CLI is missing.)
```

Ask the user with AskUserQuestion whether to proceed despite unavailability.

If user says no, stop.

### 5. Update providers.json

Set `"default": "<REQUESTED>"` in providers.json.

Write the updated JSON back.

### 6. Report success

```
## Default AI switched to: <provider_name>

Provider: <name>
CLI: <cli>
Strengths: <strengths list>
Context Window: <context_window> tokens

The routing configuration still applies:
  Large context → <routing.large_context>
  Speed → <routing.speed>
  Coding → <routing.coding>

Run /ai:route <task> to intelligently route a specific task.
Run /ai:detect to refresh which providers are available.
```

---

## If $ARGUMENTS is empty — show current state

```
## Current AI Configuration

Default provider: <default>

All providers:
  ✓ claude    — reasoning, agents, coding        [always available]
  ✓/✗ gemini  — large-context, web-search        [installed / not installed]
  ✓/✗ codex   — coding, code-completion          [requires opencode]
  ✓/✗ grok    — speed, reasoning                 [requires opencode]
  ✓/✗ kimi    — coding, math                     [requires opencode]
  ✓/✗ glm     — multilingual                     [requires cczy]
  ✓/✗ minimax — multimodal                       [requires ccmy]
  ✓/✗ opencode — coding, multi-model             [requires opencode]

Usage:
  /ai:switch gemini    — use Gemini as default
  /ai:switch claude    — revert to Claude
  /ai:detect           — refresh availability
  /ai:route <task>     — route specific task to best AI
```
