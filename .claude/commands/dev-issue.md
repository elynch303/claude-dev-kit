# Dev Issue Pipeline

Implement the next open GitHub issue end-to-end: research → plan → code → test → PR.

## Arguments
- `$ARGUMENTS` — GitHub issue number (optional, defaults to next open issue)

## Steps

### 1. Identify the issue
- If no issue number given, run `gh issue list --state open --limit 10` and pick the lowest-numbered non-epic issue
- Read the issue details with `gh issue view <number>`
- Create and checkout branch: `feature/#<number>-<slugified-title>` from latest master

### 2. Generate PRP
- Read `PRPs/INITIAL.md` and `PRPs/templates/prp_base.md` for format reference (if they exist)
- Research the codebase: find related files, existing patterns, test patterns
- Read `CLAUDE.md` for project conventions (stack, lint/test/build commands, patterns)
- Write a complete PRP to `PRPs/<feature-name>.md` with implementation tasks, pseudocode, validation gates, and gotchas

### 3. Implement
- Follow the PRP task list sequentially
- Mirror existing codebase patterns — read nearby files before writing new code
- Write unit tests **alongside** implementation (NOT after)

### 4. Validate — run ALL gates in order, fix failures before proceeding

Read `CLAUDE.md` for the project's exact lint, test, and build commands, then run:

- **Gate 1:** Lint — fix until clean
- **Gate 2:** Unit tests with coverage — all pass, coverage threshold met
- **Gate 3:** E2E tests — if changes affect user-facing flows or API routes
- **Gate 4:** Static analysis — if project has SonarQube / CodeClimate / etc.
- **Gate 5:** Build / type check — must compile cleanly with no errors

Do NOT proceed to step 5 if any gate fails.

### 5. Ship
- Stage only feature files (never `.claude/`, `.env`, or settings files)
- Commit with a conventional commit message referencing the issue number
- Push branch and create PR with `gh pr create`
- Delete the PRP file
- Output the PR URL

## Important
- **One branch per issue, one PR per issue**
- Use dependency injection for external dependencies — keep code testable
- Keep files under 500 lines
- Do NOT commit `.claude/` files, `.env`, or settings files
- Mirror the conventions already in the codebase (naming, file structure, error handling)
