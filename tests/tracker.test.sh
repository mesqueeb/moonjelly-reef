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
    pass "edit label: renames label on plan"
  else
    fail "edit label: renames label on plan" "file not found"
  fi

  if [ ! -f "$TRACKER_PATH/1 my-feature/[to-scope] plan.md" ]; then
    pass "edit label: old label file removed"
  else
    fail "edit label: old label file removed" "old file still exists"
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
    pass "edit label: renames label on slice"
  else
    fail "edit label: renames label on slice" "file not found"
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

test_edit_title() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue edit 1 --title "renamed-feature" >/dev/null 2>&1

  if [ -d "$TRACKER_PATH/1 renamed-feature" ]; then
    pass "edit title: renames directory for plan"
  else
    fail "edit title: renames directory for plan" "directory not found"
  fi

  if [ ! -d "$TRACKER_PATH/1 my-feature" ]; then
    pass "edit title: old directory removed"
  else
    fail "edit title: old directory removed" "old directory still exists"
  fi

  teardown
}

test_edit_title_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth [await: #0]" --label to-await-waves --parent 1 >/dev/null 2>&1
  t issue edit 1-1 --title "auth" >/dev/null 2>&1

  if [ -d "$TRACKER_PATH/1 my-feature/slices/1-1 auth" ]; then
    pass "edit title slice: renames slice directory"
  else
    fail "edit title slice: renames slice directory" "directory not found"
  fi

  if [ ! -d "$TRACKER_PATH/1 my-feature/slices/1-1 auth [await: #0]" ]; then
    pass "edit title slice: old directory removed"
  else
    fail "edit title slice: old directory removed" "old directory still exists"
  fi

  teardown
}

test_edit_title_with_label() {
  setup
  cd "$REPO"

  t issue create --title "auth [await: #0]" --label to-await-waves >/dev/null 2>&1
  t issue edit 1 --title "auth" --remove-label to-await-waves --add-label to-implement >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 auth/[to-implement] plan.md" ]; then
    pass "edit title+label: file at new path with new label"
  else
    fail "edit title+label: file at new path with new label" "file not found"
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

  if [ -f "$TRACKER_PATH/1 my-feature/[landed] plan.md" ]; then
    pass "close plan: renames label to landed"
  else
    fail "close plan: renames label to landed" "file not found"
  fi

  teardown
}

test_close_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth" --label to-merge --parent 1 >/dev/null 2>&1
  t issue close 1-1 >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth/[landed] slice.md" ]; then
    pass "close slice: renames label to landed"
  else
    fail "close slice: renames label to landed" "file not found"
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

test_list_search_or_labels() {
  setup
  cd "$REPO"

  t issue create --title "first" --label to-scope >/dev/null 2>&1
  t issue create --title "second" --label to-implement >/dev/null 2>&1
  t issue create --title "third" --label to-merge >/dev/null 2>&1
  t issue create --title "fourth" --label to-land >/dev/null 2>&1

  output="$(t issue list --json number,title --search 'label:to-scope OR label:to-implement' 2>/dev/null)"

  if echo "$output" | grep -q '"1"'; then
    pass "list --search: includes to-scope issue"
  else
    fail "list --search: includes to-scope issue" "got: $output"
  fi

  if echo "$output" | grep -q '"2"'; then
    pass "list --search: includes to-implement issue"
  else
    fail "list --search: includes to-implement issue" "got: $output"
  fi

  if echo "$output" | grep -q '"3"'; then
    fail "list --search: excludes non-matching to-merge" "found 3 in output"
  else
    pass "list --search: excludes non-matching to-merge"
  fi

  if echo "$output" | grep -q '"4"'; then
    fail "list --search: excludes non-matching to-land" "found 4 in output"
  else
    pass "list --search: excludes non-matching to-land"
  fi

  teardown
}

test_list_search_includes_labels_field() {
  setup
  cd "$REPO"

  t issue create --title "first" --label to-scope >/dev/null 2>&1
  t issue create --title "second" --label to-implement >/dev/null 2>&1

  output="$(t issue list --json number,title,labels --search 'label:to-scope OR label:to-implement' 2>/dev/null)"

  if echo "$output" | grep -q '"to-scope"'; then
    pass "list --search labels: to-scope label present"
  else
    fail "list --search labels: to-scope label present" "got: $output"
  fi

  if echo "$output" | grep -q '"to-implement"'; then
    pass "list --search labels: to-implement label present"
  else
    fail "list --search labels: to-implement label present" "got: $output"
  fi

  teardown
}

