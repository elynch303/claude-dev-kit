# Error Patterns Reference

This document describes the error pattern syntax used in language configs and provides common patterns for each supported language.

## Pattern Syntax

### Regex Basics

All patterns use Python `re` module compatible regular expressions:

| Syntax | Meaning | Example |
|--------|---------|---------|
| `.` | Any single character | `error.` matches "error:" |
| `.*` | Any characters (greedy) | `error.*` matches "error: something" |
| `.+` | One or more characters | `.+\.rs` matches "file.rs" |
| `\d` | Any digit | `\d+` matches "123" |
| `\s` | Any whitespace | `\s+` matches spaces/tabs |
| `()` | Capture group | `(.+):(\d+)` captures file and line |
| `(?:)` | Non-capturing group | `(?:error\|warning)` matches either |
| `\[` | Literal bracket | `\[E0308\]` matches "[E0308]" |
| `^` | Start of line | `^error:` matches line starting with "error:" |
| `$` | End of line | `\.rs$` matches lines ending in ".rs" |

### Capture Groups

Capture groups extract data from matched text:

```yaml
error_parsing:
  patterns:
    - regex: '(.+):(\d+):(\d+): (error|warning): (.+)'
      file: 1      # First capture group
      line: 2      # Second capture group
      column: 3    # Third capture group
      severity: 4  # Fourth capture group
      message: 5   # Fifth capture group
```

### Named Capture Groups

For clarity, use named groups:

```yaml
- regex: '(?P<file>.+):(?P<line>\d+):(?P<col>\d+)'
  file: file
  line: line
  column: col
```

## Rust Error Patterns

### Compiler Errors

```
error[E0308]: mismatched types
 --> src/main.rs:15:20
  |
15 |     let x: i32 = "hello";
  |            ---   ^^^^^^^ expected `i32`, found `&str`
```

Pattern:
```yaml
- regex: 'error\[E(\d+)\]:.*\n\s*--> (.+):(\d+):(\d+)'
  code: 1
  file: 2
  line: 3
  column: 4
```

### Common Rust Error Codes

| Code | Description | Auto-fixable |
|------|-------------|--------------|
| E0308 | Mismatched types | No |
| E0382 | Use of moved value | No |
| E0425 | Cannot find value in scope | No |
| E0433 | Failed to resolve (unresolved import) | No |
| E0502 | Cannot borrow as mutable | No |
| E0597 | Value does not live long enough | No |

### Rustfmt Output

```
Diff in /src/main.rs at line 5:
-fn main(){
+fn main() {
```

Pattern:
```yaml
- pattern: 'Diff in .+\.rs'
  action: format
```

## JavaScript/TypeScript Error Patterns

### TypeScript Compiler

```
src/utils.ts(10,5): error TS2322: Type 'string' is not assignable to type 'number'.
```

Pattern:
```yaml
- regex: '(.+)\((\d+),(\d+)\): error (TS\d+): (.+)'
  file: 1
  line: 2
  column: 3
  code: 4
  message: 5
```

### ESLint

```
/src/components/Button.tsx
  5:1   error  Unexpected var, use let or const  no-var
  12:10 error  Missing semicolon                 semi
```

Pattern:
```yaml
- regex: '^\s*(\d+):(\d+)\s+(error|warning)\s+(.+?)\s+(\S+)$'
  line: 1
  column: 2
  severity: 3
  message: 4
  rule: 5
```

### Fixable ESLint Errors

```
✖ 5 problems (5 errors, 0 warnings)
  3 errors and 0 warnings potentially fixable with the `--fix` option.
```

Pattern:
```yaml
- pattern: '\d+ errors? and \d+ warnings? potentially fixable'
  action: lint_fix
```

## Python Error Patterns

### Python Traceback

```
Traceback (most recent call last):
  File "src/main.py", line 10, in <module>
    result = process(data)
TypeError: process() takes 0 positional arguments but 1 was given
```

Pattern:
```yaml
- regex: 'File "(.+)", line (\d+)'
  file: 1
  line: 2
```

### Black Formatter

```
would reformat src/utils.py
would reformat tests/test_main.py
Oh no! 💥 💔 💥
2 files would be reformatted.
```

Pattern:
```yaml
- regex: 'would reformat (.+\.py)'
  file: 1
```

### Ruff/Flake8

```
src/main.py:10:5: E501 Line too long (120 > 88 characters)
src/main.py:15:1: F401 'os' imported but unused
```

Pattern:
```yaml
- regex: '(.+\.py):(\d+):(\d+): ([A-Z]\d+) (.+)'
  file: 1
  line: 2
  column: 3
  code: 4
  message: 5
```

## C++ Error Patterns

### GCC/Clang

```
src/main.cpp:15:10: error: use of undeclared identifier 'foo'
    int x = foo;
            ^
```

Pattern:
```yaml
- regex: '(.+\.(cpp|cc|cxx|c|h|hpp)):(\d+):(\d+): (error|warning): (.+)'
  file: 1
  line: 3
  column: 4
  severity: 5
  message: 6
```

### MSVC

```
src\main.cpp(15): error C2065: 'foo': undeclared identifier
```

Pattern:
```yaml
- regex: '(.+\.(cpp|cc|cxx|c|h|hpp))\((\d+)\): (error|warning) (C\d+): (.+)'
  file: 1
  line: 3
  severity: 4
  code: 5
  message: 6
```

### Linker Errors

```
/usr/bin/ld: main.o: undefined reference to `foo()'
```

Pattern:
```yaml
- regex: 'undefined reference to `(.+)'''
  symbol: 1
```

## Pattern Precedence

1. **Bail patterns are checked first** - If any bail pattern matches, stop immediately
2. **Error parsing patterns** - Extract file:line:column for reporting
3. **Fix patterns** - Match against fixable errors

## Testing Patterns

To test a pattern against sample output:

```python
import re

pattern = r'error\[E(\d+)\]:.*\n\s*--> (.+):(\d+):(\d+)'
text = """error[E0308]: mismatched types
 --> src/main.rs:15:20"""

match = re.search(pattern, text)
if match:
    print(f"Code: {match.group(1)}")    # E0308
    print(f"File: {match.group(2)}")    # src/main.rs
    print(f"Line: {match.group(3)}")    # 15
    print(f"Col: {match.group(4)}")     # 20
```

## Common Pitfalls

1. **Escaping backslashes** - In YAML, use `\\` for literal backslash
2. **Greedy matching** - Use `.*?` for non-greedy matching
3. **Multiline patterns** - Use `\n` or `(?s)` flag for multiline
4. **Special characters** - Escape `[`, `]`, `(`, `)`, `.`, `*`, `+`, `?`
