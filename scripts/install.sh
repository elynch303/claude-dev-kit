#!/usr/bin/env bash
# Claude Dev Kit — Installer v2
#
# Copies .claude/ into your project, installs hook deps,
# then runs an MCP wizard to configure Claude's integrations
# (Git platform, ticket system, design tools, code search).
#
# Usage:
#   bash install.sh [target-directory]
#   TARGET=/path/to/project bash install.sh
#   bash install.sh --mcp-only    (skip file copy, just configure MCPs)

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✗${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}$*${NC}"; }
dim()     { echo -e "${DIM}$*${NC}"; }

ask() {
  # ask <variable-name> <prompt> [default]
  local var="$1" prompt="$2" default="${3:-}"
  local hint=""
  [[ -n "$default" ]] && hint=" ${DIM}[${default}]${NC}"
  echo -ne "  ${prompt}${hint}: "
  read -r "$var" </dev/tty
  if [[ -z "${!var}" && -n "$default" ]]; then
    eval "$var='$default'"
  fi
}

ask_yn() {
  # ask_yn <prompt> — returns 0 for yes, 1 for no
  echo -ne "  $1 ${DIM}[y/N]${NC}: "
  read -r _yn </dev/tty
  [[ "$_yn" =~ ^[Yy]$ ]]
}

