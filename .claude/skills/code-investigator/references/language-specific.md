# Language-Specific Investigation Patterns

Search patterns and common locations for codebases. Use these Grep patterns as **fallbacks** when Serena and LSP tools are unavailable.

---

## Tool Priority (Serena First)

**Primary:** Use Serena MCP tools for semantic operations:
- `mcp__serena__find_symbol` - Pattern-based symbol discovery
- `mcp__serena__get_symbols_overview` - File structure
- `mcp__serena__find_referencing_symbols` - References with snippets
- `mcp__serena__search_for_pattern` - Filtered regex search

**Secondary:** Use LSP when Serena unavailable or for cursor-based ops:

| Operation | Use Case |
|-----------|----------|
| `goToDefinition` | Find symbol declaration |
| `findReferences` | Find all usages |
| `hover` | Get type info + docs |
| `documentSymbol` | List symbols in file |
| `workspaceSymbol` | Search symbols globally |
| `goToImplementation` | Find implementations |
| `incomingCalls` | Who calls this? |
| `outgoingCalls` | What does this call? |

**Fallback:** Use Grep patterns below only when:
1. Serena tools return no results
2. LSP returns "No server available for file type"
3. LSP returns no results
4. Searching for non-symbol patterns (comments, TODOs, partial matches)

---

## TypeScript / JavaScript

**LSP:** `typescript-lsp` - Full support for `.ts`, `.tsx`, `.js`, `.jsx`, `.mts`, `.cts`, `.mjs`, `.cjs`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `src/index.ts`, `src/main.ts`, `index.ts`, `package.json` "main" |
| Configuration | `tsconfig.json`, `.env`, `config/` |
| Types/Interfaces | `src/types/`, `types/`, `*.d.ts`, `src/**/*.types.ts` |
| API routes | `src/routes/`, `src/api/`, `pages/api/` (Next.js) |
| Components | `src/components/`, `components/` |
| Utilities | `src/utils/`, `src/lib/`, `src/helpers/` |
| Tests | `__tests__/`, `*.test.ts`, `*.spec.ts`, `test/` |
| Constants | `src/constants/`, `src/config/` |

### Symbol Patterns (Grep Fallback)

```
# Interface definition
Grep pattern="^\s*(export\s+)?interface\s+InterfaceName" type="ts"

# Type alias
Grep pattern="^\s*(export\s+)?type\s+TypeName\s*=" type="ts"

# React component (function)
Grep pattern="^\s*(export\s+)?(default\s+)?function\s+ComponentName" type="tsx"
Grep pattern="^\s*const\s+ComponentName\s*[:=]\s*(React\.)?FC" type="tsx"

# React component (class)
Grep pattern="class\s+ComponentName\s+extends\s+(React\.)?(Component|PureComponent)" type="tsx"

# Hook definition
Grep pattern="^\s*(export\s+)?(const|function)\s+use[A-Z]\w+" type="ts"

# Enum
Grep pattern="^\s*(export\s+)?(const\s+)?enum\s+EnumName" type="ts"

# Decorator usage
Grep pattern="^\s*@DecoratorName" type="ts"
```

### Dependency Tracing

```
# Find all imports of a module
Grep pattern="import.*from\s+['\"].*moduleName['\"]" type="ts"

# Find re-exports
Grep pattern="export\s+\*\s+from" type="ts"
Grep pattern="export\s+\{[^}]+\}\s+from" type="ts"

# Find dynamic imports
Grep pattern="import\(['\"]" type="ts"

# Find require calls
Grep pattern="require\(['\"].*moduleName['\"]\)" type="js"
```

### React-Specific

```
# useState calls
Grep pattern="useState<?\w*>?\s*\(" type="tsx"

# useEffect with dependencies
Grep pattern="useEffect\s*\(" -A 10 output_mode="content" type="tsx"

# Context usage
Grep pattern="(createContext|useContext)\s*[<\(]" type="tsx"

# Props interface for component
Grep pattern="interface\s+\w+Props" type="ts"
Grep pattern="type\s+\w+Props\s*=" type="ts"
```

---

## Python

