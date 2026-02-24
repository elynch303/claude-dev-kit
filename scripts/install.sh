#!/usr/bin/env bash
# Claude Dev Kit — installer
# Copies the .claude directory into your project and sets up hooks.
#
# Usage:
#   ./scripts/install.sh [target-directory]
#   TARGET=/path/to/project ./scripts/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"
TARGET="${1:-${TARGET:-$(pwd)}}"

echo "Claude Dev Kit — installer"
echo "================================"
echo "Kit source : $KIT_ROOT"
echo "Target     : $TARGET"
echo ""

# Confirm
if [[ "${CI:-}" != "true" ]]; then
  read -rp "Install .claude/ into $TARGET? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# Backup existing .claude if present
if [[ -d "$TARGET/.claude" ]]; then
  BACKUP="$TARGET/.claude.bak.$(date +%Y%m%d_%H%M%S)"
  echo "Backing up existing .claude → $BACKUP"
  mv "$TARGET/.claude" "$BACKUP"
fi

# Copy .claude directory (exclude node_modules)
echo "Copying .claude/ ..."
if command -v rsync &>/dev/null; then
  rsync -a --exclude='node_modules' --exclude='*.jsonl' \
    "$KIT_ROOT/.claude/" "$TARGET/.claude/"
else
  cp -r "$KIT_ROOT/.claude" "$TARGET/.claude"
  rm -rf "$TARGET/.claude/hooks/skill-activation-prompt/node_modules"
fi

# Install skill-activation-prompt hook dependencies
HOOK_DIR="$TARGET/.claude/hooks/skill-activation-prompt"
if [[ -f "$HOOK_DIR/package.json" ]]; then
  echo "Installing hook dependencies..."
  pushd "$HOOK_DIR" > /dev/null
  if command -v npm &>/dev/null; then
    npm install --silent
  elif command -v bun &>/dev/null; then
    bun install --silent
  else
    echo "  Warning: neither npm nor bun found — install manually:"
    echo "  cd $HOOK_DIR && npm install"
  fi
  popd > /dev/null
fi

echo ""
echo "Done! Next steps:"
echo ""
echo "  1. Add project-specific allow rules to .claude/settings.json"
echo "     (your lint/test/build commands, e.g. 'Bash(npm run:*)')"
echo ""
echo "  2. Create .claude/CLAUDE.md (or edit root CLAUDE.md) with:"
echo "     - Stack overview"
echo "     - Lint/test/build commands"
echo "     - Coding conventions"
echo ""
echo "  3. (Optional) Copy an agent template from examples/agents/"
echo "     into .claude/agents/ and customize it for your stack."
echo ""
echo "  4. Open Claude Code in your project and run /primer"
echo ""
