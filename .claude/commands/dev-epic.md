# Dev Epic Pipeline

Implement all stories in the next priority epic end-to-end.
Each story becomes its own commit on a single epic branch.
One PR is created for the full epic when all stories are done.

## How this command is designed to work with ralph-loop

Each iteration of the loop handles **one story**:
1. Detect which epic branch is active (or create one)
2. Find the next unimplemented story in that epic
3. Implement it fully and commit
4. On the final iteration (all stories done): push + open PR

## Steps

### 1. Detect state — are we mid-epic?

```
git branch --show-current
```

- If the current branch matches `epic/*` → we are mid-epic, **skip to step 3**
- Otherwise → we need to select an epic and create the branch (step 2)

### 2. Select the next priority epic (only when NOT mid-epic)

```
git checkout master && git pull origin master
gh issue list --state open --limit 100 --json number,title,milestone
```

- Group stories by milestone. Pick the milestone whose lowest story number is the smallest — that is the highest-priority incomplete epic
- Note the milestone name (e.g. `Epic 12A: User Authentication`)
- Create branch: `epic/<slugified-milestone>` (e.g. `epic/12a-user-authentication`)

```
git checkout -b epic/<slug>
```

### 3. List stories for this epic

```
gh issue list --state open --milestone "<milestone-name>" --limit 50 --json number,title
```

Sort by issue number ascending — this is your ordered work queue.

### 4. Find the next unimplemented story

```
git log --oneline
```

- Extract all `(#NNN)` story references already in the commit history
- Pick the **lowest-numbered** story from the milestone list that has NOT been committed yet
- If **all stories are committed** → go to step 6 (create epic PR)

### 5. Implement the story (one story per loop iteration)

Follow the same process as `/dev-issue` but **do NOT create a PR**:

a. Read the story: `gh issue view <number>`

b. Research the codebase — find related files, existing patterns, test patterns. Read `CLAUDE.md` for conventions.

c. Implement the feature:
   - Mirror existing codebase patterns
   - Use dependency injection for external dependencies — keep code testable
   - Write unit tests alongside implementation (NOT after)

d. Validate — read `CLAUDE.md` for the project's exact commands, then run ALL gates in order:
   - **Gate 1:** Lint — fix until clean
   - **Gate 2:** Unit tests with coverage — all pass, threshold met
   - **Gate 3:** E2E tests — if changes affect user-facing flows
   - **Gate 4:** Static analysis — if project has SonarQube / CodeClimate / etc.
   - **Gate 5:** Build / type check — must compile cleanly

   Do NOT commit if any gate fails.

e. Commit (no PR):
   ```
   git add <feature files only — no .claude/, .env, settings>
   git commit -m "feat: <description> (#<story-number>)"
   ```

f. The iteration is complete. The ralph loop will re-run this prompt.
   The next iteration will pick up the next unimplemented story.

### 6. Create the epic PR (only when all stories are committed)

```
git push -u origin <epic-branch>

gh pr create \
  --title "epic: <milestone name>" \
  --body "..."
```

PR body should:
- List every story number as `Closes #NNN` (one per line) so GitHub auto-closes them
- Include a brief summary of what the epic delivers
- Note test coverage and any migration steps

Then output the PR URL.

## Completion signal

Output the exact text below **only** when the PR has been created and you have a real PR URL:

```
epic pr created
```

## Important

- **One branch per epic, one commit per story, one PR per epic** — never create a PR per story
- Keep files under 500 lines
- Do NOT commit `.claude/` files, `.env`, or settings files
- If a story depends on another story not yet merged, implement it anyway on this branch — the dependency is satisfied within the same branch
- If the milestone list is empty (all stories done or no milestone found), output `epic pr created` only if a PR was genuinely opened
