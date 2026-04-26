#!/bin/sh
# tracker.sh — local issue tracker CLI for Moonjelly Reef
#
# Mirrors the `gh issue` and `gh pr` interfaces for local file-based tracking.
# Reads config from .agents/moonjelly-reef/config.md (found via git repo root).
#
# Usage:
#   tracker.sh issue view   <id> --json body,title,labels
#   tracker.sh issue edit   <id> [--title "..."] [--body "..."] [--remove-label X] [--add-label Y]
#   tracker.sh issue create [--title "..."] [--body "..."] [--label X] [--parent <id>]
#   tracker.sh issue close  <id>
#   tracker.sh issue list   [--label X] [--json number,title] [--limit N]
#   tracker.sh pr create    [<id>] --base X [--head Y] --body B [--title T] [--label L]
#   tracker.sh pr view      <id> --json body,headRefName,baseRefName [--web] [-q .field]
#   tracker.sh pr edit      <id> [--body "..."] [--add-label X] [--remove-label X]
#   tracker.sh pr list      [--search Q] [--json fields] [--limit N]
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

# Resolve any ID to its directory (for progress.md)
resolve_dir() {
  if is_slice_id "$1"; then
    resolve_slice_dir "$1"
  else
    resolve_plan_dir "$1"
  fi
}

# Resolve progress.md path for a given ID
resolve_progress_file() {
  _dir="$(resolve_dir "$1")"
  if [ -z "$_dir" ]; then
    return 1
  fi
  for _pf in "$_dir"/\[*\]\ progress.md; do
    if [ -f "$_pf" ]; then
      echo "$_pf"
      return 0
    fi
  done
  _pf="$_dir/progress.md"
  if [ -f "$_pf" ]; then
    echo "$_pf"
    return 0
  fi
  return 1
}

