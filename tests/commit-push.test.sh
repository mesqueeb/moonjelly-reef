#!/bin/sh
# Integration tests for commit-push.sh
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

setup_local() {
  TEST_ROOT="$(mktemp -d)"
  REPO="$TEST_ROOT/repo"
  git init "$REPO" >/dev/null 2>&1
  cd "$REPO"
  git checkout -b main >/dev/null 2>&1
  echo "init" > README.md
  git add README.md
  git commit -m "initial commit" >/dev/null 2>&1
  cd "$TEST_ROOT"
}

teardown_local() {
  cd /
  rm -rf "$TEST_ROOT"
}

enter() { "$SCRIPT_DIR/worktree-enter.sh" "$@"; }
commit_push() { "$SCRIPT_DIR/commit-push.sh" "$@"; }

# ============================================================
# COMMIT-PUSH TESTS
# ============================================================

test_commit_pushes_to_branch() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-commit"
  if enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1; then
    echo "new feature" > "$wt_path/feature.txt"
    cd "$wt_path"
    if commit_push --branch feat/commit-test -m "add feature" >/dev/null 2>&1; then
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
    if commit_push --branch main -m "update plan" >/dev/null 2>&1; then
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

  if commit_push >/dev/null 2>&1; then
    fail "commit: fails with no args" "succeeded"
  else
    pass "commit: fails with no args"
  fi

  if commit_push --branch feat/x >/dev/null 2>&1; then
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
    if commit_push --branch feat/empty-test -m "empty" >/dev/null 2>&1; then
      fail "commit: fails when nothing to commit" "succeeded"
    else
      pass "commit: fails when nothing to commit"
    fi
  else
    fail "commit: fails when nothing to commit" "enter failed (test setup)"
  fi

  teardown_repos
}

test_commit_succeeds_without_origin() {
  setup_local
  cd "$REPO"

  # Manually create a worktree — bypass worktree-enter.sh which is tested separately
  wt_path="$TEST_ROOT/worktree-commit-local"
  git -C "$REPO" worktree add "$wt_path" main --detach >/dev/null 2>&1
  echo "local work" > "$wt_path/work.txt"
  cd "$wt_path"

  if commit_push --branch feat/local -m "local work" >/dev/null 2>&1; then
    if git log --oneline | grep -q "local work"; then
      pass "commit (no origin): commits locally without push"
    else
      fail "commit (no origin): commits locally without push" "commit not found in history"
    fi
  else
    fail "commit (no origin): commits locally without push" "script failed"
  fi

  teardown_local
}

# ============================================================
# Run all tests
# ============================================================

test_commit_pushes_to_branch
test_commit_pushes_to_existing_branch
test_commit_fails_on_missing_args
test_commit_fails_on_nothing_to_commit
test_commit_succeeds_without_origin

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
