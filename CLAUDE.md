# Claude Code Weekly Review

Claude Code 세션을 자동 기록하고, 사용 습관과 학습 깊이를 추적하는 도구 모음.

## 프로젝트 구조

```
log-session.py                  # Stop hook — 세션 종료 시 transcript에서 메타데이터 추출하여 로그 저장
summary.py                      # CLI — 세션 로그 요약 출력 (python3 summary.py --days 7)
SKILL.md                        # /weekly-review 스킬 정의 (주간 습관 변화 + 학습 소비 현황 추적)
SKILL-deep-dive.md              # /prompt-deep-dive 스킬 정의 (특정 세션 턴별 분석)
SKILL-export-review.md          # /export-review 스킬 정의 (리뷰 결과를 Notion/로컬 저장)
LOG-SPEC.md                     # 세션 로그 형식 스펙 (스킬 파일에서 include로 참조됨)
BACKLOG-SPEC.md                 # 학습 백로그 형식 스펙 (SKILL.md에서 include로 참조됨)
learning-backlog.template.md    # 학습 백로그 설치 템플릿
install.sh                      # ~/.claude에 hook, 스킬, settings, 백로그 템플릿 설치
uninstall.sh                    # 설치된 파일 제거
settings.example.json           # Stop hook 설정 예시
```

## 데이터 흐름

```
세션 종료
  → log-session.py (Stop hook)
    → ~/.claude/session-logs/YYYY-MM-DD.jsonl (1세션 = 1줄)
      → summary.py (CLI 요약)
      → SKILL.md (주간 회고에서 로그 읽음)
      → SKILL-deep-dive.md (세션 분석에서 로그 읽음)
      → SKILL-export-review.md (리뷰 결과 저장)

세션 중 학습 포인트 발견 시
  → ~/.claude/learning-backlog.md에 행 추가
    → SKILL.md (주간 회고에서 소비 현황 집계)
```

## 핵심 규칙

- **시간 지표**: `active_elapsed_seconds`(idle gap 5분+ 제외)가 주 지표, `elapsed_seconds`(벽시계 시간)는 보조/참고용. 사용자가 세션을 터미널처럼 열어두는 습관이 있어서 elapsed는 부풀려진다.
- **로그 형식**: LOG-SPEC.md 참조. 변경 시 하위 호환 필수 — 기존 로그에 새 필드가 없을 수 있으므로 `s.get("new_field", s.get("old_field", 0))` 패턴 사용.
- **학습 백로그 형식**: BACKLOG-SPEC.md 참조. 마크다운 테이블이므로 파싱 시 헤더행/구분선 스킵 필요. 상태 열은 빈 문자열(미소비) 또는 `done`(소비 완료).
- **설치 구조**: install.sh가 이 디렉토리의 파일을 `~/.claude/hooks/`, `~/.claude/skills/` 등에 복사한다. `learning-backlog.template.md`는 `~/.claude/learning-backlog.md`로 복사 (기존 파일 보존). 파일 추가/삭제 시 install.sh, uninstall.sh 모두 업데이트 필요.
- **스킬 간 관계**: weekly-review와 prompt-deep-dive는 같은 로그 데이터를 읽지만 분석 단위가 다름 (주간 vs 세션). weekly-review는 추가로 학습 백로그를 읽어 소비 현황을 집계한다. export-review는 다른 스킬의 리포트 출력을 저장하는 후속 스킬.

## 커밋 메시지

Conventional Commits 형식: `<type>: <description>`

| type | 용도 |
|------|------|
| feat | 새 기능, 새 스킬, 새 지표 추가 |
| fix | 버그 수정, 호환성 문제 해결 |
| docs | 문서/스펙 변경 (README, LOG-SPEC 등) |
| chore | 포맷팅, 정리 등 기능 변경 없는 작업 |
| ci | GitHub Actions 워크플로우 변경 |
