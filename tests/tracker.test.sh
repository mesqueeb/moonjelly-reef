#!/bin/sh
# Integration tests for reef-pulse/tracker.sh
# Runs against real temp directories with mock config
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$TESTS_DIR/.."
TRACKER="$REPO_ROOT/reef-pulse/tracker.sh"
SCRIPT_DIR="$REPO_ROOT/reef-pulse/scripts"
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

setup() {
  TEST_ROOT="$(mktemp -d)"
  TRACKER_PATH="$TEST_ROOT/tracker"
  mkdir -p "$TRACKER_PATH"

  # Create a git repo so tracker.sh can find the repo root
  REPO="$TEST_ROOT/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init >/dev/null 2>&1
  git checkout -b main >/dev/null 2>&1
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null 2>&1

  # Create mock config
  mkdir -p "$REPO/.agents/moonjelly-reef"
  cat > "$REPO/.agents/moonjelly-reef/config.md" <<CONF
---
tracker: local-tracker-gitignored
tracker-path: $TRACKER_PATH
tracker-branch: —
---
CONF
}

teardown() {
  cd /
  rm -rf "$TEST_ROOT"
}

t() { "$TRACKER" "$@"; }

# ============================================================
# ISSUE CREATE (plans) — #25
# ============================================================

test_create_plan() {
  setup
  cd "$REPO"

  id="$(t issue create --title "my-feature" --label to-scope 2>/dev/null)"
  if [ "$id" = "1" ]; then
    pass "create plan: returns ID 1"
  else
    fail "create plan: returns ID 1" "got: $id"
  fi

  if [ -f "$TRACKER_PATH/1 my-feature/[to-scope] plan.md" ]; then
    pass "create plan: creates correct folder and file"
  else
    fail "create plan: creates correct folder and file" "file not found"
  fi

  teardown
}

test_create_plan_with_body() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "hello world" --label to-scope >/dev/null 2>&1

  content="$(cat "$TRACKER_PATH/1 my-feature/[to-scope] plan.md")"
  if [ "$content" = "hello world" ]; then
    pass "create plan: writes body content"
  else
    fail "create plan: writes body content" "got: $content"
  fi

  teardown
}

test_create_plan_auto_increment() {
  setup
  cd "$REPO"

  t issue create --title "first" --label to-scope >/dev/null 2>&1
  id="$(t issue create --title "second" --label to-scope 2>/dev/null)"

  if [ "$id" = "2" ]; then
    pass "create plan: auto-increments to 2"
  else
    fail "create plan: auto-increments to 2" "got: $id"
  fi

  if [ -d "$TRACKER_PATH/2 second" ]; then
    pass "create plan: second folder exists"
  else
    fail "create plan: second folder exists" "dir not found"
  fi

  teardown
}

test_create_plan_no_config_fails() {
  setup
  cd "$REPO"
  rm "$REPO/.agents/moonjelly-reef/config.md"

  if t issue create --title "nope" --label to-scope >/dev/null 2>&1; then
    fail "create plan: fails without config" "succeeded"
  else
    pass "create plan: fails without config"
  fi

  teardown
}

# ============================================================
# ISSUE CREATE --parent (slices) — #26
# ============================================================

test_create_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  id="$(t issue create --title "auth-endpoint" --body "slice body" --label to-implement --parent 1 2>/dev/null)"

  if [ "$id" = "1-1" ]; then
    pass "create slice: returns ID 1-1"
  else
    fail "create slice: returns ID 1-1" "got: $id"
  fi

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth-endpoint/[to-implement] slice.md" ]; then
    pass "create slice: creates correct folder structure"
  else
    fail "create slice: creates correct folder structure" "file not found"
  fi

  content="$(cat "$TRACKER_PATH/1 my-feature/slices/1-1 auth-endpoint/[to-implement] slice.md")"
  if [ "$content" = "slice body" ]; then
    pass "create slice: writes body content"
  else
    fail "create slice: writes body content" "got: $content"
  fi

  teardown
}

test_create_slice_auto_increment() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "first-slice" --label to-implement --parent 1 >/dev/null 2>&1
  id="$(t issue create --title "second-slice" --label to-implement --parent 1 2>/dev/null)"

  if [ "$id" = "1-2" ]; then
    pass "create slice: auto-increments to 1-2"
  else
    fail "create slice: auto-increments to 1-2" "got: $id"
  fi

  teardown
}

test_create_slice_bad_parent_fails() {
  setup
  cd "$REPO"

  if t issue create --title "orphan" --label to-implement --parent 999 >/dev/null 2>&1; then
    fail "create slice: fails with nonexistent parent" "succeeded"
  else
    pass "create slice: fails with nonexistent parent"
  fi

  teardown
}

# ============================================================
# ISSUE VIEW — #27
# ============================================================

