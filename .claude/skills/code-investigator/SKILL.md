---
name: code-investigator
description: >-
  Efficient code investigation through targeted searches. Use for (1) investigating
  how code works, (2) debugging specific issues, (3) understanding APIs/libraries,
  (4) exploring large codebases, (5) tracing code paths and call hierarchies,
  (6) finding where symbols are defined/used, or when users request "efficient",
  "trace", "how does X work", "find the bug", "call hierarchy", "who calls this",
  "where is X defined", "find all usages", "what type is this", "go to definition",
  "find references", "symbol lookup", "minimal context", "save tokens", or
  "targeted search" approaches.
---

# Code Investigator

Investigate code efficiently through semantic analysis and targeted searches. Minimize token usage by using structured tools before reading files.

## Core Philosophy

- **Structure before content** - Use `get_symbols_overview` before reading files
- **Semantic over textual** - Prefer `find_symbol` over Grep when symbol name is known
- **Snippets over locations** - `find_referencing_symbols` gives context, not just line numbers
- **Escalate gradually** - Start with zero-cost tools, increase scope only when necessary
- **Think before concluding** - Use thinking checkpoints to maintain quality
- **Remember across sessions** - Persist valuable findings in memory
- **Batch operations** - Run independent searches in parallel

## Quick Reference (Serena-First)

| Query Type | Serena Tool | LSP Fallback | Grep Fallback |
|------------|-------------|--------------|---------------|
| "List symbols in file" | `get_symbols_overview` | `documentSymbol` | Grep definitions |
| "Where is X defined?" | `find_symbol` (name path) | `goToDefinition` | Grep definition pattern |
| "Who calls X?" | `find_referencing_symbols` | `incomingCalls` | Grep `functionName\s*\(` |
| "Find all uses of X" | `find_referencing_symbols` | `findReferences` | Grep pattern |
| "Find symbol by name" | `find_symbol` (substring) | `workspaceSymbol` | Glob + Grep |
| "What does X call?" | `find_symbol` + body | `outgoingCalls` | Read function body |
| "What type is X?" | `find_symbol` + info | `hover` | Infer from context |
| "Pattern in code only" | `search_for_pattern` | - | Grep with glob |
| "How does X work?" | `find_symbol` chain | Call hierarchy | Explore agent |

## Tool Priority (Lowest to Highest Cost)

| Priority | Tool | Best For | Cost |
|----------|------|----------|------|
| 1 | **Serena `get_symbols_overview`** | File structure, first look at new files | Zero |
| 2 | **Serena `find_symbol`** | Known symbol names, name path patterns | Zero |
| 3 | **Serena `find_referencing_symbols`** | All usages with code snippets | Zero |
| 4 | **LSP tools** | Call hierarchy, hover, cursor-based ops | Zero |
| 5 | **Context7** | Third-party library documentation | Low |
| 6 | **Serena `search_for_pattern`** | Regex with file filtering, code-only | Low |
| 7 | **Glob / `find_file`** | File discovery by pattern | Low |
| 8 | **Grep** | Content search (when Serena unavailable) | Medium |
| 9 | **Git** | Change history (`log -p`, `blame`, `diff`) | Medium |
| 10 | **Read ranges** | Specific line ranges (`offset`/`limit`) | Medium |
| 11 | **Read full** | Small files only (<100 lines) | High |

## Default Workflow

1. **Check memory** - `list_memories` for prior investigation of this area
2. **Understand structure** - `get_symbols_overview` for new files
3. **Find symbols** - `find_symbol` for name-based discovery
4. **Trace references** - `find_referencing_symbols` for usages with context
5. **Search patterns** - `search_for_pattern` for regex searches
6. **Quality checkpoint** - `think_about_collected_information` after 3-5 searches
7. **Fall back** - LSP, then Grep if Serena tools fail
8. **Persist findings** - `write_memory` for complex investigations
9. **Report concisely** - Use `file_path:line_number` format

---

## Serena Tools (Primary)

### get_symbols_overview - First Tool for New Files

Use this **before reading any file** to understand its structure.

```yaml
Parameters:
  relative_path: "src/auth/login.ts"  # Required
  depth: 1                            # 0=top-level, 1=+children
```

Returns compact symbol tree grouped by kind (classes, functions, methods).

### find_symbol - Pattern-Based Symbol Discovery

More powerful than LSP - supports name paths and substring matching.

```yaml
Parameters:
  name_path_pattern: "ClassName/method"  # Required - supports patterns
  relative_path: "src/"                  # Scope search (optional)
  depth: 1                               # Get children (0=symbol only)
  include_body: false                    # Include source code
  include_info: true                     # Include type/signature
  substring_matching: true               # Fuzzy matching
```

**Name path examples:**
- `"AuthService/login"` - Exact path
- `"*/render"` - Any class with render method
- `"validate"` with `substring_matching: true` - Matches validateInput, validateUser, etc.

### find_referencing_symbols - Usages with Context

Superior to LSP `findReferences` - returns code snippets, not just locations.

