---
description: "Smart project setup. Detects your stack and generates customized agents, CLAUDE.md, and settings.json. Or interviews you to design a new project from scratch. Run once when adding Claude Dev Kit to any project."
argument-hint: [existing | new]
---

# /init — Project Initialization

Set up Claude Dev Kit for this project. This command either detects an existing codebase and configures agents to match, or interviews you to design a new project from scratch.

## Phase 0: Determine Mode

```
If $ARGUMENTS is "new" → skip to Phase 3 (New Project Interview)
If $ARGUMENTS is "existing" → run Phase 1
Otherwise → auto-detect:
  Run: ls -la
  If fewer than 8 non-hidden files in root → likely new project → ask user
  If package.json / pyproject.toml / Cargo.toml / go.mod found → existing project
```

---

## Phase 1: File Inventory (Existing Projects)

Run these reads in parallel to build a complete picture of the project:

```bash
# Project manifest files
cat package.json 2>/dev/null || echo "NO_PACKAGE_JSON"
cat pyproject.toml 2>/dev/null || echo "NO_PYPROJECT"
cat Cargo.toml 2>/dev/null || echo "NO_CARGO"
cat go.mod 2>/dev/null || echo "NO_GO_MOD"

# Framework config
ls next.config.* nuxt.config.* svelte.config.* remix.config.* astro.config.* vite.config.* 2>/dev/null

# Database/ORM
ls prisma/schema.prisma drizzle.config.* 2>/dev/null

# Testing
ls jest.config.* vitest.config.* playwright.config.* cypress.config.* pytest.ini conftest.py 2>/dev/null

# Mobile
ls capacitor.config.ts app.json 2>/dev/null

# CI/CD
ls .github/workflows/ 2>/dev/null | head -5
ls Dockerfile docker-compose.yml 2>/dev/null

# Project structure (top-level only)
tree -L 2 --gitignore 2>/dev/null || find . -maxdepth 2 -not -path './.git/*' -not -path './node_modules/*' -not -path './.next/*' | sort
```

---

## Phase 2: Stack Detection

Analyze the inventory to produce a detection JSON. Use this decision tree — first match wins per category:

### Framework
| Detection | Result |
|-----------|--------|
| `"next"` in package.json deps | `nextjs` |
| `"@remix-run/node"` or `"@remix-run/serve"` | `remix` |
| `"@sveltejs/kit"` | `sveltekit` |
| `"nuxt"` | `nuxt` |
| `"@nestjs/core"` | `nestjs` |
| `"fastify"` | `fastify` |
| `"express"` | `express` |
| `"fastapi"` in pyproject deps | `fastapi` |
| `"django"` in pyproject deps | `django` |
| `"flask"` in pyproject deps | `flask` |
| go.mod exists + detect router from imports | `go` |
| Cargo.toml exists + detect crate from deps | `rust` |

### Package Manager
| Detection | Result |
|-----------|--------|
| `bun.lockb` exists | `bun` |
| `pnpm-lock.yaml` exists | `pnpm` |
| `yarn.lock` exists | `yarn` |
| `package-lock.json` exists | `npm` |
| `Pipfile.lock` / `poetry.lock` | `poetry` |

### ORM / Database Layer
| Detection | Result |
|-----------|--------|
| `prisma/schema.prisma` | `prisma` |
| `drizzle.config.*` | `drizzle` |
| `"mongoose"` in deps | `mongoose` |
| `"sqlalchemy"` in pyproject | `sqlalchemy` |
| `"django"` already detected | `django-orm` |
| `"gorm"` in go.mod | `gorm` |
| `"sqlx"` in Cargo.toml | `sqlx` |

### Test Runner
| Detection | Result |
|-----------|--------|
| `jest.config.*` | `jest` |
| `vitest.config.*` | `vitest` |
| `pytest.ini` or `conftest.py` | `pytest` |
| `cargo test` (Rust) | `cargo-test` |
| `go test` (Go) | `go-test` |

### E2E
| Detection | Result |
|-----------|--------|
| `playwright.config.*` | `playwright` |
| `cypress.config.*` | `cypress` |

### Mobile
| Detection | Result |
|-----------|--------|
| `capacitor.config.ts` | `capacitor` |
| `app.json` with `"expo"` key | `expo` |

### Ambiguous / Large Codebase Fallback
If the framework is not detectable from manifest files, use Gemini:
```bash
gemini -p "@./ Identify the web framework, ORM/database layer, test runner, E2E tool, and mobile platform used in this project. Respond in exactly this format:
FRAMEWORK: <name>
ORM: <name or none>
TEST_RUNNER: <name or none>
E2E: <name or none>
MOBILE: <name or none>
PACKAGE_MANAGER: <name>"
```

---

## Phase 3: New Project Interview

Ask these questions sequentially using the AskUserQuestion tool. Wait for each answer before asking the next.

**Q1**: What are you building?
- A web application
- A mobile app (iOS/Android)
- A REST/GraphQL API
- A full-stack platform (web + mobile + API)
- Something else

**Q2**: Describe your idea in 2-3 sentences (free text — ask this as plain text, not multiple choice)

**Q3**: Expected scale and usage?
- Personal / hobby project
- Small team startup (< 50 users initially)
- Production SaaS (100s–1000s of users)
- Enterprise / high-scale

**Q4**: What language ecosystem do you prefer?
- TypeScript / JavaScript
- Python
- Go
- Rust
- Undecided — recommend for me

**Q5** (if TypeScript): Which framework?
- Next.js (full-stack, server + client)
- Remix (full-stack, web standards)
- SvelteKit (full-stack, lightweight)
- Nuxt (full-stack, Vue)
- Express / Fastify (API-only, no frontend)
- NestJS (enterprise API)
- Undecided — recommend for me

