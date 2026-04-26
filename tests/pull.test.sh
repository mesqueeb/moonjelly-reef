#!/bin/sh
# Integration tests for pull.sh
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

pull_sh() { "$SCRIPT_DIR/pull.sh" "$@"; }

# ============================================================
# PULL TESTS
# ============================================================

test_pull_updates_local_with_origin() {
  setup_repos
  cd "$REPO"

  # Push a new commit to origin from a second clone
  git clone "$ORIGIN" "$TEST_ROOT/repo2" >/dev/null 2>&1
  cd "$TEST_ROOT/repo2"
  git checkout main >/dev/null 2>&1
  echo "remote work" > remote.txt
  git add remote.txt
  git commit -m "remote commit" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  cd "$REPO"
  old_sha="$(git rev-parse HEAD)"

  if pull_sh --branch main >/dev/null 2>&1; then
    new_sha="$(git rev-parse HEAD)"
    if [ "$new_sha" != "$old_sha" ]; then
      pass "pull (with origin): fast-forwards local branch"
    else
      fail "pull (with origin): fast-forwards local branch" "HEAD did not advance"
    fi
  else
    fail "pull (with origin): fast-forwards local branch" "script failed"
  fi

  teardown_repos
}

test_pull_noop_without_origin() {
  setup_local
  cd "$REPO"

  if pull_sh --branch main >/dev/null 2>&1; then
    pass "pull (no origin): exits 0 without error"
  else
    fail "pull (no origin): exits 0 without error" "script failed"
  fi

  teardown_local
}

test_pull_fails_on_missing_args() {
  setup_repos
  cd "$REPO"

  if pull_sh >/dev/null 2>&1; then
    fail "pull: fails with no args" "succeeded"
  else
    pass "pull: fails with no args"
  fi

  teardown_repos
}

# ============================================================
# Run all tests
# ============================================================

test_pull_updates_local_with_origin
test_pull_noop_without_origin
test_pull_fails_on_missing_args

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
