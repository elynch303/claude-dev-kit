# Code Style

Keep code readable, explicit, and maintainable. These rules apply to all files in this project.

- Files stay under 500 lines — split into smaller modules when exceeded
- Functions do one thing and are named for what they do, not how they do it
- Prefer explicit over implicit — avoid magic strings, side-effect-heavy imports, or clever tricks
- No commented-out code in commits
- No `any` types in TypeScript — use `z.infer<typeof Schema>`, Prisma/Drizzle generated types, or `unknown`
- Environment variables must go through a typed config module — never use `process.env.X` inline across the codebase
- Hard-code nothing that belongs in config: URLs, timeouts, limits, feature flags
- Separate concerns: keep route/handler, service/use-case, and data-access layers distinct
- External dependencies (DB, API clients, queues) must be injectable for testability
- Handle all error paths explicitly — no silent failures or swallowed exceptions
