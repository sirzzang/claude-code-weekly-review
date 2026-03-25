#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUTO_APPROVE=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_APPROVE=true ;;
    esac
done

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
LOGS_DIR="$CLAUDE_DIR/session-logs"
SKILL_WEEKLY_DIR="$CLAUDE_DIR/skills/weekly-review"
SKILL_DEEPDIVE_DIR="$CLAUDE_DIR/skills/prompt-deep-dive"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "  ${RED}[ERROR]${NC} $1"; }
step()  { echo -e "\n${BOLD}$1${NC}"; }

INSTALLED_FILES=()
INSTALLED_DIRS=()
MODIFIED_FILES=()
SKIPPED=()

track_file() { INSTALLED_FILES+=("$1"); }
track_dir()  { INSTALLED_DIRS+=("$1"); }
track_mod()  { MODIFIED_FILES+=("$1"); }
track_skip() { SKIPPED+=("$1"); }

echo
echo -e "${BOLD}=== Claude Code Weekly Review - Install ===${NC}"

# -------------------------------------------------------
step "1/5  Checking prerequisites"
# -------------------------------------------------------
if ! command -v python3 &>/dev/null; then
    error "python3 not found. Please install Python 3.10+."
    exit 1
fi
info "python3 found: $(python3 --version)"

# -------------------------------------------------------
step "2/5  Creating directories"
# -------------------------------------------------------
for dir in "$HOOKS_DIR" "$LOGS_DIR"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        track_dir "$dir"
        info "Created: $dir"
    else
        info "Already exists: $dir"
    fi
done

# -------------------------------------------------------
step "3/5  Installing hook script"
# -------------------------------------------------------
HOOK_DEST="$HOOKS_DIR/log-session.py"
if [ -f "$HOOK_DEST" ]; then
    if diff -q "$SCRIPT_DIR/log-session.py" "$HOOK_DEST" &>/dev/null; then
        info "Already up to date: $HOOK_DEST"
        track_skip "hook (identical)"
    else
        cp "$SCRIPT_DIR/log-session.py" "$HOOK_DEST"
        chmod +x "$HOOK_DEST"
        track_file "$HOOK_DEST"
        info "Updated: $HOOK_DEST"
    fi
else
    cp "$SCRIPT_DIR/log-session.py" "$HOOK_DEST"
    chmod +x "$HOOK_DEST"
    track_file "$HOOK_DEST"
    info "Installed: $HOOK_DEST"
fi

# -------------------------------------------------------
step "4/5  Configuring settings.json"
# -------------------------------------------------------
HOOK_CMD="python3 ~/.claude/hooks/log-session.py"

