# claude-code-weekly-review

Claude Code 세션을 자동 기록하고, 주간 회고로 프롬프트 품질을 개선하는 도구입니다.

```
세션 종료 → Stop hook이 메타데이터 기록 → 스킬/CLI로 분석
```

<br>

## Quick Start

```bash
git clone https://github.com/eraser5th/claude-code-weekly-review.git
cd claude-code-weekly-review
./install.sh -y        # 전체 자동 설치 (프롬프트 없이)
```

설치 후 Claude Code를 정상 종료하면 로그가 자동으로 쌓입니다. 분석은 Claude Code에서 `주간 회고 해줘` 라고 말하면 됩니다.

<br>

## 배경

Claude Code를 쓰다 보면 프롬프트를 어떻게 쓰는지 돌아볼 기회가 없습니다. "이거 고쳐줘"로 시작해서 5턴 만에 끝나는 세션과, 맥락을 충분히 제공해서 1턴에 끝나는 세션의 차이는 큽니다. 이 차이를 인식하고 싶었고, 더 나아가 프롬프팅 습관을 장기적으로 추적하여 개선하고 싶었습니다.

습관 분석에는 시계열 데이터가 전제됩니다. 그래서 Stop hook으로 매 세션의 메타데이터를 자동으로 쌓아두고, 일정 기간 단위로 되돌아볼 수 있는 구조를 만들었습니다. command 타입 hook 기반이라 LLM 호출이 없고, 추가 토큰 비용이 발생하지 않습니다.

이 도구는 네 가지를 합니다:

1. **Stop hook** — 모든 세션의 메타데이터를 자동 기록합니다 (프롬프트 원문, 도구 사용 횟수, 소요 시간).
2. **주간 회고 스킬** — 누적 로그를 기간별로 분석하여 프롬프팅 습관의 개선점을 도출합니다.
3. **상세 분석 스킬** — 비정상 세션을 개별 식별하고, 턴 단위 Before/After 개선안을 제시합니다.
4. **리뷰 내보내기 스킬** — 리뷰 결과를 로컬 파일 또는 외부 서비스(Notion 등)에 저장합니다.

<br>

## 동작 흐름

```
Claude Code 세션 종료
        │
        ▼
┌──────────────────────────┐
│  Stop hook               │
│  log-session.py          │  transcript JSONL 파싱 → 메타데이터 추출
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  ~/.claude/session-logs/ │
│  2026-03-24.jsonl        │  날짜별 JSONL 1줄/세션
│  2026-03-25.jsonl        │
└──────────┬───────────────┘
           │
     ┌─────┼─────────┐
     ▼     ▼         ▼
  스킬     스킬       CLI
 주간회고  상세분석   summary.py
     │     │
     ▼     ▼
  스킬: 리뷰 내보내기
  (로컬 파일 / Notion 등)
```

### 기존 transcript를 활용하지 않는 이유

Claude Code는 이미 모든 대화를 `~/.claude/projects/<project-hash>/<session-id>.jsonl`에 저장하고 있습니다. 유저 프롬프트, 어시스턴트 응답, tool_use 블록 등 전체 턴이 그대로 들어있으므로, 원한다면 직접 파싱해서 분석할 수 있습니다.

다만 습관 분석 용도로는 몇 가지 불편한 점이 있습니다:

| | raw transcript | hook이 만드는 로그 |
|---|---|---|
| 구조 | 프로젝트별 디렉토리, 세션별 파일 | 날짜별 JSONL, 세션당 1줄 |
| 내용 | 전체 대화 (응답, tool 결과 포함) | 메타데이터만 (프롬프트, 도구 횟수, 시간) |
| 크기 | 세션당 수백 KB ~ 수 MB | 세션당 수백 바이트 |
| 시계열 조회 | 파일 mtime 기반으로 직접 필터링 필요 | 날짜별 파일이라 바로 range query 가능 |

hook의 역할은 거대한 raw transcript에서 습관 분석에 필요한 시그널만 추출해서 시계열로 정리해두는 것입니다.

<br>

## 구조

