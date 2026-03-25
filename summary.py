#!/usr/bin/env python3
"""
Quick summary of Claude Code session logs.

Usage:
  python3 summary.py                          # last 7 days
  python3 summary.py --from 2026-03-17 --to 2026-03-23
  python3 summary.py --verbose                # include prompt text
  python3 summary.py --days 14                # last 14 days
"""

import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path


LOG_DIR = Path.home() / ".claude" / "session-logs"
DEFAULT_DAYS = 7
PROMPT_PREVIEW_LENGTH = 120
HIGH_TURN_DISPLAY_LIMIT = 5
HIGH_TURN_MULTIPLIER = 1.5
HIGH_TURN_MIN_THRESHOLD = 3


def load_sessions(date_from: str, date_to: str) -> list[dict]:
    """Load all sessions within the given date range (inclusive)."""
    sessions = []
    if not LOG_DIR.exists():
        return sessions

    for log_file in sorted(LOG_DIR.glob("*.jsonl")):
        date_part = log_file.stem  # YYYY-MM-DD
        if date_part < date_from or date_part > date_to:
            continue
        with open(log_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    sessions.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return sessions


def print_summary(sessions: list[dict], date_from: str, date_to: str, verbose: bool):
    """Print a formatted summary of session data."""
    if not sessions:
        print(f"No session logs found for {date_from} ~ {date_to}")
        print(f"Log directory: {LOG_DIR}")
        return

    total_sessions = len(sessions)
    total_turns = sum(s.get("turn_count", 0) for s in sessions)
    total_tools = sum(s.get("tool_total", 0) for s in sessions)
    total_elapsed = sum(s.get("elapsed_seconds", 0) for s in sessions)
    avg_elapsed = total_elapsed // total_sessions if total_sessions else 0
    avg_turns = total_turns / total_sessions if total_sessions else 0

    # Tool usage aggregate
    tool_counts: Counter = Counter()
    for s in sessions:
        for tool, count in s.get("tool_usage", {}).items():
            tool_counts[tool] += count

    # Project distribution
    project_counts: Counter = Counter()
    for s in sessions:
        cwd = s.get("cwd", "unknown")
        # Use last two path components as project identifier
        parts = Path(cwd).parts
        project = "/".join(parts[-2:]) if len(parts) >= 2 else cwd
        project_counts[project] += 1

    # Daily distribution
    daily_counts: Counter = Counter()
    for s in sessions:
        daily_counts[s.get("date", "unknown")] += 1

    # Print report
    print(f"=== Claude Code Session Summary: {date_from} ~ {date_to} ===\n")

    print(f"Sessions:       {total_sessions}")
    print(f"Total prompts:  {total_turns}")
    print(f"Total time:     {_fmt(total_elapsed)}")
    print(f"Avg time/sess:  {_fmt(avg_elapsed)}")
    print(f"Avg turns/sess: {avg_turns:.1f}")
    print(f"Total tool use: {total_tools}")
    print()

    print("--- Tool Usage ---")
    for tool, count in tool_counts.most_common():
        pct = count / total_tools * 100 if total_tools else 0
        print(f"  {tool:20s} {count:5d}  ({pct:.0f}%)")
    print()

    print("--- Projects ---")
    for project, count in project_counts.most_common():
        print(f"  {project:40s} {count:3d} sessions")
    print()

    print("--- Daily Activity ---")
    for date in sorted(daily_counts):
        bar = "#" * daily_counts[date]
        print(f"  {date}  {bar} ({daily_counts[date]})")
    print()

    # High-turn sessions (potential prompt quality issues)
    high_turn = sorted(sessions, key=lambda s: s.get("turn_count", 0), reverse=True)
    threshold = max(HIGH_TURN_MIN_THRESHOLD, int(avg_turns * HIGH_TURN_MULTIPLIER))
    problem_sessions = [s for s in high_turn if s.get("turn_count", 0) >= threshold]
    if problem_sessions:
        print(f"--- High-Turn Sessions (>= {threshold} turns) ---")
        for s in problem_sessions[:HIGH_TURN_DISPLAY_LIMIT]:
            print(f"  [{s.get('date')}] {s.get('turn_count')} turns, "
                  f"{s.get('elapsed_human', '?')}, {s.get('cwd', '?')}")
            if verbose:
                for i, p in enumerate(s.get("prompts", []), 1):
                    preview = p[:PROMPT_PREVIEW_LENGTH] + ("..." if len(p) > PROMPT_PREVIEW_LENGTH else "")
                    print(f"    {i}. {preview}")
        print()

    if verbose:
        print("--- All Prompts ---")
        for s in sessions:
            print(f"\n  [{s.get('date')}] {s.get('session_id', '?')} "
                  f"({s.get('elapsed_human', '?')})")
            for i, p in enumerate(s.get("prompts", []), 1):
                print(f"    {i}. {p}")


def _fmt(seconds: int) -> str:
    if seconds < 60:
        return f"{seconds}s"
    m, s = divmod(seconds, 60)
    if m < 60:
        return f"{m}m {s}s"
    h, m = divmod(m, 60)
    return f"{h}h {m}m"


def main():
    parser = argparse.ArgumentParser(description="Summarize Claude Code session logs")
    parser.add_argument("--from", dest="date_from", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--to", dest="date_to", help="End date (YYYY-MM-DD)")
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS, help=f"Number of days to look back (default: {DEFAULT_DAYS})")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show prompt text")
    args = parser.parse_args()

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    if args.date_from:
        date_from = args.date_from
    else:
        d = datetime.now(timezone.utc) - timedelta(days=args.days)
        date_from = d.strftime("%Y-%m-%d")

    date_to = args.date_to if args.date_to else today

    sessions = load_sessions(date_from, date_to)
    print_summary(sessions, date_from, date_to, args.verbose)


if __name__ == "__main__":
    main()
