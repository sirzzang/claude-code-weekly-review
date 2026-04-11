## 전제 조건

- Stop hook(`~/.claude/hooks/log-session.py`)이 설정되어 있어야 한다.
- 로그 파일은 `~/.claude/session-logs/YYYY-MM-DD.jsonl` 형식으로 존재한다.

## 로그 형식

각 줄은 하나의 세션 기록이다. Stop hook이 세션 종료 시 transcript에서 메타데이터만 추출하여 저장한다.

- `elapsed_seconds` / `elapsed_human`: 첫 메시지~마지막 메시지 간 벽시계 시간 (idle 포함)
- `active_elapsed_seconds` / `active_elapsed_human`: 턴 간 간격 중 5분 이상 idle gap을 제외한 실제 작업 시간. 세션을 열어두는 습관이 있을 때 `elapsed`보다 정확한 작업량 지표이다.

```json
{
  "timestamp": "ISO 8601",
  "date": "YYYY-MM-DD",
  "session_id": "string",
  "cwd": "작업 디렉토리",
  "prompts": ["사용자 프롬프트 목록"],
  "turn_count": 3,
  "tool_usage": {"Bash": 5, "Read": 3, "Edit": 2},
  "tool_total": 10,
  "elapsed_seconds": 180,
  "elapsed_human": "3m 0s",
  "active_elapsed_seconds": 120,
  "active_elapsed_human": "2m 0s"
}
```
