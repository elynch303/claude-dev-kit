---
description: Run opencode cli with grok llm to execute current promt
---

# Run Grok LLM

Execute the prompt using Grok LLM via opencode CLI in background mode.

## Instructions

1. If `$ARGUMENTS` is **empty**, ask the user for their prompt and wait for their response.

2. Set `PROMPT` to `$ARGUMENTS` (or the user's response if arguments were empty).

   `PROMPT_ESCAPED` is properly shell-escaped `PROMPT`.

3. **Launch in background** using **Bash** tool:
   - `command`: `opencode run --model openrouter/x-ai/grok-4.1-fast "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Grok execution`

4. **Wait for completion** using **TaskOutput** tool:
   - `task_id`: the task ID returned from step 3
   - `block`: `true`
   - Do NOT set any timeout - let it run as long as necessary

5. Display the result clearly:
   ```
   ### Grok Response
   [paste the response here]
   ```

## Behavior Notes

- Do **not** impose any timeouts. Let the LLM work as long as necessary.
- Do **not** check intermediate output. Wait for full completion.
- Do **not** make any code changes or modify files unless the response explicitly requires it and user confirms.