menu() {
  # menu <variable-name> <prompt> <option1> <option2> ...
  local var="$1" prompt="$2"
  shift 2
  local options=("$@")
  echo -e "  ${BOLD}${prompt}${NC}"
  for i in "${!options[@]}"; do
    echo -e "    $((i+1))) ${options[$i]}"
  done
  echo -ne "  Choice [1-${#options[@]}]: "
  read -r _choice </dev/tty
  local idx=$(( _choice - 1 ))
  if [[ $idx -ge 0 && $idx -lt ${#options[@]} ]]; then
    eval "$var='${options[$idx]}'"
  else
    eval "$var='${options[0]}'"
  fi
}

multi_menu() {
  # multi_menu <array-variable-name> <prompt> <option1> <option2> ...
  local var="$1" prompt="$2"
  shift 2
  local options=("$@")
  echo -e "  ${BOLD}${prompt}${NC}"
  echo -e "  ${DIM}Enter numbers separated by spaces (e.g. 1 3)${NC}"
  for i in "${!options[@]}"; do
    echo -e "    $((i+1))) ${options[$i]}"
  done
  echo -ne "  Choices: "
  read -r _choices </dev/tty
  local -a selected=()
  for n in $_choices; do
    local idx=$(( n - 1 ))
    [[ $idx -ge 0 && $idx -lt ${#options[@]} ]] && selected+=("${options[$idx]}")
  done
  eval "$var=(\"\${selected[@]}\")"
}

require_claude_cli() {
  if ! command -v claude &>/dev/null; then
    warn "Claude CLI not found. MCP installation requires it."
    info "Install: https://claude.ai/code"
    return 1
  fi
  return 0
}

# ─── Main ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"
TARGET="${1:-${TARGET:-$(pwd)}}"
MCP_ONLY=false

[[ "${1:-}" == "--mcp-only" ]] && MCP_ONLY=true && TARGET="${TARGET:-$(pwd)}"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Claude Dev Kit — Installer      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
echo ""

# ─── Phase 1: File Installation ───────────────────────────────────────────────
if [[ "$MCP_ONLY" == "false" ]]; then
  header "Phase 1: Install .claude/ into your project"
  echo -e "  ${DIM}Source: $KIT_ROOT${NC}"
  echo -e "  ${DIM}Target: $TARGET${NC}"
  echo ""

  if [[ "${CI:-}" != "true" ]]; then
    ask_yn "Install .claude/ into $TARGET?" || { echo "Aborted."; exit 0; }
  fi

  # Backup existing .claude
  if [[ -d "$TARGET/.claude" ]]; then
    BACKUP="$TARGET/.claude.bak.$(date +%Y%m%d_%H%M%S)"
    warn "Existing .claude/ found — backing up to $(basename "$BACKUP")"
    mv "$TARGET/.claude" "$BACKUP"
  fi

  # Copy files
  info "Copying .claude/ ..."
  if command -v rsync &>/dev/null; then
    rsync -a --exclude='node_modules' --exclude='*.jsonl' \
      "$KIT_ROOT/.claude/" "$TARGET/.claude/"
  else
    cp -r "$KIT_ROOT/.claude" "$TARGET/.claude"
    rm -rf "$TARGET/.claude/hooks/skill-activation-prompt/node_modules"
  fi
  success ".claude/ installed"

  # Install hook dependencies
  HOOK_DIR="$TARGET/.claude/hooks/skill-activation-prompt"
  if [[ -f "$HOOK_DIR/package.json" ]]; then
    info "Installing skill-activation-prompt hook dependencies..."
    pushd "$HOOK_DIR" > /dev/null
    if command -v bun &>/dev/null; then
      bun install --silent
    elif command -v npm &>/dev/null; then
      npm install --silent
    else
      warn "Neither bun nor npm found. Run manually: cd $HOOK_DIR && npm install"
    fi
    popd > /dev/null
    success "Hook dependencies installed"
  fi
fi

# ─── Phase 2: MCP Wizard ──────────────────────────────────────────────────────
echo ""
header "Phase 2: Configure Claude MCP integrations"
echo -e "  ${DIM}MCPs extend Claude with tools for your Git platform, ticket system, and design tools.${NC}"
echo ""

if ! require_claude_cli; then
  warn "Skipping MCP setup — install the Claude CLI and re-run: bash $0 --mcp-only"
  echo ""
else

  # ── 2a. Git Platform ────────────────────────────────────────────────────────
  header "Git Platform"
  menu GIT_PLATFORM "Which Git platform do you use?" \
    "GitHub" \
    "GitLab" \
    "Bitbucket" \
    "Azure DevOps" \
    "None / Self-hosted"

  case "$GIT_PLATFORM" in
    "GitHub")
      echo ""
      info "Installing GitHub MCP..."
      echo -e "  ${DIM}Provides: issue/PR reading, repo search, file access via GitHub API${NC}"
      ask GITHUB_TOKEN "GitHub Personal Access Token (repo + read:org scopes)" ""
      if [[ -n "$GITHUB_TOKEN" ]]; then
        claude mcp add --scope project github \
          npx -y @modelcontextprotocol/server-github \
          --env GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" 2>/dev/null \
          && success "GitHub MCP installed" \
          || warn "GitHub MCP install failed — add manually with: claude mcp add github"
      else
        warn "No token provided — skipping GitHub MCP (add later with: claude mcp add github)"
      fi
      ;;
    "GitLab")
      echo ""
      info "Installing GitLab MCP..."
      ask GITLAB_TOKEN "GitLab Personal Access Token" ""
      ask GITLAB_URL "GitLab URL" "https://gitlab.com"
      if [[ -n "$GITLAB_TOKEN" ]]; then
        claude mcp add --scope project gitlab \
          npx -y @modelcontextprotocol/server-gitlab \
          --env GITLAB_PERSONAL_ACCESS_TOKEN="$GITLAB_TOKEN" \
          --env GITLAB_URL="$GITLAB_URL" 2>/dev/null \
          && success "GitLab MCP installed" \
          || warn "GitLab MCP install failed"
      fi
      ;;
    "None / Self-hosted")
      info "Skipping Git platform MCP"
      ;;
    *)
      warn "No official MCP for $GIT_PLATFORM yet — check https://github.com/modelcontextprotocol/servers"
      ;;
  esac

  # ── 2b. Ticket / Project Management ─────────────────────────────────────────
  echo ""
  header "Ticket / Project Management"
  menu TICKET_SYSTEM "Which ticket system do you use?" \
    "GitHub Issues (uses GitHub MCP above)" \
    "Linear" \
    "Jira" \
    "Notion" \
    "Trello" \
    "None"

  case "$TICKET_SYSTEM" in
    "Linear")
      echo ""
      info "Installing Linear MCP..."
      echo -e "  ${DIM}Provides: issue reading, project management, cycle tracking${NC}"
      ask LINEAR_KEY "Linear API Key (from Linear Settings → API)" ""
      if [[ -n "$LINEAR_KEY" ]]; then
        claude mcp add --scope project linear \
          npx -y @linear/mcp-server \
          --env LINEAR_API_KEY="$LINEAR_KEY" 2>/dev/null \
          && success "Linear MCP installed" \
          || warn "Linear MCP install failed — check: https://github.com/linear/mcp-server"
      fi
      ;;
    "Jira")
      echo ""
      info "Installing Jira MCP..."
      ask JIRA_URL "Jira URL (e.g. https://yourorg.atlassian.net)" ""
      ask JIRA_EMAIL "Jira account email" ""
      ask JIRA_TOKEN "Jira API Token (from id.atlassian.com/manage-profile/security/api-tokens)" ""
      if [[ -n "$JIRA_TOKEN" ]]; then
        claude mcp add --scope project jira \
          npx -y @modelcontextprotocol/server-jira \
          --env JIRA_URL="$JIRA_URL" \
          --env JIRA_EMAIL="$JIRA_EMAIL" \
          --env JIRA_TOKEN="$JIRA_TOKEN" 2>/dev/null \
          && success "Jira MCP installed" \
          || warn "Jira MCP install failed"
      fi
      ;;
    "Notion")
      echo ""
      info "Installing Notion MCP..."
      ask NOTION_TOKEN "Notion Integration Token (from notion.so/my-integrations)" ""
      if [[ -n "$NOTION_TOKEN" ]]; then
        claude mcp add --scope project notion \
          npx -y @modelcontextprotocol/server-notion \
          --env NOTION_API_KEY="$NOTION_TOKEN" 2>/dev/null \
          && success "Notion MCP installed" \
          || warn "Notion MCP install failed"
      fi
      ;;
    "None" | "GitHub Issues"*)
      info "Skipping ticket system MCP"
      ;;
    *)
      warn "No official MCP for $TICKET_SYSTEM yet"
      ;;
  esac

  # ── 2c. Design Tools ─────────────────────────────────────────────────────────
  echo ""
  header "Design Tools"
  multi_menu DESIGN_TOOLS "Which design tools do you use? (select all that apply)" \
    "Figma" \
    "Storybook (component library)" \
    "None"

  for tool in "${DESIGN_TOOLS[@]}"; do
    case "$tool" in
      "Figma")
        echo ""
        info "Installing Figma MCP..."
        echo -e "  ${DIM}Provides: read Figma files, inspect components, extract design tokens${NC}"
        ask FIGMA_TOKEN "Figma Personal Access Token (from figma.com/developers/apps)" ""
        if [[ -n "$FIGMA_TOKEN" ]]; then
          claude mcp add --scope project figma \
            npx -y figma-developer-mcp \
            --env FIGMA_API_KEY="$FIGMA_TOKEN" 2>/dev/null \
            && success "Figma MCP installed" \
            || warn "Figma MCP install failed — check: https://github.com/GLips/Figma-Context-MCP"
        fi
        ;;
      "Storybook"*)
        info "Storybook: run 'storybook dev' and Claude can access it via browser tools"
        ;;
    esac
  done

  # ── 2d. Always-On MCPs ────────────────────────────────────────────────────────
  echo ""
  header "Core MCPs (recommended for all projects)"

  if ask_yn "Install Context7 MCP? (instant access to up-to-date library docs)"; then
    claude mcp add --scope project context7 \
      npx -y @upstash/context7-mcp 2>/dev/null \
      && success "Context7 MCP installed" \
      || warn "Context7 MCP install failed"
  fi

  if ask_yn "Install Sequential Thinking MCP? (improves multi-step reasoning)"; then
    claude mcp add --scope project sequential-thinking \
      npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null \
      && success "Sequential Thinking MCP installed" \
      || warn "Sequential Thinking MCP install failed"
  fi

  if ask_yn "Install Filesystem MCP? (direct file access without Claude Code file tools)"; then
    claude mcp add --scope project filesystem \
      npx -y @modelcontextprotocol/server-filesystem "$TARGET" 2>/dev/null \
      && success "Filesystem MCP installed (scoped to $TARGET)" \
      || warn "Filesystem MCP install failed"
  fi

  # ── 2e. Serena (code navigation) ─────────────────────────────────────────────
  echo ""
  if command -v uvx &>/dev/null || command -v uv &>/dev/null; then
    if ask_yn "Install Serena MCP? (semantic code navigation — highly recommended for large codebases)"; then
      claude mcp add --scope project serena \
        uvx --from "serena[claude-code]" serena 2>/dev/null \
        && success "Serena MCP installed" \
        || warn "Serena MCP install failed — requires Python + uv: https://github.com/oraios/serena"
    fi
  else
    dim "  Serena MCP skipped — requires Python/uv (install uv from https://astral.sh/uv)"
  fi