```
claude-code-weekly-review/
├── log-session.py              # Stop hook: 세션 메타데이터 로깅
├── LOG-SPEC.md                 # 공통 로그 형식/전제 조건 (스킬 간 공유)
├── SKILL.md                    # 주간 회고 스킬
├── SKILL-deep-dive.md          # 프롬프트 상세 분석 스킬
├── SKILL-export-review.md      # 리뷰 내보내기 스킬
├── summary.py                  # CLI: 로그 요약 (스킬 없이 단독 실행)
├── settings.example.json       # hook 설정 예시
├── install.sh                  # 설치 스크립트
└── uninstall.sh                # 제거 스크립트
```

> 스킬 파일의 `<!-- include:LOG-SPEC -->` 플레이스홀더는 `install.sh`가
> 설치 시 `LOG-SPEC.md` 내용으로 치환합니다. 레포에서는 한 곳에서만 관리하고,
> 설치된 SKILL.md는 self-contained로 동작합니다.

<be>

## 요구 사항

- Claude Code v1.0.41 이상 (Stop hook 지원)
- Python 3.10+
- jq (선택, settings.json 자동 병합에 사용)

<br>

## 설치

> 전역 설치(`~/.claude/`)로, 설치 후 모든 프로젝트의 Claude Code 세션에 적용됩니다.

### 자동 설치

```bash
git clone https://github.com/eraser5th/claude-code-weekly-review.git
cd claude-code-weekly-review
./install.sh
```

| 옵션 | 설명 |
|------|------|
| (없음) | 스킬마다 설치 여부를 Y/n으로 확인 |
| `-y`, `--yes` | 모든 스킬을 확인 없이 자동 설치 |

설치 스크립트가 아래 작업을 수행합니다:

1. `~/.claude/hooks/log-session.py` 배치
2. `~/.claude/settings.json`에 Stop hook 등록 (기존 설정 보존)
3. 스킬 설치 (weekly-review, prompt-deep-dive, export-review)

완료 후 설치된 파일 목록, 디렉토리 구조, 테스트 방법이 출력됩니다.

<details>
<summary>install.sh -y 출력 예시</summary>

```
=== Claude Code Weekly Review - Install ===

1/5  Checking prerequisites
  [OK] python3 found: Python 3.12.4

2/5  Creating directories
  [OK] Created: ~/.claude/hooks
  [OK] Created: ~/.claude/session-logs

3/5  Installing hook script
  [OK] Installed: ~/.claude/hooks/log-session.py

4/5  Configuring settings.json
  [OK] Created new settings.json from template

5/5  Installing skills
  [OK] Installed: ~/.claude/skills/weekly-review/SKILL.md
  [OK] Installed: ~/.claude/skills/prompt-deep-dive/SKILL.md
  [OK] Installed: ~/.claude/skills/export-review/SKILL.md

=== Installation Complete ===

[Installed files]
  + dir  ~/.claude/hooks
  + dir  ~/.claude/session-logs
  + dir  ~/.claude/review-reports
  + file ~/.claude/hooks/log-session.py
  + file ~/.claude/settings.json
  + file ~/.claude/skills/weekly-review/SKILL.md
  + file ~/.claude/skills/prompt-deep-dive/SKILL.md
  + file ~/.claude/skills/export-review/SKILL.md

[Directory structure]
  ~/.claude/
  ├── hooks/
  │   └── log-session.py          # Stop hook
  ├── session-logs/                # auto-created on first session
  ├── review-reports/              # export-review가 리포트 저장
  ├── skills/weekly-review/
  │   └── SKILL.md                # weekly review skill
  ├── skills/prompt-deep-dive/
  │   └── SKILL.md                # prompt deep dive skill
  ├── skills/export-review/
  │   └── SKILL.md                # export review skill
  └── settings.json               # hook registered here

[How to test]

  1. Hook 등록 확인
     아무 디렉토리에서나 Claude Code를 열고 /hooks 입력
     -> Stop hook에 log-session.py가 보여야 합니다
     (전역 설정이므로 어느 디렉토리에서 확인해도 동일)

  2. 로그 생성 확인
     Claude Code 세션을 하나 열고 아무 질문 후 정상 종료합니다
     그 다음 확인:
     ls ~/.claude/session-logs/
     cat ~/.claude/session-logs/2026-03-26.jsonl

  3. CLI 요약
     python3 summary.py

  4. 주간 회고 스킬
     Claude Code에서: 주간 회고 해줘

  5. 상세 분석 스킬
     Claude Code에서: 비효율 세션 분석해줘

  6. 리뷰 내보내기 스킬
     주간 회고 또는 상세 분석 후: 리뷰 저장해줘
```

