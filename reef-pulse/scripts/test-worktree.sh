#!/bin/sh
# Integration tests for reef-worktree-*.sh scripts
# Runs against real git repos in a temp directory
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  printf "${GREEN}PASS${NC}: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
  printf "${RED}FAIL${NC}: %s\n" "$1"
  if [ $# -gt 1 ]; then
    printf "  %s\n" "$2"
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

test_enter_plan_level() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase ratify --slice planning 2>/dev/null)"; then
    expected="$TEST_ROOT/worktree-main-planning-ratify"
    if [ -d "$path" ]; then
      resolved_actual="$(cd "$path" && pwd -P)"
      resolved_expected="$(cd "$expected" && pwd -P)"
      if [ "$resolved_expected" = "$resolved_actual" ]; then
        pass "enter plan-level: correct path and detached HEAD"
      else
        fail "enter plan-level: correct path and detached HEAD" "expected=$resolved_expected actual=$resolved_actual"
      fi
    else
      fail "enter plan-level: correct path and detached HEAD" "path not a directory: $path"
    fi
  else
    fail "enter plan-level: correct path and detached HEAD" "script failed"
  fi

  teardown_repos
}

test_enter_create_slice_branch() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/auth --branch-op create 2>/dev/null)"; then
    if [ -d "$path" ]; then
      branch="$(cd "$path" && git rev-parse --abbrev-ref HEAD)"
      if [ "$branch" = "feat/auth" ]; then
        pass "enter --branch-op create: creates new slice branch"
      else
        fail "enter --branch-op create: creates new slice branch" "expected=feat/auth actual=$branch"
      fi
    else
      fail "enter --branch-op create: creates new slice branch" "worktree dir missing"
    fi
  else
    fail "enter --branch-op create: creates new slice branch" "script failed"
  fi

  teardown_repos
}

test_enter_checkout_existing_branch() {
  setup_repos
  cd "$REPO"

  # Create a branch on origin to check out
  git checkout -b feat/rework-me >/dev/null 2>&1
  echo "slice work" > slice.txt
  git add slice.txt
  git commit -m "slice work" >/dev/null 2>&1
  git push -u origin feat/rework-me >/dev/null 2>&1
  git checkout main >/dev/null 2>&1

  if path="$(enter --base-branch main --target-branch main --phase rework --slice auth \
    --slice-branch feat/rework-me --branch-op checkout 2>/dev/null)"; then
    if [ -f "$path/slice.txt" ]; then
      pass "enter --branch-op checkout: checks out existing slice branch"
    else
      fail "enter --branch-op checkout: checks out existing slice branch" "slice.txt missing"
    fi
  else
    fail "enter --branch-op checkout: checks out existing slice branch" "script failed"
  fi

  teardown_repos
}

test_enter_fails_slice_branch_without_branch_op() {
  setup_repos
  cd "$REPO"

  if enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/auth >/dev/null 2>&1; then
    fail "enter: fails when --slice-branch given without --branch-op" "succeeded"
  else
    pass "enter: fails when --slice-branch given without --branch-op"
  fi

  teardown_repos
}

test_enter_fails_branch_op_without_slice_branch() {
  setup_repos
  cd "$REPO"

  if enter --base-branch main --target-branch main --phase implement --slice auth \
    --branch-op create >/dev/null 2>&1; then
    fail "enter: fails when --branch-op given without --slice-branch" "succeeded"
  else
    pass "enter: fails when --branch-op given without --slice-branch"
  fi

  teardown_repos
}

test_enter_fails_invalid_branch_op() {
  setup_repos
  cd "$REPO"

  if enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/auth --branch-op nope >/dev/null 2>&1; then
    fail "enter: fails on invalid --branch-op" "succeeded"
  else
    pass "enter: fails on invalid --branch-op"
  fi

  teardown_repos
}

test_enter_fails_if_worktree_exists() {
  setup_repos
  cd "$REPO"

  enter --base-branch main --target-branch main --phase inspect --slice auth >/dev/null 2>&1 || true

  if enter --base-branch main --target-branch main --phase inspect --slice auth >/dev/null 2>&1; then
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

  if enter --base-branch main --target-branch main >/dev/null 2>&1; then
    fail "enter: fails without --phase and --slice" "succeeded"
  else
    pass "enter: fails without --phase and --slice"
  fi

  teardown_repos
}

# ============================================================
# EXIT TESTS
# ============================================================

