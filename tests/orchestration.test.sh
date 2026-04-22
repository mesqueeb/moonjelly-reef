#!/bin/sh
# test-orchestration.sh — verify phase .md files match ORCHESTRATION.md
#
# Reads ORCHESTRATION.md as the source of truth.
# For each phase/skill, checks that every explicit artifact from ORCHESTRATION.md
# exists in the .md file and appears in the declared order.
#
# Commands set to false are skipped.
# The order check uses the first occurrence of each artifact after the previous one.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
ORCHESTRATION="$REPO_ROOT/ORCHESTRATION.md"
TMPFILE="$(mktemp)"

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

# Extract a searchable fixed-string pattern from a command string.
make_pattern() {
  cmd="$1"
  case "$cmd" in
    *worktree-enter.sh*)
      echo "worktree-enter.sh --fork-from"
      ;;
    *commit.sh*)
      echo "commit.sh --branch"
      ;;
    *worktree-exit.sh*)
      echo "worktree-exit.sh"
      ;;
    "gh pr create"*)  echo "gh pr create" ;;
    "gh pr merge"*)   echo "gh pr merge" ;;
    "gh pr view"*)    echo "gh pr view" ;;
    "gh pr edit"*)    echo "gh pr edit" ;;
    "gh issue edit"*) echo "gh issue edit" ;;
    "gh issue close"*) echo "gh issue close" ;;
    "gh issue view"*) echo "gh issue view" ;;
    "tracker.sh pr create"*)  echo "tracker.sh pr create" ;;
    "tracker.sh pr merge"*)   echo "tracker.sh pr merge" ;;
    "tracker.sh pr view"*)    echo "tracker.sh pr view" ;;
    "tracker.sh pr edit"*)    echo "tracker.sh pr edit" ;;
    "tracker.sh issue view"*)  echo "tracker.sh issue view" ;;
    "tracker.sh issue edit"*)  echo "tracker.sh issue edit" ;;
    "tracker.sh issue close"*) echo "tracker.sh issue close" ;;
    "tracker.sh issue create"*) echo "tracker.sh issue create" ;;
    "tracker.sh issue list"*)  echo "tracker.sh issue list" ;;
    "git fetch"*)     echo "git fetch" ;;
    "git push"*)      echo "git push" ;;
    "git merge"*)     echo "git merge" ;;
    "rename "*)       echo "rename" ;;
    *)                printf '%s' "$cmd" | cut -c1-30 ;;
  esac
}

next_match_of() {
  file="$1"
  pattern="$2"
  after_offset="${3:--1}"
  python3 - "$file" "$pattern" "$after_offset" <<'PY'
import sys
path, pattern, after_offset = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(path, encoding="utf-8") as f:
    text = f.read()
idx = text.find(pattern, after_offset + 1)
if idx == -1:
    sys.exit(0)
line = text.count("\n", 0, idx) + 1
print(f"{idx}|{line}")
PY
}

# ============================================================
# Parse ORCHESTRATION.md into testable lines
# Format: source_file|line_no|check_type|value
# ============================================================

python3 -c "
import re, sys

with open('$ORCHESTRATION') as f:
    lines = f.readlines()

source_file = None
current_op = None
in_code = False
section_type = None

def check_type_for(op, code):
    if op == 'set-variables':
        return 'sh'
    if op == 'fetch-context':
        return 'tracker'
    if code.startswith('./tracker.sh ') or code.startswith('gh '):
        return 'tracker'
    return 'cmd'

for line_no, raw in enumerate(lines, start=1):
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
        current_op = None
        continue

    if source_file is None:
        continue

    # Operation bullet (top-level bullets are visual grouping only)
    m = re.match(r'^- (.+)', line)
    if m:
        current_op = m.group(1)
        continue

    if current_op is None:
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
        if code and code != 'false':
            ct = check_type_for(current_op, code)
            print(f'{source_file}|{line_no}|{ct}|{code}')
        continue

    # Contains directive: '  - contains: \`...\`'
    m = re.match(r'^\s+- contains:\s*\`([^\`]+)\`', line)
    if m:
        text = m.group(1)
        for part in text.split(' + '):
            print(f'{source_file}|{line_no}|contains|{part}')
        continue
" > "$TMPFILE"

# ============================================================
# Validate ORCHESTRATION.md structure
# ============================================================

OUTPUT_BUF="${OUTPUT_BUF}=== ORCHESTRATION.md structure ===
"
in_section=false
section_line=0
section_name=""
struct_fail=0
while IFS= read -r line; do
  section_line=$((section_line + 1))
  # Detect ### headings
  case "$line" in
    '### '*)
      in_section=true
      section_name="$line"
      continue
      ;;
    '## '* | '# '*)
      in_section=false
      continue
      ;;
  esac
  if $in_section && [ -n "$line" ]; then
    case "$line" in
      '- '*) ;;
      '  '*) ;;
      *)
        fail "ORCHESTRATION.md structure > bad line in $section_name" "line $section_line: $line"
        struct_fail=1
        ;;
    esac
  fi
done < "$ORCHESTRATION"
if [ "$struct_fail" -eq 0 ]; then
  pass "ORCHESTRATION.md structure > all section lines start with '- ' or '  '"
fi

# ============================================================
# Run tests
# ============================================================

current_source=""
prev_offset=-1
prev_line=0

while IFS='|' read -r source_file orchestration_line check_type value; do
  md_path="$REPO_ROOT/$source_file"

  # Print header on first encounter
  if [ "$source_file" != "$current_source" ]; then
    current_source="$source_file"
    prev_offset=-1
    prev_line=0
    OUTPUT_BUF="${OUTPUT_BUF}
=== $source_file ===
"
    if [ ! -f "$md_path" ]; then
      fail "$source_file: file not found"
      continue
    fi
  fi

  # Build label
  label="$source_file > ORCHESTRATION.md:$orchestration_line"
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
    match=$(next_match_of "$md_path" "$pattern" "$prev_offset")
    if [ -z "$match" ]; then
      fail "$label" "found only before previous checkpoint: $value"
      continue
    fi
    offset="${match%%|*}"
    line="${match##*|}"
    pass "$label"
    prev_offset="$offset"
    prev_line="$line"
  else
    fail "$label" "expected pattern: $pattern"
  fi

done < "$TMPFILE"

rm -f "$TMPFILE"

# ============================================================
# Results
# ============================================================

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
