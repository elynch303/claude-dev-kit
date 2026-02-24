# Investigation Workflows

Detailed workflows for common code investigation scenarios.

**Note:** These workflows now prefer Serena MCP tools over LSP/Grep for better context and efficiency.

---

## Workflow 1: Debug an Error

**Goal:** Find the root cause of an error message or exception.

### Step 1: Search for the Error Message (Serena-First)

```yaml
# Preferred: Serena search with code-only filter
mcp__serena__search_for_pattern:
  substring_pattern: "exact error message"
  restrict_search_to_code_files: true
  context_lines_before: 3
  context_lines_after: 5
```

Fallback to Grep:
```
Grep pattern="exact error message" output_mode="files_with_matches"
Grep pattern="key words from error" -i=true output_mode="content" -A 5 -B 5
```

### Step 2: Trace the Error Origin (Serena-First)

```yaml
# Find the throwing function with context
mcp__serena__find_symbol:
  name_path_pattern: "function_throwing_error"
  include_body: true
  include_info: true

# Find all callers with code snippets
mcp__serena__find_referencing_symbols:
  name_path: "function_throwing_error"
  relative_path: "path/to/file.ts"
```

Fallback to LSP:
- `goToDefinition` on the throwing function
- `findReferences` to trace callers

Fallback to Grep:
```
Grep pattern="function_throwing_error\s*\(" output_mode="content" -B 5 -A 15
```

### Step 3: Check Recent Changes

```bash
git log --oneline -20 --all -- <file_with_error>
git log -S "error message" --oneline
git blame <file> -L <start>,<end>
```

### Step 4: Find Related Error Handling

```
Grep pattern="(try|catch|except|Result|Error)" path="<file_with_error>" -A 3 output_mode="content"
```

### Step 5: Read Targeted Code

Convert Grep line numbers to Read ranges:
```
Read file="path/to/file" offset=<line-10> limit=25
```

### Anti-Patterns to Avoid

- Reading entire files "for context" before searching
- Searching broadly before understanding the error message
- Skipping git history for recently introduced bugs

---

## Workflow 2: Trace a Code Path

**Goal:** Understand how data flows from point A to point B.

### Preferred: Serena Symbol Tracing (Best Context)

Serena provides richer context than LSP - code snippets at each call site:

```yaml
Step 1: Find the function with its body
mcp__serena__find_symbol:
  name_path_pattern: "target_function"
  include_body: true
  include_info: true

Step 2: Trace BACKWARDS (who calls this?) - with snippets
mcp__serena__find_referencing_symbols:
  name_path: "ClassName/target_function"
  relative_path: "path/to/file.ts"
  # Returns code snippets around each call site!

Step 3: For each caller, trace further back
mcp__serena__find_referencing_symbols:
  name_path: "caller_function"
  relative_path: "path/to/caller.ts"

Step 4: Check investigation quality
mcp__serena__think_about_collected_information
```

**Advantage over LSP:** Returns actual code at call sites, not just locations.

### Alternative: LSP Call Hierarchy

If cursor position is known, LSP provides fast tracing:

```
Step 1: LSP prepareCallHierarchy filePath="/path/to/file" line=42 character=10
Step 2: LSP incomingCalls (trace backwards)
Step 3: LSP outgoingCalls (trace forwards)
```

### Fallback: Grep-Based Tracing

If both Serena and LSP are unavailable:

### Step 1: Identify Entry Point

```yaml
# Try Serena first
mcp__serena__search_for_pattern:
  substring_pattern: "entry_function_name"
  restrict_search_to_code_files: true
```

Fallback:
```
Grep pattern="entry_function_name" output_mode="files_with_matches"
```

### Step 2: Follow Function Calls

```yaml
# Get function body to see what it calls
mcp__serena__find_symbol:
  name_path_pattern: "called_function"
  include_body: true
```

Fallback:
```
Grep pattern="^\s*(export\s+)?(async\s+)?function\s+called_function" output_mode="content" -A 10
```

### Step 3: Find All References (Reverse Trace)

```yaml
mcp__serena__find_referencing_symbols:
  name_path: "target_function"
  relative_path: "path/to/file.ts"
```

Fallback:
```
Grep pattern="target_function\s*\(" output_mode="content" -B 2 -A 5
```

### Step 4: Visualize the Call Chain

Document as you trace:
```
entry_point()
  → function_a() [src/module/file.ts:42]
    → function_b() [src/utils/helper.ts:18]
      → target_function() [src/core/processor.ts:156]
```

