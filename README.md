# Claude Dev Kit

> A portable `.claude/` plugin that turns Claude Code into a fully autonomous development team — from epic grooming through validated, reviewed PRs — on **any project, any stack**.

Drop it into a project and run `bash install.sh`. Claude gains two orchestrator agents, a full specialist sub-agent hierarchy, an MCP integration wizard, smart stack detection, and a complete delivery pipeline.

---

## Architecture

```
YOU
 │
 ├── /pm:groom / /pm:size / /pm:plan-epic
 │    └── project-manager [opus] ─────── orchestrates planning
 │         ├── pm-groomer   [sonnet]  ← writes acceptance criteria, DoD, sub-tasks
 │         ├── pm-sizer     [sonnet]  ← t-shirt sizes, confidence scores, sprint plans
 │         └── pm-prp-writer[sonnet]  ← deep-research → PRP documents
 │
 └── /dev <issue> / /dev-issue / /dev-epic
      └── dev-lead [opus] ──────────── orchestrates implementation
           ├── dev-backend  [sonnet]  ← API routes, services, DB, auth
           ├── dev-frontend [sonnet]  ← components, pages, state, styling
           ├── dev-test     [sonnet]  ← unit tests, mocks, coverage
           ├── dev-e2e      [sonnet]  ← Playwright/Cypress user journeys
           └── dev-reviewer [sonnet]  ← security, correctness, pattern review
```

**Key principle**: Each sub-agent runs in a **clean context window** with only the specific files and facts it needs. Orchestrators trim context before every spawn — no sub-agent ever sees the full conversation history. This keeps context usage low and output quality high.

---

## The Full Dev Flow

### Phase 1 — Epic Grooming & Sizing

```
/pm:plan-epic "User Authentication"
```

Claude acts as your tech lead:

```
project-manager
 ├── Fetch all open issues in the milestone
 ├── pm-groomer: Rewrites each issue with Given/When/Then criteria + DoD
 ├── pm-sizer: Scores each story (scope, novelty, risk, test burden, deps)
 │   └── Returns sprint plan + confidence scores
 └── pm-prp-writer: Writes detailed PRP for each L/XL story
     └── Deep codebase scan (Gemini for large repos) + web research
```

You confirm each step before GitHub is updated.

---

### Phase 2 — Feature Implementation

```
/dev 142
```

Claude acts as your senior engineer + code reviewer:

```
dev-lead
 ├── Reads issue + PRP
 ├── Classifies work: backend-only / frontend-only / fullstack
 ├── [fullstack path]
 │   ├── dev-backend:  implements API routes + service layer
 │   ├── dev-frontend: implements UI (receives API contracts from backend)
 │   ├── dev-test:     writes unit tests (90%+ branch coverage)
 │   ├── dev-e2e:      writes Playwright tests for user journeys
 │   └── dev-reviewer: structured PASS/FAIL review (security, correctness, types)
 ├── Runs all 5 validation gates
 └── Commits + creates PR with "Closes #142"
```

---

### Phase 3 — Validation Gates

Every implementation runs all 5 gates in sequence. **Claude will not commit if any gate fails** — it re-spawns the responsible sub-agent with the error output and iterates.

| Gate | What runs | Requirement |
|------|-----------|------------|
| 1 | Lint | Zero errors — fix the code, not the rule |
| 2 | Unit tests + coverage | All pass, threshold met (90% branch by default) |
| 3 | E2E tests | All pass (when user flows changed) |
| 4 | Static analysis | Quality gate pass (SonarQube/CodeClimate if configured) |
| 5 | Build / type check | Exit 0, zero type errors |

---

### Phase 4 — Code Review

Every implementation ends with `dev-reviewer` checking:

- **Security**: injection, auth gaps, hardcoded secrets, CSRF
- **Correctness**: each acceptance criterion satisfied
- **Pattern adherence**: mirrors existing codebase conventions
- **Type safety**: no `any`, nullability handled
- **Test quality**: error paths covered, behavior tested
- **File hygiene**: no `.env`, no debug logs, files under 500 lines

`FAIL` with BLOCKERs → responsible sub-agent re-spawns to fix → re-review.
`PASS` (or warnings only) → commits and creates PR.

---

## Install

### Quick start

