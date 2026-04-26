#!/bin/sh
# pull.sh — pull a branch from origin if configured, no-op if not
#
# Usage:
#   pull.sh --branch {name}
#
# --branch: the branch to pull from origin
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
  echo "Usage: pull.sh --branch {name}" >&2
  exit 1
fi

HAS_ORIGIN=false
git remote get-url origin >/dev/null 2>&1 && HAS_ORIGIN=true

if [ "$HAS_ORIGIN" = true ]; then
  git pull --ff-only origin "$BRANCH"
fi
