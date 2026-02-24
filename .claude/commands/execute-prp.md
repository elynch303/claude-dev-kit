# Execute BASE PRP

Implement a feature using using the PRP file.

## PRP File: $ARGUMENTS

## Execution Process

1. **Load PRP**
   - Read the specified PRP file
   - Understand all context and requirements
   - Follow all instructions in the PRP and extend the research if needed
   - Ensure you have all needed context to implement the PRP fully
   - Do more web searches and codebase exploration as needed

2. **ULTRATHINK**
   - Think hard before you execute the plan. Create a comprehensive plan addressing all requirements.
   - Break down complex tasks into smaller, manageable steps using your todos tools.
   - Use the TodoWrite tool to create and track your implementation plan.
   - Identify implementation patterns from existing code to follow.

3. **Execute the plan**
   - Execute the PRP
   - Implement all the code
   - Follow performance best practices (see Performance section below)

4. **Unit Testing**
   - Write unit tests for ALL new logic and functions
   - Ensure comprehensive coverage of edge cases and error conditions
   - Run unit tests: `bun test` or appropriate test command
   - Fix any failing tests
   - Re-run until all unit tests pass

5. **E2E Testing**
   - Create E2E tests for new user-facing features and flows
   - Test critical paths and integration points
   - Run E2E tests: `bun run test:e2e` or appropriate E2E command
   - Fix any failing E2E tests
   - Re-run until all E2E tests pass

6. **Storybook**
   - Create or update Storybook stories for all new/modified UI components
   - Include stories for different component states (default, loading, error, empty, etc.)
   - Add stories for different variants and prop combinations
   - Run Storybook: `bun run storybook` to verify stories render correctly
   - Fix any rendering issues or warnings
   - Ensure stories are documented with proper controls and descriptions

7. **Validate**
   - Run each validation command
   - Run full test suite (unit + E2E)
   - Fix any failures
   - Re-run until all pass

8. **Performance Audit**
   - Run Lighthouse audit: `bun run build && npx lighthouse http://localhost:3000 --view`
   - Check bundle size impact: `bun run build` and review output sizes
   - Verify no performance regressions in Core Web Vitals (LCP, FID, CLS)
   - Review and optimize any new images (use next/image, proper sizing, lazy loading)
   - Check for unnecessary re-renders in React components
   - Ensure proper code splitting and lazy loading for new routes/components
   - Verify API calls are optimized (pagination, caching, debouncing where appropriate)
   - Run `bun run analyze` if available to check bundle composition

9. **Complete**
   - Ensure all checklist items done
   - Verify all unit tests pass
   - Verify all E2E tests pass
   - Verify all Storybook stories render correctly
   - Verify performance audit passed with no regressions
   - Run final validation suite
   - Report completion status with test coverage summary
   - Read the PRP again to ensure you have implemented everything

10. **Reference the PRP**
    - You can always reference the PRP again if needed

Note: If validation fails, use error patterns in PRP to fix and retry.

---

## Performance Best Practices

Always consider these during implementation:

### Bundle Size
- Use dynamic imports (`next/dynamic`) for heavy components not needed on initial load
- Avoid importing entire libraries when only specific functions are needed
- Tree-shake unused code by using named imports

### Rendering
- Memoize expensive computations with `useMemo`
- Prevent unnecessary re-renders with `React.memo` and `useCallback`
- Use virtualization for long lists (react-window, react-virtualized)
- Avoid inline function definitions in render where possible

### Images & Media
- Always use `next/image` for automatic optimization
- Specify width and height to prevent layout shifts
- Use appropriate formats (WebP, AVIF) and sizes
- Implement lazy loading for below-the-fold images

### Data Fetching
- Implement proper caching strategies (SWR, React Query, or Next.js caching)
- Use pagination or infinite scroll for large datasets
- Debounce search inputs and frequent API calls
- Prefetch data for anticipated navigation

### Mobile Performance
- Test on real devices or throttled connections
- Minimize JavaScript execution on mobile
- Ensure touch targets are appropriately sized
- Consider reduced motion preferences