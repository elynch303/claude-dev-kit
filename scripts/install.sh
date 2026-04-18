#!/usr/bin/env bash
# Claude Dev Kit — Installer v2.2
#
# Copies .claude/ into your project, installs hook deps,
# then runs an MCP wizard to configure Claude's integrations
# (Git platform, ticket system, design tools, code search).
#
# Usage:
#   bash install.sh [--phase=install|update|mcp] [target-directory]
#   TARGET=/path/to/project bash install.sh
#   bash install.sh --mcp-only    (alias for --phase=mcp)

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

# Run a claude mcp add command, logging output, warn on failure
mcp_add() {
  local name="$1"; shift
  local log="$LOG_FILE"
  if claude mcp add "$@" >> "$log" 2>&1; then
    success "$name MCP installed"
  else
    warn "$name MCP install failed — see $log for details"
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Arg parsing: --phase=install|update|mcp, --mcp-only (legacy alias) ───────
PHASE="install"
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --phase=install) PHASE="install" ;;
    --phase=update)  PHASE="update"  ;;
    --phase=mcp)     PHASE="mcp"     ;;
    --mcp-only)      PHASE="mcp"     ;;  # backward-compat alias
    *) POSITIONAL_ARGS+=("$arg")     ;;
  esac
done

TARGET="${POSITIONAL_ARGS[0]:-${TARGET:-$(pwd)}}"

# Derive legacy MCP_ONLY for sections that still check it
MCP_ONLY=false
[[ "$PHASE" == "mcp" ]] && MCP_ONLY=true

# Install log — all subprocess output goes here instead of being suppressed
LOG_FILE="$TARGET/.claude/install.log"

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Claude Dev Kit — Installer      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
echo ""

# ─── Phase: update (migration only, non-interactive) ─────────────────────────
if [[ "$PHASE" == "update" ]]; then
  header "Update: pulling in latest agents, skills, and hooks"
  echo -e "  ${DIM}Source: $KIT_ROOT${NC}"
  echo -e "  ${DIM}Target: $TARGET${NC}"
  echo ""

  if ! CI=true bash "$SCRIPT_DIR/migrate.sh" "$KIT_ROOT" "$TARGET"; then
    error "Migration failed — check output above"
    exit 1
  fi

  # Ensure log file exists now that .claude/ is present
  mkdir -p "$TARGET/.claude"
  : > "$LOG_FILE"

  # Install hook dependencies
  HOOK_DIR="$TARGET/.claude/hooks/skill-activation-prompt"
  if [[ -f "$HOOK_DIR/package.json" ]]; then
    info "Installing skill-activation-prompt hook dependencies..."
    pushd "$HOOK_DIR" > /dev/null
    if command -v bun &>/dev/null; then
      if ! bun install --silent >> "$LOG_FILE" 2>&1; then
        warn "bun install failed — see $LOG_FILE for details"
      fi
    elif command -v npm &>/dev/null; then
      if ! npm install --silent >> "$LOG_FILE" 2>&1; then
        warn "npm install failed — see $LOG_FILE for details"
      fi
    else
      warn "Neither bun nor npm found. Run manually: cd $HOOK_DIR && npm install"
    fi
    popd > /dev/null
    success "Hook dependencies installed"
  fi

  echo ""
  header "Update Complete"
  echo ""
  echo -e "  ${GREEN}✓${NC} .claude/ updated in $TARGET/.claude"
  echo -e "  ${DIM}  User-customized files were preserved${NC}"
  echo ""
  exit 0
fi

