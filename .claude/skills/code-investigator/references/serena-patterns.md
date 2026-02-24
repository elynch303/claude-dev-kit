# Serena MCP Patterns Reference

Detailed patterns and examples for Serena MCP tools in code investigation.

---

## Name Path Patterns

Serena's `find_symbol` uses name paths to identify symbols within files.

### Pattern Syntax

```
[ParentSymbol/]SymbolName[/ChildSymbol]
```

### Examples

| Pattern | Matches |
|---------|---------|
| `"MyClass"` | Class named MyClass |
| `"MyClass/method"` | Method `method` in `MyClass` |
| `"MyClass/__init__"` | Constructor of `MyClass` (Python) |
| `"*/render"` | Any `render` method in any class |
| `"validate"` + `substring_matching: true` | validateInput, validateUser, isValid, etc. |

### Overloaded Methods (Java/C++)

When methods are overloaded, append index:
- `"MyClass/method[0]"` - First overload
- `"MyClass/method[1]"` - Second overload

---

## get_symbols_overview Patterns

### Pattern 1: First Contact with File

Always use this before reading a new file.

```yaml
Tool: mcp__serena__get_symbols_overview
Parameters:
  relative_path: "src/auth/middleware.ts"
  depth: 0  # Top-level only for overview
```

**Output structure:**
```json
{
  "classes": ["AuthMiddleware", "TokenValidator"],
  "functions": ["authenticate", "authorize"],
  "interfaces": ["AuthConfig", "UserContext"]
}
```

### Pattern 2: Class Exploration

Get class with all its methods.

```yaml
Tool: mcp__serena__get_symbols_overview
Parameters:
  relative_path: "src/services/UserService.ts"
  depth: 1  # Include class methods
```

---

## find_symbol Patterns

### Pattern 1: Exact Symbol Lookup

```yaml
Tool: mcp__serena__find_symbol
Parameters:
  name_path_pattern: "AuthService/validateToken"
  include_body: true   # Get implementation
  include_info: true   # Get type signature
```

### Pattern 2: Find All Methods of a Class

```yaml
Tool: mcp__serena__find_symbol
Parameters:
  name_path_pattern: "UserRepository"
  depth: 1              # Get all methods
  include_body: false   # Just names, not code
```

### Pattern 3: Fuzzy Symbol Search

When you know partial name:

```yaml
Tool: mcp__serena__find_symbol
Parameters:
  name_path_pattern: "handle"
  substring_matching: true
  relative_path: "src/handlers/"  # Narrow scope
```

Matches: handleRequest, handleError, errorHandler, etc.

### Pattern 4: Find All Implementations

```yaml
Tool: mcp__serena__find_symbol
Parameters:
  name_path_pattern: "*/process"  # Any class with process method
  include_info: true
```

### Pattern 5: Scoped Search

Limit search to specific directory:

```yaml
Tool: mcp__serena__find_symbol
Parameters:
  name_path_pattern: "Controller"
  substring_matching: true
  relative_path: "src/api/"
```

---

## find_referencing_symbols Patterns

### Pattern 1: Who Calls This Function?

```yaml
Tool: mcp__serena__find_referencing_symbols
Parameters:
  name_path: "utils/logger"
  relative_path: "src/utils/logger.ts"
```

Returns code snippets around each call site.

### Pattern 2: Track Interface Usage

```yaml
Tool: mcp__serena__find_referencing_symbols
Parameters:
  name_path: "IUserRepository"
  relative_path: "src/interfaces/repository.ts"
  include_info: true  # Get type info at each site
```

### Pattern 3: Find All Instantiations

```yaml
Tool: mcp__serena__find_referencing_symbols
Parameters:
  name_path: "DatabaseConnection"
  relative_path: "src/db/connection.ts"
```

---

## search_for_pattern Patterns

### Pattern 1: TODO Comments in Code Only