</details>

### 수동 설치

```bash
# 1. hook 스크립트 배치
mkdir -p ~/.claude/hooks
cp log-session.py ~/.claude/hooks/log-session.py
chmod +x ~/.claude/hooks/log-session.py

# 2. settings.json에 hook 등록
# 기존 settings.json이 있으면 hooks.Stop 항목만 병합합니다.
# 없으면 settings.example.json을 참고하여 생성합니다.

# 3. 스킬 설치 (선택)
mkdir -p ~/.claude/skills/weekly-review
cp SKILL.md ~/.claude/skills/weekly-review/SKILL.md

mkdir -p ~/.claude/skills/prompt-deep-dive
cp SKILL-deep-dive.md ~/.claude/skills/prompt-deep-dive/SKILL.md

mkdir -p ~/.claude/skills/export-review
cp SKILL-export-review.md ~/.claude/skills/export-review/SKILL.md
```

<br>

## 제거

```bash
./uninstall.sh
```

제거 스크립트가 아래 작업을 수행합니다:

1. `~/.claude/hooks/log-session.py` 삭제
2. `~/.claude/settings.json`에서 hook 항목만 제거 (다른 설정 보존)
3. 스킬 디렉토리 삭제 (weekly-review, prompt-deep-dive, export-review)
4. 세션 로그 삭제 여부 선택 (기본 N - 보존)
5. 리뷰 리포트 삭제 여부 선택 (기본 N - 보존)

완료 후 삭제된 항목 목록과 검증 방법이 출력됩니다.

<details>
<summary>uninstall.sh 출력 예시</summary>

```
=== Claude Code Weekly Review - Uninstall ===

1/5  Removing hook script
  [OK] Removed: ~/.claude/hooks/log-session.py

2/5  Removing hook from settings.json
  [OK] Removed hook entry from settings.json (other settings preserved)

3/5  Removing skills
  [OK] Removed: ~/.claude/skills/weekly-review
  [OK] Removed: ~/.claude/skills/prompt-deep-dive
  [OK] Removed: ~/.claude/skills/export-review

4/5  Session logs
  [WARN] Session logs found: ~/.claude/session-logs (3 file(s))
  Delete all session logs? [y/N] n
  [OK] Kept: ~/.claude/session-logs

5/5  Review reports
  [OK] No review reports found

=== Uninstall Complete ===

[Removed]
  - file ~/.claude/hooks/log-session.py
  - dir  ~/.claude/skills/weekly-review
  - dir  ~/.claude/skills/prompt-deep-dive
  - dir  ~/.claude/skills/export-review
  ~ mod  ~/.claude/settings.json

[Skipped]
  - session logs (user kept)

[Verify]
  아무 디렉토리에서나 Claude Code를 열고 /hooks 입력
  -> Stop hook에 log-session.py가 없어야 합니다
  (전역 설정이므로 어느 디렉토리에서 확인해도 동일)
```

</details>

<br>

## 사용법

### 자동 로깅

설치 후 별도 조작 없이, Claude Code 세션이 정상 종료될 때마다 로그가 저장됩니다.

```
~/.claude/session-logs/
├── 2026-03-24.jsonl
├── 2026-03-25.jsonl
└── ...
```

### 주간 회고 (스킬)

Claude Code에서 아래와 같이 요청합니다:

```
주간 회고 해줘
이번 주 Claude Code 사용 패턴 분석해줘
3월 첫째 주 프롬프트 리뷰 해줘
```

### 프롬프트 상세 분석 (스킬)

비정상 세션을 식별하고 턴별로 뜯어봅니다:

```
비효율 세션 분석해줘
프롬프트 상세 분석 해줘
왜 이렇게 오래 걸렸는지 분석해줘
```

### 리뷰 내보내기 (스킬)

주간 회고나 상세 분석 결과를 저장합니다:

```
리뷰 저장해줘
리뷰 결과 노션에 올려줘
export review
```

기본적으로 로컬 파일(`~/.claude/review-reports/`)에 마크다운으로 저장합니다. Notion 등 외부 서비스의 MCP가 연결되어 있으면 추가 업로드 옵션이 제시됩니다. 어떤 서비스에 업로드할지는 사용자가 선택합니다.