# ─── Phase 1: File Installation ───────────────────────────────────────────────
if [[ "$MCP_ONLY" == "false" ]]; then
  header "Phase 1: Install .claude/ into your project"
  echo -e "  ${DIM}Source: $KIT_ROOT${NC}"
  echo -e "  ${DIM}Target: $TARGET${NC}"
  echo ""

  if [[ "${CI:-}" != "true" ]]; then
    ask_yn "Install .claude/ into $TARGET?" || { echo "Aborted."; exit 0; }
  fi

  # ── Delegate all .claude/ file management to the migration tool ──────────────
  # migrate.sh handles: categorization, conflict resolution, settings.json merge,
  # CLAUDE.md merge, and manifest maintenance. It is safe to run standalone.
  if bash "$SCRIPT_DIR/migrate.sh" "$KIT_ROOT" "$TARGET"; then
    : # migrate.sh prints its own success messages
  else
    error "Migration failed — check output above"
    exit 1
  fi

  # Ensure log directory + file exist now that .claude/ is present
  mkdir -p "$TARGET/.claude"
  : > "$LOG_FILE"

  # ── Inject .gitignore entries into target project ────────────────────────────
  TARGET_GITIGNORE="$TARGET/.gitignore"
  GITIGNORE_MARKER="# Claude Dev Kit — managed entries"
  if [[ -f "$TARGET_GITIGNORE" ]] && grep -qF "$GITIGNORE_MARKER" "$TARGET_GITIGNORE" 2>/dev/null; then
    info ".gitignore already contains CDK entries — skipping"
  else
    info "Adding .gitignore entries..."
    cat >> "$TARGET_GITIGNORE" <<'EOF'

# Claude Dev Kit — managed entries
# settings.json may contain MCP API tokens written by install.sh — never commit it.
.claude/settings.json
# Audit log, install log, and migration manifest contain local paths — no need to track.
.claude/audit.log
.claude/install.log
.claude/.cdk-manifest
# Personal Claude overrides — machine-local, never shared with teammates.
CLAUDE.local.md
EOF
    success ".gitignore updated"
  fi

  # ── Copy CLAUDE.local.md.example if not present ──────────────────────────────
  EXAMPLE_SRC="$KIT_ROOT/CLAUDE.local.md.example"
  EXAMPLE_DEST="$TARGET/CLAUDE.local.md.example"
  if [[ -f "$EXAMPLE_SRC" && ! -f "$EXAMPLE_DEST" ]]; then
    cp "$EXAMPLE_SRC" "$EXAMPLE_DEST"
    info "CLAUDE.local.md.example added — copy to CLAUDE.local.md for personal preferences"
  fi

  # ── Install hook dependencies ─────────────────────────────────────────────
  HOOK_DIR="$TARGET/.claude/hooks/skill-activation-prompt"
  if [[ -f "$HOOK_DIR/package.json" ]]; then
    info "Installing skill-activation-prompt hook dependencies..."
    pushd "$HOOK_DIR" > /dev/null
    if command -v bun &>/dev/null; then
      if ! bun install --silent >> "$LOG_FILE" 2>&1; then
        warn "bun install failed — see $LOG_FILE for details"
      fi
    elif command -v npm &>/dev/null; then
      if ! npm install --silent >> "$LOG_FILE" 2>&1; then
        warn "npm install failed — see $LOG_FILE for details"
      fi
    else
      warn "Neither bun nor npm found. Run manually: cd $HOOK_DIR && npm install"
    fi
    popd > /dev/null
    success "Hook dependencies installed"
  fi

  # ── Validation gates hook note ────────────────────────────────────────────────
  info "Validation gates hook available (.claude/hooks/stop/validation_gates.py)"
  dim "  Auto-runs lint, security, typecheck, and build checks on session end."
  dim "  Already registered in settings.json.example — copy that file to enable."
  dim "  Configure per-gate: edit 'stopGates' in .claude/settings.json"

fi

# ─── Phase 1.5: Agent Pack Selection ──────────────────────────────────────────
# Optional agent packs extend the kit with specialist agents for specific domains.
# Some packs require additional MCPs (e.g. Designer requires the Figma MCP).

DESIGNER_PACK_SELECTED=false

