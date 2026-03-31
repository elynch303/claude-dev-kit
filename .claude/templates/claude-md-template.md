# CLAUDE.md

<!-- CDK:GENERATED:START — managed by /init, do not edit this block manually -->

## Project Overview
<!-- PROJECT_DESCRIPTION -->

## Stack
| Component | Value |
|-----------|-------|
| Framework | <!-- FRAMEWORK --> |
| ORM / DB  | <!-- ORM --> |
| Language  | <!-- LANGUAGE --> |
| Package manager | <!-- PACKAGE_MANAGER --> |
| Test runner | <!-- TEST_RUNNER --> |
| E2E | <!-- E2E_RUNNER --> |
| Mobile | <!-- MOBILE --> |
| VCS | <!-- VCS_PLATFORM --> |
| Issue tracker | <!-- ISSUE_TRACKER --> |

## Development Commands
| Task | Command |
|------|---------|
| Dev server | `<!-- DEV_CMD -->` |
| Lint | `<!-- LINT_CMD -->` |
| Unit tests | `<!-- TEST_CMD -->` |
| E2E tests | `<!-- E2E_CMD -->` |
| Build | `<!-- BUILD_CMD -->` |
| Static export (mobile) | `<!-- STATIC_CMD -->` |

## Validation Gates (run in order, fix before proceeding)
1. `<!-- LINT_CMD -->` — linting, zero errors
2. `<!-- TEST_CMD -->` — unit tests, coverage threshold met
3. `<!-- E2E_CMD -->` — E2E tests, when user flows changed
4. `<!-- BUILD_CMD -->` — compilation, zero type errors

## Key Conventions
<!-- KEY_CONVENTIONS -->

> Detailed rules live in `.claude/rules/` — Claude loads them automatically:
> - `code-style.md` — code quality and structure rules (all files)
> - `security.md` — security practices (all files)
> - `api-conventions.md` — HTTP status codes, response shapes, route structure (api/** files)
> - `testing.md` — AAA pattern, coverage targets, mock strategy (test files)

## Personal Overrides

Copy `CLAUDE.local.md.example` → `CLAUDE.local.md` to set personal preferences (gitignored).

## Agent System (Claude Dev Kit)
This project uses the claude-dev-kit autonomous development pipeline:

| Command | Purpose |
|---------|---------|
| `/init` | Re-run to refresh agents after stack changes |
| `/pm:groom` | Groom <!-- ISSUE_TRACKER --> issues with acceptance criteria |
| `/pm:size` | Size stories for sprint planning |
| `/pm:plan-epic` | Full epic plan: groom → size → PRPs |
| `/dev <issue>` | Autonomous implementation: code → tests → review → PR |
| `/dev:review` | Code review of current branch |
| `/bs:brainstorm_full` | Multi-LLM brainstorming |

> **Issue tracker**: <!-- ISSUE_TRACKER --> — `/pm:groom` and `/dev` read issues from here.

<!-- CDK:GENERATED:END -->

---

## Project Notes
<!-- Add your own project-specific notes below this line. /init will never touch this section. -->