```bash
git clone https://github.com/yourusername/claude-dev-kit /tmp/cdk
bash /tmp/cdk/scripts/install.sh /path/to/your/project
```

### What the installer does

**Phase 1 — File install:**
- Copies `.claude/` into your project
- Installs hook dependencies (skill-activation-prompt)
- Backs up any existing `.claude/` first

**Phase 2 — MCP wizard (interactive prompts):**

The installer asks about your toolchain and automatically configures the right Claude MCP integrations:

```
Git Platform
  ❯ GitHub         → installs @modelcontextprotocol/server-github
    GitLab          → installs @modelcontextprotocol/server-gitlab
    Bitbucket       → (manual — no official MCP yet)
    Azure DevOps    → (manual)
    None

Ticket System
  ❯ GitHub Issues  → uses GitHub MCP (already installed)
    Linear          → installs @linear/mcp-server
    Jira            → installs @modelcontextprotocol/server-jira
    Notion          → installs @modelcontextprotocol/server-notion
    Trello          → (manual)
    None

Design Tools
    Figma           → installs figma-developer-mcp
    Storybook       → (Claude uses browser tools to access)
    None

Core MCPs (prompted individually)
    Context7        → up-to-date library documentation
    Sequential Thinking → improved multi-step reasoning
    Filesystem      → direct file access
    Serena          → semantic code navigation (requires Python/uv)
```

All MCPs are installed with `--scope project` — they activate only in this project, not globally.

### MCP-only install (add integrations to existing project)

```bash
bash /path/to/install.sh --mcp-only
```

### Requirements

| Dependency | Purpose | Required? |
|-----------|---------|-----------|
| **Claude Code CLI** | `claude mcp add` for MCP setup | For MCP wizard |
| **Node.js or Bun** | Skill-activation hook | Yes |
| **Python 3** | Context monitor hook | Yes |
| **GitHub CLI** (`gh`) | Issue/PR operations in pipeline | For `/dev` commands |
| **Gemini CLI** | Large codebase analysis | Recommended |
| **uv / uvx** | Serena MCP | For Serena only |

---

## Setup (3 steps after install)

### Step 1: Run `/init` in Claude Code

```
/init
```

This command auto-detects your stack and configures all engineering agents to match. It handles:

- **Existing projects**: scans `package.json`, `pyproject.toml`, `go.mod`, etc. → detects framework, ORM, test runner, E2E tool → generates stack-specific agents
- **New projects**: asks 10 questions about your idea (platform, scale, stack) → generates everything from scratch

Supported stacks: Next.js + Prisma, Next.js + Drizzle, Remix, SvelteKit, Nuxt, Express, Fastify, NestJS, FastAPI, Django, Flask, Go, Rust, and more.

### Step 2: Review CLAUDE.md

`/init` generates `CLAUDE.md` with your stack, commands, and conventions. Review it and add anything project-specific in the `## Project Notes` section at the bottom. `/init` will never touch that section.

### Step 3: Prime Claude's context

```
/primer
```

Reads the project structure and CLAUDE.md, so Claude understands the project before you ask it to do anything.

---

## All Commands

### Planning
| Command | What it does |
|---------|-------------|
| `/pm` | Project manager: assess and act on the backlog |
| `/pm:groom [issue \| milestone]` | Rewrite issues with AC, DoD, sub-tasks |
| `/pm:size [milestone \| issues]` | T-shirt size + sprint plan |
| `/pm:plan-epic <milestone>` | Full pipeline: groom → size → PRPs |
| `/generate-prp <file>` | Research + write a PRP manually |
| `/execute-prp <file>` | Execute a PRP with full validation |
| `/think <question>` | Meta-cognitive reasoning with confidence scores |
| `/bs:brainstorm_full <question>` | 7 AI models in parallel → synthesized recommendation |

### Implementation
| Command | What it does |
|---------|-------------|
| `/init [existing \| new]` | Smart setup — detect stack or interview for new project |
| `/dev <issue>` | Full autonomous pipeline: classify → sub-agents → validate → PR |
| `/dev-issue <issue>` | Equivalent to `/dev` |
| `/dev-epic` | All stories in highest-priority epic → one PR |
| `/dev:backend <task>` | Backend work only |
| `/dev:frontend <task>` | Frontend work only |
| `/dev:test <files>` | Write tests for specific files |
| `/dev:e2e <flow>` | Write E2E tests for a flow |
| `/dev:review` | Code review of current branch |
| `/fix-github-issue <N>` | Quick fix: read → implement → PR |