if [[ "$MCP_ONLY" == "false" && "${CI:-}" != "true" ]]; then
  echo ""
  header "Phase 1.5: Optional agent packs"
  echo -e "  ${DIM}Agent packs add specialist agents for a domain. You can skip now and add later.${NC}"
  echo ""

  multi_menu AGENT_PACKS "Which agent packs do you want to enable? (select all that apply)" \
    "Designer — Figma integration, wireframing, design tokens (requires Figma MCP)" \
    "DevOps — deployment, infrastructure, CI/CD agents" \
    "Data — analytics, reporting, data pipeline agents" \
    "All of the above" \
    "Unsure — analyze my project and recommend" \
    "None / skip for now"

  # Expand "All" selection
  for pack in "${AGENT_PACKS[@]}"; do
    if [[ "$pack" == "All of the above" ]]; then
      AGENT_PACKS=(
        "Designer — Figma integration, wireframing, design tokens (requires Figma MCP)"
        "DevOps — deployment, infrastructure, CI/CD agents"
        "Data — analytics, reporting, data pipeline agents"
      )
      break
    fi
  done

  # Handle "Unsure — analyze my project"
  for pack in "${AGENT_PACKS[@]}"; do
    if [[ "$pack" == "Unsure"* ]]; then
      echo ""
      info "Analyzing project to recommend agent packs..."
      ANALYSIS=""
      if command -v gemini &>/dev/null; then
        ANALYSIS=$(gemini -p "@./ What is this project building? Based on the codebase, which of these agent packs would be most useful: Designer (requires Figma), Mobile (Capacitor/Expo), Data/Analytics, DevOps/Infrastructure? Respond in 2-3 sentences." 2>/dev/null || cat "$TARGET/package.json" 2>/dev/null | head -20)
      else
        ANALYSIS=$(cat "$TARGET/package.json" 2>/dev/null | head -20)
      fi
      if [[ -n "$ANALYSIS" ]]; then
        echo -e "  ${DIM}${ANALYSIS}${NC}"
        echo ""
      else
        warn "Could not analyze project (no gemini CLI and no package.json)."
      fi
      echo ""
      multi_menu AGENT_PACKS "Based on the above, which packs do you want? (select all that apply)" \
        "Designer — Figma integration, wireframing, design tokens (requires Figma MCP)" \
        "DevOps — deployment, infrastructure, CI/CD agents" \
        "Data — analytics, reporting, data pipeline agents" \
        "None / skip for now"
      break
    fi
  done

  # Process final selections
  if [[ ${#AGENT_PACKS[@]} -eq 0 ]]; then
    info "No agent packs selected. You can enable packs later by re-running the installer."
  else
    for pack in "${AGENT_PACKS[@]}"; do
      case "$pack" in
        "Designer"*)
          success "Designer pack enabled — will auto-prompt for Figma MCP in Phase 2"
          DESIGNER_PACK_SELECTED=true
          ;;
        "DevOps"*)
          info "DevOps pack noted — agents will be added in a future release. No action taken now."
          ;;
        "Data"*)
          info "Data pack noted — agents will be added in a future release. No action taken now."
          ;;
        "None"*)
          info "Skipping agent packs. You can enable them later by re-running the installer."
          ;;
      esac
    done
  fi

  # Remind about unselected packs
  echo ""
  dim "  Packs not selected now can always be added later by re-running this installer."
fi

# ─── Phase 2: MCP Wizard ──────────────────────────────────────────────────────
echo ""
header "Phase 2: Configure Claude MCP integrations"
echo -e "  ${DIM}MCPs extend Claude with tools for your Git platform, ticket system, and design tools.${NC}"
echo ""

if [[ "${CI:-}" == "true" ]]; then
  info "CI mode detected — skipping MCP setup"
  echo ""
elif ! command -v claude &>/dev/null; then
  warn "Claude CLI not found — cannot configure MCPs."
  info  "Install the Claude CLI: https://claude.ai/code"
  info  "Then re-run: bash $0 --mcp-only"
  echo ""