```yaml
Tool: mcp__serena__search_for_pattern
Parameters:
  substring_pattern: "TODO|FIXME|HACK|XXX"
  restrict_search_to_code_files: true
  paths_exclude_glob: "**/*.test.*"
  context_lines_after: 1
```

### Pattern 2: Error Handling Patterns

```yaml
Tool: mcp__serena__search_for_pattern
Parameters:
  substring_pattern: "catch\\s*\\([^)]*Error"
  paths_include_glob: "**/*.ts"
  context_lines_before: 2
  context_lines_after: 5
```

### Pattern 3: API Endpoints

```yaml
Tool: mcp__serena__search_for_pattern
Parameters:
  substring_pattern: "@(Get|Post|Put|Delete|Patch)Mapping"
  paths_include_glob: "**/*Controller.java"
```

### Pattern 4: Environment Variables

```yaml
Tool: mcp__serena__search_for_pattern
Parameters:
  substring_pattern: "process\\.env\\."
  restrict_search_to_code_files: true
  paths_exclude_glob: "**/*.test.*"
```

### Pattern 5: SQL Queries

```yaml
Tool: mcp__serena__search_for_pattern
Parameters:
  substring_pattern: "(SELECT|INSERT|UPDATE|DELETE).*FROM"
  restrict_search_to_code_files: true
  context_lines_before: 3
  context_lines_after: 3
```

---

## Memory Patterns

### Pattern 1: Architecture Documentation

```yaml
Tool: mcp__serena__write_memory
Parameters:
  memory_file_name: "api-architecture"
  content: |
    # API Architecture

    ## Entry Points
    - src/api/router.ts - Main router
    - src/api/middleware/ - Auth, logging, validation

    ## Layers
    - Controllers: src/api/controllers/
    - Services: src/services/
    - Repositories: src/repositories/

    ## Key Patterns
    - All controllers extend BaseController
    - Services use dependency injection
    - Repositories implement IRepository interface
```

### Pattern 2: Bug Investigation Notes

```yaml
Tool: mcp__serena__write_memory
Parameters:
  memory_file_name: "auth-timeout-bug"
  content: |
    # Auth Timeout Bug Investigation

    ## Symptoms
    - Users logged out after 5 minutes
    - Only on production

    ## Root Cause
    - Token refresh race condition in src/auth/refresh.ts:45
    - Concurrent requests cause token invalidation

    ## Fix
    - Add mutex lock around token refresh
    - See PR #234
```

### Pattern 3: Retrieving Context

```yaml
# Start of investigation
Tool: mcp__serena__list_memories

# If relevant memory exists
Tool: mcp__serena__read_memory
Parameters:
  memory_file_name: "api-architecture"
```

---

## Investigation Workflows

For complete investigation workflows with Serena patterns, see `references/investigation-workflows.md`.

**Quick workflow summary:**

1. **Debug Error:** `search_for_pattern` → `find_symbol` → `find_referencing_symbols` → `think_about_collected_information`

2. **Trace Code Path:** `find_symbol` → `find_referencing_symbols` (recursive) → `write_memory`

3. **Understand Feature:** `list_dir` → `get_symbols_overview` → `find_symbol` → `find_referencing_symbols` → `write_memory`

---

## Error Handling

### Symbol Not Found

```yaml
Symptom: find_symbol returns empty
Actions:
  1. Enable substring_matching: true
  2. Broaden name_path_pattern (remove parent path)
  3. Check relative_path scope
  4. Fall back to search_for_pattern
  5. Fall back to LSP workspaceSymbol
```

### Language Not Supported

```yaml
Symptom: "Unsupported language" error
Actions:
  1. Fall back to LSP if available
  2. Fall back to Grep patterns
  3. Use language-specific patterns from language-specific.md
```

### Too Many Results

```yaml
Symptom: Output truncated or overwhelming
Actions:
  1. Narrow relative_path scope
  2. Use paths_include_glob to filter
  3. Use paths_exclude_glob to exclude tests/generated
  4. Add depth: 0 to reduce nesting
```
