#!/bin/sh
# tracker.sh — local issue tracker CLI for Moonjelly Reef
#
# Mirrors the `gh issue` interface for local file-based tracking.
# Reads config from .agents/moonjelly-reef/config.md (found via git repo root).
#
# Usage:
#   tracker.sh issue view   <id> --json body,title,labels
#   tracker.sh issue edit   <id> [--body "..."] [--remove-label X] [--add-label Y]
#   tracker.sh issue create [--title "..."] [--body "..."] [--label X] [--parent <id>]
#   tracker.sh issue close  <id>
#   tracker.sh issue list   [--label X] [--json number,title] [--limit N]
set -eu

# ============================================================
# Config
# ============================================================

find_config() {
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: not inside a git repository" >&2
    exit 1
  }
  CONFIG="$ROOT/.agents/moonjelly-reef/config.md"
  if [ ! -f "$CONFIG" ]; then
    echo "Error: config not found at $CONFIG" >&2
    exit 1
  fi
}

read_config() {
  find_config
  # Read frontmatter values
  _raw_path="$(sed -n 's/^tracker-path: *//p' "$CONFIG" | head -1)"
  TRACKER_BRANCH="$(sed -n 's/^tracker-branch: *//p' "$CONFIG" | head -1)"
  TRACKER_TYPE="$(sed -n 's/^tracker: *//p' "$CONFIG" | head -1)"

  if [ -z "$_raw_path" ] || [ "$_raw_path" = "—" ]; then
    echo "Error: tracker-path not set in config" >&2
    exit 1
  fi

  # Resolve tracker path relative to repo root
  case "$_raw_path" in
    /*) TRACKER_PATH="$_raw_path" ;;
    *)  TRACKER_PATH="$ROOT/$_raw_path" ;;
  esac

  IS_COMMITTED=false
  if [ "$TRACKER_TYPE" = "local-tracker-committed" ] && [ -n "$TRACKER_BRANCH" ] && [ "$TRACKER_BRANCH" != "—" ]; then
    IS_COMMITTED=true
  fi
}

# ============================================================
# Committed mode worktree wrapper
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

committed_enter() {
  mkdir -p "$ROOT/.worktrees"
  WORKTREE_TMP="$ROOT/.worktrees/tracker-$$"
  "$SCRIPT_DIR/worktree-enter.sh" --fork-from "$TRACKER_BRANCH" --pull-latest "$TRACKER_BRANCH" --path "$WORKTREE_TMP" >/dev/null 2>&1
  # Re-resolve TRACKER_PATH relative to the worktree
  case "$_raw_path" in
    /*) ;; # absolute path, no change
    *)  TRACKER_PATH="$WORKTREE_TMP/$_raw_path" ;;
  esac
  cd "$WORKTREE_TMP"
}

committed_exit() {
  _msg="$1"
  "$SCRIPT_DIR/commit.sh" --branch "$TRACKER_BRANCH" -m "$_msg" >/dev/null 2>&1
  cd "$ROOT"
  "$SCRIPT_DIR/worktree-exit.sh" --path "$WORKTREE_TMP" >/dev/null 2>&1
}

# ============================================================
# Path resolution
# ============================================================

# Determine if an ID is a plan (no hyphen) or slice (has hyphen)
is_slice_id() {
  case "$1" in
    *-*) return 0 ;;
    *)   return 1 ;;
  esac
}

# Find plan folder: $TRACKER_PATH/<id> */
resolve_plan_dir() {
  _id="$1"
  _match=""
  for _d in "$TRACKER_PATH/$_id "*/; do
    if [ -d "$_d" ]; then
      _match="$_d"
      break
    fi
  done
  if [ -z "$_match" ]; then
    # Try exact match (no title suffix)
    if [ -d "$TRACKER_PATH/$_id" ]; then
      _match="$TRACKER_PATH/$_id"
    fi
  fi
  echo "$_match"
}

# Find plan file: $TRACKER_PATH/<id> */[*] plan.md
resolve_plan_file() {
  _dir="$(resolve_plan_dir "$1")"
  if [ -z "$_dir" ]; then
    return 1
  fi
  for _f in "$_dir"/\[*\]\ plan.md; do
    if [ -f "$_f" ]; then
      echo "$_f"
      return 0
    fi
  done
  return 1
}

# Find slice folder: $TRACKER_PATH/*/slices/<id> */
resolve_slice_dir() {
  _id="$1"
  _match=""
  for _d in "$TRACKER_PATH"/*/slices/"$_id "*/; do
    if [ -d "$_d" ]; then
      _match="$_d"
      break
    fi
  done
  echo "$_match"
}

# Find slice file: $TRACKER_PATH/*/slices/<id> */[*] slice.md
resolve_slice_file() {
  _dir="$(resolve_slice_dir "$1")"
  if [ -z "$_dir" ]; then
    return 1
  fi
  for _f in "$_dir"/\[*\]\ slice.md; do
    if [ -f "$_f" ]; then
      echo "$_f"
      return 0
    fi
  done
  return 1
}

# Resolve any ID to its file
resolve_file() {
  if is_slice_id "$1"; then
    resolve_slice_file "$1"
  else
    resolve_plan_file "$1"
  fi
}

# Extract tag from filename like "[to-scope] plan.md" → "to-scope"
extract_tag() {
  _basename="$(basename "$1")"
  echo "$_basename" | sed 's/^\[\([^]]*\)\].*/\1/'
}

# Extract title from dir name like "42 my-feature" → "my-feature" or "1-1 auth" → "auth"
extract_title() {
  _dirname="$(basename "$1")"
  echo "$_dirname" | sed 's/^[0-9]*\(-[0-9]*\)* *//'
}

# ============================================================
# ID generation
# ============================================================

next_plan_id() {
  _max=0
  for _d in "$TRACKER_PATH"/*/; do
    [ -d "$_d" ] || continue
    _name="$(basename "$_d")"
    _num="$(echo "$_name" | sed 's/ .*//')"
    # Skip slice-like IDs (contain hyphens)
    case "$_num" in
      *-*) continue ;;
    esac
    if [ "$_num" -gt "$_max" ] 2>/dev/null; then
      _max="$_num"
    fi
  done
  echo $((_max + 1))
}