# Extract label from filename like "[to-scope] plan.md" → "to-scope"
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
  _title=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --body)         [ $# -lt 2 ] && { echo "Error: --body requires a value" >&2; exit 1; }; _body="$2"; shift 2 ;;
      --remove-label) [ $# -lt 2 ] && { echo "Error: --remove-label requires a value" >&2; exit 1; }; _remove_label="$2"; shift 2 ;;
      --add-label)    [ $# -lt 2 ] && { echo "Error: --add-label requires a value" >&2; exit 1; }; _add_label="$2"; shift 2 ;;
      --title)        [ $# -lt 2 ] && { echo "Error: --title requires a value" >&2; exit 1; }; _title="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  _file="$(resolve_file "$_id")" || { echo "Error: issue $_id not found" >&2; exit 1; }
  if [ -z "$_file" ]; then
    echo "Error: issue $_id not found" >&2
    exit 1
  fi

  _dir="$(dirname "$_file")"

  # Update body if requested
  if [ -n "$_body" ]; then
    printf '%s' "$_body" > "$_file"
  fi

  # Rename label if requested
  if [ -n "$_remove_label" ] && [ -n "$_add_label" ]; then
    _basename="$(basename "$_file")"
    _new_basename="$(echo "$_basename" | sed "s/\\[$_remove_label\\]/[$_add_label]/")"
    if [ "$_basename" = "$_new_basename" ]; then
      echo "Error: label [$_remove_label] not found on issue $_id" >&2
      exit 1
    fi
    mv "$_file" "$_dir/$_new_basename"
  fi

  # Rename directory (title) if requested
  if [ -n "$_title" ]; then
    _parent_dir="$(dirname "$_dir")"
    _id_part="$(basename "$_dir" | sed 's/ .*//')"
    _new_dir="$_parent_dir/$_id_part $_title"
    mv "$_dir" "$_new_dir"
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

json_list_item_labeled() {
  _number="$1"
  _title="$2"
  _lbl="$3"
  printf '{"number":"%s","title":"%s","labels":[{"name":"%s"}]}' \
    "$(json_escape "$_number")" \
    "$(json_escape "$_title")" \
    "$(json_escape "$_lbl")"
}

cmd_list() {
  _label=""
  _search=""
  _json_flag=""
  _limit=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --label)  [ $# -lt 2 ] && { echo "Error: --label requires a value" >&2; exit 1; }; _label="$2"; shift 2 ;;
      --search) [ $# -lt 2 ] && { echo "Error: --search requires a value" >&2; exit 1; }; _search="$2"; shift 2 ;;
      --json)   [ $# -lt 2 ] && { echo "Error: --json requires fields" >&2; exit 1; }; _json_flag="$2"; shift 2 ;;
      --limit)  [ $# -lt 2 ] && { echo "Error: --limit requires a value" >&2; exit 1; }; _limit="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  # Extract label:X qualifiers from --search string (OR semantics)
  if [ -n "$_search" ]; then
    _labels=""
    _tmp="$_search"
    while [ -n "$_tmp" ]; do
      case "$_tmp" in
        *label:*)
          _tmp="${_tmp#*label:}"
          _lname="${_tmp%% *}"
          _labels="$_labels $_lname"
          ;;
        *)
          _tmp=""
          ;;
      esac
    done
  else
    _labels="$_label"
  fi

  _first=1
  _count=0
  printf '['

  for _lbl in $_labels; do
    # Search plans
    for _f in "$TRACKER_PATH"/*/\["$_lbl"\]\ plan.md; do
      [ -f "$_f" ] || continue
      if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
      _dir="$(dirname "$_f")"
      _dirname="$(basename "$_dir")"
      _num="$(echo "$_dirname" | sed 's/ .*//')"
      _title="$(extract_title "$_dir")"
      if [ "$_first" -eq 1 ]; then _first=0; else printf ','; fi
      case "$_json_flag" in
        *labels*) json_list_item_labeled "$_num" "$_title" "$_lbl" ;;
        *)        json_list_item "$_num" "$_title" ;;
      esac
      _count=$((_count + 1))
    done

    # Search slices
    for _f in "$TRACKER_PATH"/*/slices/*/\["$_lbl"\]\ slice.md; do
      [ -f "$_f" ] || continue
      if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
      _dir="$(dirname "$_f")"
      _dirname="$(basename "$_dir")"
      _num="$(echo "$_dirname" | sed 's/ .*//')"
      _title="$(extract_title "$_dir")"
      if [ "$_first" -eq 1 ]; then _first=0; else printf ','; fi
      case "$_json_flag" in
        *labels*) json_list_item_labeled "$_num" "$_title" "$_lbl" ;;
        *)        json_list_item "$_num" "$_title" ;;
      esac
      _count=$((_count + 1))
    done
  done

  printf ']'
}

# ============================================================
# PR commands
# ============================================================