test_list_search_includes_slices() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth" --label to-implement --parent 1 >/dev/null 2>&1
  t issue create --title "db" --label to-inspect --parent 1 >/dev/null 2>&1

  output="$(t issue list --json number,title,labels --search 'label:to-implement OR label:to-inspect' 2>/dev/null)"

  if echo "$output" | grep -q '"1-1"'; then
    pass "list --search: includes to-implement slice"
  else
    fail "list --search: includes to-implement slice" "got: $output"
  fi

  if echo "$output" | grep -q '"1-2"'; then
    pass "list --search: includes to-inspect slice"
  else
    fail "list --search: includes to-inspect slice" "got: $output"
  fi

  if echo "$output" | grep -q '"1"[^-]'; then
    fail "list --search: excludes non-matching plan 1" "found plan 1 in output"
  else
    pass "list --search: excludes non-matching plan 1"
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
# PR CREATE — #120
# ============================================================

test_pr_create_plan() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "implementation report" >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/progress.md" ]; then
    pass "pr create plan: creates progress.md"
  else
    fail "pr create plan: creates progress.md" "file not found"
  fi

  content="$(cat "$TRACKER_PATH/1 my-feature/progress.md")"
  if echo "$content" | grep -q "^head: feat/my-feature"; then
    pass "pr create plan: frontmatter has head"
  else
    fail "pr create plan: frontmatter has head" "got: $content"
  fi

  if echo "$content" | grep -q "^base: main"; then
    pass "pr create plan: frontmatter has base"
  else
    fail "pr create plan: frontmatter has base" "got: $content"
  fi

  if echo "$content" | grep -q "implementation report"; then
    pass "pr create plan: body content written"
  else
    fail "pr create plan: body content written" "got: $content"
  fi

  teardown
}

test_pr_create_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth-endpoint" --body "slice body" --label to-implement --parent 1 >/dev/null 2>&1
  t pr create 1-1 --base main --head feat/auth-endpoint --body "slice report" >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth-endpoint/progress.md" ]; then
    pass "pr create slice: creates progress.md"
  else
    fail "pr create slice: creates progress.md" "file not found"
  fi

  teardown
}

# ============================================================
# PR VIEW — #120
# ============================================================

test_pr_view_fields() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "the report body" >/dev/null 2>&1
  output="$(t pr view 1 --json body,headRefName,baseRefName 2>/dev/null)"

  if echo "$output" | grep -q '"headRefName":"feat/my-feature"'; then
    pass "pr view: headRefName correct"
  else
    fail "pr view: headRefName correct" "got: $output"
  fi

  if echo "$output" | grep -q '"baseRefName":"main"'; then
    pass "pr view: baseRefName correct"
  else
    fail "pr view: baseRefName correct" "got: $output"
  fi

  if echo "$output" | grep -q "the report body"; then
    pass "pr view: body correct"
  else
    fail "pr view: body correct" "got: $output"
  fi

  teardown
}

test_pr_view_comments_reviews() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  output="$(t pr view 1 --json comments,reviews 2>/dev/null)"

  if echo "$output" | grep -q '"comments":\[\]'; then
    pass "pr view: comments empty array"
  else
    fail "pr view: comments empty array" "got: $output"
  fi

  if echo "$output" | grep -q '"reviews":\[\]'; then
    pass "pr view: reviews empty array"
  else
    fail "pr view: reviews empty array" "got: $output"
  fi

  teardown
}

# ============================================================
# PR EDIT — #120
# ============================================================

test_pr_edit_body() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "old report" >/dev/null 2>&1
  t pr edit 1 --body "new report" >/dev/null 2>&1

  content="$(cat "$TRACKER_PATH/1 my-feature/progress.md")"

  # Frontmatter should be preserved
  if echo "$content" | grep -q "^head: feat/my-feature"; then
    pass "pr edit body: frontmatter preserved"
  else
    fail "pr edit body: frontmatter preserved" "got: $content"
  fi

  # Body should be updated
  if echo "$content" | grep -q "new report"; then
    pass "pr edit body: body updated"
  else
    fail "pr edit body: body updated" "got: $content"
  fi

  # Old body should be gone
  if echo "$content" | grep -q "old report"; then
    fail "pr edit body: old body removed" "still found old report"
  else
    pass "pr edit body: old body removed"
  fi

  teardown
}

test_pr_create_with_label() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" --label to-inspect >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/[to-inspect] progress.md" ]; then
    pass "pr create --label: label in filename"
  else
    fail "pr create --label: label in filename" "file not found"
  fi

  teardown
}

