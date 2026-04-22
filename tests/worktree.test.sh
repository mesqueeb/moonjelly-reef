#!/bin/sh
# Integration tests for worktree-enter.sh, worktree-exit.sh, commit.sh
# Runs against real git repos in a temp directory
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$TESTS_DIR/../reef-pulse"
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

setup_repos() {
  TEST_ROOT="$(mktemp -d)"
  ORIGIN="$TEST_ROOT/origin.git"
  REPO="$TEST_ROOT/repo"

  git init --bare "$ORIGIN" >/dev/null 2>&1
  git clone "$ORIGIN" "$REPO" >/dev/null 2>&1
  cd "$REPO"
  git checkout -b main >/dev/null 2>&1
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1
  cd "$TEST_ROOT"
}

teardown_repos() {
  cd /
  rm -rf "$TEST_ROOT"
}

enter() { "$SCRIPT_DIR/worktree-enter.sh" "$@"; }
exit_wt() { "$SCRIPT_DIR/worktree-exit.sh" "$@"; }
commit_wt() { "$SCRIPT_DIR/commit.sh" "$@"; }

# ============================================================
# ENTER TESTS
# ============================================================

test_enter_detached_head() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-seal"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    if [ -d "$wt_path" ]; then
      head_status="$(cd "$wt_path" && git rev-parse --abbrev-ref HEAD)"
      if [ "$head_status" = "HEAD" ]; then
        pass "enter: creates detached HEAD worktree"
      else
        fail "enter: creates detached HEAD worktree" "expected detached HEAD, got $head_status"
      fi
    else
      fail "enter: creates detached HEAD worktree" "path not a directory: $wt_path"
    fi
  else
    fail "enter: creates detached HEAD worktree" "script failed"
  fi

  teardown_repos
}

test_enter_at_caller_defined_path() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/my-custom-path"
  output="$(enter --fork-from main --pull-latest main --path "$wt_path" 2>/dev/null)"
  if [ $? -eq 0 ]; then
    path="$(echo "$output" | head -1)"
    resolved_actual="$(cd "$path" && pwd -P)"
    resolved_expected="$(cd "$wt_path" && pwd -P)"
    if [ "$resolved_expected" = "$resolved_actual" ]; then
      pass "enter: worktree at caller-defined path"
    else
      fail "enter: worktree at caller-defined path" "expected=$resolved_expected actual=$resolved_actual"
    fi
  else
    fail "enter: worktree at caller-defined path" "script failed"
  fi

  teardown_repos
}

test_enter_creates_nested_parent_dirs() {
  setup_repos
  cd "$REPO"

  wt_path="$REPO/.worktrees/nested/worktree-seal"
  output="$(enter --fork-from main --pull-latest main --path "$wt_path" 2>/dev/null)"
  if [ $? -eq 0 ]; then
    path="$(echo "$output" | head -1)"
    resolved_actual="$(cd "$path" && pwd -P)"
    resolved_expected="$(cd "$wt_path" && pwd -P)"
    if [ "$resolved_expected" = "$resolved_actual" ] && [ -d "$REPO/.worktrees/nested" ]; then
      pass "enter: creates nested parent dirs for repo-local worktrees"
    else
      fail "enter: creates nested parent dirs for repo-local worktrees" "expected=$resolved_expected actual=$resolved_actual"
    fi
  else
    fail "enter: creates nested parent dirs for repo-local worktrees" "script failed"
  fi

  teardown_repos
}

test_enter_fails_if_worktree_exists() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-dup"
  enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1 || true

  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    fail "enter: fails if worktree already exists" "second call succeeded"
  else
    pass "enter: fails if worktree already exists"
  fi

  teardown_repos
}

test_enter_fails_on_missing_args() {
  setup_repos
  cd "$REPO"

  if enter >/dev/null 2>&1; then
    fail "enter: fails with no args" "succeeded"
  else
    pass "enter: fails with no args"
  fi

  if enter --fork-from main --pull-latest main >/dev/null 2>&1; then
    fail "enter: fails without --path" "succeeded"
  else
    pass "enter: fails without --path"
  fi

  if enter --pull-latest main --path /tmp/some-path >/dev/null 2>&1; then
    fail "enter: fails without --fork-from" "succeeded"
  else
    pass "enter: fails without --fork-from"
  fi

  if enter --fork-from main --path /tmp/some-path2 >/dev/null 2>&1; then
    fail "enter: fails without --pull-latest" "succeeded"
  else
    pass "enter: fails without --pull-latest"
  fi

  teardown_repos
}

# ============================================================
# PULL-LATEST TESTS
# ============================================================

test_pull_latest_same_branch() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-same"
  output="$(enter --fork-from main --pull-latest main --path "$wt_path" 2>/dev/null)"
  status="$(echo "$output" | tail -1)"
  if [ "$status" = "ready" ]; then
    pass "pull-latest: same branch outputs ready"
  else
    fail "pull-latest: same branch outputs ready" "got: $status"
  fi

  teardown_repos
}