else

  # ── Security preamble ────────────────────────────────────────────────────────
  echo -e "  ${YELLOW}${BOLD}Security note:${NC}"
  echo -e "  ${DIM}Tokens you enter will be stored in ${TARGET}/.claude/settings.json.${NC}"
  echo -e "  ${DIM}That file has been added to .gitignore — never commit it.${NC}"
  echo -e "  ${DIM}Prefer setting tokens as shell env vars instead:${NC}"
  echo -e "  ${DIM}  export GITHUB_PERSONAL_ACCESS_TOKEN='ghp_...'${NC}"
  echo -e "  ${DIM}  export LINEAR_API_KEY='lin_api_...'${NC}"
  echo -e "  ${DIM}Claude Code reads env vars automatically — no token in settings needed.${NC}"
  echo ""
  if ! ask_yn "Proceed with MCP token setup?"; then
    info "Skipping MCP setup. Set env vars manually and re-run: bash $0 --mcp-only"
    echo ""
  else

  # Ensure log exists for MCP-only runs
  mkdir -p "$(dirname "$LOG_FILE")"
  : >> "$LOG_FILE"

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
      echo -e "  ${DIM}Or set GITHUB_PERSONAL_ACCESS_TOKEN as an env var to skip this prompt${NC}"
      if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
        info "Using GITHUB_PERSONAL_ACCESS_TOKEN from environment"
        GITHUB_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN"
      else
        ask GITHUB_TOKEN "GitHub Personal Access Token (repo + read:org scopes)" ""
      fi
      if [[ -n "$GITHUB_TOKEN" ]]; then
        mcp_add "GitHub" --scope project github \
          npx -y @modelcontextprotocol/server-github \
          --env GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"
      else
        warn "No token provided — skipping GitHub MCP (add later with: claude mcp add github)"
      fi
      ;;
    "GitLab")
      echo ""
      info "Installing GitLab MCP..."
      if [[ -n "${GITLAB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
        info "Using GITLAB_PERSONAL_ACCESS_TOKEN from environment"
        GITLAB_TOKEN="$GITLAB_PERSONAL_ACCESS_TOKEN"
      else
        ask GITLAB_TOKEN "GitLab Personal Access Token" ""
      fi
      ask GITLAB_URL "GitLab URL" "https://gitlab.com"
      if [[ -n "$GITLAB_TOKEN" ]]; then
        mcp_add "GitLab" --scope project gitlab \
          npx -y @modelcontextprotocol/server-gitlab \
          --env GITLAB_PERSONAL_ACCESS_TOKEN="$GITLAB_TOKEN" \
          --env GITLAB_URL="$GITLAB_URL"
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
      if [[ -n "${LINEAR_API_KEY:-}" ]]; then
        info "Using LINEAR_API_KEY from environment"
        LINEAR_KEY="$LINEAR_API_KEY"
      else
        ask LINEAR_KEY "Linear API Key (from Linear Settings → API)" ""
      fi
      if [[ -n "$LINEAR_KEY" ]]; then
        mcp_add "Linear" --scope project linear \
          npx -y @linear/mcp-server \
          --env LINEAR_API_KEY="$LINEAR_KEY"
      fi
      ;;
    "Jira")
      echo ""
      info "Installing Jira MCP..."
      ask JIRA_URL "Jira URL (e.g. https://yourorg.atlassian.net)" ""
      ask JIRA_EMAIL "Jira account email" ""
      if [[ -n "${JIRA_API_TOKEN:-}" ]]; then
        info "Using JIRA_API_TOKEN from environment"
        JIRA_TOKEN="$JIRA_API_TOKEN"
      else
        ask JIRA_TOKEN "Jira API Token (from id.atlassian.com/manage-profile/security/api-tokens)" ""
      fi
      if [[ -n "$JIRA_TOKEN" ]]; then
        mcp_add "Jira" --scope project jira \
          npx -y @modelcontextprotocol/server-jira \
          --env JIRA_URL="$JIRA_URL" \
          --env JIRA_EMAIL="$JIRA_EMAIL" \
          --env JIRA_TOKEN="$JIRA_TOKEN"
      fi
      ;;
    "Notion")
      echo ""
      info "Installing Notion MCP..."
      if [[ -n "${NOTION_API_KEY:-}" ]]; then
        info "Using NOTION_API_KEY from environment"
        NOTION_TOKEN="$NOTION_API_KEY"
      else
        ask NOTION_TOKEN "Notion Integration Token (from notion.so/my-integrations)" ""
      fi
      if [[ -n "$NOTION_TOKEN" ]]; then
        mcp_add "Notion" --scope project notion \
          npx -y @modelcontextprotocol/server-notion \
          --env NOTION_API_KEY="$NOTION_TOKEN"
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
  if [[ "$DESIGNER_PACK_SELECTED" == "true" ]]; then
    info "Designer agent pack was selected — auto-including Figma in Design Tools."
    DESIGN_TOOLS=("Figma")
  else
    multi_menu DESIGN_TOOLS "Which design tools do you use? (select all that apply)" \
      "Figma" \
      "Storybook (component library)" \
      "None"
  fi

  for tool in "${DESIGN_TOOLS[@]}"; do
    case "$tool" in
      "Figma")
        echo ""
        info "Installing Figma MCP..."
        echo -e "  ${DIM}Provides: read Figma files, inspect components, extract design tokens${NC}"
        if [[ -n "${FIGMA_API_KEY:-}" ]]; then
          info "Using FIGMA_API_KEY from environment"
          FIGMA_TOKEN="$FIGMA_API_KEY"
        else
          ask FIGMA_TOKEN "Figma Personal Access Token (from figma.com/developers/apps)" ""
        fi
        if [[ -n "$FIGMA_TOKEN" ]]; then
          mcp_add "Figma" --scope project figma \
            npx -y figma-developer-mcp \
            --env FIGMA_API_KEY="$FIGMA_TOKEN"
          success "Figma MCP installed — this activates the designer agent hierarchy (designer, design-researcher, design-wireframer, design-system-manager, design-reviewer)"
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
    mcp_add "Context7" --scope project context7 \
      npx -y @upstash/context7-mcp
  fi

  if ask_yn "Install Sequential Thinking MCP? (improves multi-step reasoning)"; then
    mcp_add "Sequential Thinking" --scope project sequential-thinking \
      npx -y @modelcontextprotocol/server-sequential-thinking
  fi

  if ask_yn "Install Filesystem MCP? (direct file access without Claude Code file tools)"; then
    mcp_add "Filesystem" --scope project filesystem \
      npx -y @modelcontextprotocol/server-filesystem "$TARGET"
    success "Filesystem MCP scoped to $TARGET"
  fi

  # ── 2e. Serena (code navigation) ─────────────────────────────────────────────
  echo ""
  if command -v uvx &>/dev/null || command -v uv &>/dev/null; then
    if ask_yn "Install Serena MCP? (semantic code navigation — highly recommended for large codebases)"; then
      mcp_add "Serena" --scope project serena \
        uvx --from "serena[claude-code]" serena
    fi
  else
    dim "  Serena MCP skipped — requires Python/uv (install uv from https://astral.sh/uv)"
  fi

  fi # end "proceed with MCP token setup" block
