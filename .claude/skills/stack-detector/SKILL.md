---
version: 1.0.0
name: stack-detector
description: Detects the technology stack of a project by analyzing manifest files and dependencies. Returns a structured stack map JSON. Used by /init and other commands that need stack awareness.
---

# Stack Detector

**Notification:** Output "Detecting project stack..." at skill start.

## Purpose
Identify the complete technology stack from project files without running any code. Return a structured JSON object for use by other commands.

## Detection Steps

### Step 1: Read manifest files (in parallel)
```bash
cat package.json 2>/dev/null
cat pyproject.toml 2>/dev/null
cat Cargo.toml 2>/dev/null
cat go.mod 2>/dev/null
ls prisma/ drizzle.config.* jest.config.* vitest.config.* playwright.config.* cypress.config.* capacitor.config.ts app.json 2>/dev/null
```

### Step 2: Detect package manager
| File present | Manager |
|-------------|---------|
| `bun.lockb` | `bun` |
| `pnpm-lock.yaml` | `pnpm` |
| `yarn.lock` | `yarn` |
| `package-lock.json` | `npm` |
| `poetry.lock` | `poetry` |
| `Pipfile.lock` | `pipenv` |

### Step 3: Detect framework (first match wins)
From package.json dependencies/devDependencies:
- `"next"` → `nextjs`
- `"@remix-run/node"` or `"@remix-run/serve"` → `remix`
- `"@sveltejs/kit"` → `sveltekit`
- `"nuxt"` → `nuxt`
- `"@nestjs/core"` → `nestjs`
- `"fastify"` → `fastify`
- `"express"` → `express`

From pyproject.toml:
- `"fastapi"` → `fastapi`
- `"django"` → `django`
- `"flask"` → `flask`

From go.mod: `go`
From Cargo.toml: `rust`

### Step 4: Detect ORM
- `prisma/schema.prisma` exists → `prisma`
- `drizzle.config.*` exists → `drizzle`
- `"mongoose"` in deps → `mongoose`
- `"sqlalchemy"` in pyproject → `sqlalchemy`
- framework is `django` → `django-orm`
- `"gorm"` in go.mod → `gorm`
- `"sqlx"` in Cargo.toml → `sqlx`

### Step 5: Detect test runner
- `jest.config.*` → `jest`
- `vitest.config.*` → `vitest`
- `pytest.ini` or `conftest.py` → `pytest`
- Rust → `cargo-test`
- Go → `go-test`

### Step 6: Detect E2E runner
- `playwright.config.*` → `playwright`
- `cypress.config.*` → `cypress`

### Step 7: Detect mobile
- `capacitor.config.ts` → `capacitor`
- `app.json` with `"expo"` key → `expo`

### Fallback: Gemini scan
If framework is still unknown after all above steps:
```bash
gemini -p "@./ What framework, ORM, test runner, and E2E tool is this project using? Reply in format: FRAMEWORK:x ORM:x TEST:x E2E:x MOBILE:x"
```

## Output Format

```json
{
  "framework": "nextjs",
  "frameworkVersion": "15",
  "language": "typescript",
  "packageManager": "bun",
  "orm": "prisma",
  "testRunner": "jest",
  "e2eRunner": "playwright",
  "mobile": "capacitor",
  "templateKey": "nextjs-prisma",
  "commands": {
    "dev": "bun run dev",
    "lint": "bun lint",
    "test": "bunx jest --coverage",
    "e2e": "bunx playwright test",
    "build": "bun run build"
  }
}
```

The `templateKey` is `<framework>-<orm>` (or just `<framework>` if no ORM), used to look up `.claude/templates/stacks/<templateKey>.md`. If no matching template exists, use `generic`.

## Commands Derivation

Extract from `package.json` `scripts` where possible. Fallback defaults:

| Framework | Lint | Test | Build |
|-----------|------|------|-------|
| nextjs | `bun lint` / `npm run lint` | `bunx jest --coverage` | `bun run build` |
| fastapi | `ruff check . && mypy .` | `pytest --cov` | `echo ok` |
| django | `ruff check .` | `pytest --cov` | `python manage.py check` |
| express | `npm run lint` | `npm test` | `npm run build` |
| go | `golangci-lint run` | `go test ./... -cover` | `go build ./...` |
| rust | `cargo clippy` | `cargo test` | `cargo build` |
