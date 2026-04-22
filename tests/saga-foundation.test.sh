#!/bin/sh
# Contract tests for the saga foundation prompt and bootstrap instructions
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PULSE_SKILL="$REPO_ROOT/reef-pulse/SKILL.md"
SAGA_PROMPT="$REPO_ROOT/reef-pulse/saga-writer.md"
WORLD_TEMPLATE="$REPO_ROOT/reef-pulse/world-template.md"
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

test_pulse_skill_bootstraps_saga_state() {
  assert_contains "$PULSE_SKILL" '.agents/moonjelly-reef/saga/' "pulse skill: saga directory path is documented"
  assert_contains "$PULSE_SKILL" 'world.md' "pulse skill: world state file is documented"
  assert_contains "$PULSE_SKILL" 'Initialize `world.md` from `$SKILL_DIR/world-template.md`' "pulse skill: world bootstrap source is documented"
}

test_world_template_has_required_story_fields() {
  assert_contains "$WORLD_TEMPLATE" '## Reef setting' "world template: reef setting section exists"
  assert_contains "$WORLD_TEMPLATE" '## Active characters' "world template: active characters section exists"
  assert_contains "$WORLD_TEMPLATE" '## Ongoing threads' "world template: ongoing threads section exists"
  assert_contains "$WORLD_TEMPLATE" '## Mood' "world template: mood section exists"
  assert_contains "$WORLD_TEMPLATE" '## Current act' "world template: current act section exists"
  assert_contains "$WORLD_TEMPLATE" '## Next beat hook' "world template: next beat hook section exists"
}

test_saga_prompt_contract_is_documented() {
  assert_contains "$SAGA_PROMPT" 'Model: `sonnet`' "saga prompt: model choice is documented"
  assert_contains "$SAGA_PROMPT" 'Kishōtenketsu' "saga prompt: Kishotenketsu guidance exists"
  assert_contains "$SAGA_PROMPT" '## Input contract' "saga prompt: input contract exists"
  assert_contains "$SAGA_PROMPT" '## Output contract' "saga prompt: output contract exists"
  assert_contains "$SAGA_PROMPT" 'what NOT to do' "saga prompt: failure example is framed as what NOT to do"
  assert_contains "$SAGA_PROMPT" 'issue #128' "saga prompt: failure example references the scoped issue"
  assert_contains "$SAGA_PROMPT" 'Do not narrate the dispatch log beat-by-beat' "saga prompt: anti-pattern for 1:1 narration exists"
}

test_pulse_skill_uses_saga_prompt() {
  assert_contains "$PULSE_SKILL" '$SKILL_DIR/saga-writer.md' "pulse skill: saga writer prompt path is documented"
}

test_pulse_skill_bootstraps_only_once() {
  assert_contains "$PULSE_SKILL" 'when it does not already exist' "pulse skill: bootstrap is conditional"
}

test_pulse_skill_preserves_existing_story_collection() {
  assert_contains "$PULSE_SKILL" 'lore story list' "pulse skill: session beat collection remains in place"
}

test_pulse_skill_includes_bootstrap_timing() {
  assert_contains "$PULSE_SKILL" 'first iteration of the pulse' "pulse skill: bootstrap lives at session start"
}

test_pulse_skill_mentions_persistent_world_state() {
  assert_contains "$PULSE_SKILL" 'persistent world state' "pulse skill: world state persistence is described"
}

test_pulse_skill_links_prompt_to_later_phases() {
  assert_contains "$PULSE_SKILL" 'later storytelling steps' "pulse skill: prompt is framed as a dependency"
}

test_pulse_skill_mentions_bootstrap_behavior() {
  assert_contains "$PULSE_SKILL" 'bootstrap behavior' "pulse skill: bootstrap behavior is explicit"
}

test_pulse_skill_mentions_storytelling_contract() {
  assert_contains "$PULSE_SKILL" 'storytelling contract' "pulse skill: storytelling contract is explicit"
}

test_pulse_skill_mentions_characters_threads_and_hook() {
  assert_contains "$PULSE_SKILL" 'active characters' "pulse skill: active characters are documented"
  assert_contains "$PULSE_SKILL" 'ongoing threads' "pulse skill: ongoing threads are documented"
  assert_contains "$PULSE_SKILL" 'one-line hook for the next beat' "pulse skill: next beat hook is documented"
}

test_pulse_skill_bootstraps_world_template_before_lore() {
  skill_lines="$(grep -n 'world-template.md\|Print lore snippet' "$PULSE_SKILL")"
  world_line="$(printf '%s\n' "$skill_lines" | grep 'world-template.md' | head -1 | cut -d: -f1)"
  lore_line="$(printf '%s\n' "$skill_lines" | grep 'Print lore snippet' | head -1 | cut -d: -f1)"

  if [ -n "$world_line" ] && [ -n "$lore_line" ] && [ "$world_line" -lt "$lore_line" ]; then
    pass "pulse skill: world bootstrap instructions appear before lore generation"
  else
    fail "pulse skill: world bootstrap instructions appear before lore generation" "world_line=$world_line lore_line=$lore_line"
  fi
}

test_pulse_skill_bootstraps_saga_state
test_world_template_has_required_story_fields
test_saga_prompt_contract_is_documented
test_pulse_skill_uses_saga_prompt
test_pulse_skill_bootstraps_only_once
test_pulse_skill_preserves_existing_story_collection
test_pulse_skill_includes_bootstrap_timing
test_pulse_skill_mentions_persistent_world_state
test_pulse_skill_links_prompt_to_later_phases
test_pulse_skill_mentions_bootstrap_behavior
test_pulse_skill_mentions_storytelling_contract
test_pulse_skill_mentions_characters_threads_and_hook
test_pulse_skill_bootstraps_world_template_before_lore

printf "%b" "$OUTPUT_BUF"
printf "\n================================\n"
printf "Results: %s passed, %s total\n" "$PASS" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
