# Search Patterns Reference

Patterns for the Grep tool and Glob tool.

---

## Glob Tool Patterns

Use Glob for file discovery before content search.

### Common Patterns

```
# All TypeScript files
Glob pattern="**/*.ts"

# TypeScript in src directory
Glob pattern="src/**/*.ts"

# Multiple extensions
Glob pattern="**/*.{ts,tsx,js,jsx}"

# Config files
Glob pattern="**/*.{json,yaml,yml,toml}"

# Test files
Glob pattern="**/*.test.ts" OR Glob pattern="**/*.spec.ts"

# Specific directory
Glob pattern="src/components/**/*.tsx" path="."
```

---

## Grep Tool Patterns

The Grep tool is built on ripgrep. Use it for all content searches.

### Output Modes

```
# Find files containing pattern (fastest for discovery)
Grep pattern="<pattern>" output_mode="files_with_matches"

# Show matching lines with context
Grep pattern="<pattern>" output_mode="content" -A 5 -B 5

# Count matches per file
Grep pattern="<pattern>" output_mode="count"
```

### Filtering

```
# By file extension
Grep pattern="<pattern>" glob="*.ts"

# By file type (more efficient than glob)
Grep pattern="<pattern>" type="py"

# Multiple extensions
Grep pattern="<pattern>" glob="*.{ts,tsx,js,jsx}"

# Specific directory
Grep pattern="<pattern>" path="src/components"
```

### Context Control

```
# Lines after match
Grep pattern="<pattern>" -A 10 output_mode="content"

# Lines before match
Grep pattern="<pattern>" -B 5 output_mode="content"

# Lines before and after
Grep pattern="<pattern>" -C 5 output_mode="content"

# With line numbers (default true)
Grep pattern="<pattern>" -n true output_mode="content"
```

### Limiting Results

```
# First N results
Grep pattern="<pattern>" head_limit=10

# Skip first N, then take M
Grep pattern="<pattern>" offset=5 head_limit=10
```

### Multiline Matching

```
# Match patterns spanning lines
Grep pattern="class.*\{[\s\S]*?constructor" multiline=true
```

### Case Insensitive

```
Grep pattern="error" -i=true output_mode="content"
```

---

## Common Search Recipes

### Find Function/Method Definitions

```
# JavaScript/TypeScript
Grep pattern="^\s*(export\s+)?(async\s+)?function\s+functionName" type="ts"
Grep pattern="^\s*(public|private|protected)?\s*(async\s+)?functionName\s*\(" type="ts"

# Python
Grep pattern="^\s*def\s+function_name\s*\(" type="py"
Grep pattern="^\s*async\s+def\s+function_name\s*\(" type="py"

# Rust
Grep pattern="^\s*(pub\s+)?fn\s+function_name" type="rust"

# Go
Grep pattern="^func\s+(\([^)]+\)\s+)?FunctionName" type="go"
```

### Find Class/Type Definitions

```
# JavaScript/TypeScript
Grep pattern="^\s*(export\s+)?(abstract\s+)?class\s+ClassName" type="ts"
Grep pattern="^\s*(export\s+)?interface\s+InterfaceName" type="ts"
Grep pattern="^\s*(export\s+)?type\s+TypeName\s*=" type="ts"

# Python
Grep pattern="^\s*class\s+ClassName\s*[\(:]" type="py"

# Rust
Grep pattern="^\s*(pub\s+)?struct\s+StructName" type="rust"
Grep pattern="^\s*(pub\s+)?enum\s+EnumName" type="rust"

# Go
Grep pattern="^type\s+TypeName\s+struct" type="go"
Grep pattern="^type\s+InterfaceName\s+interface" type="go"
```

### Find Imports/Dependencies

```
# JavaScript/TypeScript
Grep pattern="^import.*from\s+['\"]moduleName['\"]" type="ts"
Grep pattern="require\(['\"]moduleName['\"]\)" type="js"

# Python
Grep pattern="^(from\s+\S+\s+)?import\s+.*module_name" type="py"

# Rust
Grep pattern="^use\s+.*crate_name" type="rust"

# Go
Grep pattern="^\s*\".*package/path\"" type="go"
```

### Find Error Handling

```
# Try-catch blocks
Grep pattern="try\s*\{" -A 20 output_mode="content" type="ts"

# Throw statements
Grep pattern="throw\s+new\s+\w+Error" type="ts"

# Error returns (Go)
Grep pattern="return.*err\s*$" type="go"
Grep pattern="if\s+err\s*!=\s*nil" type="go"

# Rust Result/Error
Grep pattern="Result<[^>]+>" type="rust"
Grep pattern="\.(unwrap|expect)\s*\(" type="rust"
```

### Find TODO/FIXME Comments

```
# All markers
Grep pattern="(TODO|FIXME|HACK|XXX|BUG):" -i=true output_mode="content"

# With author
Grep pattern="TODO\([^)]+\):" output_mode="content"
```

### Find API Endpoints

```
# Express/Node.js
Grep pattern="\.(get|post|put|delete|patch)\s*\(['\"]" type="ts"

# FastAPI/Flask
Grep pattern="@(app|router)\.(get|post|put|delete|patch)\s*\(" type="py"

# Go HTTP
Grep pattern="\.(HandleFunc|Handle|Get|Post|Put|Delete)\s*\(" type="go"
```

### Find React Components

```
# Function components
Grep pattern="^\s*(export\s+)?(default\s+)?function\s+[A-Z]\w+" type="tsx"
Grep pattern="^\s*const\s+[A-Z]\w+\s*[:=]\s*(React\.)?FC" type="tsx"

# Hooks
Grep pattern="^\s*(export\s+)?(const|function)\s+use[A-Z]\w+" type="ts"

# Props interfaces
Grep pattern="interface\s+\w+Props" type="ts"
```

---

## Converting Grep Results to Read Ranges

When Grep returns line numbers, calculate Read parameters:

```
offset = max(matched_line - padding, 0)
limit = padding * 2 + span

Padding guidelines:
- Functions: 10-15 lines
- Configuration: 5 lines
- Multi-branch logic: 15-20 lines
- Single statements: 3-5 lines
```

Example: Grep finds match at line 150 in a function context.
```
offset = max(150 - 15, 0) = 135
limit = 15 * 2 + 1 = 31
Read file="path" offset=135 limit=31
```

---

## Parallel Search Strategy

Batch independent searches in a single response:

```
# Search for multiple patterns simultaneously
Grep pattern="functionA" output_mode="files_with_matches"
Grep pattern="functionB" output_mode="files_with_matches"
Grep pattern="functionC" output_mode="files_with_matches"
```

This reduces round-trips and speeds up investigation.
