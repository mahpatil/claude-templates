#!/bin/bash
# ~/.claude/hooks/session-tracker.sh
#
# Records Claude session info into .claude_sessions in the current project dir.
# Triggered by the Stop hook (end of each Claude turn).
# Each session_id is recorded once; last_seen is updated on subsequent stops.
# Entries older than 7 days are pruned automatically.

# Read hook input from stdin
INPUT=$(cat)

# Extract session_id from hook JSON
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Fallback to environment variable if available
if [ -z "$SESSION_ID" ] && [ -n "${CLAUDE_SESSION_ID:-}" ]; then
  SESSION_ID="$CLAUDE_SESSION_ID"
fi

# Exit gracefully if no session ID found
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Determine project directory (fall back to cwd)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSIONS_FILE="$PROJECT_DIR/.claude_sessions"
LOCK_FILE="$PROJECT_DIR/.claude_sessions.lock"

# Current timestamp (ISO 8601 UTC) and unix epoch
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
UNIX_TS=$(date +%s)

# Cutoff: 7 days ago (seconds)
CUTOFF=$((UNIX_TS - 604800))

# Ensure project directory exists
mkdir -p "$PROJECT_DIR"

# Use a temp file in the same directory as sessions file so mv is atomic
TEMP_FILE=$(mktemp "$PROJECT_DIR/.claude_sessions.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT

# Acquire exclusive lock (timeout after 5s to avoid blocking Claude)
exec 9>"$LOCK_FILE"
if ! flock -w 5 9; then
  exit 0
fi
trap 'rm -f "$TEMP_FILE" "$LOCK_FILE"; flock -u 9' EXIT

SESSION_EXISTS=false

# Process existing sessions file (if it exists)
if [ -f "$SESSIONS_FILE" ]; then
  while IFS= read -r line; do
    # Skip blank lines
    [ -z "$line" ] && continue

    # Prune entries older than 7 days (default to 0 if unix_ts missing/invalid)
    entry_unix=$(echo "$line" | jq -r '.unix_ts // 0' 2>/dev/null)
    if [[ ! "$entry_unix" =~ ^[0-9]+$ ]]; then
      entry_unix=0
    fi
    if [ "$entry_unix" -le "$CUTOFF" ]; then
      continue
    fi

    # Check if this is the current session
    entry_sid=$(echo "$line" | jq -r '.session_id // empty' 2>/dev/null)
    if [ "$entry_sid" = "$SESSION_ID" ]; then
      # Update last_seen for this session
      SESSION_EXISTS=true
      updated=$(echo "$line" | jq -c \
        --arg ts "$TIMESTAMP" \
        --argjson uts "$UNIX_TS" \
        '.last_seen = $ts | .unix_ts = $uts' 2>/dev/null)
      if [ -n "$updated" ]; then
        echo "$updated"
      else
        echo "$line"
      fi
    else
      echo "$line"
    fi
  done < "$SESSIONS_FILE" > "$TEMP_FILE"
fi

# Add new entry if session not yet recorded
if [ "$SESSION_EXISTS" = "false" ]; then
  NEW_ENTRY=$(jq -cn \
    --arg sid "$SESSION_ID" \
    --arg ts "$TIMESTAMP" \
    --argjson uts "$UNIX_TS" \
    --arg dir "$PROJECT_DIR" \
    '{session_id: $sid, first_seen: $ts, last_seen: $ts, unix_ts: $uts, project_dir: $dir}')
  echo "$NEW_ENTRY" >> "$TEMP_FILE"
fi

# Atomically replace the sessions file (mv on same filesystem is atomic)
mv "$TEMP_FILE" "$SESSIONS_FILE"

exit 0
