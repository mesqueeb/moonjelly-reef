#!/bin/sh
# Behavioral tests for reef-pulse slicing instructions.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
SLICE_FILE="$REPO_ROOT/reef-pulse/slice.md"
SINGLE_FILE="$REPO_ROOT/reef-pulse/slice-one-issue.md"
SUBISSUES_FILE="$REPO_ROOT/reef-pulse/slice-subissues.md"
ORCHESTRATION_FILE="$REPO_ROOT/ORCHESTRATION.md"
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

test_slice_router_handles_research_and_lucky_bearings() {
  diagnostics="$(grep -nE 'deep-research|feeling-lucky|research-native|best-effort|follow-up|angle-based|dependency-based' "$SLICE_FILE" || true)"
  printf 'DIAGNOSTIC: slice.md bearing guidance currently contains:\n%s\n' "$diagnostics"

  assert_contains "$SLICE_FILE" '`deep-research` plans as research-native work' "slice router treats deep-research as research-native work"
  assert_contains "$SLICE_FILE" 'Compact research plans can stay as a single research issue' "slice router keeps compact research as one issue"
  assert_contains "$SLICE_FILE" 'angle-based or dependency-based research slices' "slice router can split larger research work into research slices"
  assert_contains "$SLICE_FILE" 'deeply interpret the ticket using both the issue and the codebase' "slice router lets feeling-lucky inspect issue plus codebase"
  assert_contains "$SLICE_FILE" 'rewrite `bearing` into a combined value such as `feature (feeling-lucky)`' "slice router preserves lucky provenance in rewritten bearing"
  assert_contains "$SLICE_FILE" 'without asking the user follow-up questions' "slice router handles lucky work without bouncing back to scope"
}

test_single_issue_path_preserves_bearing_and_acceptance_shape() {
  assert_contains "$SINGLE_FILE" 'scoped `pr-branch` and rewritten `bearing` preserved' "single-issue flow preserves rewritten bearing in frontmatter"
  assert_contains "$SINGLE_FILE" 'If the slice bearing is deep-research, the acceptance criteria must stay research-focused' "single-issue flow keeps research acceptance criteria research-native"
  assert_contains "$SINGLE_FILE" 'For deep-research, label the issue to-research instead of to-implement.' "single-issue flow routes research work into to-research"
}

test_subissues_path_carries_effective_bearing_into_slice_bodies() {
  assert_contains "$SUBISSUES_FILE" 'PLAN_BEARING="{from plan issue body bearing field}"' "subissues flow reads bearing from the plan"
  assert_contains "$SUBISSUES_FILE" 'EFFECTIVE_BEARING="{deep-research or inferred lane such as feature (feeling-lucky)}"' "subissues flow computes effective bearing for lucky work"
  assert_contains "$SUBISSUES_FILE" 'bearing: $SLICE_BEARING' "subissue template persists slice bearing in frontmatter"
  assert_contains "$SUBISSUES_FILE" 'SLICE_LABEL="{to-research for unblocked deep-research slices, otherwise to-implement; or to-await-waves if blocked}"' "subissues flow routes research slices into to-research when unblocked"
  assert_contains "$SUBISSUES_FILE" 'For deep-research, make the slices research-native' "subissues flow keeps research slice descriptions research-native"
}

test_orchestration_tracks_slice_bearing_rules() {
  assert_contains "$ORCHESTRATION_FILE" 'contains: `deep-research` + `feeling-lucky` + `feature (feeling-lucky)`' "orchestration spec records slice bearing cases"
  assert_contains "$ORCHESTRATION_FILE" 'contains: `inferred combined value before saving the issue body`' "orchestration spec records single-issue bearing preservation"
  assert_contains "$ORCHESTRATION_FILE" 'contains: `For deep-research, label the issue to-research instead of to-implement.`' "orchestration spec records research single-issue routing"
  assert_contains "$ORCHESTRATION_FILE" 'bearing: $SLICE_BEARING' "orchestration spec records subissue bearing frontmatter"
}

test_slice_router_handles_research_and_lucky_bearings
test_single_issue_path_preserves_bearing_and_acceptance_shape
test_subissues_path_carries_effective_bearing_into_slice_bodies
test_orchestration_tracks_slice_bearing_rules

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
