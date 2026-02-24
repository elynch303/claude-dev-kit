---
description: Simplify and refine code for clarity and maintainability
argument-hint: [file-or-pattern]
---

# Code Simplifier

Invoke the **@"code-simplifier:code-simplifier (agent)"** to simplify and refine code for clarity, consistency, and maintainability while preserving all functionality.

## Purpose

- Simplify code structure and reduce unnecessary complexity
- Apply project coding standards from CLAUDE.md
- Enhance readability through clear naming and organization
- Remove redundant code and abstractions
- Maintain balance - avoid over-simplification

## Process

1. **Determine scope**
   - If `$ARGUMENTS` is provided, focus on those specific files/patterns
   - Otherwise, review the whole project in its current state

2. **Launch the code-simplifier agent**
   - Use the Task tool with `subagent_type: "code-simplifier:code-simplifier"`
   - Pass the target scope: `$ARGUMENTS`

3. **The agent will:**
   - Identify target code sections
   - Analyze for opportunities to improve clarity and consistency
   - Apply project-specific best practices
   - Ensure all functionality remains unchanged

4. **Verify results**
   - Run tests if available
   - Run linting/formatting checks
   - Confirm no behavioral changes

5. **Report statistics**
   - Lines simplified/removed
   - Functions refactored
   - Patterns standardized

## Examples

```bash
# Simplify entire project
/code:simplify

# Simplify specific file
/code:simplify src/utils.ts

# Simplify multiple files
/code:simplify src/utils.ts src/helpers.ts lib/core.ts

# Simplify matching pattern
/code:simplify **/*.tsx

# Simplify a directory
/code:simplify src/components/
```

## Notes

- Preserves exact functionality - only changes how code is written
- Follows CLAUDE.md project standards
- Prefers clarity over brevity
- Avoids nested ternaries - uses switch/if-else instead
- Does not over-simplify or create overly clever solutions

## Error Handling

- If no files match the pattern, reports back without making changes
- Invalid paths are reported explicitly, not silently ignored
- Syntax errors in target code are flagged before attempting simplification
- If tests fail after changes, reverts and reports the issue
- If CLAUDE.md is missing, proceeds with general best practices
