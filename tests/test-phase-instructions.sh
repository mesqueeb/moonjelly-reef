#!/bin/sh
# test-phase-instructions.sh — verify phase .md files match phase-instructions.json
#
# Reads phase-instructions.json as the source of truth.
# For each phase/skill, checks that every command string exists in the .md file,
# that commands appear in the declared order, and that ensure-body-contains strings are present.
#
# Commands set to false are skipped.
# The order check uses the LAST occurrence of each command's key substring in the .md.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
JSON="$TESTS_DIR/phase-instructions.json"
TMPFILE="$(mktemp)"

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

# Extract a searchable fixed-string pattern from a command string.
make_pattern() {
  cmd="$1"
  case "$cmd" in
    worktree-enter.sh*)
      echo "worktree-enter.sh --fork-from"
      ;;
    commit.sh*)
      echo "commit.sh --branch"
      ;;
    worktree-exit.sh*)
      echo "worktree-exit.sh"
      ;;
    "gh pr create"*)  echo "gh pr create" ;;
    "gh pr merge"*)   echo "gh pr merge" ;;
    "gh pr view"*)    echo "gh pr view" ;;
    "gh pr edit"*)    echo "gh pr edit" ;;
    "gh issue edit"*) echo "gh issue edit" ;;
    "gh issue close"*) echo "gh issue close" ;;
    "gh issue view"*) echo "gh issue view" ;;
    "git fetch"*)     echo "git fetch" ;;
    "git push"*)      echo "git push" ;;
    "rename "*)       echo "rename" ;;
    *)                echo "$cmd" | cut -c1-30 ;;
  esac
}

last_line_of() {
  grep -nF -e "$2" "$1" | tail -1 | cut -d: -f1
}

# ============================================================
# Flatten JSON into testable lines
# Format: source_file|op_name|check_type|value
# ============================================================

python3 -c "
import json

with open('$JSON') as f:
    data = json.load(f)

def resolve_md(name, section):
    if section == 'skills':
        return name + '/SKILL.md'
    else:
        return 'reef-pulse/' + name

def emit(md_file, op_name, key, val):
    print(f'{md_file}|{op_name}|{key}|{val}')

for section in ['skills', 'phases']:
    if section not in data:
        continue
    for name, ops in data[section].items():
        if not isinstance(ops, list):
            continue
        md_file = resolve_md(name, section)
        for op in ops:
            op_name = op.get('op', '?')
            # sh arrays in set-variables: each line is a literal check
            sh = op.get('sh')
            if isinstance(sh, list):
                for line in sh:
                    emit(md_file, op_name, 'sh', line)
            # Command keys (string or array)
            for key in ['cmd', 'tracker-github', 'tracker-local', 'tracker-local-gitignored', 'tracker-local-committed', 'tracker-github-pass', 'tracker-github-fail']:
                val = op.get(key)
                if val is None or val is False or isinstance(val, bool):
                    continue
                if isinstance(val, list):
                    for line in val:
                        emit(md_file, op_name, key, line)
                elif isinstance(val, str):
                    emit(md_file, op_name, key, val)
" > "$TMPFILE"

# ============================================================
# Run tests
# ============================================================

current_source=""
prev_line=0
prev_op=""
prev_check_type=""

while IFS='|' read -r source_file op_name check_type value; do
  md_path="$REPO_ROOT/$source_file"

  # Print header on first encounter
  if [ "$source_file" != "$current_source" ]; then
    current_source="$source_file"
    prev_line=0
    prev_op=""
    prev_check_type=""
    echo ""
    echo "=== $source_file ==="
    if [ ! -f "$md_path" ]; then
      fail "$source_file: file not found"
      continue
    fi
  fi

  # Reset ordering when entering a new op or check_type so tracker-local
  # arrays (which contain enter/commit/exit patterns) don't interfere with
  # the main flow's ordering, and different tracker types within the same op
  # don't interfere with each other.
  if [ "$op_name" != "$prev_op" ] || [ "$check_type" != "$prev_check_type" ]; then
    prev_line=0
    prev_op="$op_name"
    prev_check_type="$check_type"
  fi

  # Build label
  label="$source_file > $op_name"
  if [ "$check_type" != "cmd" ]; then
    label="$label ($check_type)"
  fi

  # For sh lines and tracker arrays, use the value literally.
  # For commands, extract a key substring via make_pattern.
  if [ "$check_type" = "sh" ]; then
    pattern="$value"
  else
    pattern=$(make_pattern "$value")
  fi

  if grep -qF -e "$pattern" "$md_path"; then
    line=$(last_line_of "$md_path" "$pattern")
    pass "$label"

    # Order check: should not appear before the previous found command
    if [ "$prev_line" -gt 0 ] && [ -n "$line" ] && [ "$line" -lt "$prev_line" ]; then
      fail "$label: ordering — line $line is before previous at line $prev_line"
    fi
    if [ -n "$line" ]; then
      prev_line="$line"
    fi
  else
    fail "$label" "expected pattern: $pattern"
  fi

done < "$TMPFILE"

rm -f "$TMPFILE"

# ============================================================
# Results
# ============================================================

echo ""
echo "================================"
printf "Results: %s passed, %s failed, %s total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