next_slice_id() {
  _parent="$1"
  _parent_dir="$(resolve_plan_dir "$_parent")"
  if [ -z "$_parent_dir" ]; then
    echo "Error: parent $_parent not found" >&2
    return 1
  fi
  _max=0
  if [ -d "$_parent_dir/slices" ]; then
    for _d in "$_parent_dir/slices"/*/; do
      [ -d "$_d" ] || continue
      _name="$(basename "$_d")"
      _num="$(echo "$_name" | sed 's/ .*//' | sed "s/^${_parent}-//")"
      if [ "$_num" -gt "$_max" ] 2>/dev/null; then
        _max="$_num"
      fi
    done
  fi
  echo "$_parent-$((_max + 1))"
}

# ============================================================
# JSON output helpers
# ============================================================

# Escape a string for JSON output
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | awk '{
    if (NR > 1) printf "\\n"
    printf "%s", $0
  }'
}

json_object() {
  _number="$1"
  _title="$2"
  _labels="$3"
  _body="$4"
  printf '{"number":"%s","title":"%s","labels":["%s"],"body":"%s"}' \
    "$(json_escape "$_number")" \
    "$(json_escape "$_title")" \
    "$(json_escape "$_labels")" \
    "$(json_escape "$_body")"
}

json_list_item() {
  _number="$1"
  _title="$2"
  printf '{"number":"%s","title":"%s"}' \
    "$(json_escape "$_number")" \
    "$(json_escape "$_title")"
}

# ============================================================
# Commands
# ============================================================

cmd_create() {
  _title=""
  _body=""
  _label=""
  _parent=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --title)  [ $# -lt 2 ] && { echo "Error: --title requires a value" >&2; exit 1; }; _title="$2"; shift 2 ;;
      --body)   [ $# -lt 2 ] && { echo "Error: --body requires a value" >&2; exit 1; }; _body="$2"; shift 2 ;;
      --label)  [ $# -lt 2 ] && { echo "Error: --label requires a value" >&2; exit 1; }; _label="$2"; shift 2 ;;
      --parent) [ $# -lt 2 ] && { echo "Error: --parent requires a value" >&2; exit 1; }; _parent="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [ -z "$_title" ]; then
    echo "Error: --title is required" >&2
    exit 1
  fi

  if [ -z "$_label" ]; then
    echo "Error: --label is required" >&2
    exit 1
  fi

  if [ -n "$_parent" ]; then
    # Create slice
    _id="$(next_slice_id "$_parent")" || exit 1
    _parent_dir="$(resolve_plan_dir "$_parent")"
    _slice_dir="$_parent_dir/slices/$_id $_title"
    mkdir -p "$_slice_dir"
    printf '%s' "$_body" > "$_slice_dir/[$_label] slice.md"
  else
    # Create plan
    _id="$(next_plan_id)"
    _plan_dir="$TRACKER_PATH/$_id $_title"
    mkdir -p "$_plan_dir"
    printf '%s' "$_body" > "$_plan_dir/[$_label] plan.md"
  fi

  echo "$_id"
}

cmd_view() {
  _id="$1"; shift
  _json_flag=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --json) [ $# -lt 2 ] && { echo "Error: --json requires fields" >&2; exit 1; }; _json_flag="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [ -z "$_json_flag" ]; then
    echo "Error: --json flag is required" >&2
    exit 1
  fi

  _file="$(resolve_file "$_id")" || { echo "Error: issue $_id not found" >&2; exit 1; }
  if [ -z "$_file" ]; then
    echo "Error: issue $_id not found" >&2
    exit 1
  fi

  _tag="$(extract_tag "$_file")"
  _dir="$(dirname "$_file")"
  _title="$(extract_title "$_dir")"
  _body="$(cat "$_file")"

  json_object "$_id" "$_title" "$_tag" "$_body"
}

