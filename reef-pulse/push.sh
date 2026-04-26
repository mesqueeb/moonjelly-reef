#!/bin/sh
# push.sh — push HEAD to a branch (or advance local ref if no origin)
#
# Usage:
#   push.sh --branch {name}
#
# --branch: the branch to push HEAD to (origin/{branch} if origin configured,
#           local ref otherwise)
set -eu

BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch)
      [ $# -lt 2 ] && { echo "Error: --branch requires a value" >&2; exit 1; }
      BRANCH="$2"; shift 2 ;;
    *)
      echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$BRANCH" ]; then
  echo "Usage: push.sh --branch {name}" >&2
  exit 1
fi

HAS_ORIGIN=false
git remote get-url origin >/dev/null 2>&1 && HAS_ORIGIN=true

if [ "$HAS_ORIGIN" = true ]; then
  git push origin "HEAD:refs/heads/${BRANCH}"
else
  git update-ref "refs/heads/${BRANCH}" HEAD
fi
