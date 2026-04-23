#!/bin/sh
# Behavioral tests for research and feeling-lucky review guidance.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
INSPECT_FILE="$REPO_ROOT/reef-pulse/inspect.md"
REWORK_FILE="$REPO_ROOT/reef-pulse/rework.md"
SEAL_FILE="$REPO_ROOT/reef-pulse/seal.md"
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

test_inspect_handles_research_and_lucky_work() {
  diagnostics="$(grep -nE 'research|deep-research|feeling-lucky|lucky|mechanical' "$INSPECT_FILE" || true)"
  printf 'DIAGNOSTIC: inspect guidance currently contains:\n%s\n' "$diagnostics"

  assert_contains "$INSPECT_FILE" 'For deep-research, inspect the committed research artifact mechanically rather than treating it like code.' "inspect treats research as committed research"
  assert_contains "$INSPECT_FILE" 'Check that the writing is clear, coherent, not overly drawn out, and actually answers the promised angle or question.' "inspect checks research writing quality and relevance"
  assert_contains "$INSPECT_FILE" 'If acceptance criteria are fuzzy because the issue was intentionally feeling-lucky, do not get fussy about their absence.' "inspect stays mechanically pragmatic for lucky work"
  assert_contains "$INSPECT_FILE" 'Still review lucky work for clarity, simplicity, polish opportunities, and obvious quality problems.' "inspect preserves the normal mechanical bar for lucky work"
}

test_rework_handles_research_gaps_and_lucky_reframing() {
  diagnostics="$(grep -nE 'research|deep-research|feeling-lucky|lucky|bearing|lane' "$REWORK_FILE" || true)"
  printf 'DIAGNOSTIC: rework guidance currently contains:\n%s\n' "$diagnostics"

  assert_contains "$REWORK_FILE" 'For deep-research, rework means revising the committed research docs to close the flagged gaps.' "rework treats research fixes as research-doc revisions"
  assert_contains "$REWORK_FILE" 'Typical research fixes include answering missed questions, tightening the writing, clarifying conclusions, or adding missing source links.' "rework lists research-specific revision work"
  assert_contains "$REWORK_FILE" 'For feeling-lucky, rework may refine the inferred lane or bearing if QA surfaced a better interpretation.' "rework allows lucky work to refine its inferred lane"
}

test_seal_handles_research_and_lucky_holistically() {
  diagnostics="$(grep -nE 'research|deep-research|feeling-lucky|lucky|strict|holistic|end goal' "$SEAL_FILE" || true)"
  printf 'DIAGNOSTIC: seal guidance currently contains:\n%s\n' "$diagnostics"

  assert_contains "$SEAL_FILE" 'For deep-research, review the written research holistically against the end goal, not just the slice acceptance criteria.' "seal reviews research against the end goal"
  assert_contains "$SEAL_FILE" 'Check whether the full research answer is coherent, complete enough for the promised question, and sensible as a whole.' "seal checks the research answer as a complete whole"
  assert_contains "$SEAL_FILE" 'For feeling-lucky, keep the normal mechanical quality bar but apply slightly softer strictness during holistic review.' "seal softens holistic strictness for lucky-origin work"
  assert_contains "$SEAL_FILE" 'Ask whether the outcome makes good sense for the exploratory ticket the human tossed into the reef.' "seal evaluates lucky work against the exploratory ticket"
}

test_orchestration_records_review_bearing_rules() {
  assert_contains "$ORCHESTRATION_FILE" 'contains: `For deep-research, inspect the committed research artifact mechanically rather than treating it like code.`' "orchestration captures inspect research guidance"
  assert_contains "$ORCHESTRATION_FILE" 'contains: `For feeling-lucky, rework may refine the inferred lane or bearing if QA surfaced a better interpretation.`' "orchestration captures rework lucky guidance"
  assert_contains "$ORCHESTRATION_FILE" 'contains: `For deep-research, review the written research holistically against the end goal, not just the slice acceptance criteria.`' "orchestration captures seal research guidance"
  assert_contains "$ORCHESTRATION_FILE" 'contains: `For feeling-lucky, keep the normal mechanical quality bar but apply slightly softer strictness during holistic review.`' "orchestration captures seal lucky guidance"
}

test_inspect_handles_research_and_lucky_work
test_rework_handles_research_gaps_and_lucky_reframing
test_seal_handles_research_and_lucky_holistically
test_orchestration_records_review_bearing_rules

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
