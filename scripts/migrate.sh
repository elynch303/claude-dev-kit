#!/usr/bin/env bash
# scripts/migrate.sh — Claude Dev Kit Migration Tool
#
# Intelligently merges CDK into an existing .claude/ setup without data loss.
# Detects NEW / UNCHANGED / MODIFIED files, asks about conflicts, and
# performs smart merges of settings.json and CLAUDE.md.
#
# Usage (called by install.sh):
#   bash scripts/migrate.sh <kit-root> <target-dir>
#
# Safe to run standalone. Exit codes: 0 = success, 1 = aborted/error.

# Bash 3.x treats empty arrays as unbound under `set -u`, which breaks
# migration on stock macOS shells. Keep `-e` and `pipefail`, but avoid `-u`.
set -eo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
KIT_ROOT="${1:-}"
TARGET="${2:-}"

if [[ -z "$KIT_ROOT" || -z "$TARGET" ]]; then
  echo "Usage: bash scripts/migrate.sh <kit-root> <target-dir>" >&2
  exit 1
fi

CDK_CLAUDE="$KIT_ROOT/.claude"
TGT_CLAUDE="$TARGET/.claude"
MANIFEST="$TGT_CLAUDE/.cdk-manifest"

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${CYAN}  →${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $*"; }
error()   { echo -e "${RED}  ✗${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}$*${NC}"; }
dim()     { echo -e "${DIM}$*${NC}"; }

make_temp_file() {
  mktemp "${TMPDIR:-/tmp}/cdk-temp.XXXXXX"
}

CI_MODE="${CI:-false}"

# ─── Section 1: Load existing manifest ────────────────────────────────────────
IS_FIRST_INSTALL=false

mkdir -p "$TGT_CLAUDE"

if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
  done < "$MANIFEST"
else
  IS_FIRST_INSTALL=true
fi

# ─── Section 2: Enumerate CDK files ───────────────────────────────────────────
declare -a cdk_files=()

while IFS= read -r -d '' f; do
  rel="${f#"$CDK_CLAUDE"/}"
  # Skip files that have their own special merge logic or should never be copied
  [[ "$rel" == "settings.json" ]]          && continue
  [[ "$rel" == "settings.json.example" ]]  && continue
  [[ "$rel" == ".cdk-manifest" ]]          && continue
  [[ "$rel" == *"node_modules"* ]]         && continue
  [[ "$rel" == *.jsonl ]]                  && continue
  [[ "$rel" == "learning/"* ]]             && continue
  cdk_files+=("$rel")
done < <(find "$CDK_CLAUDE" -type f -print0 2>/dev/null | sort -z)

# ─── Section 3: Categorize files ──────────────────────────────────────────────
declare -a cat_new=()
declare -a cat_unchanged=()
declare -a cat_modified=()

for rel in "${cdk_files[@]}"; do
  src="$CDK_CLAUDE/$rel"
  dst="$TGT_CLAUDE/$rel"

  if [[ ! -f "$dst" ]]; then
    cat_new+=("$rel")
  elif cmp -s "$src" "$dst"; then
    cat_unchanged+=("$rel")
  else
    # File exists in both and content differs — it was modified
    cat_modified+=("$rel")
  fi
done

# Count user-only files (in target .claude but not in CDK source)
user_only_count=0
if [[ -d "$TGT_CLAUDE" ]]; then
  while IFS= read -r -d '' f; do
    rel="${f#"$TGT_CLAUDE"/}"
    [[ "$rel" == ".cdk-manifest" ]] && continue
    # Check if this file is in the CDK source
    if [[ ! -f "$CDK_CLAUDE/$rel" ]]; then
      (( user_only_count++ )) || true
    fi
  done < <(find "$TGT_CLAUDE" -type f -print0 2>/dev/null)
fi

# ─── Section 4: Print migration report ────────────────────────────────────────
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Claude Dev Kit — Migration Tool       ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${DIM}Source: $KIT_ROOT${NC}"
echo -e "  ${DIM}Target: $TARGET${NC}"
echo ""

if [[ "$IS_FIRST_INSTALL" == "true" ]] && [[ ! -d "$TARGET/.claude" || -z "$(ls -A "$TGT_CLAUDE" 2>/dev/null)" ]]; then
  info "No existing .claude/ found — performing fresh install"
else
  header "Migration Report"
  echo ""

  echo -e "  ${GREEN}${BOLD}NEW${NC}       ${#cat_new[@]} file(s)   — will be added"
  if [[ ${#cat_new[@]} -gt 0 && ${#cat_new[@]} -le 10 ]]; then
    for f in "${cat_new[@]}"; do echo -e "    ${DIM}$f${NC}"; done
  elif [[ ${#cat_new[@]} -gt 10 ]]; then
    for f in "${cat_new[@]:0:5}"; do echo -e "    ${DIM}$f${NC}"; done
    echo -e "    ${DIM}... and $((${#cat_new[@]} - 5)) more${NC}"
  fi
  echo ""

  echo -e "  ${CYAN}${BOLD}UNCHANGED${NC} ${#cat_unchanged[@]} file(s)   — CDK version matches yours, will refresh"
  echo ""

  if [[ ${#cat_modified[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}MODIFIED${NC}  ${#cat_modified[@]} file(s)   — differ from CDK, ${BOLD}requires your input${NC}"
    for f in "${cat_modified[@]}"; do echo -e "    ${YELLOW}$f${NC}"; done
    echo ""
  fi

  if [[ $user_only_count -gt 0 ]]; then
    echo -e "  ${BLUE}${BOLD}YOURS${NC}     $user_only_count file(s)   — only in your .claude/, CDK will never touch"
    echo ""
  fi

  echo -e "  ${BOLD}SPECIAL MERGES${NC}"
  if [[ -f "$TGT_CLAUDE/settings.json" ]]; then
    echo -e "    ${DIM}settings.json${NC}  — will merge hooks + permissions (yours preserved)"
  else
    echo -e "    ${DIM}settings.json${NC}  — will be created from CDK template"
  fi
  if [[ -f "$TARGET/CLAUDE.md" ]]; then
    if grep -qF "CDK:GENERATED:START" "$TARGET/CLAUDE.md" 2>/dev/null; then
      echo -e "    ${DIM}CLAUDE.md${NC}      — will update CDK block (your custom content preserved)"
    else
      echo -e "    ${DIM}CLAUDE.md${NC}      — will append CDK block (your existing content preserved)"
    fi
  else
    echo -e "    ${DIM}CLAUDE.md${NC}      — will be created from template"
  fi
  echo ""
fi

# ─── Section 5: Confirm before proceeding ─────────────────────────────────────
if [[ "$CI_MODE" != "true" && ${#cat_modified[@]} -eq 0 ]]; then
  echo -ne "  Proceed with migration? ${DIM}[Y/n]${NC}: "
  read -r _confirm </dev/tty
  if [[ "$_confirm" =~ ^[Nn]$ ]]; then
    echo "  Aborted."
    exit 1
  fi
fi

# ─── Section 6: Resolve MODIFIED files interactively ──────────────────────────
declare -a resolution_files=()
declare -a resolution_actions=()

set_resolution() {
  local file="$1"
  local action="$2"
  local i
  for (( i=0; i<${#resolution_files[@]}; i++ )); do
    if [[ "${resolution_files[$i]}" == "$file" ]]; then
      resolution_actions[$i]="$action"
      return
    fi
  done
  resolution_files+=("$file")
  resolution_actions+=("$action")
}

get_resolution() {
  local file="$1"
  local i
  for (( i=0; i<${#resolution_files[@]}; i++ )); do
    if [[ "${resolution_files[$i]}" == "$file" ]]; then
      printf '%s\n' "${resolution_actions[$i]}"
      return
    fi
  done
  printf 'keep\n'
}

if [[ ${#cat_modified[@]} -gt 0 ]]; then
  if [[ "$CI_MODE" == "true" ]]; then
    warn "CI mode — all ${#cat_modified[@]} modified file(s) will be preserved (keeping your versions)"
    warn "To update them: run scripts/migrate.sh manually and choose [u] for each"
    for rel in "${cat_modified[@]}"; do
      set_resolution "$rel" "keep"
    done
  else
    header "Resolving modified files"
    echo -e "  ${DIM}For each file that differs from CDK, choose what to do.${NC}"
    echo ""

    for rel in "${cat_modified[@]}"; do
      src="$CDK_CLAUDE/$rel"
      dst="$TGT_CLAUDE/$rel"

      echo -e "  ${YELLOW}${BOLD}MODIFIED:${NC} $rel"

      while true; do
        echo -ne "  [k]eep mine  [u]se CDK version  [d]iff  [s]kip: "
        read -r -n1 choice </dev/tty
        echo ""

        case "$choice" in
          k|K)
            set_resolution "$rel" "keep"
            info "Keeping your version"
            break
            ;;
          u|U)
            set_resolution "$rel" "cdk"
            info "Will use CDK version"
            break
            ;;
          d|D)
            echo ""
            if command -v diff &>/dev/null; then
              diff --color=always -u "$dst" "$src" 2>/dev/null | head -80 || true
            else
              warn "diff not available — cannot show comparison"
            fi
            echo ""
            ;;
          s|S)
            resolutions["$rel"]="keep"
            info "Skipped (keeping yours)"
            break
            ;;
          *)
            echo -ne "  Invalid choice. "
            ;;
        esac
      done
      echo ""
    done
  fi
fi

# ─── Section 7: Apply regular file changes ────────────────────────────────────
header "Applying changes"
echo ""

new_count=0
unchanged_count=0
modified_applied=0
modified_kept=0

# Apply NEW files
for rel in "${cat_new[@]}"; do
  src="$CDK_CLAUDE/$rel"
  dst="$TGT_CLAUDE/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  (( new_count++ )) || true
done

# Apply UNCHANGED files (refresh to latest CDK version — they're identical so this is safe)
for rel in "${cat_unchanged[@]}"; do
  src="$CDK_CLAUDE/$rel"
  dst="$TGT_CLAUDE/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  (( unchanged_count++ )) || true
done

# Apply MODIFIED based on user decisions
for rel in "${cat_modified[@]}"; do
  case "$(get_resolution "$rel")" in
    cdk)
      mkdir -p "$(dirname "$TGT_CLAUDE/$rel")"
      cp "$CDK_CLAUDE/$rel" "$TGT_CLAUDE/$rel"
      (( modified_applied++ )) || true
      ;;
    keep)
      (( modified_kept++ )) || true
      ;;
  esac
done

[[ $new_count -gt 0 ]]       && success "$new_count new file(s) added"
[[ $unchanged_count -gt 0 ]] && success "$unchanged_count unchanged file(s) refreshed"
[[ $modified_applied -gt 0 ]] && success "$modified_applied modified file(s) updated to CDK version"
[[ $modified_kept -gt 0 ]]    && info    "$modified_kept modified file(s) kept as your version"

# ─── Section 8: Merge settings.json ───────────────────────────────────────────
merge_settings() {
  local tgt_settings="$TGT_CLAUDE/settings.json"
  local cdk_settings="$CDK_CLAUDE/settings.json"
  local merge_script="$KIT_ROOT/scripts/lib/merge-settings.js"

  if [[ ! -f "$cdk_settings" ]]; then
    cdk_settings="$CDK_CLAUDE/settings.json.example"
  fi

  if [[ ! -f "$cdk_settings" ]]; then
    warn "settings.json: CDK source not found — skipping"
    return
  fi

  if [[ ! -f "$tgt_settings" ]]; then
    # No existing settings — install CDK's (strip internal comment keys)
    node -e "
      const s = JSON.parse(require('fs').readFileSync('$cdk_settings', 'utf8'));
      delete s._comment; delete s._hooks_note;
      process.stdout.write(JSON.stringify(s, null, 2) + '\n');
    " > "$tgt_settings"
    success "settings.json: created from CDK template"
    return
  fi

  local tmp
  tmp=$(make_temp_file)
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  if node "$merge_script" "$tgt_settings" "$cdk_settings" > "$tmp" 2>&1; then
    # Validate output is parseable JSON before overwriting
    if node -e "JSON.parse(require('fs').readFileSync('$tmp', 'utf8'))" 2>/dev/null; then
      cp "$tmp" "$tgt_settings"
      success "settings.json: merged (permissions + hooks updated)"
    else
      warn "settings.json: merge produced invalid JSON — your original preserved"
      warn "Manual merge reference: $CDK_CLAUDE/settings.json.example"
    fi
  else
    warn "settings.json: merge failed — your original preserved"
    warn "Manual merge reference: $CDK_CLAUDE/settings.json.example"
  fi
}

merge_settings

# ─── Section 9: Merge CLAUDE.md ───────────────────────────────────────────────
merge_claude_md() {
  local tgt_md="$TARGET/CLAUDE.md"
  local cdk_template="$CDK_CLAUDE/templates/claude-md-template.md"
  local START_MARKER="CDK:GENERATED:START"
  local END_MARKER="CDK:GENERATED:END"

  if [[ ! -f "$cdk_template" ]]; then
    warn "CLAUDE.md: template not found at $cdk_template — skipping"
    return
  fi

  if [[ ! -f "$tgt_md" ]]; then
    cp "$cdk_template" "$tgt_md"
    success "CLAUDE.md: created from template"
    return
  fi

  if grep -qF "$START_MARKER" "$tgt_md" 2>/dev/null; then
    # Has CDK markers — replace only the block between markers (inclusive)
    local tmp
    tmp=$(make_temp_file)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN

    # Extract CDK block from template
    local cdk_block
    cdk_block=$(awk "/<!-- ${START_MARKER}/,/<!-- ${END_MARKER} -->/" "$cdk_template")

    # Build merged file: content before START + cdk block + content after END
    awk -v block="$cdk_block" \
      -v start="$START_MARKER" \
      -v end="$END_MARKER" \
      'BEGIN { in_block=0; printed=0 }
       index($0, start) > 0 {
         if (!printed) { print block; printed=1 }
         in_block=1; next
       }
       in_block && index($0, end) > 0 { in_block=0; next }
       !in_block { print }
      ' "$tgt_md" > "$tmp"

    cp "$tmp" "$tgt_md"
    success "CLAUDE.md: CDK block updated (your custom content preserved)"
  else
    # No CDK markers — append the CDK block at the end
    local cdk_block
    cdk_block=$(awk "/<!-- ${START_MARKER}/,/<!-- ${END_MARKER} -->/" "$cdk_template")
    {
      echo ""
      echo "---"
      echo ""
      printf '%s\n' "$cdk_block"
    } >> "$tgt_md"
    success "CLAUDE.md: CDK block appended (your existing content preserved)"
    info    "Tip: you can move the appended block anywhere in the file — the markers let future migrations update it in place"
  fi
}

merge_claude_md

# ─── Section 10: Write manifest ───────────────────────────────────────────────
write_manifest() {
  {
    echo "# CDK Manifest — generated by scripts/migrate.sh"
    echo "# Lists all files installed by claude-dev-kit."
    echo "# Do not edit manually. Used to distinguish CDK-owned from user-created files."
    echo "#"
    for rel in "${cdk_files[@]}"; do
      echo "$rel"
    done
  } > "$MANIFEST"
  success "Manifest written (.claude/.cdk-manifest — tracks CDK-owned files for future migrations)"
}

write_manifest

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
success "Migration complete"
echo ""
echo -e "  ${DIM}Next steps:${NC}"
if [[ ! -f "$TARGET/CLAUDE.md" ]] || ! grep -qF "CDK:GENERATED" "$TARGET/CLAUDE.md" 2>/dev/null; then
  echo -e "  ${DIM}  1. Run \`/init\` inside Claude Code to configure CLAUDE.md for your stack${NC}"
  echo -e "  ${DIM}  2. Copy CLAUDE.local.md.example → CLAUDE.local.md for personal preferences${NC}"
  echo -e "  ${DIM}  3. Run \`/primer\` to verify Claude understands the project${NC}"
else
  echo -e "  ${DIM}  1. Copy CLAUDE.local.md.example → CLAUDE.local.md for personal preferences${NC}"
  echo -e "  ${DIM}  2. Review any modified files you chose to keep — ensure they're still compatible${NC}"
  echo -e "  ${DIM}  3. Run \`/primer\` to verify Claude understands the project${NC}"
fi
echo ""