test_pull_latest_clean_merge() {
  setup_repos
  cd "$REPO"

  # Create a target branch forked from main
  git checkout -b feat/target >/dev/null 2>&1
  echo "target work" > target.txt
  git add target.txt
  git commit -m "target commit" >/dev/null 2>&1
  git push origin feat/target >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  # Add a commit to main that feat/target doesn't have
  echo "main update" > main-update.txt
  git add main-update.txt
  git commit -m "main update" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  wt_path="$TEST_ROOT/worktree-merge"
  output="$(enter --fork-from feat/target --pull-latest main --path "$wt_path" 2>/dev/null)"
  status="$(echo "$output" | tail -1)"

  if echo "$status" | grep -q "^synced: pulled .* commits from main into feat/target$"; then
    # Verify push happened
    git fetch origin >/dev/null 2>&1
    if git -C "$REPO" log origin/feat/target --oneline | grep -q "Merge"; then
      # Verify worktree is still detached HEAD
      head_status="$(cd "$wt_path" && git rev-parse --abbrev-ref HEAD)"
      if [ "$head_status" = "HEAD" ]; then
        pass "pull-latest: clean merge syncs and pushes"
      else
        fail "pull-latest: clean merge syncs and pushes" "not detached HEAD: $head_status"
      fi
    else
      fail "pull-latest: clean merge syncs and pushes" "merge commit not on origin"
    fi
  else
    fail "pull-latest: clean merge syncs and pushes" "got: $status"
  fi

  teardown_repos
}

test_pull_latest_conflicts() {
  setup_repos
  cd "$REPO"

  # Create a target branch that modifies README.md
  git checkout -b feat/conflict >/dev/null 2>&1
  echo "conflict version A" > README.md
  git add README.md
  git commit -m "conflict A" >/dev/null 2>&1
  git push origin feat/conflict >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  # Modify the same file on main
  echo "conflict version B" > README.md
  git add README.md
  git commit -m "conflict B" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  wt_path="$TEST_ROOT/worktree-conflict"
  output="$(enter --fork-from feat/conflict --pull-latest main --path "$wt_path" 2>/dev/null)"
  status="$(echo "$output" | tail -1)"

  if [ "$status" = "conflicts: merge of main into feat/conflict has conflicts" ]; then
    # Verify conflict markers exist in worktree
    if grep -q "<<<<<<" "$wt_path/README.md" 2>/dev/null; then
      # Verify nothing was pushed (origin/feat/conflict should still be at "conflict A")
      git fetch origin >/dev/null 2>&1
      last_msg="$(git log origin/feat/conflict -1 --format=%s)"
      if [ "$last_msg" = "conflict A" ]; then
        pass "pull-latest: conflicts outputs message and leaves markers"
      else
        fail "pull-latest: conflicts outputs message and leaves markers" "push happened: $last_msg"
      fi
    else
      fail "pull-latest: conflicts outputs message and leaves markers" "no conflict markers in worktree"
    fi
  else
    fail "pull-latest: conflicts outputs message and leaves markers" "got: $status"
  fi

  teardown_repos
}

test_pull_latest_already_up_to_date() {
  setup_repos
  cd "$REPO"

  # Create a target branch that is ahead of main (main is ancestor)
  git checkout -b feat/ahead >/dev/null 2>&1
  echo "ahead work" > ahead.txt
  git add ahead.txt
  git commit -m "ahead commit" >/dev/null 2>&1
  git push origin feat/ahead >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  wt_path="$TEST_ROOT/worktree-uptodate"
  output="$(enter --fork-from feat/ahead --pull-latest main --path "$wt_path" 2>/dev/null)"
  status="$(echo "$output" | tail -1)"

  if [ "$status" = "ready" ]; then
    # Verify no merge commit was created (still at "ahead commit")
    last_msg="$(cd "$wt_path" && git log -1 --format=%s)"
    if [ "$last_msg" = "ahead commit" ]; then
      pass "pull-latest: already up to date outputs ready"
    else
      fail "pull-latest: already up to date outputs ready" "unexpected commit: $last_msg"
    fi
  else
    fail "pull-latest: already up to date outputs ready" "got: $status"
  fi

  teardown_repos
}

test_pull_latest_detached_head_after_merge() {
  setup_repos
  cd "$REPO"

  # Create a target branch
  git checkout -b feat/detach-test >/dev/null 2>&1
  echo "detach work" > detach.txt
  git add detach.txt
  git commit -m "detach commit" >/dev/null 2>&1
  git push origin feat/detach-test >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  # Add commit to main
  echo "main detach" > main-detach.txt
  git add main-detach.txt
  git commit -m "main detach" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  wt_path="$TEST_ROOT/worktree-detach"
  enter --fork-from feat/detach-test --pull-latest main --path "$wt_path" >/dev/null 2>&1

  head_status="$(cd "$wt_path" && git rev-parse --abbrev-ref HEAD)"
  if [ "$head_status" = "HEAD" ]; then
    pass "pull-latest: worktree stays detached HEAD after merge"
  else
    fail "pull-latest: worktree stays detached HEAD after merge" "got: $head_status"
  fi

  teardown_repos
}