### Step 5: Store Complex Findings

For complex call chains, persist to memory:
```yaml
mcp__serena__write_memory:
  memory_file_name: "payment-call-chain"
  content: |
    # Payment Processing Call Chain
    entry_point() → ...
```

---

## Workflow 3: Learn a Library/API

**Goal:** Understand how to use an external library.

### Step 1: Check Context7 First

```
mcp__context7__resolve-library-id libraryName="library-name" query="what I want to do"
mcp__context7__query-docs libraryId="/org/library" query="specific topic"
```

### Step 2: Find Usage Examples in Codebase

```
Grep pattern="import.*library-name" output_mode="files_with_matches"
Grep pattern="from library-name import" output_mode="files_with_matches"
```

### Step 3: Study Existing Implementations

```
Grep pattern="libraryFunction\(" output_mode="content" -A 5 -B 2
```

### Step 4: Check Configuration

```
Grep pattern="library" glob="*.{json,yaml,yml,toml,ini,env}" output_mode="content"
```

### Step 5: Read Targeted Examples

Select the most relevant file from Step 2 and read specific usage:
```
Read file="path/to/example" offset=<import_line> limit=50
```

---

## Workflow 4: Understand a Feature

**Goal:** Comprehensively understand how a feature works.

### Step 1: Explore Feature Directory (Serena-First)

```yaml
# Get directory structure
mcp__serena__list_dir:
  relative_path: "src/features/feature_name"
  recursive: true
  skip_ignored_files: true

# For each key file, get symbol overview
mcp__serena__get_symbols_overview:
  relative_path: "src/features/feature_name/index.ts"
  depth: 1
```

Fallback:
```
Grep pattern="feature_name" output_mode="files_with_matches"
```

### Step 2: Find Entry Points (Serena-First)

```yaml
# Search for exports/handlers
mcp__serena__find_symbol:
  name_path_pattern: "feature"
  substring_matching: true
  relative_path: "src/features/"

# Or search patterns
mcp__serena__search_for_pattern:
  substring_pattern: "(route|endpoint|handler).*feature"
  restrict_search_to_code_files: true
```

### Step 3: Map the Architecture

Create a mental model:
```
Feature: [name]
├── UI Layer: [files]
├── API Layer: [files]
├── Business Logic: [files]
├── Data Layer: [files]
└── Tests: [files]
```

### Step 4: Trace Key Flows

Pick 2-3 critical operations and use Workflow 2 (Serena tracing) to follow them.

### Step 5: Check Tests for Behavior Specification

```yaml
mcp__serena__search_for_pattern:
  substring_pattern: "describe.*feature|test.*feature"
  paths_include_glob: "**/*.test.*"
  context_lines_after: 20
```

### Step 6: Quality Check and Persist

```yaml
# Check if investigation is complete
mcp__serena__think_about_collected_information

# Store findings for future reference
mcp__serena__write_memory:
  memory_file_name: "feature-name-architecture"
  content: |
    # Feature Architecture
    ## Entry Points
    - ...
    ## Key Components
    - ...
```

---

## Workflow 5: Investigate Performance Issues

**Goal:** Find performance bottlenecks.

### Step 1: Search for Known Slow Patterns

```
# N+1 queries
Grep pattern="for.*\{" -A 10 output_mode="content" then look for (query|find|select|fetch)

# Synchronous operations in async code
Grep pattern="(sync|blocking|sleep)" type="rust" output_mode="content"

# Missing indexes (comments/TODOs)
Grep pattern="(slow|performance|optimize|TODO.*index)" -i=true output_mode="content"
```

### Step 2: Find Heavy Operations

```
# Large data operations
Grep pattern="(map|filter|reduce|forEach)\s*\(" -A 3 output_mode="content"

# File I/O
Grep pattern="(readFile|writeFile|open\(|File::)" output_mode="content"

# Network calls
Grep pattern="(fetch|axios|http\.|request\()" output_mode="content"
```

### Step 3: Check Caching

```
Grep pattern="(cache|memo|lazy|preload)" -i=true output_mode="files_with_matches"
```

### Step 4: Review Database Queries

```
Grep pattern="(SELECT|INSERT|UPDATE|DELETE|\.query|\.execute)" -A 2 output_mode="content"
```

### Step 5: Examine Loops and Iterations

```
Grep pattern="(for\s*\(|while\s*\(|\.forEach|\.map\()" -A 5 output_mode="content" glob="!*test*"
```

