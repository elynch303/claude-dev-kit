---
description: "Read-only token audit of .claude/. Profiles agent description cost, finds unreferenced/cold agents, flags over-permissioned tools, estimates per-session token budget. Run /optimize to apply fixes."
argument-hint: [verbose]
---

# /audit — .claude Token & Usage Audit

Read-only analysis of the `.claude/` directory. Profiles token cost, finds unreferenced agents, verbose descriptions, and over-permissioned tools. Makes no changes.

**Not in scope**: skill trigger gaps → use `/improve`. AI quality critique → use `/self-improve`.

## Steps

### 1. Agent inventory

```bash
ls .claude/agents/*.md 2>/dev/null
wc -c .claude/agents/*.md 2>/dev/null
grep -h '^description:' .claude/agents/*.md 2>/dev/null
grep -h '^name:' .claude/agents/*.md 2>/dev/null
```

For each agent compute:
- `desc_chars` = character count of the `description:` value (strip surrounding quotes)
- `desc_tokens` = `desc_chars / 4` (rounded)
- `file_tokens` = `file_bytes / 4` (rounded)

### 2. Command cross-reference

```bash
grep -rh 'agent:' .claude/commands/ 2>/dev/null
grep -rl 'subagent_type' .claude/commands/ 2>/dev/null
grep -rh 'subagent_type' .claude/commands/ 2>/dev/null
grep -rh '@agents/' .claude/commands/ 2>/dev/null
```

Also search agent names (by slug) in all command bodies:
```bash
for agent in .claude/agents/*.md; do
  name=$(grep '^name:' "$agent" | head -1 | sed "s/name: *//;s/['\"]//g")
  count=$(grep -rl "$name" .claude/commands/ 2>/dev/null | wc -l)
  echo "$count $name"
done
```

Build:
- `referenced_agents` = agents named in any command file
- `unreferenced_agents` = agents present in `.claude/agents/` with zero command references

### 3. Learning log cross-reference (optional)

```bash
ls .claude/learning/sessions/*.jsonl 2>/dev/null | head -5
```

- If **no logs found**: note "Learning logs not found — cold agent detection skipped. Enable the learning logger hook, or logs will appear after sessions run."
- If **`mempalace.yaml` exists** in the project root: note it as an alternative memory source (do not parse it — different schema).
- If logs found:
  ```bash
  cat .claude/learning/sessions/*.jsonl 2>/dev/null
  ```
  Aggregate every agent name that ever appeared in any `agents_spawned` array.
  - `cold_agents` = filesystem agents whose name never appeared
  - `log_date_range` = min/max `date` values
  - `log_record_count` = total records
  - If `agents_spawned: []` in **all** records: flag as data gap ("logger may not capture Task-tool sub-agent spawns") — do NOT report all agents as cold.

### 4. Verbosity scan

```bash
grep -h '^description:' .claude/agents/*.md 2>/dev/null
```

Flag:
- **Verbose** = description > 200 chars (~50+ tokens) — inflates system prompt every session
- **Minimal** = description < 60 chars — may be too sparse for accurate agent selection

Rank all agents by `desc_chars` descending.

### 5. Tool scope scan

```bash
grep -h '^tools:' .claude/agents/*.md 2>/dev/null
grep -h '^name:\|^tools:' .claude/agents/*.md 2>/dev/null
```

Flag:
- Bare `Bash` with no parentheses (unscoped — can run any shell command)
- `MultiEdit` or `TodoWrite` on agents whose role is read-only (reviewer, researcher, reader agents)

### 6. Empty directory scan

```bash
find .claude/commands/ -mindepth 1 -maxdepth 1 -type d | while read d; do
  count=$(ls "$d"/*.md 2>/dev/null | wc -l)
  echo "$count $d"
done
```

Flag dirs where count = 0.

### 7. Token budget

Compute:
- `total_desc_tokens` = sum of all `desc_tokens` (loaded every session via system prompt)
- `unref_file_tokens` = sum of `file_tokens` for unreferenced agents
- `savings_archive` = `unref_file_tokens`
- `savings_compress` = `total_desc_tokens * 0.67` (assumes compression to ~100 chars avg)

### 8. Output report

```markdown
## /audit Report — <date>

### Token Budget Summary
| Category | Est. tokens | Notes |
|---|---|---|
| All agent descriptions | ~<N> | Loaded every session |
| Unreferenced agent files | ~<N> | Loaded every session, 0 commands reference them |
| Est. savings — archive unreferenced | ~<N>/session | |
| Est. savings — compress descriptions | ~<N>/session | Assumes 3× reduction |

### Unreferenced Agents
No command spawns these — they load into context but are never called:

| Agent | File | Est. tokens | Description (truncated) |
|---|---|---|---|
| <name> | <file> | ~<N> | <first 80 chars> |

Suggestion: archive to `.claude/agents/archive/` or add commands that surface them.

### Cold Agents (learning log cross-reference)
<results or skip notice>

### Verbose Descriptions (>200 chars)
| Agent | Chars | Est. tokens | Savings to 100 chars |
|---|---|---|---|
| <name> | <N> | ~<N> | ~<N> tok |

### Minimal Descriptions (<60 chars)
<list or "None found.">

### Tool Scope Issues
| Agent | Flag | Details |
|---|---|---|
| <name> | Unscoped Bash | Consider: Bash(cmd:*) restriction |
| <name> | MultiEdit on read-only agent | Review if write access is needed |

### Empty Command Directories
<list or "None found.">

### Recommendations (ranked by token impact)
1. **Archive <N> unreferenced agents** — saves ~<N> tok/session
   Run: `/optimize structural`

2. **Compress <N> verbose descriptions** — saves ~<N> tok/session
   Run: `/optimize` (or `/optimize descriptions`)

3. **Scope unscoped Bash on <N> agents** — security improvement
   Run: `/optimize structural` for instructions
```

Print "None found." for any empty section.

If `$ARGUMENTS` is `verbose`, include a full per-agent table with name, desc_chars, desc_tokens, file_tokens, and reference count.

## Notes

- Read-only — no files are modified.
- Token estimates: chars/4 approximation (±20% accuracy).
- Learning logs are optional infrastructure. `/audit` works fully without them.
- For skill trigger gaps use `/improve`. For multi-AI quality critique use `/self-improve`.
- To apply safe fixes run `/optimize`.