# ============================================================
# EXIT TESTS
# ============================================================

test_exit_removes_clean_worktree() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-clean"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    cd "$REPO"
    if exit_wt --path "$wt_path" >/dev/null 2>&1; then
      if [ -d "$wt_path" ]; then
        fail "exit: removes clean worktree" "directory still exists"
      else
        pass "exit: removes clean worktree"
      fi
    else
      fail "exit: removes clean worktree" "exit script failed"
    fi
  else
    fail "exit: removes clean worktree" "enter failed (test setup)"
  fi

  teardown_repos
}

test_exit_fails_on_unstaged_changes() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-dirty"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    echo "dirty" > "$wt_path/dirty.txt"
    cd "$REPO"
    if exit_wt --path "$wt_path" >/dev/null 2>&1; then
      fail "exit: fails on unstaged changes" "succeeded"
    else
      pass "exit: fails on unstaged changes"
    fi
  else
    fail "exit: fails on unstaged changes" "enter failed (test setup)"
  fi

  teardown_repos
}

test_exit_fails_on_staged_changes() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-staged"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    echo "staged" > "$wt_path/staged.txt"
    (cd "$wt_path" && git add staged.txt)
    cd "$REPO"
    if exit_wt --path "$wt_path" >/dev/null 2>&1; then
      fail "exit: fails on staged changes" "succeeded"
    else
      pass "exit: fails on staged changes"
    fi
  else
    fail "exit: fails on staged changes" "enter failed (test setup)"
  fi

  teardown_repos
}

test_exit_fails_on_missing_args() {
  setup_repos
  cd "$REPO"

  if exit_wt >/dev/null 2>&1; then
    fail "exit: fails with no args" "succeeded"
  else
    pass "exit: fails with no args"
  fi

  teardown_repos
}

# ============================================================
# COMMIT TESTS
# ============================================================

test_commit_pushes_to_branch() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-commit"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    echo "new feature" > "$wt_path/feature.txt"
    cd "$wt_path"
    if commit_wt --branch feat/commit-test -m "add feature" >/dev/null 2>&1; then
      cd "$REPO"
      git fetch origin >/dev/null 2>&1
      if git rev-parse --verify origin/feat/commit-test >/dev/null 2>&1; then
        pass "commit --branch: pushes to named branch"
      else
        fail "commit --branch: pushes to named branch" "branch not on origin"
      fi
    else
      fail "commit --branch: pushes to named branch" "commit script failed"
    fi
  else
    fail "commit --branch: pushes to named branch" "enter failed (test setup)"
  fi

  teardown_repos
}

test_commit_pushes_to_existing_branch() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-commit-main"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    echo "metadata" > "$wt_path/plan.md"
    cd "$wt_path"
    if commit_wt --branch main -m "update plan" >/dev/null 2>&1; then
      cd "$REPO"
      git fetch origin >/dev/null 2>&1
      if git log origin/main --oneline | grep -q "update plan"; then
        pass "commit --branch: pushes directly to existing branch"
      else
        fail "commit --branch: pushes directly to existing branch" "commit not on origin/main"
      fi
    else
      fail "commit --branch: pushes directly to existing branch" "commit script failed"
    fi
  else
    fail "commit --branch: pushes directly to existing branch" "enter failed (test setup)"
  fi

  teardown_repos
}

test_commit_fails_on_missing_args() {
  setup_repos
  cd "$REPO"

  if commit_wt >/dev/null 2>&1; then
    fail "commit: fails with no args" "succeeded"
  else
    pass "commit: fails with no args"
  fi

  if commit_wt --branch feat/x >/dev/null 2>&1; then
    fail "commit: fails without -m" "succeeded"
  else
    pass "commit: fails without -m"
  fi

  teardown_repos
}

test_commit_fails_on_nothing_to_commit() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-empty"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    cd "$wt_path"
    if commit_wt --branch feat/empty-test -m "empty" >/dev/null 2>&1; then
      fail "commit: fails when nothing to commit" "succeeded"
    else
      pass "commit: fails when nothing to commit"
    fi
  else
    fail "commit: fails when nothing to commit" "enter failed (test setup)"
  fi

  teardown_repos
}

# ============================================================
# Run all tests
# ============================================================

test_enter_detached_head
test_enter_at_caller_defined_path
test_enter_creates_nested_parent_dirs
test_enter_fails_if_worktree_exists
test_enter_fails_on_missing_args

test_pull_latest_same_branch
test_pull_latest_clean_merge
test_pull_latest_conflicts
test_pull_latest_already_up_to_date
test_pull_latest_detached_head_after_merge

test_exit_removes_clean_worktree
test_exit_fails_on_unstaged_changes
test_exit_fails_on_staged_changes
test_exit_fails_on_missing_args

test_commit_pushes_to_branch
test_commit_pushes_to_existing_branch
test_commit_fails_on_missing_args
test_commit_fails_on_nothing_to_commit

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
