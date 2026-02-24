---
description: "Run a prompt with a local Ollama model. Data stays on your machine — no cloud calls. Optionally specify a model with 'model:name prompt'."
argument-hint: [prompt | model:<name> prompt]
---

# Run Ollama (Local LLM)

Execute the prompt using a locally running Ollama model. Nothing leaves your machine.

## Instructions

1. If `$ARGUMENTS` is **empty**, ask the user for their prompt and wait for their response.

2. Set `PROMPT` to `$ARGUMENTS` (or the user's response if arguments were empty).

3. **Check for model override in PROMPT:**
   - If PROMPT starts with `model:` (e.g. `model:codellama explain this code`):
     - Extract `MODEL` = word after `model:` (e.g. `codellama`)
     - Set `PROMPT` = rest of the string after the model word
   - Otherwise, read the active model from providers.json:
     ```bash
     python3 -c "import json; d=json.load(open('.claude/providers.json')); print(d['providers']['ollama'].get('model','llama3.2'))" 2>/dev/null || echo "llama3.2"
     ```
     Set `MODEL` = result (default: `llama3.2`)

4. **Verify Ollama is running:**
   ```bash
   ollama list 2>/dev/null | head -1 || echo "OLLAMA_DOWN"
   ```
   If output is `OLLAMA_DOWN` or contains an error:
   ```
   Ollama is not running. Start it first:
     ollama serve

   Then pull a model if you haven't:
     ollama pull llama3.2
     ollama pull codellama
     ollama pull qwen2.5-coder

   Install Ollama: https://ollama.ai
   ```
   Stop.

5. **Launch in background** using **Bash** tool:
   - `command`: `ollama run MODEL "PROMPT_ESCAPED"`
   - `run_in_background`: `true`
   - `description`: `Ollama (<MODEL>) execution`

   Replace `MODEL` with the actual model name and `PROMPT_ESCAPED` with the properly shell-escaped prompt.

6. **Wait for completion** using **TaskOutput** tool:
   - `task_id`: the task ID returned from step 5
   - `block`: `true`
   - Do NOT set any timeout — local models can take time on first run

7. Display the result clearly:
   ```
   ### Ollama Response [model: <MODEL>] [LOCAL — no cloud]

   [paste the response here]
   ```

## Behavior Notes

- **Private by design**: all computation happens on your machine, no data is sent to any API
- Do **not** impose any timeouts — first runs may be slow while the model loads into memory
- If the model isn't pulled yet, Ollama will automatically download it (this can take several minutes)
- Use `model:` prefix to override the active model for a one-off: `/bs:ollama model:codellama explain this function`
- To permanently switch models: `/ai:switch ollama:codellama`
- To see available models: `ollama list`
- Do **not** make any code changes or modify files unless explicitly confirmed by the user
