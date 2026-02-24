# Claude Dev Kit

> A portable `.claude/` plugin that turns Claude Code into a fully autonomous development team — from epic grooming and sizing through validated, reviewed PRs.

Drop it into any project. Claude gains specialized agents, a full delivery pipeline, safety guardrails, and smart skill suggestions — all with zero vendor lock-in.

---

## What's Inside

```
.claude/
├── agents/                     # Specialized sub-agents (spawn automatically)
│   ├── system-architect        # Architecture design, ADRs, C4 diagrams         [opus]
│   ├── deep-think-partner      # Complex reasoning, trade-off analysis           [opus]
│   ├── documentation-manager   # Docs sync, README accuracy                     [sonnet]
│   ├── validation-gates        # Lint → test → build gates, iterative fixes     [sonnet]
│   └── haiku-executor          # Fast one-shot tasks in a clean sub-context     [haiku]
├── commands/                   # Slash commands for the dev pipeline
│   ├── dev-issue.md            # /dev-issue  — implement a GitHub issue E2E
│   ├── dev-epic.md             # /dev-epic   — implement all stories in an epic
│   ├── generate-prp.md         # /generate-prp — research + write an impl plan
│   ├── execute-prp.md          # /execute-prp  — execute a plan file
│   ├── fix-github-issue.md     # /fix-github-issue — quick fix for an issue
│   ├── think.md                # /think — meta-cognitive reasoning
│   ├── primer.md               # /primer — prime Claude with project context
│   ├── haiku.md                # /haiku — delegate to fast sub-context
│   ├── git/status.md           # /git:status — git state summary
│   ├── code/build-and-fix.md   # /code:build-and-fix — build + auto-fix
│   ├── code/simplify.md        # /code:simplify — refactor for clarity
│   └── bs/                     # /bs:* — multi-LLM brainstorming (7 models)
├── hooks/
│   ├── pre-tool-use/           # Blocks 25+ dangerous Bash patterns before exec
│   ├── stop/                   # Context monitor: warns at 65%, stops at 85%
│   └── skill-activation-prompt/# Suggests the right skill based on what you type
├── skills/
│   ├── build-and-fix/          # Auto-detect stack, build, fix lint/format
│   ├── code-investigator/      # Efficient codebase exploration (Serena-first)
│   └── verification-before-completion/  # Iron law: evidence before claims
└── settings.json               # Hook wiring + permission template
examples/
└── agents/                     # Ready-to-adapt stack-specific agents
    ├── nextjs-engineer.md      # Next.js 15/16 App Router, TypeScript, Tailwind
    ├── prisma-engineer.md      # Prisma ORM + PostgreSQL
    ├── stripe-engineer.md      # Stripe Payments SDK
    └── capacitor-engineer.md   # Capacitor iOS/Android mobile
scripts/
└── install.sh                  # One-command installer
```

---

## The Full Dev Flow

### Phase 1 — Epic Grooming & Sizing

Claude acts as your tech lead: reads GitHub milestones, sizes stories, and writes detailed implementation plans before a single line of code is written.

```
┌──────────────────────────────────────────────────────────┐
│  EPIC GROOMING                                           │
│                                                          │
│  1. /primer           Prime Claude with project context  │
│  2. /think <question> Decompose complexity, size effort  │
│  3. /generate-prp     Research + write PRP for a story   │
│  4. /bs:brainstorm_full Get 7 AI models to weigh in      │
└──────────────────────────────────────────────────────────┘
```

**`/think <sizing question>`**
Uses meta-cognitive decomposition with explicit confidence scores (0–1). If overall confidence < 0.8, it identifies the weakest assumption and iterates. Great for: "How complex is adding real-time notifications?" or "What are the risks of migrating to a new ORM?"

**`/generate-prp <feature-file>`**
Performs deep codebase + external research, then writes a PRP (Problem Resolution Plan) to `PRPs/<name>.md`. The PRP contains:
- Implementation tasks in order
- Pseudocode for critical paths
- Real code examples from your codebase
- External documentation URLs
- Validation gates (executable commands)
- Confidence score (1–10)

