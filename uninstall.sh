#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$CLAUDE_DIR/session-logs"
SKILL_WEEKLY_DIR="$CLAUDE_DIR/skills/weekly-review"
SKILL_DEEPDIVE_DIR="$CLAUDE_DIR/skills/prompt-deep-dive"
SKILL_EXPORT_DIR="$CLAUDE_DIR/skills/export-review"
REPORTS_DIR="$CLAUDE_DIR/review-reports"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "  ${RED}[ERROR]${NC} $1"; }
step()  { echo -e "\n${BOLD}$1${NC}"; }

REMOVED_FILES=()
REMOVED_DIRS=()
MODIFIED_FILES=()
SKIPPED=()

track_rm()   { REMOVED_FILES+=("$1"); }
track_rdir() { REMOVED_DIRS+=("$1"); }
track_mod()  { MODIFIED_FILES+=("$1"); }
track_skip() { SKIPPED+=("$1"); }

echo
echo -e "${BOLD}=== Claude Code Weekly Review - Uninstall ===${NC}"

# -------------------------------------------------------
step "1/5  Removing hook script"
# -------------------------------------------------------
HOOK_FILE="$HOOKS_DIR/log-session.py"
if [ -f "$HOOK_FILE" ]; then
    rm "$HOOK_FILE"
    track_rm "$HOOK_FILE"
    info "Removed: $HOOK_FILE"
else
    track_skip "hook (not found)"
    info "Not found: $HOOK_FILE (already removed)"
fi

# Remove hooks dir if empty
if [ -d "$HOOKS_DIR" ] && [ -z "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]; then
    rmdir "$HOOKS_DIR"
    track_rdir "$HOOKS_DIR"
    info "Removed empty directory: $HOOKS_DIR"
fi

# -------------------------------------------------------
step "2/5  Removing hook from settings.json"
# -------------------------------------------------------
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "log-session.py" "$SETTINGS_FILE" 2>/dev/null; then
        if command -v jq &>/dev/null; then
            # Remove Stop hook entries that reference log-session.py
            CLEANED=$(jq '
                if .hooks and .hooks.Stop then
                    .hooks.Stop = [
                        .hooks.Stop[] |
                        .hooks = [.hooks[] | select(.command | contains("log-session.py") | not)] |
                        select(.hooks | length > 0)
                    ] |
                    if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end |
                    if (.hooks | length) == 0 then del(.hooks) else . end
                else . end
            ' "$SETTINGS_FILE")

            # Check if settings is now empty (only {} left)
            if [ "$(echo "$CLEANED" | jq 'length')" = "0" ]; then
                rm "$SETTINGS_FILE"
                track_rm "$SETTINGS_FILE"
                info "Removed settings.json (no other settings remain)"
            else
                echo "$CLEANED" > "$SETTINGS_FILE"
                track_mod "$SETTINGS_FILE"
                info "Removed hook entry from settings.json (other settings preserved)"
            fi
        else
            warn "jq not found. Cannot auto-clean settings.json"
            warn "Please manually remove the log-session.py hook from $SETTINGS_FILE"
        fi
    else
        track_skip "settings.json (hook not found)"
        info "Hook not found in settings.json (already removed)"
    fi
else
    track_skip "settings.json (file not found)"
    info "Not found: $SETTINGS_FILE"
fi

# -------------------------------------------------------
step "3/5  Removing skills"
# -------------------------------------------------------
remove_skill() {
    local name="$1" dir="$2"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        track_rdir "$dir"
        info "Removed: $dir"
    else
        track_skip "$name skill (not found)"
        info "Not found: $dir (already removed)"
    fi
}

remove_skill "weekly-review" "$SKILL_WEEKLY_DIR"
remove_skill "prompt-deep-dive" "$SKILL_DEEPDIVE_DIR"
remove_skill "export-review" "$SKILL_EXPORT_DIR"

# Remove skills dir if empty
SKILLS_DIR="$CLAUDE_DIR/skills"
if [ -d "$SKILLS_DIR" ] && [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null)" ]; then
    rmdir "$SKILLS_DIR"
    track_rdir "$SKILLS_DIR"
    info "Removed empty directory: $SKILLS_DIR"
fi

# -------------------------------------------------------
step "4/5  Session logs"
# -------------------------------------------------------
LOG_COUNT=0
if [ -d "$LOGS_DIR" ]; then
    LOG_COUNT=$(find "$LOGS_DIR" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$LOG_COUNT" -gt 0 ]; then
    echo
    warn "Session logs found: $LOGS_DIR ($LOG_COUNT file(s))"
    read -rp "  Delete all session logs? [y/N] " answer
    answer="${answer:-N}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$LOGS_DIR"
        track_rdir "$LOGS_DIR"
        info "Removed: $LOGS_DIR ($LOG_COUNT file(s) deleted)"
    else
        track_skip "session logs (user kept)"
        info "Kept: $LOGS_DIR"
    fi
else
    info "No session logs found"
fi

# -------------------------------------------------------
step "5/5  Review reports"
# -------------------------------------------------------
REPORT_COUNT=0
if [ -d "$REPORTS_DIR" ]; then
    REPORT_COUNT=$(find "$REPORTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$REPORT_COUNT" -gt 0 ]; then
    echo
    warn "Review reports found: $REPORTS_DIR ($REPORT_COUNT file(s))"
    read -rp "  Delete all review reports? [y/N] " answer
    answer="${answer:-N}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$REPORTS_DIR"
        track_rdir "$REPORTS_DIR"
        info "Removed: $REPORTS_DIR ($REPORT_COUNT file(s) deleted)"
    else
        track_skip "review reports (user kept)"
        info "Kept: $REPORTS_DIR"
    fi
else
    if [ -d "$REPORTS_DIR" ]; then
        rmdir "$REPORTS_DIR" 2>/dev/null && track_rdir "$REPORTS_DIR" && info "Removed empty directory: $REPORTS_DIR" || true
    else
        info "No review reports found"
    fi
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo
echo -e "${BOLD}=== Uninstall Complete ===${NC}"

echo
echo -e "${BOLD}[Removed]${NC}"
if [ ${#REMOVED_FILES[@]} -eq 0 ] && [ ${#REMOVED_DIRS[@]} -eq 0 ] && [ ${#MODIFIED_FILES[@]} -eq 0 ]; then
    echo -e "  ${DIM}(nothing to remove - was already clean)${NC}"
else
    for f in "${REMOVED_DIRS[@]+"${REMOVED_DIRS[@]}"}"; do
        echo -e "  ${RED}- dir${NC}  $f"
    done
    for f in "${REMOVED_FILES[@]+"${REMOVED_FILES[@]}"}"; do
        echo -e "  ${RED}- file${NC} $f"
    done
    for f in "${MODIFIED_FILES[@]+"${MODIFIED_FILES[@]}"}"; do
        echo -e "  ${YELLOW}~ mod${NC}  $f"
    done
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo
    echo -e "${BOLD}[Skipped]${NC}"
    for s in "${SKIPPED[@]}"; do
        echo -e "  ${DIM}- $s${NC}"
    done
fi

echo
echo -e "${BOLD}[Verify]${NC}"
echo -e "  아무 디렉토리에서나 Claude Code를 열고 ${BOLD}/hooks${NC} 입력"
echo -e "  -> Stop hook에 log-session.py가 없어야 한다"
echo -e "  ${DIM}(전역 설정이므로 어느 디렉토리에서 확인해도 동일)${NC}"
echo
