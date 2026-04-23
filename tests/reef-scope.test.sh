#!/bin/sh
# Behavioral tests for reef-scope route selection instructions.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
SKILL_FILE="$REPO_ROOT/reef-scope/SKILL.md"
DEEP_RESEARCH_FILE="$REPO_ROOT/reef-scope/scope-deep-research.md"
README_FILE="$REPO_ROOT/README.md"
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
    fail "$label" "expected pattern: $pattern"
  fi
}

assert_equals() {
  expected="$1"
  actual="$2"
  label="$3"

  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label" "expected: $expected, actual: $actual"
  fi
}

route_picker_block() {
  awk '
    /^The route picker always offers exactly these five options:/ { capture=1; next }
    capture && /^If `ISSUE_ID` was provided/ { exit }
    capture && /^- `/ { print }
  ' "$SKILL_FILE"
}

test_route_picker_lists_exact_routes() {
  routes="$(route_picker_block)"
  route_count="$(printf '%s\n' "$routes" | sed '/^$/d' | wc -l | tr -d ' ')"
  expected_routes='- `scope a feature`
- `scope a refactor`
- `triage a bug`
- `I'\''m feeling lucky (hand over to the reef)`
- `deep research`'

  printf 'DIAGNOSTIC: reef-scope route picker block currently resolves to:\n%s\n' "$routes"

  assert_equals "5" "$route_count" "route picker exposes exactly five selectable routes"
  assert_equals "$expected_routes" "$routes" "route picker routes match the required options exactly"
}

test_issue_recommendation_uses_issue_text_only() {
  assert_contains "$SKILL_FILE" 'reads only the issue title and body before showing the picker' "issue-based runs only read issue text before recommending"
  assert_contains "$SKILL_FILE" 'marks exactly one route as `(recommended)`' "issue-based runs mark exactly one recommended route"
}

test_selected_route_persists_as_bearing() {
  bearings=$(grep -n 'bearing' "$SKILL_FILE")
  printf 'DIAGNOSTIC: bearing references currently in reef-scope/SKILL.md:\n%s\n' "$bearings"

  assert_contains "$SKILL_FILE" 'bearing: `feature`' "feature bearing is documented"
  assert_contains "$SKILL_FILE" 'bearing: `refactor`' "refactor bearing is documented"
  assert_contains "$SKILL_FILE" 'bearing: `bug`' "bug bearing is documented"
  assert_contains "$SKILL_FILE" 'bearing: `deep-research`' "deep-research bearing is documented"
  assert_contains "$SKILL_FILE" 'bearing: `feeling-lucky`' "feeling-lucky bearing is documented"
}

test_deep_research_route_has_dedicated_guide() {
  if [ -f "$DEEP_RESEARCH_FILE" ]; then
    pass "deep-research guide file exists"
  else
    fail "deep-research guide file exists" "missing file: $DEEP_RESEARCH_FILE"
  fi

  assert_contains "$SKILL_FILE" '[scope-deep-research.md](scope-deep-research.md)' "reef-scope routes deep research into dedicated guide"
  assert_contains "$DEEP_RESEARCH_FILE" 'what they want researched' "deep-research guide asks what to research"
  assert_contains "$DEEP_RESEARCH_FILE" 'why it matters' "deep-research guide asks why it matters"
  assert_contains "$DEEP_RESEARCH_FILE" 'what end goal they want answered' "deep-research guide asks for the end goal"
}

test_readme_documents_route_options() {
  assert_contains "$README_FILE" 'The route picker always offers these five options:' "README introduces route picker options"
  assert_contains "$README_FILE" '`scope a feature`' "README lists feature route"
  assert_contains "$README_FILE" '`scope a refactor`' "README lists refactor route"
  assert_contains "$README_FILE" '`triage a bug`' "README lists bug route"
  assert_contains "$README_FILE" '`I'\''m feeling lucky (hand over to the reef)`' "README lists feeling-lucky route"
  assert_contains "$README_FILE" '`deep research`' "README lists deep-research route"
}

test_route_picker_lists_exact_routes
test_issue_recommendation_uses_issue_text_only
test_selected_route_persists_as_bearing
test_deep_research_route_has_dedicated_guide
test_readme_documents_route_options

echo ""
if [ "$FAIL" -gt 0 ]; then
  printf "%s" "$OUTPUT_BUF"
  echo "================================"
  printf "Results: %s passed, ${RED}%s failed${NC}, %s total\n" "$PASS" "$FAIL" "$TOTAL"
  exit 1
else
  echo "================================"
  printf "Results: %s passed, %s total\n" "$PASS" "$TOTAL"
fi
