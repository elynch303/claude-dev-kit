# Example: JavaScript ESLint Fix

## Scenario
User runs build on a JS/TS project with fixable ESLint errors.

## Build Output
```
$ npm run build

> project@1.0.0 build
> eslint . && tsc

/src/utils.ts
  5:1  error  Expected indentation of 2 spaces  indent
  12:20  error  Missing semicolon  semi

2 problems (2 errors, 0 warnings)
  2 errors and 0 warnings potentially fixable with the `--fix` option.
```

## Expected Response
```
Using build-and-fix to detect and build project...

[DETECT] JavaScript/TypeScript project (package.json found, using npm)
[BUILD] Building project...
[ERROR] Build failed - 2 ESLint errors
[ANALYZE] Analyzing build errors...
[FIX] Applying fixes... Running npm run lint -- --fix...
[RETRY] Building project...
[SUCCESS] Build passed! Fixed 2 linting issues in 1 retry cycle.
```

## Key Points
- Pattern `\d+ fixable with.*--fix` detects ESLint fixable errors
- Package manager detected from lock files (npm/yarn/pnpm)
- Uses appropriate lint command for detected package manager
