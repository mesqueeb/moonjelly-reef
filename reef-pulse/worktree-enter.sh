#!/bin/sh
# worktree-enter.sh — create a git worktree at a caller-defined path
#
# Usage:
#   worktree-enter.sh --fork-from {branch} --pull-latest {branch} --path {worktree-path}
#
# --fork-from:    the remote branch to fork from (detached HEAD on origin/{branch})
# --pull-latest:  the remote branch to merge into the worktree after creation (required)
# --path:         absolute or relative path where the worktree will be created
#
# Always creates a detached HEAD worktree from origin/{fork-from}.
# After creation, compares fork-from and pull-latest:
#   - Same branch: outputs "ready" (no merge)
#   - Different branch, clean merge: pushes merge commit and outputs
#     "synced: pulled N commits from {pull-latest} into {fork-from}"
#   - Different branch, already up to date: outputs "ready"
#   - Different branch, conflicts: outputs
#     "conflicts: merge of {pull-latest} into {fork-from} has conflicts"
#
# Worktree remains detached HEAD throughout (no local branch names created).
# Prints the absolute worktree path on the first line, status on the second line.
set -eu

FORK_FROM=""
PULL_LATEST=""
WORKTREE_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --fork-from)
      [ $# -lt 2 ] && { echo "Error: --fork-from requires a value" >&2; exit 1; }
      FORK_FROM="$2"; shift 2 ;;
    --pull-latest)
      [ $# -lt 2 ] && { echo "Error: --pull-latest requires a value" >&2; exit 1; }
      PULL_LATEST="$2"; shift 2 ;;
    --path)
      [ $# -lt 2 ] && { echo "Error: --path requires a value" >&2; exit 1; }
      WORKTREE_PATH="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$FORK_FROM" ] || [ -z "$PULL_LATEST" ] || [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: worktree-enter.sh --fork-from {branch} --pull-latest {branch} --path {worktree-path}" >&2
  exit 1
fi

if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: worktree path already exists: $WORKTREE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORKTREE_PATH")"

git fetch origin --prune >/dev/null

git worktree add "$WORKTREE_PATH" "origin/${FORK_FROM}" --detach >/dev/null

ABS_PATH="$(cd "$WORKTREE_PATH" && pwd -P)"
echo "$ABS_PATH"

# If fork-from and pull-latest are the same branch, no merge needed
if [ "$FORK_FROM" = "$PULL_LATEST" ]; then
  echo "ready"
  exit 0
fi

# Different branches — check if already up to date
LATEST_SHA="$(git rev-parse "origin/${PULL_LATEST}")"
MERGE_BASE="$(git -C "$ABS_PATH" merge-base HEAD "$LATEST_SHA")"

if [ "$LATEST_SHA" = "$MERGE_BASE" ]; then
  # pull-latest is already an ancestor of fork-from — nothing to merge
  echo "ready"
  exit 0
fi

# Count how many commits will be merged
COMMIT_COUNT="$(git -C "$ABS_PATH" rev-list "$MERGE_BASE".."$LATEST_SHA" | wc -l | tr -d ' ')"

# Attempt the merge (staying detached HEAD)
if git -C "$ABS_PATH" merge --no-edit "$LATEST_SHA" >/dev/null 2>&1; then
  # Clean merge — push to origin using explicit refspec (no force)
  git -C "$ABS_PATH" push origin "HEAD:refs/heads/${FORK_FROM}" >/dev/null
  echo "synced: pulled $COMMIT_COUNT commits from $PULL_LATEST into $FORK_FROM"
  exit 0
else
  # Conflicts — leave conflict markers, don't push
  echo "conflicts: merge of $PULL_LATEST into $FORK_FROM has conflicts"
  exit 0
fi
