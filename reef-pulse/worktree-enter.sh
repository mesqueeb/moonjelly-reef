#!/bin/sh
# worktree-enter.sh — create a git worktree at a caller-defined path
#
# Usage:
#   worktree-enter.sh --fork-from {branch} --path {worktree-path}
#
# --fork-from: the remote branch to fork from (detached HEAD on origin/{branch})
# --path:      absolute or relative path where the worktree will be created
#
# Always creates a detached HEAD worktree from origin/{fork-from}.
# The caller decides the path — Reef phases conventionally keep worktrees inside
# the repo under .worktrees/ so the main checkout stays self-contained.
# Prints the absolute worktree path to stdout.
set -eu

FORK_FROM=""
WORKTREE_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --fork-from)
      [ $# -lt 2 ] && { echo "Error: --fork-from requires a value" >&2; exit 1; }
      FORK_FROM="$2"; shift 2 ;;
    --path)
      [ $# -lt 2 ] && { echo "Error: --path requires a value" >&2; exit 1; }
      WORKTREE_PATH="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$FORK_FROM" ] || [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: worktree-enter.sh --fork-from {branch} --path {worktree-path}" >&2
  exit 1
fi

if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: worktree path already exists: $WORKTREE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORKTREE_PATH")"

git fetch origin --prune >/dev/null 2>&1

git worktree add "$WORKTREE_PATH" "origin/${FORK_FROM}" --detach >/dev/null 2>&1

cd "$WORKTREE_PATH" && pwd -P
