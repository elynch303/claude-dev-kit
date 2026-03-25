---
globs: "**/*.test.ts,**/*.test.tsx,**/*.spec.ts,**/*.spec.tsx,**/*.test.py,**/tests/**,**/__tests__/**"
---

# Testing Conventions

- **AAA pattern**: Arrange → Act → Assert — one clear block per concern
- Test behavior, not implementation: test what a function *does*, not how it does it internally
- Test names describe the scenario in plain language: `"returns 409 when slot is already booked"`
- Cover: happy path, each distinct error path, and boundary conditions
- **Dependency injection for mocking** — avoid module-level patching when the code supports DI
- 90%+ branch coverage on all new and modified files
- No arbitrary `sleep()` or `setTimeout()` in tests — use proper async waiting mechanisms
- Never test private methods or internal state directly — test through the public interface
- One `describe` block per unit/feature — keep test files focused
- Mock at the seam closest to the external dependency (DB, HTTP, filesystem)