**LSP:** `pyright-lsp` - Full support for `.py`, `.pyi`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `main.py`, `app.py`, `__main__.py`, `manage.py` |
| Configuration | `config.py`, `settings.py`, `pyproject.toml`, `setup.py` |
| Models | `models/`, `models.py`, `schemas/` |
| API routes | `routes/`, `views/`, `api/`, `endpoints/` |
| Utilities | `utils/`, `helpers/`, `lib/` |
| Tests | `tests/`, `test_*.py`, `*_test.py` |
| Types | `types.py`, `typing.py`, `schemas/` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*class\s+ClassName\s*[\(:]" type="py"

# Function definition
Grep pattern="^\s*(async\s+)?def\s+function_name\s*\(" type="py"

# Method in class (indented def)
Grep pattern="^\s{4}(async\s+)?def\s+method_name" type="py"

# Decorator definition
Grep pattern="^\s*def\s+decorator_name\s*\(.*\)\s*:" -A 5 output_mode="content" type="py"

# Dataclass
Grep pattern="@dataclass" -A 10 output_mode="content" type="py"

# Pydantic model
Grep pattern="class\s+\w+\(.*BaseModel.*\):" type="py"

# Type alias
Grep pattern="^\s*\w+\s*=\s*(TypeVar|Union|Optional|List|Dict)" type="py"
```

### Dependency Tracing

```
# Import statements
Grep pattern="^from\s+\S+\s+import" type="py"
Grep pattern="^import\s+\S+" type="py"

# Relative imports
Grep pattern="^from\s+\.\S*\s+import" type="py"

# Find all usages of a function
Grep pattern="function_name\s*\(" type="py"
```

### Django-Specific

```
# Model definition
Grep pattern="class\s+\w+\(.*models\.Model.*\):" type="py"

# View definition
Grep pattern="(def|class)\s+\w+(View|Viewset|APIView)" type="py"

# URL pattern
Grep pattern="path\(.*,\s*\w+.*\)" type="py"

# Migration operations
Grep pattern="migrations\.(\w+)\s*\(" type="py"
```

### FastAPI-Specific

```
# Route definitions
Grep pattern="@(app|router)\.(get|post|put|delete|patch)\s*\(" type="py"

# Dependency injection
Grep pattern="Depends\s*\(" type="py"

# Response models
Grep pattern="response_model\s*=" type="py"
```

---

## Rust

**LSP:** `rust-analyzer-lsp` - Full support for `.rs`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `src/main.rs`, `src/lib.rs` |
| Configuration | `Cargo.toml`, `config/` |
| Modules | `src/*/mod.rs`, `src/*.rs` |
| Types | `src/types.rs`, `src/models/` |
| Errors | `src/error.rs`, `src/errors/` |
| Tests | `tests/`, `#[cfg(test)]` modules |
| Macros | `src/macros.rs`, files with `macro_rules!` |

### Symbol Patterns (Grep Fallback)

```
# Function definition
Grep pattern="^\s*(pub\s+)?(async\s+)?fn\s+function_name" type="rust"

# Struct definition
Grep pattern="^\s*(pub\s+)?struct\s+StructName" type="rust"

# Enum definition
Grep pattern="^\s*(pub\s+)?enum\s+EnumName" type="rust"

# Trait definition
Grep pattern="^\s*(pub\s+)?trait\s+TraitName" type="rust"

# Impl block
Grep pattern="^\s*impl(<[^>]+>)?\s+(StructName|TraitName)" type="rust"

# Macro definition
Grep pattern="macro_rules!\s+macro_name" type="rust"

# Derive macros
Grep pattern="#\[derive\([^)]*DeriveName" type="rust"

# Attribute macros
Grep pattern="#\[(tokio::main|async_trait|test)\]" type="rust"
```

### Dependency Tracing

```
# Use statements
Grep pattern="^use\s+.*::\w+;" type="rust"
Grep pattern="^use\s+crate::" type="rust"

# Module declarations
Grep pattern="^(pub\s+)?mod\s+\w+;" type="rust"

# External crate usage (exclude std/crate/self/super)
Grep pattern="^use\s+\w+::" type="rust"
```

### Error Handling

```
# Result types
Grep pattern="Result<[^>]+>" type="rust"

# Error definitions
Grep pattern="#\[derive\([^)]*Error" type="rust"
Grep pattern="impl\s+.*Error\s+for" type="rust"

# ? operator usage
Grep pattern="\?\s*;" type="rust"
Grep pattern="\.ok\(\)\?" type="rust"

# unwrap/expect (potential panics)
Grep pattern="\.(unwrap|expect)\s*\(" type="rust"
```

### Async/Tokio

```
# Async functions
Grep pattern="async\s+fn" type="rust"

# Spawn tasks
Grep pattern="tokio::spawn\s*\(" type="rust"
Grep pattern="\.spawn\s*\(" type="rust"

# Await points
Grep pattern="\.await" type="rust"
```

---

## Go

**LSP:** `gopls-lsp` - Full support for `.go`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `main.go`, `cmd/*/main.go` |
| Configuration | `config/`, `internal/config/` |
| Handlers | `handlers/`, `internal/handlers/`, `api/` |
| Models | `models/`, `internal/models/`, `pkg/models/` |
| Utilities | `pkg/`, `internal/utils/`, `lib/` |
| Tests | `*_test.go` (same directory as source) |
| Interfaces | Often in same file or `interfaces.go` |

### Symbol Patterns (Grep Fallback)

```
# Function definition
Grep pattern="^func\s+FunctionName\s*\(" type="go"

# Method definition
Grep pattern="^func\s+\([^)]+\)\s+MethodName\s*\(" type="go"

# Struct definition
Grep pattern="^type\s+StructName\s+struct" type="go"

# Interface definition
Grep pattern="^type\s+InterfaceName\s+interface" type="go"

# Type alias
Grep pattern="^type\s+TypeName\s+=?\s+\w+" type="go"

# Constant block
Grep pattern="^const\s+\(" -A 20 output_mode="content" type="go"

# Variable block
Grep pattern="^var\s+\(" -A 20 output_mode="content" type="go"
```

### Dependency Tracing

```
# Import statements (in specific file)
Grep pattern="^\s*\".*\"" path="path/to/file.go" output_mode="content"

# Find interface implementations
Grep pattern="func\s+\([^)]+\s+\*?TypeName\)\s+" type="go"

# Find all calls to a function
Grep pattern="FunctionName\s*\(" type="go"
```

### Error Handling

```
# Error checks
Grep pattern="if\s+err\s*!=\s*nil" type="go"

# Error returns
Grep pattern="return.*,?\s*err\s*$" type="go"

# Error wrapping
Grep pattern="(fmt\.Errorf|errors\.Wrap|errors\.New)\s*\(" type="go"

# Custom error types
Grep pattern="func\s+\([^)]+Error\)\s+Error\s*\(" type="go"
```

### Concurrency

```
# Goroutines
Grep pattern="go\s+func\s*\(" type="go"
Grep pattern="go\s+\w+\s*\(" type="go"

# Channels
Grep pattern="(make\s*\(\s*chan|<-\s*\w+|\w+\s*<-)" type="go"

# Mutex usage
Grep pattern="(\.Lock\(\)|\.Unlock\(\)|\.RLock\(\)|\.RUnlock\(\))" type="go"

# WaitGroup
Grep pattern="sync\.WaitGroup" type="go"
```

### HTTP/Web

```
# Handler functions
Grep pattern="func.*http\.ResponseWriter.*\*http\.Request" type="go"

# Route registration
Grep pattern="\.(HandleFunc|Handle|Get|Post|Put|Delete)\s*\(" type="go"

# Middleware
Grep pattern="func.*http\.Handler.*http\.Handler" type="go"
```

---

## C / C++

**LSP:** `clangd-lsp` - Full support for `.c`, `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `main.cpp`, `main.c`, `src/main.cpp` |
| Headers | `include/`, `src/*.h`, `*.hpp` |
| Configuration | `CMakeLists.txt`, `Makefile`, `meson.build` |
| Tests | `tests/`, `test/`, `*_test.cpp` |
| Libraries | `lib/`, `src/lib/` |

### Symbol Patterns (Grep Fallback)

```
# Function definition
Grep pattern="^\s*(\w+\s+)+FunctionName\s*\(" glob="*.{c,cpp,cc,cxx}"

# Class definition
Grep pattern="^\s*class\s+ClassName" glob="*.{cpp,hpp,h}"

# Struct definition
Grep pattern="^\s*struct\s+StructName" glob="*.{c,cpp,h,hpp}"

# Template class
Grep pattern="^\s*template\s*<.*>\s*class\s+ClassName" glob="*.{cpp,hpp}"

# Namespace
Grep pattern="^\s*namespace\s+NamespaceName" glob="*.{cpp,hpp}"

# Macro definition
Grep pattern="^\s*#define\s+MACRO_NAME" glob="*.{c,cpp,h,hpp}"

# Include statements
Grep pattern="#include\s+[<\"].*[>\"]" glob="*.{c,cpp,h,hpp}"
```

### Memory Management

```
# new/delete
Grep pattern="\b(new|delete)\s+" glob="*.{cpp,cc,cxx}"

# malloc/free
Grep pattern="\b(malloc|free|realloc|calloc)\s*\(" glob="*.{c,cpp}"

# Smart pointers
Grep pattern="(unique_ptr|shared_ptr|weak_ptr|make_unique|make_shared)" glob="*.{cpp,hpp}"
```

---

## Java

**LSP:** `jdtls-lsp` - Full support for `.java`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `**/Main.java`, `**/Application.java` |
| Configuration | `pom.xml`, `build.gradle`, `application.properties` |
| Controllers | `**/controller/`, `**/controllers/` |
| Services | `**/service/`, `**/services/` |
| Models | `**/model/`, `**/entity/`, `**/domain/` |
| Repositories | `**/repository/`, `**/dao/` |
| Tests | `src/test/`, `**/*Test.java` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*(public\s+)?(abstract\s+)?class\s+ClassName" type="java"

# Interface definition
Grep pattern="^\s*(public\s+)?interface\s+InterfaceName" type="java"

# Method definition
Grep pattern="^\s*(public|private|protected)?\s*(\w+\s+)+methodName\s*\(" type="java"

# Annotation usage
Grep pattern="^\s*@AnnotationName" type="java"

# Enum definition
Grep pattern="^\s*(public\s+)?enum\s+EnumName" type="java"

# Package declaration
Grep pattern="^package\s+[\w\.]+;" type="java"
```

### Spring-Specific

```
# Controller endpoints
Grep pattern="@(GetMapping|PostMapping|PutMapping|DeleteMapping|RequestMapping)" type="java"

# Service/Component
Grep pattern="@(Service|Component|Repository|Controller|RestController)" type="java"

# Dependency injection
Grep pattern="@(Autowired|Inject)" type="java"

# Configuration
Grep pattern="@(Configuration|Bean|Value)" type="java"
```

---

## Kotlin

**LSP:** `kotlin-lsp` - Full support for `.kt`, `.kts`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `**/Main.kt`, `**/Application.kt` |
| Configuration | `build.gradle.kts`, `settings.gradle.kts` |
| Data classes | `**/model/`, `**/dto/` |
| Tests | `src/test/`, `**/*Test.kt` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*(open\s+|abstract\s+|data\s+)?class\s+ClassName" type="kotlin"

# Function definition
Grep pattern="^\s*(suspend\s+)?fun\s+functionName" type="kotlin"

# Object declaration
Grep pattern="^\s*object\s+ObjectName" type="kotlin"

# Interface definition
Grep pattern="^\s*interface\s+InterfaceName" type="kotlin"

# Extension function
Grep pattern="^\s*fun\s+\w+\.extensionName" type="kotlin"

# Data class
Grep pattern="^\s*data\s+class\s+ClassName" type="kotlin"
```

---

## C#

**LSP:** `csharp-lsp` - Full support for `.cs`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `Program.cs`, `Startup.cs` |
| Configuration | `*.csproj`, `appsettings.json`, `web.config` |
| Controllers | `Controllers/` |
| Models | `Models/`, `Entities/` |
| Services | `Services/` |
| Tests | `*.Tests/`, `**/*Tests.cs` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*(public\s+)?(partial\s+)?(abstract\s+)?class\s+ClassName" type="cs"

# Interface definition
Grep pattern="^\s*(public\s+)?interface\s+IInterfaceName" type="cs"

# Method definition
Grep pattern="^\s*(public|private|protected|internal)\s+(\w+\s+)+MethodName\s*\(" type="cs"

# Property definition
Grep pattern="^\s*(public|private|protected)\s+\w+\s+PropertyName\s*\{" type="cs"

# Namespace
Grep pattern="^\s*namespace\s+[\w\.]+" type="cs"

# Attribute usage
Grep pattern="^\s*\[AttributeName" type="cs"
```

### ASP.NET-Specific

```
# Controller actions
Grep pattern="\[(HttpGet|HttpPost|HttpPut|HttpDelete|Route)\]" type="cs"

# Dependency injection
Grep pattern="(services\.Add|IServiceCollection)" type="cs"
```

---

## Swift

**LSP:** `swift-lsp` - Full support for `.swift`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `main.swift`, `App.swift`, `*App.swift` |
| Configuration | `Package.swift`, `*.xcodeproj` |
| Models | `Models/`, `*Model.swift` |
| Views | `Views/`, `*View.swift` |
| Controllers | `Controllers/`, `*ViewController.swift` |
| Tests | `Tests/`, `*Tests.swift` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*(public\s+|open\s+|final\s+)?class\s+ClassName" type="swift"

# Struct definition
Grep pattern="^\s*(public\s+)?struct\s+StructName" type="swift"

# Protocol definition
Grep pattern="^\s*(public\s+)?protocol\s+ProtocolName" type="swift"

# Function definition
Grep pattern="^\s*(public\s+|private\s+)?func\s+functionName" type="swift"

# Enum definition
Grep pattern="^\s*(public\s+)?enum\s+EnumName" type="swift"

# Extension
Grep pattern="^\s*extension\s+TypeName" type="swift"
```

---

## PHP

**LSP:** `php-lsp` - Full support for `.php`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `index.php`, `public/index.php` |
| Configuration | `composer.json`, `config/`, `.env` |
| Controllers | `app/Http/Controllers/`, `src/Controller/` |
| Models | `app/Models/`, `src/Entity/` |
| Routes | `routes/`, `config/routes.php` |
| Tests | `tests/`, `**/*Test.php` |

### Symbol Patterns (Grep Fallback)

```
# Class definition
Grep pattern="^\s*(abstract\s+)?class\s+ClassName" type="php"

# Interface definition
Grep pattern="^\s*interface\s+InterfaceName" type="php"

# Trait definition
Grep pattern="^\s*trait\s+TraitName" type="php"

# Function definition
Grep pattern="^\s*(public|private|protected)?\s*function\s+functionName" type="php"

# Namespace
Grep pattern="^\s*namespace\s+[\w\\\\]+;" type="php"

# Use statements
Grep pattern="^\s*use\s+[\w\\\\]+;" type="php"
```

### Laravel-Specific

```
# Route definitions
Grep pattern="Route::(get|post|put|delete|patch)\s*\(" type="php"

# Eloquent models
Grep pattern="class\s+\w+\s+extends\s+Model" type="php"

# Blade directives
Grep pattern="@(if|foreach|extends|section|yield)" glob="*.blade.php"
```

---

## Lua

**LSP:** `lua-lsp` - Full support for `.lua`

### Project Structure (Common Locations)

| Looking For | Check First |
|-------------|-------------|
| Entry point | `main.lua`, `init.lua` |
| Configuration | `config.lua`, `.luacheckrc` |
| Modules | `lua/`, `lib/` |
| Tests | `spec/`, `tests/`, `*_spec.lua` |

### Symbol Patterns (Grep Fallback)

```
# Function definition (global)
Grep pattern="^\s*function\s+functionName\s*\(" type="lua"

# Function definition (local)
Grep pattern="^\s*local\s+function\s+functionName\s*\(" type="lua"

# Module table
Grep pattern="^\s*local\s+M\s*=\s*\{\}" type="lua"

# Require statement
Grep pattern="require\s*\(['\"]" type="lua"

# Return module
Grep pattern="^return\s+\w+" type="lua"
```

### Neovim-Specific

```
# Plugin setup
Grep pattern="\.setup\s*\(" type="lua"

# Keymaps
Grep pattern="vim\.keymap\.set" type="lua"

# Autocommands
Grep pattern="vim\.api\.nvim_create_autocmd" type="lua"
```

---

## Cross-Language Patterns

### Find All Entry Points

```
Grep pattern="(^func\s+main|^def\s+main|if\s+__name__.*__main__|^fn\s+main|int\s+main|void\s+main)" glob="*.{go,py,rs,c,cpp,java}"
```

### Find Configuration Loading

```
Grep pattern="(load.*config|read.*config|parse.*config|config\.(load|read|parse))" -i=true
```

### Find Database Queries

```
Grep pattern="(SELECT|INSERT|UPDATE|DELETE|\.query|\.execute|\.find|\.findOne|\.aggregate)" -i=true
```

### Find API Endpoints

```
Grep pattern="(@(app|router)\.(get|post)|\.HandleFunc|#\[route|path\(|@GetMapping|@PostMapping)"
```

### Find Test Files

```
Glob pattern="**/*test*"
Glob pattern="**/*spec*"
Glob pattern="**/*Test.*"
```