test_pr_edit_label() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" --label to-merge >/dev/null 2>&1
  t pr edit 1 --remove-label to-merge --add-label to-seal >/dev/null 2>&1

  if [ -f "$TRACKER_PATH/1 my-feature/[to-seal] progress.md" ]; then
    pass "pr edit label: renamed to new label"
  else
    fail "pr edit label: renamed to new label" "file not found"
  fi

  if [ -f "$TRACKER_PATH/1 my-feature/[to-merge] progress.md" ]; then
    fail "pr edit label: old labeled file removed" "old file still exists"
  else
    pass "pr edit label: old labeled file removed"
  fi

  content="$(cat "$TRACKER_PATH/1 my-feature/[to-seal] progress.md")"
  if echo "$content" | grep -q "report"; then
    pass "pr edit label: body preserved"
  else
    fail "pr edit label: body preserved" "got: $content"
  fi

  teardown
}

test_pr_view_labels() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" --label to-seal >/dev/null 2>&1
  output="$(t pr view 1 --json labels 2>/dev/null)"

  if echo "$output" | grep -q '"to-seal"'; then
    pass "pr view labels: returns label from filename"
  else
    fail "pr view labels: returns label from filename" "got: $output"
  fi

  teardown
}

# ============================================================
# PR MERGE — #121
# ============================================================

# Setup helper that creates a git repo with origin, a feature branch with a commit,
# and a progress.md so pr merge can read head/base.
setup_merge() {
  TEST_ROOT="$(mktemp -d)"
  ORIGIN="$TEST_ROOT/origin.git"
  REPO="$TEST_ROOT/repo"
  TRACKER_PATH="$TEST_ROOT/tracker"

  git init --bare "$ORIGIN" >/dev/null 2>&1
  git clone "$ORIGIN" "$REPO" >/dev/null 2>&1
  cd "$REPO"
  git checkout -b main >/dev/null 2>&1
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1

  # Create feature branch with a commit
  git checkout -b feat/my-feature >/dev/null 2>&1
  echo "feature work" > feature.txt
  git add feature.txt
  git commit -m "add feature" >/dev/null 2>&1
  git push -u origin feat/my-feature >/dev/null 2>&1

  # Back to main for the merge
  git checkout main >/dev/null 2>&1

  # Create tracker dir and config
  mkdir -p "$TRACKER_PATH"
  mkdir -p "$REPO/.agents/moonjelly-reef"
  cat > "$REPO/.agents/moonjelly-reef/config.md" <<CONF
---
tracker: local-tracker-gitignored
tracker-path: $TRACKER_PATH
tracker-branch: —
---
CONF

  # Create issue and progress.md
  mkdir -p "$TRACKER_PATH/1 my-feature"
  echo "plan content" > "$TRACKER_PATH/1 my-feature/[to-inspect] plan.md"
  cat > "$TRACKER_PATH/1 my-feature/progress.md" <<PROGRESS
---
head: feat/my-feature
base: main
---

implementation report
PROGRESS
}

test_pr_merge_squash() {
  setup_merge
  cd "$REPO"

  t pr merge 1 --squash --delete-branch >/dev/null 2>&1

  # Should be on main with the feature file present
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$current_branch" = "main" ]; then
    pass "pr merge squash: stays on base branch"
  else
    fail "pr merge squash: stays on base branch" "on: $current_branch"
  fi

  if [ -f "feature.txt" ]; then
    pass "pr merge squash: feature file present after merge"
  else
    fail "pr merge squash: feature file present after merge" "feature.txt not found"
  fi

  # Squash merge should create a single commit (not a merge commit with two parents)
  parent_count="$(git cat-file -p HEAD | grep -c '^parent' || true)"
  if [ "$parent_count" -eq 1 ]; then
    pass "pr merge squash: single parent (squash merge)"
  else
    fail "pr merge squash: single parent (squash merge)" "parents: $parent_count"
  fi

  teardown
}

test_pr_merge_regular() {
  setup_merge
  cd "$REPO"

  t pr merge 1 --delete-branch >/dev/null 2>&1

  if [ -f "feature.txt" ]; then
    pass "pr merge regular: feature file present after merge"
  else
    fail "pr merge regular: feature file present after merge" "feature.txt not found"
  fi

  # Regular merge should create a merge commit with two parents
  parent_count="$(git cat-file -p HEAD | grep -c '^parent' || true)"
  if [ "$parent_count" -eq 2 ]; then
    pass "pr merge regular: two parents (merge commit)"
  else
    fail "pr merge regular: two parents (merge commit)" "parents: $parent_count"
  fi

  teardown
}