```yaml
Parameters:
  name_path: "utils/handleError"      # Symbol to find refs for
  relative_path: "src/utils/error.ts" # File containing symbol
  include_info: false                 # Include signatures
```

### search_for_pattern - Filtered Regex Search

More powerful than Grep - glob filtering and code-only restriction.

```yaml
Parameters:
  substring_pattern: "TODO|FIXME"        # Python regex
  relative_path: "src/"                  # Scope (optional)
  paths_include_glob: "**/*.ts"          # Include patterns
  paths_exclude_glob: "**/*.test.ts"     # Exclude patterns
  restrict_search_to_code_files: true    # Skip configs/docs
  context_lines_before: 1
  context_lines_after: 2
```

---

## Investigation Quality Control

Use thinking tools at key checkpoints to maintain investigation rigor.

### Checkpoint 1: After Information Gathering

**When:** After 3-5 searches or when you feel you have basics.

```yaml
Tool: mcp__serena__think_about_collected_information
```

Ask: Do I have enough? Am I missing context? Should I search deeper?

### Checkpoint 2: Before Code Changes

**When:** Before any insert, replace, or rename operation.

```yaml
Tool: mcp__serena__think_about_task_adherence
```

Ask: Am I still on track? Did I drift from the original request?

### Checkpoint 3: Before Claiming Done

**When:** Before final answer or summary.

```yaml
Tool: mcp__serena__think_about_whether_you_are_done
```

Ask: Have I actually answered the question? Are there loose ends?

---

## Fallback Strategy

```
Symbol Definition:
  find_symbol → LSP goToDefinition → Grep pattern

References with Context:
  find_referencing_symbols → LSP findReferences + Read → Grep

File Structure:
  get_symbols_overview → LSP documentSymbol → Grep definitions

Pattern Search:
  search_for_pattern → Grep with glob → Read + manual search
```

### When to Escalate

| Condition | Action |
|-----------|--------|
| Serena returns empty | Enable `substring_matching`, broaden pattern |
| Still empty | Try LSP equivalent |
| LSP fails | Fall back to Grep patterns |
| File <100 lines | Safe to read fully |
| Open-ended exploration | Delegate to Explore agent |

---

## Persistent Memory

Store findings for multi-session investigations.

### When to Use Memory

- Investigation took >3 tool calls to complete
- Complex architecture discovered
- Bug root cause found
- Patterns/conventions documented

### Memory Workflow

```yaml
# Check for existing findings
Tool: mcp__serena__list_memories

# Read relevant memory
Tool: mcp__serena__read_memory
  memory_file_name: "auth-flow"

# Store new findings
Tool: mcp__serena__write_memory
  memory_file_name: "auth-flow"
  content: |
    # Auth Flow
    ## Entry Points
    - src/auth/login.ts:login()
    ## Key Components
    - JWT in src/auth/jwt.ts
```

### Naming Conventions

- `{feature}-architecture` - System overviews
- `{topic}-investigation` - Deep dive findings
- `{component}-known-issues` - Documented bugs
- `codebase-conventions` - Patterns and standards

---

## LSP Tools (Fallback)

Use when Serena tools are unavailable or for cursor-based operations.

| Operation | Use Case |
|-----------|----------|
| `goToDefinition` | Jump to declaration |
| `findReferences` | All usages (locations only) |
| `hover` | Type info and docs |
| `documentSymbol` | File symbol list |
| `workspaceSymbol` | Global symbol search |
| `incomingCalls` | Who calls this? |
| `outgoingCalls` | What does this call? |

### LSP Supported Languages

TypeScript/JavaScript, Python, Rust, Go, C/C++, Java, Kotlin, C#, Swift, PHP, Lua

---

## Guardrails

| Condition | Action |
|-----------|--------|
| New file to understand | Use `get_symbols_overview` first |
| Known symbol name | Use `find_symbol`, not Grep |
| Need usage context | Use `find_referencing_symbols` |
| After 3-5 searches | Use `think_about_collected_information` |
| Before code changes | Use `think_about_task_adherence` |
| Complex investigation | Store in memory |
| Serena/LSP fail | Fall back to Grep patterns |

## When to Delegate to Explore Agent

For open-ended exploration requiring multiple search rounds, use the `Task` tool with `subagent_type="Explore"`:

```yaml
Task:
  subagent_type: "Explore"
  prompt: "Explore how authentication works in this codebase"
  description: "Explore auth system"
```

Use Explore agent when:
- "What is the codebase structure?"
- "Where are errors handled?"
- "How does feature X work?" (when starting point unknown)
- Investigation requires many search iterations
- You're unsure where to start looking

---

## Bundled References

Load reference files when deeper guidance is needed. To load a reference, read the file at `references/<filename>.md`.

| Reference | Use When |
|-----------|----------|
| `references/serena-patterns.md` | Serena tool examples, name path patterns, memory patterns |
| `references/search-patterns.md` | Grep/Glob syntax, output modes, filtering |
| `references/language-specific.md` | Language-specific Grep fallbacks when Serena/LSP unavailable |
| `references/investigation-workflows.md` | Complex debugging, tracing, security audit, refactoring prep |