pr_create() {
  _id=""
  _base=""
  _head=""
  _body=""
  _title=""  # accepted for gh compatibility, used for ID resolution only
  _label=""

  # First positional arg (if not a flag) is the ID
  if [ $# -gt 0 ]; then
    case "$1" in
      --*) ;;  # not a positional arg
      *)  _id="$1"; shift ;;
    esac
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --base)  [ $# -lt 2 ] && { echo "Error: --base requires a value" >&2; exit 1; }; _base="$2"; shift 2 ;;
      --head)  [ $# -lt 2 ] && { echo "Error: --head requires a value" >&2; exit 1; }; _head="$2"; shift 2 ;;
      --body)  [ $# -lt 2 ] && { echo "Error: --body requires a value" >&2; exit 1; }; _body="$2"; shift 2 ;;
      --title) [ $# -lt 2 ] && { echo "Error: --title requires a value" >&2; exit 1; }; _title="$2"; shift 2 ;;
      --label) [ $# -lt 2 ] && { echo "Error: --label requires a value" >&2; exit 1; }; _label="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [ -z "$_base" ]; then
    echo "Error: --base is required" >&2
    exit 1
  fi

  # --head defaults to current branch if omitted
  if [ -z "$_head" ]; then
    _head="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
      echo "Error: --head is required (could not detect current branch)" >&2
      exit 1
    }
  fi

  # If no positional ID, resolve from --title by finding a matching issue folder
  if [ -z "$_id" ] && [ -n "$_title" ]; then
    # Search plans
    for _d in "$TRACKER_PATH"/*/; do
      [ -d "$_d" ] || continue
      _dname="$(basename "$_d")"
      _dtitle="$(echo "$_dname" | sed 's/^[0-9]* *//')"
      if [ "$_dtitle" = "$_title" ]; then
        _id="$(echo "$_dname" | sed 's/ .*//')"
        break
      fi
    done
    # Search slices
    if [ -z "$_id" ]; then
      for _d in "$TRACKER_PATH"/*/slices/*/; do
        [ -d "$_d" ] || continue
        _dname="$(basename "$_d")"
        _dtitle="$(echo "$_dname" | sed 's/^[0-9]*\(-[0-9]*\)* *//')"
        if [ "$_dtitle" = "$_title" ]; then
          _id="$(echo "$_dname" | sed 's/ .*//')"
          break
        fi
      done
    fi
  fi

  if [ -z "$_id" ]; then
    echo "Error: could not determine issue ID (provide positional ID or --title)" >&2
    exit 1
  fi

  _dir="$(resolve_dir "$_id")"
  if [ -z "$_dir" ]; then
    echo "Error: issue $_id not found" >&2
    exit 1
  fi

  if [ -n "$_label" ]; then
    _progress="$_dir/[$_label] progress.md"
  else
    _progress="$_dir/progress.md"
  fi
  {
    printf '%s\n' "---"
    printf '%s\n' "head: $_head"
    printf '%s\n' "base: $_base"
    printf '%s\n' "---"
    printf '\n'
  } > "$_progress"
  if [ -n "$_body" ]; then
    printf '%s' "$_body" >> "$_progress"
  fi

  # Output the issue ID (analogous to gh pr create returning the PR number)
  echo "$_id"
}

pr_view() {
  _id="$1"; shift
  _json_flag=""
  _query=""  # -q flag: accepted for gh compatibility, used to extract a single field
  _web=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --json) [ $# -lt 2 ] && { echo "Error: --json requires fields" >&2; exit 1; }; _json_flag="$2"; shift 2 ;;
      -q)     [ $# -lt 2 ] && { echo "Error: -q requires a value" >&2; exit 1; }; _query="$2"; shift 2 ;;
      --web)  _web=true; shift ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [ "$_web" = true ]; then
    _progress=$(resolve_progress_file "$_id")
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$_progress"
    else
      open "$_progress"
    fi
    return 0
  fi

  if [ -z "$_json_flag" ]; then
    echo "Error: --json flag is required" >&2
    exit 1
  fi

  _progress="$(resolve_progress_file "$_id")" || { echo "Error: progress.md not found for $_id" >&2; exit 1; }
  if [ -z "$_progress" ]; then
    echo "Error: progress.md not found for $_id" >&2
    exit 1
  fi

  # Check if requesting comments/reviews (return empty arrays)
  case "$_json_flag" in
    *comments*|*reviews*)
      printf '{"comments":[],"reviews":[]}'
      return 0
      ;;
  esac

  # Parse frontmatter
  _head="$(sed -n 's/^head: *//p' "$_progress" | head -1)"
  _base="$(sed -n 's/^base: *//p' "$_progress" | head -1)"
  _labels="$(basename "$_progress" | sed -n 's/^\[\([^]]*\)\] progress\.md$/\1/p')"

  # Parse body (everything after the closing ---)
  _body="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$_progress")"
  # Trim leading blank line
  _body="$(echo "$_body" | sed '/./,$!d')"

  # Build JSON output with all requested fields
  _json="{"
  _first_field=1
  # Split comma-separated field list and output each requested field
  _remaining="$_json_flag"
  while [ -n "$_remaining" ]; do
    _field="${_remaining%%,*}"
    if [ "$_field" = "$_remaining" ]; then
      _remaining=""
    else
      _remaining="${_remaining#*,}"
    fi
    if [ "$_first_field" -eq 1 ]; then _first_field=0; else _json="$_json,"; fi
    case "$_field" in
      body)             _json="$_json\"body\":\"$(json_escape "$_body")\"" ;;
      headRefName)      _json="$_json\"headRefName\":\"$(json_escape "$_head")\"" ;;
      baseRefName)      _json="$_json\"baseRefName\":\"$(json_escape "$_base")\"" ;;
      number)           _json="$_json\"number\":\"$(json_escape "$_id")\"" ;;
      mergeStateStatus) _json="$_json\"mergeStateStatus\":\"CLEAN\"" ;;
      labels)           _json="$_json\"labels\":[\"$(json_escape "$_labels")\"]" ;;
      *)                _json="$_json\"$_field\":null" ;;
    esac
  done
  _json="$_json}"

  # If -q flag was given, extract the requested field value
  if [ -n "$_query" ]; then
    # Simple jq-style .field extraction (e.g. ".body", ".mergeStateStatus")
    _qfield="$(echo "$_query" | sed 's/^\.//')"
    case "$_qfield" in
      body)             printf '%s' "$_body" ;;
      headRefName)      printf '%s' "$_head" ;;
      baseRefName)      printf '%s' "$_base" ;;
      number)           printf '%s' "$_id" ;;
      mergeStateStatus) printf '%s' "CLEAN" ;;
      labels)           printf '%s' "$_labels" ;;
      *)                printf 'null' ;;
    esac
  else
    printf '%s' "$_json"
  fi
}