**`/bs:brainstorm_full <question>`**
Launches Claude, Gemini, GPT, Grok, GLM, MiniMax, and Kimi in parallel, then synthesizes: consensus, unique insights, contradictions, and a recommended action. Useful for hard architectural decisions.

---

### Phase 2 — Single Issue Implementation

```
/dev-issue 123
```

Claude runs the full pipeline autonomously:

```
┌─────────────────────────────────────────────────────────────┐
│  DEV ISSUE PIPELINE                           /dev-issue     │
│                                                             │
│  1. Read issue         gh issue view 123                    │
│  2. Create branch      feature/#123-<slug>                  │
│  3. Generate PRP       Research → write PRPs/<name>.md      │
│  4. Implement          Mirror codebase patterns             │
│     └── Write tests alongside code (not after)             │
│  5. Validate           All 5 gates must pass (see below)    │
│  6. Ship               Commit → push → gh pr create         │
│  7. Clean up           Delete PRP file, output PR URL       │
└─────────────────────────────────────────────────────────────┘
```

---

### Phase 3 — Epic Implementation (Multiple Stories)

```
/dev-epic
```

Designed to run inside the **ralph-loop** — each loop iteration delivers one story, commits it, and the loop continues until all stories in the epic are done. One branch, one PR for the whole epic.

```
┌─────────────────────────────────────────────────────────────────┐
│  DEV EPIC PIPELINE                             /dev-epic         │
│                                                                 │
│  Loop iteration N:                                              │
│  ├── Detect epic branch (or create epic/<slug>)                 │
│  ├── Find lowest unimplemented story in milestone               │
│  ├── Implement story (same as /dev-issue, no PR)                │
│  ├── Run all 5 validation gates                                 │
│  └── Commit: "feat: <description> (#<story-number>)"            │
│                                                                 │
│  Final iteration (all stories committed):                       │
│  └── Push branch → gh pr create with Closes #N for each story  │
└─────────────────────────────────────────────────────────────────┘
```

**Epic organization:** Stories are tracked as GitHub Issues grouped by Milestone. Claude picks the milestone whose lowest issue number is smallest (highest priority).

---

### Phase 4 — Validation Gates

Every commit — whether from `/dev-issue`, `/dev-epic`, or `/execute-prp` — must pass all 5 gates. **Claude will not commit if any gate fails.** It iterates on fixes until all pass.

```
Gate 1: Lint           Zero errors. Fix the code, don't disable rules.
Gate 2: Unit Tests     All pass. Coverage meets project threshold.
Gate 3: E2E Tests      Run if user-facing flows or API routes changed.
Gate 4: Static Analysis SonarQube / CodeClimate quality gate (if configured).
Gate 5: Build          Exit 0. No type errors. No compile failures.
```

The `validation-gates` agent is model-agnostic — it reads your `CLAUDE.md` to find the correct lint/test/build commands for your stack.

---

### Phase 5 — Code Review

Claude doesn't just write code — it also reviews it.

**Inline review via deep-think-partner:**
```
Use the deep-think-partner agent to review this PR diff for:
- Logic correctness
- Security vulnerabilities
- Performance regressions
- API contract changes
```

**Architecture review via system-architect:**
```
Use the system-architect agent to evaluate whether this design
follows clean architecture principles and identify any coupling risks.
```

**Multi-model review via brainstorm:**
```
/bs:brainstorm_full Should we use optimistic UI or server-confirmed state here?
```

---

## Install

### Quick install (copy to your project)

```bash
git clone https://github.com/yourusername/claude-dev-kit /tmp/claude-dev-kit
cd /your-project
bash /tmp/claude-dev-kit/scripts/install.sh
```

### Manual install

```bash
cp -r /tmp/claude-dev-kit/.claude /your-project/.claude
cd /your-project/.claude/hooks/skill-activation-prompt && npm install
```

### What gets copied

- `.claude/` — all agents, commands, hooks, skills, settings
- Nothing else — your project files are untouched

---

## Setup (3 steps)

### Step 1: Tell Claude about your stack

Create or update your `CLAUDE.md` with project-specific context:

```markdown
## Stack
- Framework: Next.js 15, TypeScript strict
- Database: PostgreSQL with Prisma
- Package manager: Bun

## Commands
- Lint: `bun lint`
- Test: `bunx jest --coverage`
- Build: `bun run build`

## Conventions
- Use dependency injection for external services
- Keep files under 500 lines
- Conventional commits: feat/fix/chore/docs
```

### Step 2: Add your stack's allowed commands to settings.json

Edit `.claude/settings.json` and add your project's commands to the `allow` list:

```json
"Bash(bun run:*)",
"Bash(bunx jest:*)",
"Bash(bun lint:*)",
"Bash(docker compose:*)"
```

### Step 3: (Optional) Add a stack-specific agent

Copy an example from `examples/agents/` into `.claude/agents/` and customize it. The examples cover:

| File | Stack |
|------|-------|
| `nextjs-engineer.md` | Next.js 15/16, React Server Components, TypeScript, Tailwind |
| `prisma-engineer.md` | Prisma ORM, PostgreSQL, migrations, seed scripts |
| `stripe-engineer.md` | Stripe Payments, webhooks, saved methods |
| `capacitor-engineer.md` | Capacitor iOS/Android, native plugins, static export |

For other stacks, create a new file in `.claude/agents/` following this template:

```markdown
---
name: your-stack-engineer
description: "Expert <stack> engineer for <project>. Use PROACTIVELY for: <trigger scenarios>."
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
color: green
---

You are a senior <stack> engineer working on <project>.

## Stack
- <technology> — <key details>

## Response Process
1. Read related files before writing
2. Mirror existing patterns
3. Write tests alongside implementation
```

---

## All Commands

| Command | Usage | What it does |
|---------|-------|--------------|
| `/primer` | `/primer` | Reads project structure + CLAUDE.md, explains back |
| `/think` | `/think Is this approach correct?` | Decompose → solve → verify → synthesize with confidence |
| `/generate-prp` | `/generate-prp PRPs/feature.md` | Research codebase + web, write implementation plan |
| `/execute-prp` | `/execute-prp PRPs/feature.md` | Execute a PRP with full unit + E2E + perf validation |
| `/dev-issue` | `/dev-issue 123` | Full pipeline: read issue → PRP → implement → validate → PR |
| `/dev-epic` | `/dev-epic` | All stories in highest-priority epic → one PR |
| `/fix-github-issue` | `/fix-github-issue 456` | Quick fix: read → implement → lint/test → PR |
| `/code:build-and-fix` | `/code:build-and-fix` | Auto-detect stack, build, fix lint/format |
| `/code:simplify` | `/code:simplify src/utils.ts` | Simplify code while preserving behavior |
| `/git:status` | `/git:status` | Current branch, diff vs origin, status summary |
| `/haiku` | `/haiku count lines in src/` | Fast one-shot task in clean Haiku sub-context |
| `/bs:brainstorm_full` | `/bs:brainstorm_full <question>` | 7 LLMs in parallel → synthesized recommendation |
| `/bs:claude` | `/bs:claude <question>` | Claude CLI in background |
| `/bs:gemini` | `/bs:gemini <question>` | Gemini CLI in background |

---

## All Agents

| Agent | Model | When to use |
|-------|-------|-------------|
| `system-architect` | opus | New features, architectural decisions, ADRs, C4 diagrams |
| `deep-think-partner` | opus | Complex reasoning, multi-step logic, trade-off analysis |
| `documentation-manager` | sonnet | After code changes — keeps docs in sync |
| `validation-gates` | sonnet | After implementation — runs all quality gates |
| `haiku-executor` | haiku | One-shot tasks: count, search, quick transforms |

Agents are invoked automatically by commands or explicitly: _"Use the system-architect agent to design the caching layer."_

---

## Skills (Auto-Suggested)

The `UserPromptSubmit` hook watches what you type and surfaces relevant skills:

| Skill | Triggered by | Purpose |
|-------|-------------|---------|
| `verification-before-completion` | done, complete, fixed, finished | Run verification before any completion claim |
| `code-investigator` | debug, trace, how does, investigate | Efficient targeted search (Serena-first, token-cheap) |
| `build-and-fix` | build, lint, compile, fix errors | Auto-detect stack, build, apply safe auto-fixes |