test_view_plan() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content here" --label to-slice >/dev/null 2>&1
  output="$(t issue view 1 --json body,title,labels 2>/dev/null)"

  if echo "$output" | grep -q '"title"'; then
    pass "view plan: returns JSON with title"
  else
    fail "view plan: returns JSON with title" "got: $output"
  fi

  if echo "$output" | grep -q '"my-feature"'; then
    pass "view plan: title is my-feature"
  else
    fail "view plan: title is my-feature" "got: $output"
  fi

  if echo "$output" | grep -q '"to-slice"'; then
    pass "view plan: labels include to-slice"
  else
    fail "view plan: labels include to-slice" "got: $output"
  fi

  if echo "$output" | grep -q 'plan content here'; then
    pass "view plan: body contains plan content"
  else
    fail "view plan: body contains plan content" "got: $output"
  fi

  teardown
}

test_view_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth-endpoint" --body "slice stuff" --label to-implement --parent 1 >/dev/null 2>&1
  output="$(t issue view 1-1 --json body,title,labels 2>/dev/null)"

  if echo "$output" | grep -q '"auth-endpoint"'; then
    pass "view slice: title is auth-endpoint"
  else
    fail "view slice: title is auth-endpoint" "got: $output"
  fi

  if echo "$output" | grep -q '"to-implement"'; then
    pass "view slice: labels include to-implement"
  else
    fail "view slice: labels include to-implement" "got: $output"
  fi

  teardown
}

test_view_nonexistent_fails() {
  setup
  cd "$REPO"

  if t issue view 999 --json body,title,labels >/dev/null 2>&1; then
    fail "view: fails for nonexistent ID" "succeeded"
  else
    pass "view: fails for nonexistent ID"
  fi

  teardown
}

test_view_requires_json_flag() {
  setup
  cd "$REPO"

  t issue create --title "test" --label to-scope >/dev/null 2>&1

  if t issue view 1 >/dev/null 2>&1; then
    fail "view: fails without --json" "succeeded"
  else
    pass "view: fails without --json"
  fi

  teardown
}

# ============================================================
# ISSUE EDIT — #28
# ============================================================

test_edit_label() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue edit 1 --remove-label to-scope --add-label to-slice >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/[to-slice] plan.md" ]; then
    pass "edit label: renames tag on plan"
  else
    fail "edit label: renames tag on plan" "file not found"
  fi

  if [ ! -f "$TRACKER_PATH/1 my-feature/[to-scope] plan.md" ]; then
    pass "edit label: old tag file removed"
  else
    fail "edit label: old tag file removed" "old file still exists"
  fi

  teardown
}

test_edit_label_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth" --label to-implement --parent 1 >/dev/null 2>&1
  t issue edit 1-1 --remove-label to-implement --add-label to-inspect >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth/[to-inspect] slice.md" ]; then
    pass "edit label: renames tag on slice"
  else
    fail "edit label: renames tag on slice" "file not found"
  fi

  teardown
}

test_edit_body() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "old" --label to-scope >/dev/null 2>&1
  t issue edit 1 --body "new content" >/dev/null 2>&1

  content="$(cat "$TRACKER_PATH/1 my-feature/[to-scope] plan.md")"
  if [ "$content" = "new content" ]; then
    pass "edit body: overwrites content"
  else
    fail "edit body: overwrites content" "got: $content"
  fi

  teardown
}

test_edit_body_and_label() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "old" --label to-scope >/dev/null 2>&1
  t issue edit 1 --body "updated" --remove-label to-scope --add-label to-slice >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/[to-slice] plan.md" ]; then
    content="$(cat "$TRACKER_PATH/1 my-feature/[to-slice] plan.md")"
    if [ "$content" = "updated" ]; then
      pass "edit body+label: both updated"
    else
      fail "edit body+label: both updated" "body: $content"
    fi
  else
    fail "edit body+label: both updated" "file not found"
  fi

  teardown
}

test_edit_nonexistent_fails() {
  setup
  cd "$REPO"

  if t issue edit 999 --add-label to-slice --remove-label to-scope >/dev/null 2>&1; then
    fail "edit: fails for nonexistent ID" "succeeded"
  else
    pass "edit: fails for nonexistent ID"
  fi

  teardown
}

# ============================================================
# ISSUE CLOSE — #29
# ============================================================

test_close_plan() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-land >/dev/null 2>&1
  t issue close 1 >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/[done] plan.md" ]; then
    pass "close plan: renames tag to done"
  else
    fail "close plan: renames tag to done" "file not found"
  fi

  teardown
}

test_close_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth" --label to-merge --parent 1 >/dev/null 2>&1
  t issue close 1-1 >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth/[done] slice.md" ]; then
    pass "close slice: renames tag to done"
  else
    fail "close slice: renames tag to done" "file not found"
  fi

  teardown
}

# ============================================================
# ISSUE LIST — #29
# ============================================================

