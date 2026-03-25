# claude-code-weekly-review

Claude Code 세션을 자동 기록하고, 주간 회고로 프롬프트 품질을 개선하는 도구.

```
세션 종료 → Stop hook이 메타데이터 기록 → 스킬/CLI로 분석
```

## Quick Start

```bash
git clone https://github.com/eraser5th/claude-code-weekly-review.git
cd claude-code-weekly-review
./install.sh -y        # 전체 자동 설치 (프롬프트 없이)
```

설치 후 Claude Code를 정상 종료하면 로그가 자동으로 쌓인다. 분석은 Claude Code에서 `주간 회고 해줘` 라고 말하면 된다.

## 왜 만들었나

Claude Code를 쓰다 보면 프롬프트를 어떻게 쓰는지 돌아볼 기회가 없다.
"이거 고쳐줘"로 시작해서 5턴 만에 끝나는 세션과, 맥락을 충분히 제공해서 1턴에 끝나는 세션의 차이는 크다.

이 도구는 세 가지를 한다:

1. **Stop hook**으로 모든 세션의 메타데이터를 자동 기록한다 (프롬프트 원문, 도구 사용 횟수, 소요 시간).
2. **주간 회고 스킬**로 누적된 로그를 분석하여 프롬프팅 습관의 개선점을 도출한다.
3. **상세 분석 스킬**로 비정상 세션을 개별 식별하고, 턴 단위로 Before/After 개선안을 제시한다.

command 타입 hook이라 LLM 호출이 없고, 추가 토큰 비용이 발생하지 않는다.

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
  스킬    스킬      CLI
 주간회고 상세분석  summary.py
```

## 구조

```
claude-code-weekly-review/
├── log-session.py              # Stop hook: 세션 메타데이터 로깅
├── SKILL.md                    # 주간 회고 스킬
├── SKILL-deep-dive.md          # 프롬프트 상세 분석 스킬
├── summary.py                  # CLI: 로그 요약 (스킬 없이 단독 실행)
├── settings.example.json       # hook 설정 예시
├── install.sh                  # 설치 스크립트
└── uninstall.sh                # 제거 스크립트
```

## 요구 사항

- Claude Code v1.0.41 이상 (Stop hook 지원)
- Python 3.10+
- jq (선택, settings.json 자동 병합에 사용)

## 설치

> 전역 설치(`~/.claude/`)로, 설치 후 모든 프로젝트의 Claude Code 세션에 적용된다.

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

설치 스크립트가 아래 작업을 수행한다:

1. `~/.claude/hooks/log-session.py` 배치
2. `~/.claude/settings.json`에 Stop hook 등록 (기존 설정 보존)
3. 스킬 설치 (weekly-review, prompt-deep-dive)

완료 후 설치된 파일 목록, 디렉토리 구조, 테스트 방법이 출력된다.

### 수동 설치

```bash
# 1. hook 스크립트 배치
mkdir -p ~/.claude/hooks
cp log-session.py ~/.claude/hooks/log-session.py
chmod +x ~/.claude/hooks/log-session.py

# 2. settings.json에 hook 등록
# 기존 settings.json이 있으면 hooks.Stop 항목만 병합한다.
# 없으면 settings.example.json을 참고하여 생성한다.

# 3. 스킬 설치 (선택)
mkdir -p ~/.claude/skills/weekly-review
cp SKILL.md ~/.claude/skills/weekly-review/SKILL.md

mkdir -p ~/.claude/skills/prompt-deep-dive
cp SKILL-deep-dive.md ~/.claude/skills/prompt-deep-dive/SKILL.md
```

## 제거

```bash
./uninstall.sh
```

제거 스크립트가 아래 작업을 수행한다:

1. `~/.claude/hooks/log-session.py` 삭제
2. `~/.claude/settings.json`에서 hook 항목만 제거 (다른 설정 보존)
3. 스킬 디렉토리 삭제 (weekly-review, prompt-deep-dive)
4. 세션 로그 삭제 여부 선택 (기본 N - 보존)

완료 후 삭제된 항목 목록과 검증 방법이 출력된다.

## 사용법

### 자동 로깅

설치 후 별도 조작 없이, Claude Code 세션이 정상 종료될 때마다 로그가 저장된다.

```
~/.claude/session-logs/
├── 2026-03-24.jsonl
├── 2026-03-25.jsonl
└── ...
```

### 주간 회고 (스킬)

Claude Code에서 아래와 같이 요청한다:

```
주간 회고 해줘
이번 주 Claude Code 사용 패턴 분석해줘
3월 첫째 주 프롬프트 리뷰 해줘
```

### 프롬프트 상세 분석 (스킬)

비정상 세션을 식별하고 턴별로 뜯어본다:

```
비효율 세션 분석해줘
프롬프트 상세 분석 해줘
왜 이렇게 오래 걸렸는지 분석해줘
```

### 빠른 요약 (CLI)

스킬 없이 터미널에서 바로 확인할 수 있다:

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

## 로그 형식

각 세션은 JSONL 한 줄로 기록된다:

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

## 제한사항

- `Ctrl+C`로 강제 종료한 세션은 Stop hook이 실행되지 않아 로그가 누락될 수 있다.
- transcript JSONL의 내부 구조는 Claude Code 버전에 따라 변경될 수 있다. 파싱 실패 시 해당 세션은 무시된다.
- 프롬프트 원문에 민감 정보가 포함될 수 있다. 로그 파일의 접근 권한에 주의한다.

## 커스텀

### hook만 쓰고 스킬은 쓰지 않는 경우

`log-session.py`와 `summary.py`만 사용하면 된다. `install.sh` 실행 시 스킬 설치를 n으로 건너뛴다.

### 기존 settings.json에 병합

`settings.example.json`을 참고하여 기존 `hooks` 설정에 `Stop` 항목만 추가한다. `install.sh`는 기존 설정을 덮어쓰지 않고 병합을 시도한다.

### 로그 보관 기간 설정

기본적으로 로그는 무한 보관된다. 디스크가 우려되면 cron으로 오래된 로그를 정리한다:

```bash
# 30일 이상 된 로그 삭제
find ~/.claude/session-logs/ -name "*.jsonl" -mtime +30 -delete
```

## License

MIT
