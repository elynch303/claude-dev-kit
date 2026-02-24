---
description: Run codex cli to execute current promt
---

# Run Codex LLM

Execute the prompt using Codex CLI in background mode.

## Instructions

1. If `$ARGUMENTS` is **empty**, ask the user for their prompt and wait for their response.

2. Set `PROMPT` to `$ARGUMENTS` (or the user's response if arguments were empty).

   `PROMPT_ESCAPED` is properly shell-escaped `PROMPT`.

3. **Launch in background** using **Bash** tool:
   - `command`: `opencode run --model openai/gpt-5.3-codex "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Codex execution`

4. **Wait for completion** using **TaskOutput** tool:
   - `task_id`: the task ID returned from step 3
   - `block`: `true`
   - Do NOT set any timeout - let it run as long as necessary

5. Display the result clearly:
   ```
   ### Codex Response
   [paste the response here]
   ```

## Behavior Notes

- Do **not** impose any timeouts. Let the LLM work as long as necessary.
- Do **not** check intermediate output. Wait for full completion.
- Do **not** make any code changes or modify files unless the response explicitly requires it and user confirms.
