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

### 5c. Generate CLAUDE.local.md.example

If `CLAUDE.local.md.example` does not already exist in the project root, copy `.claude/templates/CLAUDE.local.md.example` (or generate the standard template) so developers know they can create a personal `CLAUDE.local.md`.

Also ensure `.gitignore` (or `.git/info/exclude` for projects without a shared `.gitignore`) contains `CLAUDE.local.md`.

### 5d. Scaffold stack-specific rules overrides

Check if `.claude/rules/` already exists. If not present, note to the user that the generic rules installed with CDK cover universal patterns. If a stack-specific rules file would add value (e.g., a `db-conventions.md` for Prisma schema practices, or a `components.md` for Next.js component hierarchy), generate it now:

**Next.js + Prisma projects** — create `.claude/rules/db-conventions.md`:
```markdown
---
globs: "prisma/**,app/generated/**,lib/db*"
---

# Database Conventions (Prisma)

- Schema lives at `prisma/schema.prisma` — all model changes start here
- Run `bun prisma migrate dev` to generate migrations from schema changes
- Never edit generated migration files — re-generate if incorrect
- Use `prisma.model.findFirst` for conflict checks — not `findUnique` on non-unique fields
- Always call `db.refresh(obj)` / re-query after mutations to return updated state
- Prisma client is a singleton — import from `lib/db`, never instantiate directly
- Use `select` / `include` to fetch only the fields the caller needs
```

**FastAPI + SQLAlchemy projects** — create `.claude/rules/db-conventions.md`:
```markdown
---
globs: "app/models/**,app/schemas/**,alembic/**"
---

# Database Conventions (SQLAlchemy 2.x)

- Models at `app/models/<domain>.py` — use `mapped_column` and `Mapped[T]` for all columns
- Schemas at `app/schemas/<domain>.py` — separate `Create`, `Update`, `Out` Pydantic models
- Migrations via Alembic — never edit the DB schema directly in production
- Use `AsyncSession` throughout — never use synchronous session in async endpoints
- Always `await db.refresh(obj)` after commit to return accurate data to the caller
- Use SQLAlchemy 2.x `select()` / `insert()` — no raw SQL unless absolutely necessary
```

**Express.js projects** — create `.claude/rules/db-conventions.md` if an ORM is detected, following the same pattern.

Skip this step if stack is `generic` or no database layer was detected.

### 5e. Update .claude/settings.json

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
- `.claude/rules/code-style.md` — universal code quality rules (all files)
- `.claude/rules/security.md` — universal security practices (all files)
- `.claude/rules/api-conventions.md` — HTTP/REST conventions (api/** files, path-scoped)
- `.claude/rules/testing.md` — test structure and coverage rules (test files, path-scoped)
- `.claude/rules/db-conventions.md` — database/ORM conventions (stack-specific, if applicable)
- `CLAUDE.local.md.example` — personal override template (copy to `CLAUDE.local.md`)

### Next Steps
1. **Personal setup**: Copy `CLAUDE.local.md.example` → `CLAUDE.local.md` and fill in your preferences (it's gitignored)
2. **Review** `CLAUDE.md` and add any project-specific notes in the Project Notes section
3. **Customize rules**: Edit `.claude/rules/*.md` files for project-specific conventions
4. **Run** `/primer` to verify Claude understands the project
5. **Plan** your backlog: `/pm:groom` → `/pm:size` → `/pm:plan-epic`
6. **Build**: `/dev <issue-number>` to implement your first feature
```

---

## Important Notes

- `/init` is safe to re-run — it preserves manual customizations in CLAUDE.md (outside CDK fences) and preserves all hooks in settings.json
- After a major stack change (e.g., adding a new ORM), re-run `/init` to refresh the engineering agents
- The `project-manager` and `dev-lead` orchestrators are stack-agnostic — they are never modified by `/init`