cmd_edit() {
  _id="$1"; shift
  _body=""
  _remove_label=""
  _add_label=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --body)         [ $# -lt 2 ] && { echo "Error: --body requires a value" >&2; exit 1; }; _body="$2"; shift 2 ;;
      --remove-label) [ $# -lt 2 ] && { echo "Error: --remove-label requires a value" >&2; exit 1; }; _remove_label="$2"; shift 2 ;;
      --add-label)    [ $# -lt 2 ] && { echo "Error: --add-label requires a value" >&2; exit 1; }; _add_label="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  _file="$(resolve_file "$_id")" || { echo "Error: issue $_id not found" >&2; exit 1; }
  if [ -z "$_file" ]; then
    echo "Error: issue $_id not found" >&2
    exit 1
  fi

  # Update body if requested
  if [ -n "$_body" ]; then
    printf '%s' "$_body" > "$_file"
  fi

  # Rename label if requested
  if [ -n "$_remove_label" ] && [ -n "$_add_label" ]; then
    _dir="$(dirname "$_file")"
    _basename="$(basename "$_file")"
    _new_basename="$(echo "$_basename" | sed "s/\\[$_remove_label\\]/[$_add_label]/")"
    if [ "$_basename" = "$_new_basename" ]; then
      echo "Error: label [$_remove_label] not found on issue $_id" >&2
      exit 1
    fi
    mv "$_file" "$_dir/$_new_basename"
  fi
}

cmd_close() {
  _id="$1"

  _file="$(resolve_file "$_id")" || { echo "Error: issue $_id not found" >&2; exit 1; }
  if [ -z "$_file" ]; then
    echo "Error: issue $_id not found" >&2
    exit 1
  fi

  _tag="$(extract_tag "$_file")"
  _dir="$(dirname "$_file")"
  _basename="$(basename "$_file")"
  _new_basename="$(echo "$_basename" | sed "s/\\[$_tag\\]/[landed]/")"
  mv "$_file" "$_dir/$_new_basename"
}

cmd_list() {
  _label=""
  _json_flag=""
  _limit=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --label) [ $# -lt 2 ] && { echo "Error: --label requires a value" >&2; exit 1; }; _label="$2"; shift 2 ;;
      --json)  [ $# -lt 2 ] && { echo "Error: --json requires fields" >&2; exit 1; }; _json_flag="$2"; shift 2 ;;
      --limit) [ $# -lt 2 ] && { echo "Error: --limit requires a value" >&2; exit 1; }; _limit="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  _first=1
  _count=0
  printf '['

  # Search plans
  for _f in "$TRACKER_PATH"/*/\["$_label"\]\ plan.md; do
    [ -f "$_f" ] || continue
    if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
    _dir="$(dirname "$_f")"
    _dirname="$(basename "$_dir")"
    _num="$(echo "$_dirname" | sed 's/ .*//')"
    _title="$(extract_title "$_dir")"
    if [ "$_first" -eq 1 ]; then _first=0; else printf ','; fi
    json_list_item "$_num" "$_title"
    _count=$((_count + 1))
  done

  # Search slices
  for _f in "$TRACKER_PATH"/*/slices/*/\["$_label"\]\ slice.md; do
    [ -f "$_f" ] || continue
    if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
    _dir="$(dirname "$_f")"
    _dirname="$(basename "$_dir")"
    _num="$(echo "$_dirname" | sed 's/ .*//')"
    _title="$(extract_title "$_dir")"
    if [ "$_first" -eq 1 ]; then _first=0; else printf ','; fi
    json_list_item "$_num" "$_title"
    _count=$((_count + 1))
  done

  printf ']'
}

# ============================================================
# Main dispatch
# ============================================================

if [ $# -lt 2 ]; then
  echo "Usage: tracker.sh issue <command> [args]" >&2
  exit 1
fi

if [ "$1" != "issue" ]; then
  echo "Error: unknown command group: $1 (only 'issue' is supported)" >&2
  exit 1
fi

SUBCMD="$2"
shift 2

read_config

case "$SUBCMD" in
  create)
    if [ "$IS_COMMITTED" = true ]; then committed_enter; fi
    _output="$(cmd_create "$@")"
    if [ "$IS_COMMITTED" = true ]; then committed_exit "tracker: create $_output"; fi
    echo "$_output"
    ;;
  view)
    if [ $# -lt 1 ]; then echo "Error: issue view requires an ID" >&2; exit 1; fi
    cmd_view "$@" ;;
  edit)
    if [ $# -lt 1 ]; then echo "Error: issue edit requires an ID" >&2; exit 1; fi
    if [ "$IS_COMMITTED" = true ]; then committed_enter; fi
    cmd_edit "$@"
    if [ "$IS_COMMITTED" = true ]; then committed_exit "tracker: edit $1"; fi
    ;;
  close)
    if [ $# -lt 1 ]; then echo "Error: issue close requires an ID" >&2; exit 1; fi
    if [ "$IS_COMMITTED" = true ]; then committed_enter; fi
    cmd_close "$@"
    if [ "$IS_COMMITTED" = true ]; then committed_exit "tracker: close $1"; fi
    ;;
  list) cmd_list "$@" ;;
  *) echo "Error: unknown subcommand: $SUBCMD" >&2; exit 1 ;;
esac
