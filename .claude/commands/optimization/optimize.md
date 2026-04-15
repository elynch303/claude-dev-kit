---
description: "Apply safe token optimizations to .claude/ agents. AI-rewrites verbose descriptions to ~100 chars. Prints manual instructions for archiving unreferenced agents and scoping tools. Requires confirmation before writing any file."
argument-hint: [descriptions | structural | all]
---

# /optimize — .claude Token Optimizer

Applies safe, reversible optimizations to reduce per-session token cost.

- **`descriptions`** (default) — AI-rewrites verbose `description:` fields to ~100 chars. Requires confirmation before any write.
- **`structural`** — prints manual instructions for archiving agents and scoping tools. No files written.
- **`all`** — both of the above.

**Write scope**: only the `description:` line in agent frontmatter. Agent bodies are never modified.
**Not in scope**: skill trigger gaps (use `/improve`), AI quality critique (use `/self-improve`).

## Steps

### 1. Determine mode

```
MODE = $ARGUMENTS  (default if empty: "descriptions")
```

### 2. Gather current state

Run these reads regardless of mode:

```bash
grep -h '^name:\|^description:\|^tools:' .claude/agents/*.md 2>/dev/null
wc -c .claude/agents/*.md 2>/dev/null
grep -rh 'agent:' .claude/commands/ 2>/dev/null
grep -rh '@agents/' .claude/commands/ 2>/dev/null
```

Identify:
- `verbose_agents` = agents with description > 200 chars
- `unreferenced_agents` = agents with 0 command references
- `unscoped_bash_agents` = agents where `tools:` contains bare `Bash` (no parentheses)

### 3. Description compression (if mode is `descriptions` or `all`)

For each agent in `verbose_agents`, generate a compressed description.

**Compression rules:**
- Target: 80–110 characters (20–28 tokens)
- Preserve: role, who invokes it (if a sub-agent), primary output artifact
- Remove: filler phrases ("Be sure to", "Always call", "Proactively"), redundant workflow step labels, over-specified minor behaviors
- Keep: spawn relationships ("Invoked by X only"), tool restrictions ("Never modifies files")

Show a diff-style preview for every agent before writing anything:

```
━━━ dev-lead.md ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Before: 341 chars (~85 tok)
  "Dev lead orchestrator (opus). Owns end-to-end implementation of a single
   GitHub issue. Reads the issue and PRP, classifies the work, spawns
   engineering sub-agents in sequence with narrow context, runs all 5
   validation gates, and ships. Never writes code directly — delegates to
   dev-backend, dev-frontend, dev-test, dev-e2e, and dev-reviewer."

  After:  102 chars (~26 tok)
  "Implements a GitHub issue end-to-end. Classifies work, spawns sub-agents
   with narrow context, runs 5 validation gates, ships PR."

  Savings: ~59 tokens
```

After showing all previews, ask:

> **Apply description rewrites?**
> - `all` — apply all <N> rewrites
> - `<name> <name> ...` — apply only listed agents (space-separated slugs)
> - `none` — skip

Wait for user response. If `none` or no response confirms, skip all writes.

For each approved agent:
1. Read the full agent file
2. Locate the `description:` line in the frontmatter (between the opening `---` and closing `---`)
3. Replace only that line with the new value (preserve all surrounding frontmatter and body)
4. Write the file back
5. Confirm: `✓ Updated .claude/agents/<name>.md — saved ~<N> tokens`

### 4. Structural instructions (if mode is `structural` or `all`)

Print the following as instructions — do NOT auto-execute any of these:

```markdown
## Structural Optimization Instructions

### Archive Unreferenced Agents
These agents load into every session but no command ever spawns them.
Moving to an archive directory removes them from the agent loader.

Files: <list unreferenced_agents>

Steps:
  mkdir -p .claude/agents/archive
  git mv .claude/agents/<name>.md .claude/agents/archive/
  # repeat for each
  git commit -m "chore: archive unreferenced agents"

Token savings: ~<N>/session (full file content no longer loaded)
Reversible: git mv .claude/agents/archive/<name>.md .claude/agents/

To surface them instead of archiving, create wrapper commands:
  .claude/commands/optimization/validate.md  → spawns validation-gates
  .claude/commands/optimization/architect.md → spawns system-architect
  .claude/commands/optimization/document.md  → spawns documentation-manager

### Scope Unscoped Bash Tools
Agents with bare Bash access (no parentheses). Restricting reduces blast radius:

<per-agent table: current tools → suggested scoped tools>

These require manual edits — read each agent body to confirm what shell
commands it actually needs before narrowing the scope.

### Clean Empty Command Directories
<list empty dirs>

Verify empty, then:
  rmdir .claude/commands/<dirname>/
```

### 5. Summary

```markdown
## Optimization Summary

Applied:
  - Description rewrites: <N> agents updated, ~<N> tokens saved/session
    (or "None applied — descriptions mode skipped or no changes confirmed")

Printed as instructions (not applied):
  - Archive <N> unreferenced agents (~<N> tok/session if completed)
  - Scope Bash on <N> agents (security improvement)
  - Clean <N> empty directories

Total potential:
  - Already applied: ~<N> tok/session
  - If structural steps completed: ~<N> additional tok/session
```

## Notes

- The only files this command writes are `.claude/agents/*.md` description lines.
- All writes are git-tracked — verify with `git diff .claude/agents/`.
- Structural changes (git mv, tools: edits) must be done manually.
- Learning logs are not required — optimization works from static file analysis alone.
- Run `/audit` first for the full profiling report before optimizing.