fi # end claude CLI check

# ─── Phase 3: Summary ─────────────────────────────────────────────────────────
echo ""
header "Installation Complete 🎉"
echo ""

if [[ "$MCP_ONLY" == "false" ]]; then
  echo -e "  ${GREEN}✓${NC} .claude/ merged into $TARGET/.claude"
  echo -e "  ${GREEN}✓${NC} Hook dependencies installed"
  echo -e "  ${GREEN}✓${NC} .gitignore updated (settings.json excluded)"
  echo -e "  ${DIM}  settings.json and CLAUDE.md were preserved if they existed${NC}"
fi

echo ""
echo -e "  ${BOLD}Security reminder:${NC}"
echo -e "  ${DIM}.claude/settings.json is in .gitignore — never force-add it.${NC}"
echo -e "  ${DIM}Prefer env vars for tokens: export GITHUB_PERSONAL_ACCESS_TOKEN='...'${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo ""
echo -e "  1. ${CYAN}cd $TARGET${NC}"
echo ""
echo -e "  2. ${CYAN}Update CLAUDE.md${NC} with your project's stack and conventions."
echo -e "     ${DIM}(Or run /init in Claude Code to auto-generate it)${NC}"
echo ""
echo -e "  3. ${CYAN}Add tool permissions${NC} to .claude/settings.json for your build commands:"
echo -e "     ${DIM}e.g. \"Bash(npm run:*)\", \"Bash(pytest:*)\", \"Bash(cargo:*)\"${NC}"
echo ""
echo -e "  4. ${CYAN}Open Claude Code${NC} in your project and run:"
echo -e "     ${BOLD}/init${NC}          — auto-detect stack and configure agents"
echo -e "     ${BOLD}/primer${NC}        — prime Claude's project context"
echo -e "     ${BOLD}/pm:groom${NC}      — groom your GitHub/Linear issues"
echo -e "     ${BOLD}/dev <issue>${NC}   — implement your first feature autonomously"
echo ""
if [[ -s "$LOG_FILE" ]]; then
  echo -e "  ${DIM}Install log: $LOG_FILE${NC}"
fi
echo -e "  ${DIM}Docs: https://github.com/$(git -C "$KIT_ROOT" config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/.git//')${NC}"
echo ""
