#!/bin/sh
# reef-worktree-enter.sh — create a git worktree for a reef phase
#
# Usage:
#   reef-worktree-enter.sh --base-branch {branch} --target-branch {branch} --phase {phase} --slice {name} \
#     [--slice-branch {name} --branch-op create|checkout]
#
# --base-branch:   the plan's base branch (required for context/safety, not yet used in logic — see #20)
# --target-branch: the plan's target branch (used for worktree path and as checkout source when no --slice-branch)
# --phase:         reef phase (slice, implement, inspect, rework, etc.)
# --slice:         slice name
# --slice-branch:  slice branch name (requires --branch-op)
# --branch-op:     "create" to create a new branch, "checkout" to use an existing one
#
# Without --slice-branch: worktree checks out origin/{target-branch} (detached HEAD)
# With --slice-branch --branch-op create: creates new branch from origin/{target-branch}
# With --slice-branch --branch-op checkout: checks out existing origin/{slice-branch}
#
# Worktree path: ../worktree-{target-branch}-{slice}-{phase}
# Prints the absolute worktree path to stdout.
set -eu

BASE_BRANCH=""
TARGET_BRANCH=""
PHASE=""
SLICE=""
SLICE_BRANCH=""
BRANCH_OP=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base-branch)
      [ $# -lt 2 ] && { echo "Error: --base-branch requires a value" >&2; exit 1; }
      BASE_BRANCH="$2"; shift 2 ;;
    --target-branch)
      [ $# -lt 2 ] && { echo "Error: --target-branch requires a value" >&2; exit 1; }
      TARGET_BRANCH="$2"; shift 2 ;;
    --phase)
      [ $# -lt 2 ] && { echo "Error: --phase requires a value" >&2; exit 1; }
      PHASE="$2"; shift 2 ;;
    --slice)
      [ $# -lt 2 ] && { echo "Error: --slice requires a value" >&2; exit 1; }
      SLICE="$2"; shift 2 ;;
    --slice-branch)
      [ $# -lt 2 ] && { echo "Error: --slice-branch requires a value" >&2; exit 1; }
      SLICE_BRANCH="$2"; shift 2 ;;
    --branch-op)
      [ $# -lt 2 ] && { echo "Error: --branch-op requires a value" >&2; exit 1; }
      BRANCH_OP="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$BASE_BRANCH" ] || [ -z "$TARGET_BRANCH" ] || [ -z "$PHASE" ] || [ -z "$SLICE" ]; then
  echo "Usage: reef-worktree-enter.sh --base-branch {branch} --target-branch {branch} --phase {phase} --slice {name} [--slice-branch {name} --branch-op create|checkout]" >&2
  exit 1
fi

if [ -n "$SLICE_BRANCH" ] && [ -z "$BRANCH_OP" ]; then
  echo "Error: --slice-branch requires --branch-op (create or checkout)" >&2
  exit 1
fi

if [ -z "$SLICE_BRANCH" ] && [ -n "$BRANCH_OP" ]; then
  echo "Error: --branch-op requires --slice-branch" >&2
  exit 1
fi

if [ -n "$BRANCH_OP" ] && [ "$BRANCH_OP" != "create" ] && [ "$BRANCH_OP" != "checkout" ]; then
  echo "Error: --branch-op must be 'create' or 'checkout'" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE_PATH="$REPO_ROOT/../worktree-${TARGET_BRANCH}-${SLICE}-${PHASE}"

if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: worktree path already exists: $WORKTREE_PATH" >&2
  exit 1
fi

git fetch origin --prune >/dev/null 2>&1

if [ "$BRANCH_OP" = "create" ]; then
  git worktree add "$WORKTREE_PATH" -b "$SLICE_BRANCH" "origin/${TARGET_BRANCH}" >/dev/null 2>&1
elif [ "$BRANCH_OP" = "checkout" ]; then
  git worktree add "$WORKTREE_PATH" "origin/${SLICE_BRANCH}" >/dev/null 2>&1
else
  git worktree add "$WORKTREE_PATH" "origin/${TARGET_BRANCH}" >/dev/null 2>&1
fi

cd "$WORKTREE_PATH" && pwd -P
