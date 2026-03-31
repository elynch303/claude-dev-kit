#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d /tmp/claude-dev-kit-smoke-XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Expected file: $path"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -qF "$needle" "$file" || fail "Expected '$needle' in $file"
}

echo "Packing npm tarball..."
PACK_JSON="$TMP_ROOT/pack.json"
npm pack --json --cache "$TMP_ROOT/npm-cache" > "$PACK_JSON"
TARBALL_NAME="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); process.stdout.write(data[0].filename);" "$PACK_JSON")"
TARBALL_PATH="$ROOT/$TARBALL_NAME"
[[ -f "$TARBALL_PATH" ]] || fail "Tarball not found: $TARBALL_PATH"

echo "Checking packaged files..."
tar -tf "$TARBALL_PATH" > "$TMP_ROOT/tar-contents.txt"
assert_contains "$TMP_ROOT/tar-contents.txt" "package/bin/claude-dev-kit.js"
assert_contains "$TMP_ROOT/tar-contents.txt" "package/scripts/install.sh"
assert_contains "$TMP_ROOT/tar-contents.txt" "package/scripts/migrate.sh"
assert_contains "$TMP_ROOT/tar-contents.txt" "package/scripts/lib/merge-settings.js"

echo "Unpacking tarball..."
mkdir -p "$TMP_ROOT/unpacked"
tar -xzf "$TARBALL_PATH" -C "$TMP_ROOT/unpacked"
PKG_ROOT="$TMP_ROOT/unpacked/package"
INSTALL_SH="$PKG_ROOT/scripts/install.sh"

assert_file "$INSTALL_SH"
assert_file "$PKG_ROOT/scripts/migrate.sh"
assert_file "$PKG_ROOT/scripts/lib/merge-settings.js"

PROJECT_DIR="$TMP_ROOT/project"
mkdir -p "$PROJECT_DIR"
cat > "$PROJECT_DIR/package.json" <<'EOF'
{
  "name": "smoke-project",
  "private": true
}
EOF

echo "Running fresh install..."
CI=true bash "$INSTALL_SH" "$PROJECT_DIR"

assert_file "$PROJECT_DIR/.claude/.cdk-manifest"
assert_file "$PROJECT_DIR/.claude/settings.json"
assert_file "$PROJECT_DIR/CLAUDE.md"
assert_file "$PROJECT_DIR/CLAUDE.local.md.example"
assert_contains "$PROJECT_DIR/.gitignore" "# Claude Dev Kit — managed entries"

MODIFIED_FILE="$PROJECT_DIR/.claude/commands/dev.md"
assert_file "$MODIFIED_FILE"
printf '\n<!-- smoke-test-marker -->\n' >> "$MODIFIED_FILE"

echo "Running migration over modified managed file..."
CI=true bash "$INSTALL_SH" "$PROJECT_DIR"
assert_contains "$MODIFIED_FILE" "<!-- smoke-test-marker -->"

echo "Running MCP-only mode..."
MCP_ONLY_LOG="$TMP_ROOT/mcp-only.log"
(
  cd "$PROJECT_DIR"
  CI=true bash "$INSTALL_SH" --mcp-only
) | tee "$MCP_ONLY_LOG"

assert_file "$PROJECT_DIR/.claude/.cdk-manifest"
assert_file "$PROJECT_DIR/CLAUDE.md"
assert_contains "$MCP_ONLY_LOG" "cd $PROJECT_DIR"

rm -f "$TARBALL_PATH"

echo "Installer smoke test passed."
