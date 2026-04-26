#!/bin/sh
# Integration tests for push.sh
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
push_sh() { "$SCRIPT_DIR/push.sh" "$@"; }

# ============================================================
# PUSH TESTS
# ============================================================

test_push_creates_remote_branch_with_origin() {
  setup_repos
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-push"
  enter --fork-from main --pull-latest main --path "$wt_path" >/dev/null 2>&1
  cd "$wt_path"

  if push_sh --branch feat/push-test >/dev/null 2>&1; then
    git -C "$REPO" fetch origin >/dev/null 2>&1
    if git -C "$REPO" rev-parse --verify origin/feat/push-test >/dev/null 2>&1; then
      pass "push (with origin): creates remote branch"
    else
      fail "push (with origin): creates remote branch" "branch not on origin"
    fi
  else
    fail "push (with origin): creates remote branch" "script failed"
  fi

  teardown_repos
}

test_push_creates_local_ref_without_origin() {
  setup_local
  cd "$REPO"

  wt_path="$TEST_ROOT/worktree-push-local"
  git -C "$REPO" worktree add "$wt_path" main --detach >/dev/null 2>&1
  cd "$wt_path"

  if push_sh --branch feat/local-push >/dev/null 2>&1; then
    if git -C "$REPO" rev-parse --verify feat/local-push >/dev/null 2>&1; then
      pass "push (no origin): creates local branch ref"
    else
      fail "push (no origin): creates local branch ref" "local branch not found"
    fi
  else
    fail "push (no origin): creates local branch ref" "script failed"
  fi

  teardown_local
}

test_push_fails_on_missing_args() {
  setup_repos
  cd "$REPO"

  if push_sh >/dev/null 2>&1; then
    fail "push: fails with no args" "succeeded"
  else
    pass "push: fails with no args"
  fi

  teardown_repos
}

# ============================================================
# Run all tests
# ============================================================

test_push_creates_remote_branch_with_origin
test_push_creates_local_ref_without_origin
test_push_fails_on_missing_args

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
