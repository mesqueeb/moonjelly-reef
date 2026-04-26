#!/bin/sh
# merge.sh — local-tracker equivalent of `gh pr merge`
#
# For GitHub or ClickUp trackers, use: gh pr merge <branch> [flags]
# This script is the local-tracker equivalent — it reads the base branch from progress.md
# and performs the git merge directly.
#
# Usage:
#   merge.sh pr merge <branch> [--squash|-s] [--merge|-m] [--rebase|-r] [--delete-branch|-d]
#
# pr merge:            required subcommand (mirrors `gh pr merge`)
# <branch>:            the head branch to merge from
# --squash, -s:        squash all commits into one commit and merge
# --merge, -m:         merge with a merge commit (default)
# --rebase, -r:        rebase the commits onto the base branch
# --delete-branch, -d: delete the local and remote head branch after merging
set -eu

if [ $# -lt 2 ] || [ "$1" != "pr" ] || [ "$2" != "merge" ]; then
  echo "Usage: merge.sh pr merge <branch> [--squash|-s] [--merge|-m] [--rebase|-r] [--delete-branch|-d]" >&2
  exit 1
fi
shift 2

BRANCH=""
STRATEGY="merge"
DELETE_BRANCH=false

if [ $# -gt 0 ]; then
  case "$1" in
    --*|-*) ;;
    *) BRANCH="$1"; shift ;;
  esac
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --squash|-s)        STRATEGY="squash"; shift ;;
    --merge|-m)         STRATEGY="merge"; shift ;;
    --rebase|-r)        STRATEGY="rebase"; shift ;;
    --delete-branch|-d) DELETE_BRANCH=true; shift ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$BRANCH" ]; then
  echo "Usage: merge.sh pr merge <branch> [--squash|-s] [--merge|-m] [--rebase|-r] [--delete-branch|-d]" >&2
  exit 1
fi

# Look up base branch from progress.md (written by tracker.sh pr create)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository" >&2
  exit 1
}
CONFIG="$ROOT/.agents/moonjelly-reef/config.md"
if [ ! -f "$CONFIG" ]; then
  echo "Error: config not found at $CONFIG" >&2
  exit 1
fi
_raw_path="$(sed -n 's/^tracker-path: *//p' "$CONFIG" | head -1)"
case "$_raw_path" in
  /*) TRACKER_PATH="$_raw_path" ;;
  *)  TRACKER_PATH="$ROOT/$_raw_path" ;;
esac

BASE=""
for _pf in \
  "$TRACKER_PATH"/*/\[*\]\ progress.md \
  "$TRACKER_PATH"/*/progress.md \
  "$TRACKER_PATH"/*/slices/*/\[*\]\ progress.md \
  "$TRACKER_PATH"/*/slices/*/progress.md; do
  [ -f "$_pf" ] || continue
  _head="$(sed -n 's/^head: *//p' "$_pf" | head -1)"
  if [ "$_head" = "$BRANCH" ]; then
    BASE="$(sed -n 's/^base: *//p' "$_pf" | head -1)"
    break
  fi
done

if [ -z "$BASE" ]; then
  echo "Error: no progress.md found with head: $BRANCH" >&2
  exit 1
fi

git checkout "$BASE"

case "$STRATEGY" in
  squash)
    git merge --squash "$BRANCH"
    git commit -m "Squash merge $BRANCH into $BASE"
    ;;
  rebase)
    git rebase "$BRANCH"
    ;;
  merge)
    git merge --no-ff "$BRANCH" -m "Merge $BRANCH into $BASE"
    ;;
esac

if [ "$DELETE_BRANCH" = true ]; then
  git branch -D "$BRANCH" || true
  git push origin --delete "$BRANCH" || true
fi