---

## Workflow 6: Security Audit

**Goal:** Find potential security vulnerabilities.

### Step 1: Search for Common Vulnerabilities

```
# SQL Injection
Grep pattern="(\+.*query|query.*\+|f\".*SELECT|\.format.*SELECT)" output_mode="content"

# Command Injection
Grep pattern="(exec\(|spawn\(|system\(|subprocess|child_process)" output_mode="content"

# XSS
Grep pattern="(innerHTML|dangerouslySetInnerHTML|v-html)" output_mode="content"

# Hardcoded secrets
Grep pattern="(password|secret|api_key|token)\s*=\s*['\"]" -i=true output_mode="content"

# Insecure randomness
Grep pattern="(Math\.random|random\(\))" output_mode="content"
```

### Step 2: Check Input Validation

```
Grep pattern="(validate|sanitize|escape|encode)" output_mode="files_with_matches"
Grep pattern="(req\.body|req\.params|req\.query)" -A 3 output_mode="content"
```

### Step 3: Review Authentication/Authorization

```
Grep pattern="(auth|login|session|jwt|token)" -i=true output_mode="files_with_matches"
Grep pattern="(middleware|guard|interceptor)" -A 5 output_mode="content"
```

### Step 4: Check Dependencies

```
# Look for known vulnerable patterns in package files
Glob pattern="**/package.json"
Glob pattern="**/Cargo.toml"
Glob pattern="**/requirements.txt"
Glob pattern="**/go.mod"
```

---

## Workflow 7: Prepare for Refactoring

**Goal:** Understand impact before making changes.

### Step 1: Find All References (Serena-First)

```yaml
# Get all usages with code context
mcp__serena__find_referencing_symbols:
  name_path: "symbol_to_refactor"
  relative_path: "path/to/symbol/file.ts"
  include_info: true
```

Fallback to LSP `findReferences`, then Grep:
```
Grep pattern="symbol_to_refactor" output_mode="files_with_matches"
```

### Step 2: Check for Dynamic Usage

```yaml
mcp__serena__search_for_pattern:
  substring_pattern: "\\[.*symbol_to_refactor.*\\]|eval\\(|new Function"
  restrict_search_to_code_files: true
```

### Step 3: Review Tests

```yaml
mcp__serena__search_for_pattern:
  substring_pattern: "symbol_to_refactor"
  paths_include_glob: "**/*test*"
  context_lines_before: 2
  context_lines_after: 5
```

### Step 4: Check for External Exposure

```yaml
# Public API exposure
mcp__serena__search_for_pattern:
  substring_pattern: "export.*symbol_to_refactor|(public|pub)\\s+.*symbol_to_refactor"
  restrict_search_to_code_files: true

# Configuration references
mcp__serena__search_for_pattern:
  substring_pattern: "symbol_to_refactor"
  paths_include_glob: "**/*.{json,yaml,yml,toml}"
```

### Step 5: Quality Check Before Proceeding

```yaml
# Verify we have complete impact assessment
mcp__serena__think_about_task_adherence

# Ensure we haven't missed anything
mcp__serena__think_about_collected_information
```

### Step 6: Document Impact

```yaml
mcp__serena__write_memory:
  memory_file_name: "refactor-symbol-impact"
  content: |
    # Refactoring Impact: symbol_to_refactor

    ## Files Affected
    - file1.ts (5 usages)
    - file2.ts (2 usages)

    ## Test Coverage
    - Tests exist in test_file.ts

    ## External Exposure
    - Exported from public API: yes/no

    ## Risk Level
    - Low/Medium/High

    ## Recommended Approach
    - ...
```

### Step 7: Execute Refactoring (if approved)

```yaml
# Serena can rename across codebase
mcp__serena__rename_symbol:
  name_path: "symbol_to_refactor"
  relative_path: "path/to/file.ts"
  new_name: "new_symbol_name"
```

---

## Git Investigation Patterns

### Find When Something Was Introduced

```bash
git log -S "pattern" --oneline
git log -G "regex" --oneline
git log --all --oneline -- path/to/file
```

### Find Who Wrote Code

```bash
git blame file.ts -L 100,120
git log --follow -p -- path/to/file
```

### Find Related Changes

```bash
git log --oneline --since="2 weeks ago" -- path/
git diff HEAD~10..HEAD -- path/to/file
git log --grep="feature" --oneline
```

### Compare Branches

```bash
git diff main..feature-branch -- path/
git log main..feature-branch --oneline
```