외부 서비스 연동은 `SKILL-export-review.md` 내 **업로드 핸들러 레지스트리** 섹션에서 관리합니다. Notion, Confluence, GitHub 핸들러가 기본 제공되며, 새 서비스를 추가하려면 레지스트리에 핸들러를 추가하면 됩니다.

### 빠른 요약 (CLI)

스킬 없이 터미널에서 바로 확인할 수 있습니다:

```bash
python3 summary.py                                    # 최근 7일
python3 summary.py --days 14                           # 최근 14일
python3 summary.py --from 2026-03-17 --to 2026-03-23  # 특정 기간
python3 summary.py --verbose                           # 프롬프트 원문 포함
```

출력 예시:

```
=== Claude Code Session Summary: 2026-03-18 ~ 2026-03-25 ===

Sessions:       23
Total prompts:  87
Total time:     4h 12m
Avg time/sess:  10m 57s
Avg turns/sess: 3.8
Total tool use: 342

--- Tool Usage ---
  Read                   112  (33%)
  Edit                    89  (26%)
  Bash                    74  (22%)
  Grep                    42  (12%)
  Write                   25  ( 7%)

--- Projects ---
  projects/stradv-mlops                     9 sessions
  projects/claude-code-weekly-review        8 sessions
  projects/my-app                           6 sessions

--- Daily Activity ---
  2026-03-18  ### (3)
  2026-03-19  ##### (5)
  2026-03-20  ## (2)
  ...
```

<br>

## 로그 형식

각 세션은 JSONL 한 줄로 기록됩니다:

```json
{
  "timestamp": "2026-03-25T09:30:00+00:00",
  "date": "2026-03-25",
  "session_id": "abc123",
  "cwd": "/home/eraser/projects/stradv-mlops",
  "prompts": [
    "Deployment 리소스에 GPU resource limits 추가해줘. RTX 4090 기준으로 nvidia.com/gpu: 1",
    "HPA 설정도 추가해줘. CPU 70% 기준, min 2 max 5로."
  ],
  "turn_count": 2,
  "tool_usage": {"Read": 3, "Edit": 2, "Bash": 1},
  "tool_total": 6,
  "elapsed_seconds": 145,
  "elapsed_human": "2m 25s"
}
```

<br>

## 제한사항

- `Ctrl+C`로 강제 종료한 세션은 Stop hook이 실행되지 않아 로그가 누락될 수 있습니다.
- transcript JSONL의 내부 구조는 Claude Code 버전에 따라 변경될 수 있습니다. 파싱 실패 시 해당 세션은 무시됩니다.
- 프롬프트 원문에 민감 정보가 포함될 수 있습니다. 로그 파일의 접근 권한에 주의해 주세요.

<br>

## 커스텀

### hook만 쓰고 스킬은 쓰지 않는 경우

`log-session.py`와 `summary.py`만 사용하면 됩니다. `install.sh` 실행 시 스킬 설치를 n으로 건너뜁니다.

### 기존 settings.json에 병합

`settings.example.json`을 참고하여 기존 `hooks` 설정에 `Stop` 항목만 추가합니다. `install.sh`는 기존 설정을 덮어쓰지 않고 병합을 시도합니다.

### 로그 보관 기간 설정

기본적으로 로그는 무한 보관됩니다. 디스크가 우려되면 cron으로 오래된 로그를 정리합니다:

```bash
# 30일 이상 된 로그 삭제
find ~/.claude/session-logs/ -name "*.jsonl" -mtime +30 -delete
```

<br>

## 관련 프로젝트

이 도구는 주간 단위의 습관 변화 추적에 집중합니다. 
단발성 프롬프트 품질 진단이나 종합 리포트가 필요하다면 아래 프로젝트가 더 적합합니다:

- **[claude-code-prompt-coach-skill](https://github.com/hancengiz/claude-code-prompt-coach-skill)**: Anthropic 베스트 프랙티스 기준으로 프롬프트 품질을 점수화합니다. 토큰 소비량, 도구 활용도, 에러 패턴 등 현재 상태의 전체 스냅샷이 필요할 때 유용합니다.
- **[Vibe-Log](https://github.com/vibe-log/vibe-log-cli)**: standup 요약, HTML 생산성 리포트, 실시간 프롬프트 코칭 statusline 등 더 풍부한 기능을 제공합니다. 클라우드 대시보드로 장기 추이도 볼 수 있습니다.

<br>

## License

MIT
