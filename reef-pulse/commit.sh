#!/bin/sh
# commit.sh — stage, commit, and push changes from a worktree
#
# Usage:
#   commit.sh --branch {name} -m {message}
#
# --branch: the remote branch to push to (origin/{branch})
# -m:       commit message
#
# Must be run from inside the worktree.
set -eu

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
  echo "Usage: commit.sh --branch {name} -m {message}" >&2
  exit 1
fi

# Check there's something to commit
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  echo "Error: nothing to commit" >&2
  exit 1
fi

git add -A
git commit -m "$MESSAGE"
git push origin "HEAD:refs/heads/${BRANCH}"
