#!/bin/sh
# Contract tests for saga chapter compilation and pulse documentation
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PULSE_SKILL="$REPO_ROOT/reef-pulse/SKILL.md"
README="$REPO_ROOT/README.md"
PASS=0
FAIL=0
TOTAL=0
OUTPUT_BUF=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  OUTPUT_BUF="${OUTPUT_BUF}$(printf "${GREEN}PASS${NC}: %s" "$1")
"
}

fail() {
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
  OUTPUT_BUF="${OUTPUT_BUF}$(printf "${RED}FAIL${NC}: %s" "$1")
"
  if [ $# -gt 1 ]; then
    OUTPUT_BUF="${OUTPUT_BUF}$(printf "  %s" "$2")
"
  fi
}

assert_contains() {
  file="$1"
  pattern="$2"
  label="$3"

  if grep -qF "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label" "missing pattern: $pattern"
  fi
}

test_pulse_skill_documents_chapter_compilation() {
  assert_contains "$PULSE_SKILL" 'chapter-NNN.md' "pulse skill: chapter file naming is documented"
  assert_contains "$PULSE_SKILL" 'compiled into `chapter-NNN.md`' "pulse skill: session-end chapter compilation is documented"
  assert_contains "$PULSE_SKILL" 'SESSION COMPLETE' "pulse skill: session wrap-up remains tied to the story archive"
}

test_readme_connects_saga_flow() {
  assert_contains "$README" 'saga-writer.md' "README: pulse docs point to the saga writer contract"
  assert_contains "$README" 'world.md' "README: pulse docs mention persistent world state"
  assert_contains "$README" 'chapter-NNN.md' "README: pulse docs mention session chapter output"
}

test_pulse_skill_documents_chapter_compilation
test_readme_connects_saga_flow

printf "%b" "$OUTPUT_BUF"
printf "\n================================\n"
printf "Results: %s passed, %s total\n" "$PASS" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
