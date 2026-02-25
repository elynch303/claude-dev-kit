---
description: "Analyze session learning logs to identify patterns and propose concrete improvements to agents, skills, and commands. The kit's feedback loop."
argument-hint: [days=14 | all]
---

# /improve — Self-Improvement Analysis

Read session learning data captured by the learning logger, identify patterns, and propose concrete improvements to the kit's agents, skills, and skill-activation rules. Optionally auto-apply low-risk improvements.

## Steps

### 1. Determine lookback window

```
DAYS = $ARGUMENTS (default: 14)
```

If `$ARGUMENTS` is "all", read all available logs.
If empty, default to last 14 days.

### 2. Read learning logs

```bash
ls .claude/learning/sessions/ 2>/dev/null | sort -r | head -30
```

For each relevant log file (within the requested date window):
```bash
cat .claude/learning/sessions/<YYYY-MM-DD>.jsonl
```

### 3. Aggregate statistics

Compute across all sessions:

**Command frequency:**
- Which slash commands were used most? (`slash_commands` field)
- Which were never used?

**Agent usage:**
- Which agents were spawned most? (`agents_spawned` field)
- Agent-to-turn ratio (efficiency indicator)

**Tool call patterns:**
- Most-used tools (`tools_called` field)
- Any tools never used?

**Error patterns:**
- Common error substrings from `errors` field
- Which sessions had the most errors?

**Token consumption:**
- Average tokens per session
- Most expensive sessions

**Skill activation gaps:**
- Compare `slash_commands` against `skill-rules.json` triggers
- Identify user phrases that DIDN'T trigger skills but should have

### 4. Read current skill rules

```bash
cat .claude/hooks/skill-activation-prompt/skill-rules.json
```

### 5. Read current agent files (sample)

Read the agents that showed the highest usage or most errors:
```bash
cat .claude/agents/<most-used-agent>.md
```

### 6. Generate improvement report

Using the data, produce a structured analysis:

```markdown
## /improve Analysis — Last <N> Days

### Usage Summary
- Sessions analyzed: <count>
- Total turns: <count>
- Total tokens consumed: <count>
- Average tokens/session: <count>

### Most-Used Commands
1. /<cmd> — <count> times
2. /<cmd> — <count> times
...

### Unused Commands (consider removing or improving)
- /<cmd> — 0 uses in <N> days
- /<cmd> — 0 uses in <N> days

### Skill Activation Gaps
Phrases found in user prompts that DIDN'T trigger a skill but likely should have:
- "<phrase>" → suggest adding trigger to <skill>
- "<phrase>" → suggest adding trigger to <skill>

### Agent Efficiency
- <agent>: avg <X> turns per spawn (high = may need tighter prompts)
- <agent>: avg <X> turns per spawn

### Common Error Patterns
- "<error snippet>" — appears in <N> sessions
  → Likely cause: <analysis>
  → Suggested fix: <fix>

### Token Hotspots
- Top consuming sessions: <count> tokens — commands used: <list>
  → Consider: caching results, using Haiku for this task, or splitting into smaller chunks

### Proposed Improvements

#### High Priority (auto-apply candidates)
1. **Add skill trigger**: Add "<phrase>" to `skill-rules.json` triggers for <skill>
   - Evidence: seen in <N> sessions

2. **Agent prompt tightening**: <agent>.md — add constraint to reduce turn count
   - Evidence: avg <X> turns, expected < <Y>

#### Medium Priority (review before applying)
3. **New skill needed**: Pattern "<X>" appears repeatedly with no skill match
   - Suggested: create a new skill for <purpose>

4. **Command consolidation**: /<cmd1> and /<cmd2> often used together
   - Suggested: create /<combined> shorthand

#### Low Priority (future consideration)
5. **Unused command cleanup**: /<cmd> — 0 uses in 14 days
   - Suggested: add to README as "advanced" or deprecate
```

### 7. Offer to apply improvements

After showing the report, ask:

> **Auto-apply safe improvements?**
> This would update `skill-rules.json` with suggested new triggers only (no agent edits).
> Agent prompt changes require your review.

Use AskUserQuestion with options:
- "Yes — update skill-rules.json only"
- "Yes — update skill-rules.json AND show agent diffs for review"
- "No — just show the report"

### 8. Apply approved improvements

**For skill-rules.json updates:**
1. Read current rules
2. Add new trigger keywords to appropriate skill entries
3. Write back to `.claude/hooks/skill-activation-prompt/skill-rules.json`
4. Report which triggers were added

**For agent improvements:**
Show the proposed diff using a clear before/after format. Only apply after user confirmation.

### 9. Log improvement action

Append to `.claude/learning/improvements.jsonl`:
```json
{
  "ts": <timestamp>,
  "date": "<YYYY-MM-DD>",
  "sessions_analyzed": <count>,
  "improvements_proposed": <count>,
  "improvements_applied": <count>,
  "changes": ["<description>", ...]
}
```

## Notes

- This command reads only `.claude/learning/` data — no external network calls
- All analysis is local — session data stays on your machine
- Learning data is automatically pruned after 90 days (by the learning_logger hook)
- Run after every few development sessions for best results
- For AI-powered critique of the kit itself, use `/self-improve`
