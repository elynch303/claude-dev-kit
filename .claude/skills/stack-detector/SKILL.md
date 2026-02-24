---
version: 1.1.0
name: stack-detector
description: Detects the technology stack of a project by analyzing manifest files and dependencies. Returns a structured stack map JSON. Used by /init and other commands that need stack awareness.
---

# Stack Detector

**Notification:** Output "Detecting project stack..." at skill start.

## Purpose
Identify the complete technology stack from project files without running any code. Return a structured JSON object for use by other commands.

## Detection Steps

### Step 1: Read manifest files (in parallel)
Use the Read tool (not bash cat) to read these files — avoids shell injection with unusual paths:
- `package.json`
- `pyproject.toml`
- `Cargo.toml`
- `go.mod`
- `deno.json` or `deno.jsonc`
- `astro.config.*`

Also check presence of these config files:
```
prisma/schema.prisma  drizzle.config.*  jest.config.*  vitest.config.*
playwright.config.*   cypress.config.*  capacitor.config.ts  app.json
deno.json  deno.jsonc  astro.config.mjs  astro.config.ts
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
| `deno.json` or `deno.jsonc` | `deno` |

### Step 3: Detect framework (first match wins)

**Special case — Deno:** If `deno.json` or `deno.jsonc` exists, set `framework: "deno"` immediately and skip remaining JS detection.

From package.json dependencies/devDependencies:
- `"next"` → `nextjs`
- `"@remix-run/node"` or `"@remix-run/serve"` → `remix`
- `"@sveltejs/kit"` → `sveltekit`
- `"nuxt"` → `nuxt`
- `"@nestjs/core"` → `nestjs`
- `"fastify"` → `fastify`
- `"express"` → `express`
- `"astro"` → `astro`
- `"solid-js"` or `"@solidjs/start"` → `solidjs`

From pyproject.toml:
- `"fastapi"` → `fastapi`
- `"django"` → `django`
- `"flask"` → `flask`

From go.mod: `go`
From Cargo.toml: `rust`

### Step 4: Detect Next.js router variant (important — different templates)
If framework is `nextjs`:
- Check if `app/` directory exists AND contains `layout.tsx` or `layout.js` → `routerVariant: "app"`
- Otherwise if `pages/` directory exists → `routerVariant: "pages"`
- Default to `"app"` (Next.js 13+ default)

This affects the templateKey: `nextjs-prisma-app` vs `nextjs-prisma-pages`.

### Step 5: Detect ORM
- `prisma/schema.prisma` exists → `prisma`
- `drizzle.config.*` exists → `drizzle`
- `"mongoose"` in deps → `mongoose`
- `"sqlalchemy"` in pyproject → `sqlalchemy`
- framework is `django` → `django-orm`
- `"gorm"` in go.mod → `gorm`
- `"sqlx"` in Cargo.toml → `sqlx`

### Step 6: Detect test runner
- `jest.config.*` → `jest`
- `vitest.config.*` → `vitest`
- `pytest.ini` or `conftest.py` → `pytest`
- Rust → `cargo-test`
- Go → `go-test`
- Deno → `deno-test`

### Step 7: Detect E2E runner
- `playwright.config.*` → `playwright`
- `cypress.config.*` → `cypress`

### Step 8: Detect mobile
- `capacitor.config.ts` → `capacitor`
- `app.json` with `"expo"` key → `expo`

### Fallback: Gemini scan
If framework is still unknown after all above steps AND Gemini CLI is available:
```bash
# Use the Read tool to get the current directory path first, then construct the command safely
# IMPORTANT: always double-quote the path in the @ reference to handle spaces and special chars
gemini -p "@'./' What framework, ORM, test runner, and E2E tool is this project using? Reply in format: FRAMEWORK:x ORM:x TEST:x E2E:x MOBILE:x"
```

If `gemini` is not available, fall back to grep-based analysis:
```bash
grep -r "import\|require\|from" src/ app/ lib/ --include="*.ts" --include="*.js" --include="*.py" -l 2>/dev/null | head -10
```
Read 2-3 of those files and infer the framework from import patterns.

## Output Format

```json
{
  "framework": "nextjs",
  "frameworkVersion": "15",
  "routerVariant": "app",
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
| astro | `npm run lint` | `npm test` | `npm run build` |
| solidjs | `npm run lint` | `npm test` | `npm run build` |
| deno | `deno lint` | `deno test --coverage` | `deno compile` |
| go | `golangci-lint run` | `go test ./... -cover` | `go build ./...` |
| rust | `cargo clippy` | `cargo test` | `cargo build` |
