#!/bin/sh
# Integration tests for worktree-enter.sh, worktree-exit.sh, commit.sh
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

test_enter_detached_head() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-ratify"
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if path="$(enter --fork-from main --path "$wt_path" 2>/dev/null)"; then
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

test_enter_fails_if_worktree_exists() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-dup"
  enter --fork-from main --path "$wt_path" >/dev/null 2>&1 || true

  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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

  if enter --fork-from main >/dev/null 2>&1; then
    fail "enter: fails without --path" "succeeded"
  else
    pass "enter: fails without --path"
  fi

  if enter --path /tmp/some-path >/dev/null 2>&1; then
    fail "enter: fails without --fork-from" "succeeded"
  else
    pass "enter: fails without --fork-from"
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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
  if enter --fork-from main --path "$wt_path" >/dev/null 2>&1; then
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

echo "=== worktree-enter.sh ==="
test_enter_detached_head
test_enter_at_caller_defined_path
test_enter_fails_if_worktree_exists
test_enter_fails_on_missing_args

echo ""
echo "=== worktree-exit.sh ==="
test_exit_removes_clean_worktree
test_exit_fails_on_unstaged_changes
test_exit_fails_on_staged_changes
test_exit_fails_on_missing_args

echo ""
echo "=== commit.sh ==="
test_commit_pushes_to_branch
test_commit_pushes_to_existing_branch
test_commit_fails_on_missing_args
test_commit_fails_on_nothing_to_commit

echo ""
echo "================================"
printf "Results: %s passed, %s failed, %s total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
