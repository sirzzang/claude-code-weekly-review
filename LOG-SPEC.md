## 전제 조건

- Stop hook(`~/.claude/hooks/log-session.py`)이 설정되어 있어야 한다.
- 로그 파일은 `~/.claude/session-logs/YYYY-MM-DD.jsonl` 형식으로 존재한다.

## 로그 형식

각 줄은 하나의 세션 기록이다. Stop hook이 세션 종료 시 transcript에서 메타데이터만 추출하여 저장한다:

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
  "elapsed_human": "3m 0s"
}
```