test_pr_merge_deletes_head_branch_locally() {
  setup_merge
  cd "$REPO"

  t pr merge 1 --squash --delete-branch >/dev/null 2>&1

  if git rev-parse --verify feat/my-feature >/dev/null 2>&1; then
    fail "pr merge: deletes head branch locally" "branch still exists"
  else
    pass "pr merge: deletes head branch locally"
  fi

  teardown
}

test_pr_merge_deletes_head_branch_from_origin() {
  setup_merge
  cd "$REPO"

  t pr merge 1 --squash --delete-branch >/dev/null 2>&1

  git fetch origin --prune >/dev/null 2>&1
  if git rev-parse --verify origin/feat/my-feature >/dev/null 2>&1; then
    fail "pr merge: deletes head branch from origin" "remote branch still exists"
  else
    pass "pr merge: deletes head branch from origin"
  fi

  teardown
}

test_pr_merge_no_progress_fails() {
  setup
  cd "$REPO"

  t issue create --title "no-pr" --label to-implement >/dev/null 2>&1

  if t pr merge 1 --squash --delete-branch >/dev/null 2>&1; then
    fail "pr merge: fails without progress.md" "succeeded"
  else
    pass "pr merge: fails without progress.md"
  fi

  teardown
}

test_pr_merge_commit_message() {
  setup_merge
  cd "$REPO"

  t pr merge 1 --squash --delete-branch >/dev/null 2>&1

  msg="$(git log -1 --format='%s')"
  if echo "$msg" | grep -q "feat/my-feature"; then
    pass "pr merge: commit message references head branch"
  else
    fail "pr merge: commit message references head branch" "msg: $msg"
  fi

  teardown
}

# ============================================================
# PR DISPATCH — #120
# ============================================================

test_pr_dispatch() {
  setup
  cd "$REPO"

  if t pr create 1 --base main --head x --body y >/dev/null 2>&1; then
    # It will fail because issue 1 doesn't exist, but it means dispatch accepted 'pr'
    fail "pr dispatch: accepts pr command group" "should fail because issue 1 doesn't exist"
  else
    # If it fails with "issue 1 not found" that means dispatch worked, resolution failed
    pass "pr dispatch: accepts pr command group (fails at resolution, not dispatch)"
  fi

  teardown
}

# ============================================================
# PR CREATE — gh-compatible syntax (--title, --label, no positional ID)
# ============================================================

test_pr_create_gh_compat() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  # Call pr create without positional ID, using --title to resolve
  id="$(t pr create --base main --head feat/my-feature --title "my-feature" --body "report" --label to-inspect 2>/dev/null)"

  if [ "$id" = "1" ]; then
    pass "pr create gh-compat: returns issue ID"
  else
    fail "pr create gh-compat: returns issue ID" "got: $id"
  fi

  if [ -f "$TRACKER_PATH/1 my-feature/[to-inspect] progress.md" ]; then
    pass "pr create gh-compat: creates labeled progress.md"
  else
    fail "pr create gh-compat: creates labeled progress.md" "file not found"
  fi

  content="$(cat "$TRACKER_PATH/1 my-feature/[to-inspect] progress.md")"
  if echo "$content" | grep -q "^head: feat/my-feature"; then
    pass "pr create gh-compat: frontmatter has head"
  else
    fail "pr create gh-compat: frontmatter has head" "got: $content"
  fi

  teardown
}

test_pr_create_gh_compat_slice() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --label to-scope >/dev/null 2>&1
  t issue create --title "auth-endpoint" --body "slice body" --label to-implement --parent 1 >/dev/null 2>&1
  id="$(t pr create --base main --head feat/auth --title "auth-endpoint" --body "slice report" --label to-inspect 2>/dev/null)"

  if [ "$id" = "1-1" ]; then
    pass "pr create gh-compat slice: returns slice ID"
  else
    fail "pr create gh-compat slice: returns slice ID" "got: $id"
  fi

  if [ -f "$TRACKER_PATH/1 my-feature/slices/1-1 auth-endpoint/[to-inspect] progress.md" ]; then
    pass "pr create gh-compat slice: creates labeled progress.md"
  else
    fail "pr create gh-compat slice: creates labeled progress.md" "file not found"
  fi

  teardown
}

# ============================================================
# PR VIEW — -q flag, mergeStateStatus, number, --web
# ============================================================