**Q6** (if TypeScript/fullstack): Database?
- PostgreSQL with Prisma ORM
- PostgreSQL with Drizzle ORM
- MongoDB with Mongoose
- SQLite (local / edge)
- Undecided — recommend for me

**Q7**: Authentication needed?
- Yes — Auth.js / NextAuth (for Next.js)
- Yes — BetterAuth (framework-agnostic)
- Yes — Clerk (managed service)
- Yes — Custom JWT
- No authentication needed

**Q8**: Payments?
- Stripe
- Other payment provider
- No payments needed

**Q9**: Mobile app?
- Yes — Capacitor (wrap web app for iOS/Android)
- Yes — Expo (React Native)
- No mobile needed

**Q10**: Testing approach?
- Full coverage: unit tests + E2E + coverage enforcement
- Unit tests only
- Minimal (lint + build only)

Build the stack map from answers. For "Undecided — recommend for me" answers, apply these defaults:
- TypeScript + small/medium scale + web → Next.js + Prisma + PostgreSQL
- TypeScript + API-only → Fastify + Drizzle
- Python → FastAPI + SQLAlchemy
- Go → Gin + GORM

---

## Phase 4: Read Stack Templates

Based on the detection result, read the matching templates from `.claude/templates/`:

```
Primary template:  .claude/templates/stacks/<framework>-<orm>.md
                   (or .claude/templates/stacks/<framework>.md if no ORM)
Test template:     .claude/templates/test-runners/<test-runner>.md
E2E template:      .claude/templates/test-runners/<e2e-runner>.md  (if applicable)
Mobile template:   .claude/templates/mobile/<mobile>.md            (if applicable)
Fallback:          .claude/templates/stacks/generic.md
```

Extract from each template:
- `BACKEND_AGENT_BODY` section → replaces body in `.claude/agents/dev-backend.md`
- `FRONTEND_AGENT_BODY` section → replaces body in `.claude/agents/dev-frontend.md`
- `TEST_AGENT_BODY` section → replaces body in `.claude/agents/dev-test.md`
- `E2E_AGENT_BODY` section → replaces body in `.claude/agents/dev-e2e.md`
- `LINT_CMD`, `TEST_CMD`, `BUILD_CMD`, `E2E_CMD` → used in CLAUDE.md + settings.json

---

## Phase 5: Generate Files

### 5a. Update engineering agents

For each agent: preserve the YAML frontmatter exactly. Replace everything after the closing `---` with the stack-specific body from the template.

Files to update:
- `.claude/agents/dev-backend.md`
- `.claude/agents/dev-frontend.md`
- `.claude/agents/dev-test.md`
- `.claude/agents/dev-e2e.md`

### 5b. Generate or update CLAUDE.md

**If CLAUDE.md exists:** Preserve content outside `<!-- CDK:START -->` / `<!-- CDK:END -->` fences. Only replace the fenced section.

**If new:** Generate the full file using `.claude/templates/claude-md-template.md` as the structure.

**Content to populate:**
- Project name from `package.json` `name` field (or ask for new projects)
- Stack summary
- Dev commands table (extracted from `package.json` `scripts` or language conventions)
- Validation gate commands

### 5c. Update .claude/settings.json

Read existing settings.json. Preserve the `hooks` section verbatim. Replace only the `permissions.allow` array with:

**Always include:**
```json
"Read", "Write", "Edit",
"Bash(gh:*)", "Bash(git:*)", "Bash(ls:*)", "Bash(grep:*)", "Bash(tree:*)",
"Bash(gemini:*)", "Bash(gemini -p:*)"
```

**Per package manager:**
- bun → `"Bash(bun:*)"`, `"Bash(bunx:*)"`
- npm → `"Bash(npm run:*)"`, `"Bash(npx:*)"`
- pnpm → `"Bash(pnpm:*)"`, `"Bash(pnpm dlx:*)"`
- yarn → `"Bash(yarn:*)"`
- poetry → `"Bash(poetry:*)"`, `"Bash(python:*)"`
- go → `"Bash(go:*)"`
- cargo → `"Bash(cargo:*)"`

**Per tools:**
- Docker present → `"Bash(docker:*)"`, `"Bash(docker compose:*)"`
- Playwright → `"Bash(npx playwright:*)"` or `"Bash(bunx playwright:*)"`

---

## Phase 6: Completion Report

```markdown
## /init Complete ✅

### Detected / Configured Stack
| Component | Value |
|-----------|-------|
| Framework | Next.js 15 (App Router) |
| ORM | Prisma 7 + PostgreSQL |
| Package manager | Bun |
| Test runner | Jest |
| E2E | Playwright |
| Mobile | Capacitor |

### Files Generated/Updated
- `.claude/agents/dev-backend.md` — Next.js + Prisma patterns
- `.claude/agents/dev-frontend.md` — Next.js App Router + Tailwind patterns
- `.claude/agents/dev-test.md` — Jest + Bun + DI mock patterns
- `.claude/agents/dev-e2e.md` — Playwright patterns
- `CLAUDE.md` — project guide created/updated
- `.claude/settings.json` — permissions updated

### Next Steps
1. **Review** `CLAUDE.md` and add any project-specific conventions
2. **Run** `/primer` to verify Claude understands the project
3. **Plan** your backlog: `/pm:groom` → `/pm:size` → `/pm:plan-epic`
4. **Build**: `/dev <issue-number>` to implement your first feature
```

---

## Important Notes

- `/init` is safe to re-run — it preserves manual customizations in CLAUDE.md (outside CDK fences) and preserves all hooks in settings.json
- After a major stack change (e.g., adding a new ORM), re-run `/init` to refresh the engineering agents
- The `project-manager` and `dev-lead` orchestrators are stack-agnostic — they are never modified by `/init`
