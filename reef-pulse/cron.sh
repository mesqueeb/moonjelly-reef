#!/usr/bin/env bash
# Moonjelly Reef — pulse cron script
# Runs a single reef-pulse, then exits.
# Uses a lock file to prevent overlapping runs.
#
# Usage:
#   ./cron.sh /path/to/your/project
#
# Cron example (every 30 minutes):
#   */30 * * * * /path/to/cron.sh /path/to/your/project >> /tmp/reef-pulse.log 2>&1
#
# launchd example (macOS, every 30 minutes):
#   See reef-pulse/launchd.plist
#
# Requirements:
#   - claude CLI installed and authenticated
#   - git, gh (if using GitHub tracker) available in PATH

set -euo pipefail

PROJECT_DIR="${1:?Usage: $0 /path/to/your/project}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: $PROJECT_DIR is not a directory" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Lock file prevents overlapping runs.
# Placed inside the project's .agents directory so it's project-specific.
LOCK_DIR=".agents/moonjelly-reef"
LOCK_FILE="$LOCK_DIR/pulse.lock"

mkdir -p "$LOCK_DIR"

# Check if another pulse is running.
# Use the lock file's PID to verify the process is still alive.
if [ -f "$LOCK_FILE" ]; then
  OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reef-pulse skipped — previous run (PID $OLD_PID) still active"
    exit 0
  else
    # Stale lock file — previous process is gone
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reef-pulse removing stale lock (PID $OLD_PID)"
    rm -f "$LOCK_FILE"
  fi
fi

# Write our PID to the lock file
echo $$ > "$LOCK_FILE"

# Clean up lock file on exit (success or failure)
cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reef-pulse starting in $PROJECT_DIR"

claude --dangerously-skip-permissions -p "/reef-pulse"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reef-pulse complete"