test_list_by_label() {
  setup
  cd "$REPO"

  t issue create --title "first" --label to-implement >/dev/null 2>&1
  t issue create --title "second" --label to-scope >/dev/null 2>&1
  t issue create --title "third" --label to-implement >/dev/null 2>&1

  output="$(t issue list --label to-implement --json number,title 2>/dev/null)"

  if echo "$output" | grep -q '"1"'; then
    pass "list: includes matching plan 1"
  else
    fail "list: includes matching plan 1" "got: $output"
  fi

  if echo "$output" | grep -q '"3"'; then
    pass "list: includes matching plan 3"
  else
    fail "list: includes matching plan 3" "got: $output"
  fi

  if echo "$output" | grep -q '"2"'; then
    fail "list: excludes non-matching plan 2" "plan 2 found in output"
  else
    pass "list: excludes non-matching plan 2"
  fi

  teardown
}

test_list_includes_slices() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth" --label to-implement --parent 1 >/dev/null 2>&1
  t issue create --title "db" --label to-implement --parent 1 >/dev/null 2>&1

  output="$(t issue list --label to-implement --json number,title 2>/dev/null)"

  if echo "$output" | grep -q '"1-1"'; then
    pass "list: includes slice 1-1"
  else
    fail "list: includes slice 1-1" "got: $output"
  fi

  if echo "$output" | grep -q '"1-2"'; then
    pass "list: includes slice 1-2"
  else
    fail "list: includes slice 1-2" "got: $output"
  fi

  teardown
}

test_list_empty() {
  setup
  cd "$REPO"

  output="$(t issue list --label to-implement --json number,title 2>/dev/null)"

  if [ "$output" = "[]" ]; then
    pass "list: returns empty array when no matches"
  else
    fail "list: returns empty array when no matches" "got: $output"
  fi

  teardown
}

# ============================================================
# COMMITTED MODE — #30
# ============================================================

setup_committed() {
  TEST_ROOT="$(mktemp -d)"
  ORIGIN="$TEST_ROOT/origin.git"
  REPO="$TEST_ROOT/repo"
  TRACKER_PATH=".agents/moonjelly-reef/tracker"

  git init --bare "$ORIGIN" >/dev/null 2>&1
  git clone "$ORIGIN" "$REPO" >/dev/null 2>&1
  cd "$REPO"
  git checkout -b main >/dev/null 2>&1
  echo "init" > README.md
  mkdir -p "$TRACKER_PATH"
  mkdir -p ".agents/moonjelly-reef"
  cat > ".agents/moonjelly-reef/config.md" <<CONF
---
tracker: local-tracker-committed
tracker-path: $TRACKER_PATH
tracker-branch: main
---
CONF
  git add -A
  git commit -m "initial commit" >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1
}

test_committed_create_pushes() {
  setup_committed

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1

  # The commit should be on origin/main
  git fetch origin >/dev/null 2>&1
  if git log origin/main --oneline | grep -q "tracker:"; then
    pass "committed create: pushes to tracker branch"
  else
    fail "committed create: pushes to tracker branch" "no tracker commit on origin/main"
  fi

  teardown
}

test_committed_edit_pushes() {
  setup_committed

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue edit 1 --remove-label to-scope --add-label to-slice >/dev/null 2>&1

  git fetch origin >/dev/null 2>&1
  log="$(git log origin/main --oneline)"
  # Should have at least 2 tracker commits (create + edit)
  count="$(echo "$log" | grep -c "tracker:" || true)"
  if [ "$count" -ge 2 ]; then
    pass "committed edit: pushes label change to tracker branch"
  else
    fail "committed edit: pushes label change to tracker branch" "commits: $count, log: $log"
  fi

  teardown
}

test_committed_view_no_worktree() {
  setup_committed

  t issue create --title "my-feature" --body "content" --label to-scope >/dev/null 2>&1

  # Simulate what reef-pulse does before dispatching: pull latest
  git pull origin main >/dev/null 2>&1

  # View should work without creating a worktree (reads from working dir)
  output="$(t issue view 1 --json body,title,labels 2>/dev/null)"
  if echo "$output" | grep -q '"my-feature"'; then
    pass "committed view: reads after pull"
  else
    fail "committed view: reads after pull" "got: $output"
  fi

  teardown
}

test_committed_close_pushes() {
  setup_committed

  t issue create --title "my-feature" --label to-land >/dev/null 2>&1
  t issue close 1 >/dev/null 2>&1

  git fetch origin >/dev/null 2>&1
  log="$(git log origin/main --oneline)"
  if echo "$log" | grep -q "tracker:.*close"; then
    pass "committed close: pushes to tracker branch"
  else
    fail "committed close: pushes to tracker branch" "log: $log"
  fi

  teardown
}

# ============================================================
# Run all tests
# ============================================================

test_create_plan
test_create_plan_with_body
test_create_plan_auto_increment
test_create_plan_no_config_fails

test_create_slice
test_create_slice_auto_increment
test_create_slice_bad_parent_fails

test_view_plan
test_view_slice
test_view_nonexistent_fails
test_view_requires_json_flag

test_edit_label
test_edit_label_slice
test_edit_body
test_edit_body_and_label
test_edit_nonexistent_fails

test_close_plan
test_close_slice

test_list_by_label
test_list_includes_slices
test_list_empty

test_committed_create_pushes
test_committed_edit_pushes
test_committed_view_no_worktree
test_committed_close_pushes

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
