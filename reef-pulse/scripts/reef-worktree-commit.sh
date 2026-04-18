#!/bin/sh
# reef-worktree-commit.sh — stage, commit, and push changes from a worktree
#
# Usage:
#   reef-worktree-commit.sh --slice-branch {name} -m {message}
#   reef-worktree-commit.sh --target-branch {name} -m {message}
#
# --slice-branch:  push to origin/{slice-branch} (code changes, PR flow)
# --target-branch: push to origin/{target-branch} (metadata, direct push)
# -m:              commit message
#
# Exactly one of --slice-branch or --target-branch must be given.
# Must be run from inside the worktree.
set -eu

SLICE_BRANCH=""
TARGET_BRANCH=""
MESSAGE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --slice-branch)
      [ $# -lt 2 ] && { echo "Error: --slice-branch requires a value" >&2; exit 1; }
      SLICE_BRANCH="$2"; shift 2 ;;
    --target-branch)
      [ $# -lt 2 ] && { echo "Error: --target-branch requires a value" >&2; exit 1; }
      TARGET_BRANCH="$2"; shift 2 ;;
    -m)
      [ $# -lt 2 ] && { echo "Error: -m requires a message" >&2; exit 1; }
      MESSAGE="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MESSAGE" ]; then
  echo "Usage: reef-worktree-commit.sh (--slice-branch {name} | --target-branch {name}) -m {message}" >&2
  exit 1
fi

if [ -n "$SLICE_BRANCH" ] && [ -n "$TARGET_BRANCH" ]; then
  echo "Error: pass --slice-branch or --target-branch, not both" >&2
  exit 1
fi

PUSH_TO=""
if [ -n "$SLICE_BRANCH" ]; then
  PUSH_TO="$SLICE_BRANCH"
elif [ -n "$TARGET_BRANCH" ]; then
  PUSH_TO="$TARGET_BRANCH"
else
  echo "Usage: reef-worktree-commit.sh (--slice-branch {name} | --target-branch {name}) -m {message}" >&2
  exit 1
fi

# Check there's something to commit
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  echo "Error: nothing to commit" >&2
  exit 1
fi

git add -A
git commit -m "$MESSAGE"
git push origin "HEAD:refs/heads/${PUSH_TO}"
