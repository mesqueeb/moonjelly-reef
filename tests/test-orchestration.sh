#!/bin/sh
# test-orchestration.sh — verify phase .md files match ORCHESTRATION.md
#
# Reads ORCHESTRATION.md as the source of truth.
# For each phase/skill, checks that every command string exists in the .md file,
# that commands appear in the declared order, and that ensure-body-contains strings are present.
#
# Commands set to false are skipped.
# The order check uses the LAST occurrence of each command's key substring in the .md.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
ORCHESTRATION="$REPO_ROOT/ORCHESTRATION.md"
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
    "tracker.sh issue view"*)  echo "tracker.sh issue view" ;;
    "tracker.sh issue edit"*)  echo "tracker.sh issue edit" ;;
    "tracker.sh issue close"*) echo "tracker.sh issue close" ;;
    "tracker.sh issue create"*) echo "tracker.sh issue create" ;;
    "tracker.sh issue list"*)  echo "tracker.sh issue list" ;;
    "git fetch"*)     echo "git fetch" ;;
    "git push"*)      echo "git push" ;;
    "git merge"*)     echo "git merge" ;;
    "rename "*)       echo "rename" ;;
    *)                echo "$cmd" | cut -c1-30 ;;
  esac
}

last_line_of() {
  grep -nF -e "$2" "$1" | tail -1 | cut -d: -f1
}

# ============================================================
# Parse ORCHESTRATION.md into testable lines
# Format: source_file|op_name|check_type|value
# ============================================================

python3 -c "
import re, sys

with open('$ORCHESTRATION') as f:
    lines = f.readlines()

source_file = None
op_name = None
in_code = False
section_type = None

def check_type_for(op):
    if op == 'set-variables':
        return 'sh'
    if op in ('fetch-context', 'update-tracker'):
        return 'tracker'
    return 'cmd'

for raw in lines:
    line = raw.rstrip('\\n')

    # Track section
    if line.startswith('## Skills'):
        section_type = 'skills'
        continue
    if line.startswith('## Phases'):
        section_type = 'phases'
        continue

    # Phase/skill heading — extract path from markdown link
    m = re.match(r'^### (.+)', line)
    if m:
        heading = m.group(1).strip()
        link = re.match(r'\[[^\]]+\]\(\.\/([^)]+)\)', heading)
        if link:
            source_file = link.group(1)
        elif section_type == 'skills':
            source_file = heading.lstrip('/') + '/SKILL.md'
        else:
            source_file = 'reef-pulse/' + heading
        op_name = None
        continue

    if source_file is None:
        continue

    # Operation bullet (top-level: '- op-name')
    m = re.match(r'^- (\S+)', line)
    if m:
        op_name = m.group(1)
        continue

    if op_name is None:
        continue

    # Code block start
    if re.match(r'^\s+\`\`\`sh', line):
        in_code = True
        continue

    # Code block end
    if in_code and re.match(r'^\s+\`\`\`', line):
        in_code = False
        continue

    # Code block content
    if in_code:
        code = line.strip()
        if code:
            ct = check_type_for(op_name)
            print(f'{source_file}|{op_name}|{ct}|{code}')
        continue

    # Sub-items: '  - pass: \`...\`' or '  - fail: \`...\`'
    m = re.match(r'^\s+- (pass|fail):\s*\`([^\`]+)\`', line)
    if m:
        sub = m.group(1)
        cmd = m.group(2)
        print(f'{source_file}|{op_name}|tracker-{sub}|{cmd}')
        continue
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