---

## Safety Hooks

### Block Dangerous Commands
Intercepts every `Bash` call and blocks at configurable safety levels:

| Level | Blocks |
|-------|--------|
| `critical` | `rm ~`, `rm -rf /`, `dd to disk`, fork bombs |
| `high` (default) | `curl \| sh`, force push to main, `git reset --hard`, `.env` reads, SSH key deletion |
| `strict` | Any force push, `sudo rm`, `docker prune`, `crontab -r` |

All blocks are logged to `~/.claude/hooks-logs/YYYY-MM-DD.jsonl`.

To change the safety level, edit `.claude/hooks/pre-tool-use/block-dangerous-commands.js`:
```js
const SAFETY_LEVEL = 'high'; // 'critical' | 'high' | 'strict'
```

### Context Monitor
Watches context window usage after every response:
- **65%** — Yellow warning: "Complete current task, wrap up soon"
- **85%** — Red stop: "Run /clear to reset context"

---

## PRP Format

A PRP (Problem Resolution Plan) is Claude's implementation blueprint. Generate one with `/generate-prp` or write it manually. Store in `PRPs/`.

```markdown
# Feature Name

## Problem
What needs to be built and why.

## Context
- Related files: `src/auth/login.ts`, `lib/jwt.ts`
- Existing pattern: see `src/users/create.ts`
- External docs: https://docs.example.com/api

## Implementation Tasks
- [ ] 1. Add schema migration
- [ ] 2. Implement service function with DI
- [ ] 3. Add route handler
- [ ] 4. Write unit tests (happy path + errors)
- [ ] 5. Write E2E test for the flow

## Pseudocode
...

## Validation Gates
\`\`\`bash
npm run lint
npm test -- --coverage --testPathPattern=auth
npm run build
\`\`\`

## Gotchas
- Library X has a known issue with Y in version Z
- Validate input before calling downstream API

## Confidence: 8/10
```

---

## Model Strategy

Models are chosen to balance cost and quality:

| Task | Model | Reasoning |
|------|-------|-----------|
| Architecture, deep reasoning | **Opus** | Trade-off analysis needs depth |
| Code generation, docs, testing | **Sonnet** | Domain knowledge > raw reasoning |
| Fast one-shot tasks | **Haiku** | Speed + cost for simple work |

This means the most frequently-called agents (coding specialists) run on Sonnet, keeping costs low without sacrificing output quality.

---

## Requirements

- **Claude Code** — [claude.ai/code](https://claude.ai/code)
- **GitHub CLI** (`gh`) — for issue/PR operations
- **Node.js or Bun** — for the skill-activation hook
- **Python 3** — for the context monitor hook
- **Project tooling** — your stack's lint/test/build commands (configured in `CLAUDE.md`)

### Optional (enhance investigation)
- **Serena MCP** — semantic code navigation (zero-cost symbol lookup)
- **Gemini CLI** — for `/bs:gemini` and large-codebase analysis

---

## FAQ

**Can I use this without GitHub?**
The core pipeline uses `gh` for issue reading and PR creation. You can skip `/dev-issue` and `/dev-epic` and use `/execute-prp` directly with manually written PRPs.

**Do I need all the example agents?**
No. Only the agents in `.claude/agents/` are active. `examples/agents/` are templates — copy what's relevant and delete the rest.

**Can I add my own agents?**
Yes. Create `.claude/agents/your-agent.md` with a YAML frontmatter block (name, description, tools, model, color) and a system prompt. Claude Code will discover it automatically.

**How do I customize validation gates?**
Edit `.claude/agents/validation-gates.md` — replace the command table in the instructions with your actual lint/test/build commands.

**What's the ralph-loop?**
A companion plugin that loops Claude Code automatically for multi-story epic delivery. `/dev-epic` is designed to work with it but also works as a one-shot command for a single story.

---

## Contributing

PRs welcome. To add a new example agent, follow the format in `examples/agents/`. To add a new hook, drop it in `.claude/hooks/<event>/` and wire it up in `settings.json`.
