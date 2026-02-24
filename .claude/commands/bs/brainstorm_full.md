---
description: Brainstorm using 7 different LLMs (four-step flow)
---

# Multi-LLM Brainstorming (Mode)

You are orchestrating a multi-LLM brainstorming workflow using background tasks and explicit output retrieval.

This workflow has four phases:

- Phase 0: Determine the brainstorm prompt
- Phase 1: Launch 7 LLMs in parallel (background)
- Phase 2: Collect results
- Phase 3: Synthesize results

---

## Phase 0 — Get the prompt

1. If `$ARGUMENTS` is **not empty**, then:
   - Set `PROMPT = $ARGUMENTS`
   - Skip asking the user anything and go straight to **Phase 1**.

2. If `$ARGUMENTS` is **empty**, then:
   - Say **only**:
     > Multi-LLM brainstorm mode activated. Send me your brainstorm question in the next message.
   - Then **wait** for the user's next message.
   - When the user replies, set:
     - `PROMPT =` the full content of that next user message.
   - Immediately continue with **Phase 1** using `PROMPT`.

---

## Phase 1 — Launch 7 LLMs in parallel

Launch ALL 7 LLMs **in a single message** using background execution.
Append to `PROMPT`: "Do **not** make any changes in code. Do **not** modify any files."

Let each tool run as long as necessary. Don't enforce any timeouts or finish tasks by timeout.
**IMPORTANT** - don't stop any process. Let LLM to work as long as necessary, even if it take 24 hours.
**NEVER** check intermediate bash output of running bashes. Let them FINISH execution as long as necessary.

`PROMPT_ESCAPED` is properly shell-escaped `PROMPT`

**CRITICAL**: Use the actual **Bash** tool, NOT the Skill tool. Launch all 7 in ONE message with these exact tool calls:

1. **Claude**
   Use **Bash** tool:
   - `command`: `echo "PROMPT_ESCAPED" | env -u CLAUDECODE claude -p --agent deep-think-partner`
   - `run_in_background`: `true`
   - `description`: `Claude brainstorm`

2. **Codex**
   Use **Bash** tool:
   - `command`: `opencode run --model openai/gpt-5.3-codex "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Codex brainstorm`

3. **Gemini**
   Use **Bash** tool:
   - `command`: `gemini -p "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Gemini brainstorm`

4. **Grok**
   Use **Bash** tool:
   - `command`: `opencode run --model openrouter/x-ai/grok-4.1-fast "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Grok brainstorm`

5. **Glm**
   Use **Bash** tool:
   - `command`: `echo "PROMPT_ESCAPED" | env -u CLAUDECODE cczy -p --agent deep-think-partner`
   - `run_in_background`: `true`
   - `description`: `Glm brainstorm`

6. **MiniMax**
   Use **Bash** tool:
   - `command`: `echo "PROMPT_ESCAPED" | env -u CLAUDECODE ccmy -p --agent deep-think-partner`
   - `run_in_background`: `true`
   - `description`: `MiniMax brainstorm`

7. **Kimi**
   Use **Bash** tool:
   - `command`: `opencode run --model openrouter/moonshotai/kimi-k2.5 "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Kimi brainstorm`

After launching, you will receive task IDs for each background process.

---

## Phase 2 — Collect results and Synthesize

Use **TaskOutput** tool to retrieve each result. Call TaskOutput for each task_id with `block: true` to wait for completion.

**IMPORTANT**: Let each task run as long as needed. Do NOT impose any timeouts.

As each result comes in, display it clearly labeled:

```
### Claude
[paste Claude's response here]

### Codex
[paste Codex's response here]

### Gemini
[paste Gemini's response here]

### Grok
[paste Grok's response here]

### Glm
[paste Glm's response here]

### MiniMax
[paste MiniMax's response here]

### Kimi
[paste Kimi's response here]
```

If any task fails, note which one failed and continue with the remaining ones.

---

## Phase 3 — Synthesize

After all available model responses are collected:

Provide a concise analysis with these sections:

1. **Consensus** – What do at least 4 models broadly agree on?
2. **Unique Insights** – What valuable, distinct perspective did each model add?
3. **Contradictions** – Where do they disagree, and what might explain the difference?
4. **Recommendation** – Your synthesized best approach / action plan.

Keep the synthesis **concise and actionable**.

---

## Behavior Notes

- Do **not** re-ask for the prompt once `PROMPT` is set, unless the user clearly changes the question.
- Always use **Bash** and **Task** tools directly, NOT the Skill tool for invoking LLMs.
- Use `run_in_background: true` for all 7 launches, then retrieve with `TaskOutput`.
- Do **not** make any changes in code. Do **not** modify any files.
- If the user gives a new message after the synthesis clearly changing the topic, treat that as a request to **rerun the whole workflow** with the new `PROMPT`.