if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "log-session.py" "$SETTINGS_FILE" 2>/dev/null; then
        info "Hook already registered in settings.json"
        track_skip "settings.json (hook exists)"
    else
        if command -v jq &>/dev/null; then
            STOP_HOOK='[{"matcher":"","hooks":[{"type":"command","command":"'"$HOOK_CMD"'"}]}]'
            MERGED=$(jq --argjson stop "$STOP_HOOK" '
                .hooks //= {} |
                .hooks.Stop //= [] |
                .hooks.Stop += $stop
            ' "$SETTINGS_FILE")
            echo "$MERGED" > "$SETTINGS_FILE"
            track_mod "$SETTINGS_FILE"
            info "Hook merged into existing settings.json"
        else
            warn "jq not found. Cannot auto-merge settings."
            warn "Please manually add the Stop hook to $SETTINGS_FILE"
            warn "See settings.example.json for the format."
        fi
    fi
else
    cp "$SCRIPT_DIR/settings.example.json" "$SETTINGS_FILE"
    track_file "$SETTINGS_FILE"
    info "Created new settings.json from template"
fi

# -------------------------------------------------------
step "5/5  Installing skills"
# -------------------------------------------------------
install_skill() {
    local name="$1" src="$2" dest_dir="$3"
    local dest="$dest_dir/SKILL.md"

    local answer="Y"
    if [ "$AUTO_APPROVE" = false ]; then
        echo
        read -rp "  Install ${name} skill? [Y/n] " answer
        answer="${answer:-Y}"
    fi
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        mkdir -p "$dest_dir"
        if [ -f "$dest" ] && diff -q "$src" "$dest" &>/dev/null; then
            info "Already up to date: $dest"
            track_skip "$name skill (identical)"
        else
            cp "$src" "$dest"
            track_file "$dest"
            if [ -f "$dest" ]; then
                info "Updated: $dest"
            else
                info "Installed: $dest"
            fi
        fi
    else
        track_skip "$name skill (user skipped)"
        info "$name skill installation skipped"
    fi
}

install_skill "weekly-review" "$SCRIPT_DIR/SKILL.md" "$SKILL_WEEKLY_DIR"
install_skill "prompt-deep-dive" "$SCRIPT_DIR/SKILL-deep-dive.md" "$SKILL_DEEPDIVE_DIR"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo
echo -e "${BOLD}=== Installation Complete ===${NC}"

echo
echo -e "${BOLD}[Installed files]${NC}"
if [ ${#INSTALLED_FILES[@]} -eq 0 ] && [ ${#INSTALLED_DIRS[@]} -eq 0 ] && [ ${#MODIFIED_FILES[@]} -eq 0 ]; then
    echo -e "  ${DIM}(nothing new - everything was already installed)${NC}"
else
    for f in "${INSTALLED_DIRS[@]+"${INSTALLED_DIRS[@]}"}"; do
        echo -e "  ${GREEN}+ dir${NC}  $f"
    done
    for f in "${INSTALLED_FILES[@]+"${INSTALLED_FILES[@]}"}"; do
        echo -e "  ${GREEN}+ file${NC} $f"
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
echo -e "${BOLD}[Directory structure]${NC}"
echo -e "  ~/.claude/"
echo -e "  ├── hooks/"
echo -e "  │   └── log-session.py          ${DIM}# Stop hook${NC}"
echo -e "  ├── session-logs/                ${DIM}# auto-created on first session${NC}"
[ -d "$SKILL_WEEKLY_DIR" ] && \
echo -e "  ├── skills/weekly-review/"       && \
echo -e "  │   └── SKILL.md                ${DIM}# weekly review skill${NC}"
[ -d "$SKILL_DEEPDIVE_DIR" ] && \
echo -e "  ├── skills/prompt-deep-dive/"    && \
echo -e "  │   └── SKILL.md                ${DIM}# prompt deep dive skill${NC}"
echo -e "  └── settings.json               ${DIM}# hook registered here${NC}"

echo
echo -e "${BOLD}[How to test]${NC}"
echo
echo -e "  ${CYAN}1. Hook 등록 확인${NC}"
echo -e "     아무 디렉토리에서나 Claude Code를 열고 ${BOLD}/hooks${NC} 입력"
echo -e "     -> Stop hook에 log-session.py가 보여야 한다"
echo -e "     ${DIM}(전역 설정이므로 어느 디렉토리에서 확인해도 동일)${NC}"
echo
echo -e "  ${CYAN}2. 로그 생성 확인${NC}"
echo -e "     Claude Code 세션을 하나 열고 아무 질문 후 정상 종료한다"
echo -e "     그 다음 확인:"
echo -e "     ${DIM}ls ~/.claude/session-logs/${NC}"
echo -e "     ${DIM}cat ~/.claude/session-logs/$(date +%Y-%m-%d).jsonl${NC}"
echo
echo -e "  ${CYAN}3. CLI 요약${NC}"
echo -e "     ${DIM}python3 $(printf '%s' "$SCRIPT_DIR")/summary.py${NC}"
echo
[ -d "$SKILL_WEEKLY_DIR" ] && \
echo -e "  ${CYAN}4. 주간 회고 스킬${NC}" && \
echo -e "     Claude Code에서: ${BOLD}주간 회고 해줘${NC}" && \
echo
[ -d "$SKILL_DEEPDIVE_DIR" ] && \
echo -e "  ${CYAN}5. 상세 분석 스킬${NC}" && \
echo -e "     Claude Code에서: ${BOLD}비효율 세션 분석해줘${NC}" && \
echo
