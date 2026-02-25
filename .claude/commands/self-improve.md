---
description: "Use multiple AI models to critique the kit's own agents, commands, and skills, then synthesize improvements and optionally create a PR. The kit improves itself."
argument-hint: [focus: agents | commands | skills | all]
---

# /self-improve — Multi-AI Kit Self-Critique

Use available AI models to read the kit's own agent prompts, commands, and skills, critique them for gaps or improvements, synthesize the best suggestions, and optionally commit them as a PR. Claude Code orchestrates — other AIs are reviewers.

## Steps

### 1. Determine focus area

```
FOCUS = $ARGUMENTS (default: "all")
```

Valid values: `agents`, `commands`, `skills`, `all`

### 2. Read the files to critique

Based on FOCUS:

**If agents or all:**
```bash
for f in .claude/agents/*.md; do echo "=== $f ==="; cat "$f"; done
```

**If commands or all:**
```bash
for f in .claude/commands/*.md .claude/commands/**/*.md; do echo "=== $f ==="; cat "$f"; done
```

**If skills or all:**
```bash
for f in .claude/skills/*/SKILL.md; do echo "=== $f ==="; cat "$f"; done
```

**Always read:**
```bash
cat .claude/hooks/skill-activation-prompt/skill-rules.json
cat .claude/providers.json
```

**If learning data exists, read summary:**
```bash
ls .claude/learning/sessions/ 2>/dev/null | tail -5
# Read last 3 files if they exist
```

### 3. Build the critique prompt

```
CRITIQUE_PROMPT = """
You are reviewing an AI development kit called "Claude Dev Kit". This kit is a collection of
agent prompts, slash commands, and skills that run inside AI coding assistants (Claude Code,
and now multi-AI via opencode/gemini/codex).

Your job: Critique the following kit files and produce SPECIFIC, ACTIONABLE improvements.

Focus on:
1. Agent prompt quality — are the instructions clear, unambiguous, complete?
2. Missing capabilities — what common dev tasks are not covered?
3. Redundancy — any commands/agents that overlap too much?
4. Skill trigger gaps — are the activation keywords comprehensive?
5. Multi-AI opportunities — where could tasks be better delegated to non-Claude AIs?
6. Self-improvement gaps — what feedback loops are missing?

For each improvement, provide:
- The specific file to change
- The exact text to add/modify/remove
- The reason (evidence-based)

Be concrete. "Make it better" is not useful. "Add 'refactor' and 'reorganize' as triggers
for code-investigator in skill-rules.json" is useful.

=== FILES TO CRITIQUE ===
<file contents>
"""
```

Substitute `<file contents>` with the actual concatenated file contents.

### 4. Check available AI providers

```bash
cat .claude/providers.json
```

Identify providers with `"available": true`.

### 5. Launch parallel critiques

Launch ALL available AI providers simultaneously (background mode).
Skip providers where `available` is `false`.

**Always run (Claude as orchestrator-reviewer):**
Use the Task tool with `subagent_type: deep-think-partner`:
- prompt: `CRITIQUE_PROMPT`
- run_in_background: true

**If gemini available:**
```bash
gemini -p "<CRITIQUE_PROMPT escaped>"
```
run_in_background: true

**If opencode/codex available:**
```bash
opencode run --model openai/gpt-5.3-codex "<CRITIQUE_PROMPT escaped>"
```
run_in_background: true

**If grok available:**
```bash
opencode run --model openrouter/x-ai/grok-4.1-fast "<CRITIQUE_PROMPT escaped>"
```
run_in_background: true

**If kimi available:**
```bash
opencode run --model openrouter/moonshotai/kimi-k2.5 "<CRITIQUE_PROMPT escaped>"
```
run_in_background: true

Wait for all background tasks to complete (no timeout).

### 6. Collect and display all critiques

```markdown
## Self-Improvement Critiques

### Claude (deep-think-partner)
<response>

### Gemini
<response>

### Codex
<response>

### Grok
<response>

### Kimi
<response>
```

### 7. Synthesize improvements

Analyze all critiques and identify:

**Consensus improvements** (suggested by 2+ AIs):
- These are the highest-confidence improvements

**Unique valuable insights** (only one AI suggested but strong argument):
- Include if the reasoning is compelling

**Contradictions** (AIs disagree):
- Note the disagreement and propose the more conservative option

Produce a synthesis:

```markdown
## Synthesized Improvement Plan

### Consensus (2+ AIs agree)
1. **<improvement title>**
   - File: <path>
   - Change: <specific change>
   - Suggested by: Claude, Gemini, Grok
   - Reason: <why>

### High-Value Singles
2. **<improvement title>**
   - File: <path>
   - Change: <specific change>
   - Suggested by: Codex
   - Reason: <why>

### Contradictions (held for human review)
3. **<topic>**: Claude suggests X, Gemini suggests Y
   - Recommendation: <your assessment>
```

### 8. Offer to apply improvements

Ask the user:

> **Apply improvements?**
> Consensus improvements (high confidence) can be auto-applied.
> Other improvements will be shown as diffs for review.

Use AskUserQuestion:
- "Apply consensus improvements automatically + show diffs for others"
- "Show me all as diffs first — I'll decide what to apply"
- "Just show the report — I'll apply manually"

### 9. Apply approved improvements

For each approved improvement:
1. Read the target file
2. Apply the specific change
3. Verify the file still looks correct
4. Report: "Updated <file>: <description>"

### 10. Commit and optionally create PR

If improvements were applied, offer to commit:

```bash
git add .claude/
git commit -m "self-improve: <N> improvements from multi-AI critique

Applied consensus improvements from Claude, Gemini, and <others>.
Run /self-improve to regenerate.

Generated by /self-improve on $(date +%Y-%m-%d)"
```

Ask if they want to create a PR:
```bash
gh pr create --title "self-improve: kit improvements from multi-AI critique" \
  --body "..."
```

### 11. Log the self-improvement run

```bash
# Append to learning log
cat >> .claude/learning/improvements.jsonl << 'EOF'
{"ts": <timestamp>, "type": "self-improve", "providers_used": [...], "improvements_applied": <N>}
EOF
```

## Notes

- The kit can critique itself — this is meta-cognition
- More AI providers = more diverse perspectives = better improvements
- Run this monthly or after major feature additions to keep the kit sharp
- All changes are committed to git — fully auditable and reversible
- `/improve` uses local session data; `/self-improve` uses AI critique — they complement each other
- For targeted improvements, specify focus: `/self-improve agents` or `/self-improve skills`
