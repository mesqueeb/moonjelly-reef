#!/bin/sh
# worktree-exit.sh — remove a git worktree
#
# Usage: worktree-exit.sh --path {worktree-path}
#
# --path: absolute path to the worktree to remove
#
# Fails if the worktree has uncommitted, staged, or untracked changes.
set -eu

WORKTREE_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --path)
      [ $# -lt 2 ] && { echo "Error: --path requires a value" >&2; exit 1; }
      WORKTREE_PATH="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: worktree-exit.sh --path {worktree-path}" >&2
  exit 1
fi

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "Error: worktree path does not exist: $WORKTREE_PATH" >&2
  exit 1
fi

# Check for uncommitted changes (staged or unstaged)
if ! git -C "$WORKTREE_PATH" diff --quiet 2>/dev/null; then
  echo "Error: worktree has unstaged changes: $WORKTREE_PATH" >&2
  exit 1
fi

if ! git -C "$WORKTREE_PATH" diff --cached --quiet 2>/dev/null; then
  echo "Error: worktree has staged changes: $WORKTREE_PATH" >&2
  exit 1
fi

# Check for untracked files
if [ -n "$(git -C "$WORKTREE_PATH" ls-files --others --exclude-standard 2>/dev/null)" ]; then
  echo "Error: worktree has untracked files: $WORKTREE_PATH" >&2
  exit 1
fi

git worktree remove "$WORKTREE_PATH"