### Utilities
| Command | What it does |
|---------|-------------|
| `/primer` | Prime context: read project structure + CLAUDE.md |
| `/code:build-and-fix` | Build and auto-fix lint/format errors |
| `/code:simplify [files]` | Refactor for clarity |
| `/git:status` | Current branch, diff, status |
| `/haiku <task>` | Fast one-shot task in clean Haiku sub-context |

---

## All Agents

| Agent | Model | Role |
|-------|-------|------|
| `project-manager` | opus | Planning orchestrator — grooms, sizes, PRPs |
| `dev-lead` | opus | Dev orchestrator — implements, validates, ships |
| `pm-groomer` | sonnet | Writes AC, DoD, sub-tasks for issues |
| `pm-sizer` | sonnet | T-shirt sizes, confidence scores, sprint plans |
| `pm-prp-writer` | sonnet | Deep research + PRP authoring |
| `dev-backend` | sonnet | API routes, services, DB, auth *(stack-specific after /init)* |
| `dev-frontend` | sonnet | Components, pages, state *(stack-specific after /init)* |
| `dev-test` | sonnet | Unit tests, mocks, coverage *(stack-specific after /init)* |
| `dev-e2e` | sonnet | E2E tests *(stack-specific after /init)* |
| `dev-reviewer` | sonnet | Security, correctness, pattern, type safety review |
| `system-architect` | opus | Architecture design, ADRs, C4 diagrams |
| `deep-think-partner` | opus | Complex reasoning, trade-off analysis |
| `documentation-manager` | sonnet | Docs sync after code changes |
| `validation-gates` | sonnet | Quality gate runner (standalone use) |
| `haiku-executor` | haiku | Fast one-shot tasks |

---

## Skills (Auto-Suggested)

The `UserPromptSubmit` hook suggests relevant skills based on keywords:

| Skill | Triggered by | Purpose |
|-------|-------------|---------|
| `verification-before-completion` | done, complete, fixed | Run verification before claiming done |
| `code-investigator` | debug, trace, how does, investigate | Serena-first targeted search |
| `build-and-fix` | build, lint, compile, fix errors | Auto-fix simple build errors |
| `stack-detector` | Used internally by /init | Detect project stack |

---

## Safety Hooks

| Hook | What it does |
|------|-------------|
| **Block Dangerous Commands** | Intercepts Bash calls — blocks rm ~, force push main, git reset --hard, .env reads, etc. (configurable: critical/high/strict) |
| **Context Monitor** | Warns at 65% context, stops at 85% — instructs to `/clear` |
| **Skill Suggester** | Watches your prompts — surfaces the right skill at the right time |

---

## Model Strategy

| Task type | Model | Why |
|-----------|-------|-----|
| Orchestration, architecture, deep reasoning | **Opus** | Trade-off analysis, coordination |
| Code generation, testing, reviews | **Sonnet** | Excellent at code; domain knowledge in system prompt matters more than raw reasoning |
| Fast one-shot tasks | **Haiku** | Speed + cost for simple work |

The 5 code-specialist sub-agents run on Sonnet. Orchestrators run on Opus. This keeps costs low while maintaining quality where it matters.

---

## Adding a Stack Agent

Copy from `examples/agents/` and customize:

```bash
cp examples/agents/nextjs-engineer.md .claude/agents/my-stack-engineer.md
```

Or add a new stack template to `.claude/templates/stacks/my-stack.md` and re-run `/init`.

---

## Re-initializing

Run `/init` again after:
- Changing your framework or ORM
- Adding a new test runner or E2E tool
- Switching package managers

It safely preserves manual edits in `CLAUDE.md` (outside the CDK fences) and never overwrites your hooks in `settings.json`.

---

## Contributing

PRs welcome. To add support for a new stack:
1. Add `.claude/templates/stacks/<framework>-<orm>.md` with `BACKEND_AGENT_BODY`, `FRONTEND_AGENT_BODY`, `TEST_AGENT_BODY`, `E2E_AGENT_BODY` sections
2. Add detection logic to `.claude/skills/stack-detector/SKILL.md`
3. Add an example to `examples/agents/`