fi # end require_claude_cli block

# ─── Phase 3: Summary ─────────────────────────────────────────────────────────
echo ""
header "Installation Complete 🎉"
echo ""

if [[ "$MCP_ONLY" == "false" ]]; then
  echo -e "  ${GREEN}✓${NC} .claude/ installed at $TARGET/.claude"
  echo -e "  ${GREEN}✓${NC} Hook dependencies installed"
fi

echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. ${CYAN}cd $TARGET${NC}"
echo ""
echo -e "  2. ${CYAN}Update CLAUDE.md${NC} with your project's stack and conventions."
echo -e "     ${DIM}(Or run /init in Claude Code to auto-generate it)${NC}"
echo ""
echo -e "  3. ${CYAN}Add tool permissions${NC} to .claude/settings.json for your build commands:"
echo -e '     ${DIM}e.g. "Bash(npm run:*)", "Bash(pytest:*)", "Bash(cargo:*)"${NC}'
echo ""
echo -e "  4. ${CYAN}Open Claude Code${NC} in your project and run:"
echo -e "     ${BOLD}/init${NC}          — auto-detect stack and configure agents"
echo -e "     ${BOLD}/primer${NC}        — prime Claude's project context"
echo -e "     ${BOLD}/pm:groom${NC}      — groom your GitHub/Linear issues"
echo -e "     ${BOLD}/dev <issue>${NC}   — implement your first feature autonomously"
echo ""
echo -e "  ${DIM}Docs: https://github.com/$(git -C "$KIT_ROOT" config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/.git//')${NC}"
echo ""