pr_edit() {
  _id="$1"; shift
  _body=""
  _add_label=""
  _remove_label=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --body)         [ $# -lt 2 ] && { echo "Error: --body requires a value" >&2; exit 1; }; _body="$2"; shift 2 ;;
      --add-label)    [ $# -lt 2 ] && { echo "Error: --add-label requires a value" >&2; exit 1; }; _add_label="$2"; shift 2 ;;
      --remove-label) [ $# -lt 2 ] && { echo "Error: --remove-label requires a value" >&2; exit 1; }; _remove_label="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  if [ -z "$_body" ] && [ -z "$_add_label" ] && [ -z "$_remove_label" ]; then
    return 0
  fi

  _progress="$(resolve_progress_file "$_id")" || { echo "Error: progress.md not found for $_id" >&2; exit 1; }
  if [ -z "$_progress" ]; then
    echo "Error: progress.md not found for $_id" >&2
    exit 1
  fi

  # Rename file for label changes (mirrors how issue edit renames plan.md)
  if [ -n "$_add_label" ] || [ -n "$_remove_label" ]; then
    _dir="$(dirname "$_progress")"
    if [ -n "$_add_label" ]; then
      _new_progress="$_dir/[$_add_label] progress.md"
    else
      _new_progress="$_dir/progress.md"
    fi
    if [ "$_progress" != "$_new_progress" ]; then
      mv "$_progress" "$_new_progress"
      _progress="$_new_progress"
    fi
  fi

  # Update body if requested
  if [ -n "$_body" ]; then
    _head="$(sed -n 's/^head: *//p' "$_progress" | head -1)"
    _base="$(sed -n 's/^base: *//p' "$_progress" | head -1)"
    {
      printf '%s\n' "---"
      printf '%s\n' "head: $_head"
      printf '%s\n' "base: $_base"
      printf '%s\n' "---"
      printf '\n'
    } > "$_progress"
    printf '%s' "$_body" >> "$_progress"
  fi
}

