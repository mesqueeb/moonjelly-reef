#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

for t in "$DIR"/tests/*.test.sh; do
  bash "$t"
done