test_pr_view_q_flag() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "the report body" >/dev/null 2>&1
  output="$(t pr view 1 --json body -q .body 2>/dev/null)"

  if [ "$output" = "the report body" ]; then
    pass "pr view -q: extracts body field"
  else
    fail "pr view -q: extracts body field" "got: $output"
  fi

  teardown
}

test_pr_view_merge_state_status() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  output="$(t pr view 1 --json mergeStateStatus -q .mergeStateStatus 2>/dev/null)"

  if [ "$output" = "CLEAN" ]; then
    pass "pr view: mergeStateStatus returns CLEAN"
  else
    fail "pr view: mergeStateStatus returns CLEAN" "got: $output"
  fi

  teardown
}

test_pr_view_number_field() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  output="$(t pr view 1 --json number,body,headRefName,baseRefName 2>/dev/null)"

  if echo "$output" | grep -q '"number":"1"'; then
    pass "pr view: number field included"
  else
    fail "pr view: number field included" "got: $output"
  fi

  teardown
}

test_pr_view_web_noop() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1

  if t pr view 1 --web >/dev/null 2>&1; then
    pass "pr view --web: no-op succeeds"
  else
    fail "pr view --web: no-op succeeds" "exited non-zero"
  fi

  teardown
}

# ============================================================
# PR LIST — #119 rework
# ============================================================

test_pr_list() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  output="$(t pr list --json number,title 2>/dev/null)"

  if echo "$output" | grep -q '"1"'; then
    pass "pr list: includes issue with progress.md"
  else
    fail "pr list: includes issue with progress.md" "got: $output"
  fi

  teardown
}

test_pr_list_search() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t issue create --title "other-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  t pr create 2 --base main --head feat/other --body "report" >/dev/null 2>&1
  output="$(t pr list --search "my-feature" --json number,title 2>/dev/null)"

  if echo "$output" | grep -q '"1"'; then
    pass "pr list --search: finds matching PR"
  else
    fail "pr list --search: finds matching PR" "got: $output"
  fi

  if echo "$output" | grep -q '"2"'; then
    fail "pr list --search: excludes non-matching PR" "found 2 in output"
  else
    pass "pr list --search: excludes non-matching PR"
  fi

  teardown
}

test_pr_list_search_head() {
  setup
  cd "$REPO"

  t issue create --title "my-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t issue create --title "other-feature" --body "plan content" --label to-implement >/dev/null 2>&1
  t pr create 1 --base main --head feat/my-feature --body "report" >/dev/null 2>&1
  t pr create 2 --base main --head feat/other --body "report" >/dev/null 2>&1
  output="$(t pr list --search "head:feat/my-feature" --json number,title 2>/dev/null)"

  if echo "$output" | grep -q '"1"'; then
    pass "pr list head: syntax: finds matching PR"
  else
    fail "pr list head: syntax: finds matching PR" "got: $output"
  fi

  if echo "$output" | grep -q '"2"'; then
    fail "pr list head: syntax: excludes non-matching PR" "found 2 in output"
  else
    pass "pr list head: syntax: excludes non-matching PR"
  fi

  teardown
}

test_pr_list_empty() {
  setup
  cd "$REPO"

  output="$(t pr list --json number,title 2>/dev/null)"

  if [ "$output" = "[]" ]; then
    pass "pr list: returns empty array when no PRs"
  else
    fail "pr list: returns empty array when no PRs" "got: $output"
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
test_edit_title
test_edit_title_slice
test_edit_title_with_label

test_close_plan
test_close_slice

test_list_by_label
test_list_includes_slices
test_list_empty
test_list_search_or_labels
test_list_search_includes_labels_field
test_list_search_includes_slices

test_committed_create_pushes
test_committed_edit_pushes
test_committed_view_no_worktree
test_committed_close_pushes

test_pr_create_plan
test_pr_create_slice
test_pr_create_with_label
test_pr_view_fields
test_pr_view_comments_reviews
test_pr_view_labels
test_pr_edit_body
test_pr_edit_label
test_pr_merge_squash
test_pr_merge_regular
test_pr_merge_deletes_head_branch_locally
test_pr_merge_deletes_head_branch_from_origin
test_pr_merge_no_progress_fails
test_pr_merge_commit_message
test_pr_dispatch
test_pr_create_gh_compat
test_pr_create_gh_compat_slice
test_pr_view_q_flag
test_pr_view_merge_state_status
test_pr_view_number_field
test_pr_view_web_noop
test_pr_list
test_pr_list_search
test_pr_list_search_head
test_pr_list_empty

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