# Returns 0 if a PR matches the --search query, 1 if not.
# Supports GitHub-compatible "head:branch-name" syntax for exact branch matching,
# or falls back to substring match against "$head $title" for plain strings.
pr_matches_search() {
  _ms_head="$1"
  _ms_title="$2"
  _ms_query="$3"
  case "$_ms_query" in
    *head:*)
      _ms_branch="${_ms_query#*head:}"
      _ms_branch="${_ms_branch%% *}"
      [ "$_ms_head" = "$_ms_branch" ]
      ;;
    *)
      case "$_ms_head $_ms_title" in
        *${_ms_query}*) return 0 ;;
        *) return 1 ;;
      esac
      ;;
  esac
}

pr_list() {
  _search=""
  _json_flag=""
  _limit=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --search) [ $# -lt 2 ] && { echo "Error: --search requires a value" >&2; exit 1; }; _search="$2"; shift 2 ;;
      --json)   [ $# -lt 2 ] && { echo "Error: --json requires fields" >&2; exit 1; }; _json_flag="$2"; shift 2 ;;
      --limit)  [ $# -lt 2 ] && { echo "Error: --limit requires a value" >&2; exit 1; }; _limit="$2"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  # List all issues that have a progress.md file
  _first=1
  _count=0
  printf '['

  # Search plans
  for _pf in "$TRACKER_PATH"/*/\[*\]\ progress.md "$TRACKER_PATH"/*/progress.md; do
    [ -f "$_pf" ] || continue
    if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
    _dir="$(dirname "$_pf")"
    _dirname="$(basename "$_dir")"
    _num="$(echo "$_dirname" | sed 's/ .*//')"
    _title="$(extract_title "$_dir")"
    _head="$(sed -n 's/^head: *//p' "$_pf" | head -1)"
    if [ -n "$_search" ]; then
      pr_matches_search "$_head" "$_title" "$_search" || continue
    fi
    if [ "$_first" -eq 1 ]; then _first=0; else printf ','; fi
    json_list_item "$_num" "$_title"
    _count=$((_count + 1))
  done

  # Search slices
  for _pf in "$TRACKER_PATH"/*/slices/*/\[*\]\ progress.md "$TRACKER_PATH"/*/slices/*/progress.md; do
    [ -f "$_pf" ] || continue
    if [ -n "$_limit" ] && [ "$_count" -ge "$_limit" ]; then break; fi
    _dir="$(dirname "$_pf")"
    _dirname="$(basename "$_dir")"
    _num="$(echo "$_dirname" | sed 's/ .*//')"
    _title="$(extract_title "$_dir")"
    _head="$(sed -n 's/^head: *//p' "$_pf" | head -1)"
    if [ -n "$_search" ]; then
      pr_matches_search "$_head" "$_title" "$_search" || continue
    fi
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
  echo "Usage: tracker.sh <issue|pr> <command> [args]" >&2
  exit 1
fi

CMD_GROUP="$1"
SUBCMD="$2"
shift 2

read_config

case "$CMD_GROUP" in
  issue)
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
      *) echo "Error: unknown issue subcommand: $SUBCMD" >&2; exit 1 ;;
    esac
    ;;
  pr)
    case "$SUBCMD" in
      create)
        if [ "$IS_COMMITTED" = true ]; then committed_enter; fi
        pr_create "$@"
        if [ "$IS_COMMITTED" = true ]; then committed_exit "tracker: pr create"; fi
        ;;
      view)
        if [ $# -lt 1 ]; then echo "Error: pr view requires an ID" >&2; exit 1; fi
        pr_view "$@" ;;
      edit)
        if [ $# -lt 1 ]; then echo "Error: pr edit requires an ID" >&2; exit 1; fi
        if [ "$IS_COMMITTED" = true ]; then committed_enter; fi
        pr_edit "$@"
        if [ "$IS_COMMITTED" = true ]; then committed_exit "tracker: pr edit $1"; fi
        ;;
      list) pr_list "$@" ;;
      *) echo "Error: unknown pr subcommand: $SUBCMD" >&2; exit 1 ;;
    esac
    ;;
  *) echo "Error: unknown command group: $CMD_GROUP (expected 'issue' or 'pr')" >&2; exit 1 ;;
esac
