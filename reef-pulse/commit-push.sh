#!/bin/sh
# commit-push.sh — stage, commit, and push changes from a worktree
#
# Usage:
#   commit-push.sh --branch {name} -m {message}
#
# --branch: the branch to push to
# -m:       commit message
#
# Must be run from inside the worktree.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BRANCH=""
MESSAGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)
      [ $# -lt 2 ] && { echo "Error: --branch requires a value" >&2; exit 1; }
      BRANCH="$2"; shift 2 ;;
    -m)
      [ $# -lt 2 ] && { echo "Error: -m requires a message" >&2; exit 1; }
      MESSAGE="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$BRANCH" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: commit-push.sh --branch {name} -m {message}" >&2
  exit 1
fi

# Guard: abort if running from the main repo, not a worktree
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)
if [ "$GIT_DIR" = "$GIT_COMMON" ]; then
  echo "Error: commit-push.sh must be run from a worktree, not the main repo." >&2
  exit 1
fi

# Check there's something to commit
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  echo "Error: nothing to commit" >&2
  exit 1
fi

git add -A
git commit -m "$MESSAGE"
"$SCRIPT_DIR/push.sh" --branch "$BRANCH"
