#!/usr/bin/env python3
"""
Claude Code Stop hook: session logger.

Parses the transcript JSONL on session completion to extract:
- Raw user prompts
- Tool usage counts by tool name
- Session elapsed time (first to last message timestamp)

Logs are appended as one JSON line per session to:
  ~/.claude/session-logs/YYYY-MM-DD.jsonl

Exit codes:
  0 - success or graceful skip
  1 - unexpected error (non-blocking, stderr shown in verbose mode)
"""

from __future__ import annotations

import json
import sys
import os
from datetime import datetime
from pathlib import Path
from collections import Counter

LOG_DIR = Path.home() / ".claude" / "session-logs"


def parse_transcript(transcript_path: str) -> dict:
    """Parse a Claude Code transcript JSONL and extract session metrics."""
    prompts: list[str] = []
    tool_counts: Counter = Counter()
    timestamps: list[str] = []

    with open(transcript_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            ts = entry.get("timestamp")
            if ts:
                timestamps.append(ts)

            msg_type = entry.get("type", "")

            # Extract user prompts from user turns
            if msg_type in ("human", "user"):
                content = entry.get("message", {}).get("content", "")
                text = _extract_text(content)
                if text:
                    prompts.append(text)

            # Count tool_use blocks in assistant turns
            if msg_type == "assistant":
                content = entry.get("message", {}).get("content", [])
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "tool_use":
                            tool_counts[block.get("name", "unknown")] += 1

    elapsed = _calc_elapsed(timestamps)
    active_elapsed = _calc_active_elapsed(timestamps)

    return {
        "prompts": prompts,
        "tool_usage": dict(tool_counts),
        "tool_total": sum(tool_counts.values()),
        "elapsed_seconds": elapsed,
        "active_elapsed_seconds": active_elapsed,
        "turn_count": len(prompts),
    }


def _extract_text(content) -> str:
    """Extract text from a message content field (string or content blocks)."""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        return " ".join(parts).strip()
    return ""


def _calc_elapsed(timestamps: list[str]) -> int:
    """Calculate elapsed seconds between first and last timestamp."""
    if len(timestamps) < 2:
        return 0
    first = _parse_ts(timestamps[0])
    last = _parse_ts(timestamps[-1])
    if first and last:
        return max(0, int((last - first).total_seconds()))
    return 0


# Gaps longer than this are considered idle (user left the session open).
IDLE_THRESHOLD_SECONDS = 300  # 5 minutes


def _calc_active_elapsed(timestamps: list[str]) -> int:
    """Calculate active elapsed seconds, excluding idle gaps (>5 min)."""
    parsed = [t for t in (_parse_ts(ts) for ts in timestamps) if t is not None]
    if len(parsed) < 2:
        return 0
    active = 0
    for i in range(1, len(parsed)):
        gap = (parsed[i] - parsed[i - 1]).total_seconds()
        if gap <= IDLE_THRESHOLD_SECONDS:
            active += gap
    return max(0, int(active))


def _parse_ts(ts_str: str) -> datetime | None:
    """Parse an ISO 8601 timestamp string."""
    if not ts_str:
        return None
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _format_duration(seconds: int) -> str:
    """Format seconds as human-readable duration."""
    if seconds < 60:
        return f"{seconds}s"
    minutes, secs = divmod(seconds, 60)
    if minutes < 60:
        return f"{minutes}m {secs}s"
    hours, mins = divmod(minutes, 60)
    return f"{hours}h {mins}m"


def main():
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("Invalid JSON on stdin", file=sys.stderr)
        sys.exit(1)

    # Prevent infinite loop: skip if a previous Stop hook already kept Claude running
    if hook_input.get("stop_hook_active"):
        sys.exit(0)

    transcript_path = hook_input.get("transcript_path", "")
    session_id = hook_input.get("session_id", "unknown")
    cwd = hook_input.get("cwd", "")

    if not transcript_path or not os.path.isfile(transcript_path):
        sys.exit(0)

    try:
        metrics = parse_transcript(transcript_path)
    except Exception as e:
        print(f"Transcript parse error: {e}", file=sys.stderr)
        sys.exit(0)  # non-fatal: don't block the session from stopping

    if not metrics.get("prompts"):
        sys.exit(0)

    now = datetime.now().astimezone()
    log_entry = {
        "timestamp": now.isoformat(),
        "date": now.strftime("%Y-%m-%d"),
        "session_id": session_id,
        "cwd": cwd,
        "prompts": metrics["prompts"],
        "turn_count": metrics["turn_count"],
        "tool_usage": metrics["tool_usage"],
        "tool_total": metrics["tool_total"],
        "elapsed_seconds": metrics["elapsed_seconds"],
        "elapsed_human": _format_duration(metrics["elapsed_seconds"]),
        "active_elapsed_seconds": metrics["active_elapsed_seconds"],
        "active_elapsed_human": _format_duration(metrics["active_elapsed_seconds"]),
    }

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / f"{now.strftime('%Y-%m-%d')}.jsonl"

    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
    except OSError as e:
        print(f"Log write error: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
