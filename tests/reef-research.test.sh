#!/bin/sh
# Behavioral tests for the dedicated to-research lifecycle.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PULSE_FILE="$REPO_ROOT/reef-pulse/SKILL.md"
AWAIT_FILE="$REPO_ROOT/reef-pulse/await-waves.md"
RESEARCH_FILE="$REPO_ROOT/reef-pulse/research.md"
SINGLE_FILE="$REPO_ROOT/reef-pulse/slice-one-issue.md"
SUBISSUES_FILE="$REPO_ROOT/reef-pulse/slice-subissues.md"
README_FILE="$REPO_ROOT/README.md"
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

test_pulse_dispatches_to_research_as_first_class_phase() {
  diagnostics="$(grep -nE 'to-await-waves|to-implement|to-research|to-inspect|🪸|🐬' "$PULSE_FILE" || true)"
  printf 'DIAGNOSTIC: reef-pulse phase routing currently contains:\n%s\n' "$diagnostics"

  assert_contains "$PULSE_FILE" 'label:to-research' "pulse scan includes to-research items"
  assert_contains "$PULSE_FILE" '| `to-research`  | `$SKILL_DIR/research.md`  |' "pulse dispatch table routes to-research into research.md"
  assert_contains "$PULSE_FILE" '| `to-research`    | `  🐬`      |' "pulse emoji table assigns the dolphin to to-research"
}

test_await_waves_promotes_research_work_into_to_research() {
  assert_contains "$AWAIT_FILE" 'label `to-research`' "await-waves docs describe promotion into to-research for research work"
  assert_contains "$AWAIT_FILE" 'NEXT_PHASE="to-research" # or "to-implement" or "to-await-waves" depending on bearing and blockers' "await-waves handoff documents research-aware routing"
}

test_slice_flows_stop_forcing_research_into_to_implement() {
  assert_contains "$SINGLE_FILE" 'For deep-research, label the issue to-research instead of to-implement.' "single-issue slicing routes research issues into to-research"
  assert_contains "$SINGLE_FILE" 'NEXT_PHASE="to-research"' "single-issue handoff returns to-research for research work"
  assert_contains "$SUBISSUES_FILE" 'SLICE_LABEL="{to-research for unblocked deep-research slices, otherwise to-implement; or to-await-waves if blocked}"' "subissue slicing labels unblocked research slices to-research"
}

test_research_phase_exists_and_documents_markdown_outputs() {
  if [ -f "$RESEARCH_FILE" ]; then
    pass "research phase file exists"
  else
    fail "research phase file exists" "missing file: $RESEARCH_FILE"
  fi

  assert_contains "$RESEARCH_FILE" 'produce a durable research artifact instead of code' "research phase focuses on durable research artifacts"
  assert_contains "$RESEARCH_FILE" 'lightweight source links near externally sourced findings' "research phase requires nearby source links"
  assert_contains "$RESEARCH_FILE" './commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: research"' "research phase commits research artifacts onto the PR branch"
}

test_readme_and_orchestration_document_to_research() {
  assert_contains "$README_FILE" 'state "🌊　to-research" as to_research' "README state machine includes to-research"
  assert_contains "$README_FILE" '<summary>🌊 <b><code>to-research</code></b> 🏷️</summary>' "README adds a dedicated to-research phase section"
  assert_contains "$README_FILE" '🐬' "README uses dolphin flavor text for the research phase"
  assert_contains "$ORCHESTRATION_FILE" '### [research.md](./reef-pulse/research.md)' "orchestration spec includes the research phase file"
  assert_contains "$ORCHESTRATION_FILE" './tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-research --add-label to-inspect' "orchestration spec records research issue promotion to inspect"
}

test_pulse_dispatches_to_research_as_first_class_phase
test_await_waves_promotes_research_work_into_to_research
test_slice_flows_stop_forcing_research_into_to_implement
test_research_phase_exists_and_documents_markdown_outputs
test_readme_and_orchestration_document_to_research

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