test_exit_removes_clean_worktree() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase inspect --slice auth 2>/dev/null)"; then
    cd "$REPO"
    if exit_wt --path "$path" >/dev/null 2>&1; then
      if [ -d "$path" ]; then
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

  if path="$(enter --base-branch main --target-branch main --phase inspect --slice auth 2>/dev/null)"; then
    echo "dirty" > "$path/dirty.txt"
    cd "$REPO"
    if exit_wt --path "$path" >/dev/null 2>&1; then
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

  if path="$(enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/stage-test --branch-op create 2>/dev/null)"; then
    echo "staged" > "$path/staged.txt"
    (cd "$path" && git add staged.txt)
    cd "$REPO"
    if exit_wt --path "$path" >/dev/null 2>&1; then
      fail "exit: fails on staged changes" "succeeded"
    else
      pass "exit: fails on staged changes"
    fi
  else
    fail "exit: fails on staged changes" "enter failed (test setup)"
  fi

  teardown_repos
}

test_exit_cleans_up_slice_branch() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/cleanup-test --branch-op create 2>/dev/null)"; then
    cd "$REPO"
    if exit_wt --path "$path" --slice-branch feat/cleanup-test >/dev/null 2>&1; then
      if git rev-parse --verify feat/cleanup-test >/dev/null 2>&1; then
        fail "exit --slice-branch: local branch deleted" "branch still exists"
      else
        pass "exit --slice-branch: local branch deleted"
      fi
    else
      fail "exit --slice-branch: local branch deleted" "exit script failed"
    fi
  else
    fail "exit --slice-branch: local branch deleted" "enter failed (test setup)"
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

test_commit_with_slice_branch() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/commit-test --branch-op create 2>/dev/null)"; then
    echo "new feature" > "$path/feature.txt"
    cd "$path"
    if commit_wt --slice-branch feat/commit-test -m "add feature" >/dev/null 2>&1; then
      cd "$REPO"
      git fetch origin >/dev/null 2>&1
      if git rev-parse --verify origin/feat/commit-test >/dev/null 2>&1; then
        pass "commit --slice-branch: pushes to slice branch"
      else
        fail "commit --slice-branch: pushes to slice branch" "branch not on origin"
      fi
    else
      fail "commit --slice-branch: pushes to slice branch" "commit script failed"
    fi
  else
    fail "commit --slice-branch: pushes to slice branch" "enter failed (test setup)"
  fi

  teardown_repos
}

test_commit_with_target_branch() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase slice --slice planning \
    --slice-branch temp-work --branch-op create 2>/dev/null)"; then
    echo "metadata" > "$path/plan.md"
    cd "$path"
    if commit_wt --target-branch main -m "update plan" >/dev/null 2>&1; then
      cd "$REPO"
      git fetch origin >/dev/null 2>&1
      if git log origin/main --oneline | grep -q "update plan"; then
        pass "commit --target-branch: pushes directly to target"
      else
        fail "commit --target-branch: pushes directly to target" "commit not on origin/main"
      fi
    else
      fail "commit --target-branch: pushes directly to target" "commit script failed"
    fi
  else
    fail "commit --target-branch: pushes directly to target" "enter failed (test setup)"
  fi

  teardown_repos
}

test_commit_fails_with_both() {
  setup_repos
  cd "$REPO"

  if commit_wt --slice-branch feat/x --target-branch main -m "msg" >/dev/null 2>&1; then
    fail "commit: fails with both --slice-branch and --target-branch" "succeeded"
  else
    pass "commit: fails with both --slice-branch and --target-branch"
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

  if commit_wt --slice-branch feat/x >/dev/null 2>&1; then
    fail "commit: fails without -m" "succeeded"
  else
    pass "commit: fails without -m"
  fi

  teardown_repos
}

test_commit_fails_on_nothing_to_commit() {
  setup_repos
  cd "$REPO"

  if path="$(enter --base-branch main --target-branch main --phase implement --slice auth \
    --slice-branch feat/empty-test --branch-op create 2>/dev/null)"; then
    cd "$path"
    if commit_wt --slice-branch feat/empty-test -m "empty" >/dev/null 2>&1; then
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

echo "=== worktree-enter.sh ==="
test_enter_plan_level
test_enter_create_slice_branch
test_enter_checkout_existing_branch
test_enter_fails_slice_branch_without_branch_op
test_enter_fails_branch_op_without_slice_branch
test_enter_fails_invalid_branch_op
test_enter_fails_if_worktree_exists
test_enter_fails_on_missing_args

echo ""
echo "=== worktree-exit.sh ==="
test_exit_removes_clean_worktree
test_exit_fails_on_unstaged_changes
test_exit_fails_on_staged_changes
test_exit_cleans_up_slice_branch
test_exit_fails_on_missing_args

echo ""
echo "=== commit.sh ==="
test_commit_with_slice_branch
test_commit_with_target_branch
test_commit_fails_with_both
test_commit_fails_on_missing_args
test_commit_fails_on_nothing_to_commit

echo ""
echo "================================"
printf "Results: %s passed, %s failed, %s total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
