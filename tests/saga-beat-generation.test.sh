#!/bin/sh
# Contract tests for saga beat generation and world-state persistence
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PULSE_SKILL="$REPO_ROOT/reef-pulse/SKILL.md"
SAGA_PROMPT="$REPO_ROOT/reef-pulse/saga-writer.md"
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

test_pulse_skill_reads_world_state_at_session_start() {
  assert_contains "$PULSE_SKILL" 'Read the current `world.md` contents into a `WORLD_STATE` variable' "pulse skill: world state is loaded at session start"
  assert_contains "$PULSE_SKILL" 'Carry that state through the session' "pulse skill: world state persists across the session"
}

test_pulse_skill_uses_story_subagent_for_lore() {
  assert_contains "$PULSE_SKILL" 'generate a lore snippet by spawning a storytelling sub-agent' "pulse skill: lore generation uses a sub-agent"
  assert_contains "$PULSE_SKILL" 'Do not generate lore inline inside the pulse' "pulse skill: inline lore generation is forbidden"
  assert_contains "$PULSE_SKILL" '`sonnet` unless the prompt is intentionally updated later' "pulse skill: creative model is called out during beat generation"
}

test_pulse_skill_passes_required_context_to_story_subagent() {
  assert_contains "$PULSE_SKILL" 'The current `WORLD_STATE` loaded at session start and updated after each prior beat' "pulse skill: sub-agent receives current world state"
  assert_contains "$PULSE_SKILL" 'The prior lore snippets from the current session, in order' "pulse skill: sub-agent receives prior beats"
  assert_contains "$PULSE_SKILL" 'Pipeline state for this pulse: dispatched phases, returned transitions, human items, idle items, and any labels still waiting after the pulse' "pulse skill: sub-agent receives pipeline state"
  assert_contains "$PULSE_SKILL" 'Treat pipeline state as loose DnD-style inspiration and not narrate events 1:1' "pulse skill: sub-agent gets anti-transcript guidance"
}

test_pulse_skill_requires_parseable_story_response() {
  assert_contains "$PULSE_SKILL" '`beat:` followed by the lore prose' "pulse skill: beat response label is documented"
  assert_contains "$PULSE_SKILL" '`world:` followed by the full updated `world.md` contents' "pulse skill: world response label is documented"
}

test_pulse_skill_persists_updated_world_state() {
  assert_contains "$PULSE_SKILL" 'Replace `WORLD_STATE` with the returned `world:` content' "pulse skill: in-memory world state is updated"
  assert_contains "$PULSE_SKILL" 'Persist the returned `world:` content back to `$WORLD_FILE` immediately' "pulse skill: world state is written to disk after each beat"
}

test_pulse_skill_keeps_non_lore_output_unchanged() {
  assert_contains "$PULSE_SKILL" 'Leave dispatch lines, metrics tables, and return-result output unchanged' "pulse skill: non-lore output contract is preserved"
  assert_contains "$PULSE_SKILL" 'existing dashed lore box format' "pulse skill: lore box format stays the same"
}

test_saga_prompt_documents_parseable_contract() {
  assert_contains "$SAGA_PROMPT" 'It includes dispatched phases, returned transitions, human items, idle items, and labels that remain after the pulse' "saga prompt: pipeline state details are documented"
  assert_contains "$SAGA_PROMPT" 'Treat these details as inspiration only' "saga prompt: pipeline state is framed as inspiration"
  assert_contains "$SAGA_PROMPT" '`beat:` on its own label' "saga prompt: beat label is documented"
  assert_contains "$SAGA_PROMPT" '`world:` on its own label' "saga prompt: world label is documented"
  assert_contains "$SAGA_PROMPT" 'Do not wrap either part in code fences' "saga prompt: parseability rule exists"
  assert_contains "$SAGA_PROMPT" 'persist `world:` back to disk after every beat' "saga prompt: persistence expectation is documented"
}

test_world_state_load_happens_before_lore_generation() {
  skill_lines="$(grep -n 'Read the current `world.md` contents into a `WORLD_STATE` variable\|Print lore snippet' "$PULSE_SKILL")"
  world_line="$(printf '%s\n' "$skill_lines" | grep 'Read the current `world.md` contents into a `WORLD_STATE` variable' | head -1 | cut -d: -f1)"
  lore_line="$(printf '%s\n' "$skill_lines" | grep 'Print lore snippet' | head -1 | cut -d: -f1)"

  if [ -n "$world_line" ] && [ -n "$lore_line" ] && [ "$world_line" -lt "$lore_line" ]; then
    pass "pulse skill: world state is loaded before lore generation"
  else
    fail "pulse skill: world state is loaded before lore generation" "world_line=$world_line lore_line=$lore_line"
  fi
}

test_pulse_skill_reads_world_state_at_session_start
test_pulse_skill_uses_story_subagent_for_lore
test_pulse_skill_passes_required_context_to_story_subagent
test_pulse_skill_requires_parseable_story_response
test_pulse_skill_persists_updated_world_state
test_pulse_skill_keeps_non_lore_output_unchanged
test_saga_prompt_documents_parseable_contract
test_world_state_load_happens_before_lore_generation

printf "%b" "$OUTPUT_BUF"
printf "\n================================\n"
printf "Results: %s passed, %s total\n" "$PASS" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
