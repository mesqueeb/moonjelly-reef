#!/bin/sh
# fetch.sh — fetch from origin if configured, no-op if not
#
# Usage:
#   fetch.sh
set -eu

HAS_ORIGIN=false
git remote get-url origin >/dev/null 2>&1 && HAS_ORIGIN=true

if [ "$HAS_ORIGIN" = true ]; then
  git fetch origin --prune
fi
