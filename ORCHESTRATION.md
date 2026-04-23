# Phase instructions

This file captures the orchestration contract for each skill/phase.
It is intentionally narrow: only record the external I/O and durable side effects that must stay stable across implementations.

That means things like:
- tracker reads and writes via `./tracker.sh`
- worktree entry/exit calls
- commit calls
- handoff variables and other persisted state

Do not use this file to document general prompting, prose instructions, or other internal execution detail that can live in the phase `.md` files.

## Branch contract

Every issue in the slice lifecycle carries both:

- `$PR_BRANCH` — the branch the PR lives on; phases fork from it, commit to it, and review it
- `$BASE_BRANCH` — the branch the PR merges into

General rules:

- If an issue has no `parent-issue`, `$BASE_BRANCH` is usually `main`
- If an issue has `parent-issue`, `$BASE_BRANCH` is the parent issue's `$PR_BRANCH`
- If the current issue creates sub-issues, each sub-issue gets its own `$PR_BRANCH`, while the current issue keeps its own `$PR_BRANCH` as the integration branch

## Skills

### [/reef-pulse](./reef-pulse/SKILL.md)

- set-variables
  ```sh
  SKILL_DIR="{base directory for this skill}"
  TRACKER_BRANCH="{from config.md}" # e.g. main
  LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
  ```
- checkout-tracker-branch — if local-tracker-committed
  ```sh
  git fetch origin "$TRACKER_BRANCH" && git checkout "$TRACKER_BRANCH" && git pull
  ```
- set-variables
  ```sh
  PULSE_NR=1
  AGENT_COUNT_SESSION=0
  SESSION_START_TS="$(date +%s)"
  ```
- pulse-loop
  - contains: `read and follow [`pulse-loop.md`](pulse-loop.md) from top to bottom for the first pulse-loop iteration`
- release-lock — if `"$IS_SESSION_COMPLETE" = "true"`
  - contains: `delete the `pulse.lock` file`

### [/reef-scope](./reef-scope/SKILL.md)

- set-variables
  ```sh
  START_TIME="{current UTC timestamp}"
  ```
- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate, eg.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- phase-specific
- set-variables
  ```sh
  BASE_BRANCH="{from branch discussion}"
  ```
- conflict-anticipation — scan in-flight issues on same base-branch and surface overlaps
  ```sh
  for LABEL in to-slice in-progress to-implement to-inspect to-rework to-merge to-seal to-land to-await-waves; do
    ./tracker.sh issue list --label "$LABEL" --json number,title,body,labels
  done
  ```
- set-variables
  ```sh
  BASE_BRANCH="{from branch discussion}"
  PR_BRANCH="{from branch discussion}"
  ```
- update-tracker
  ```sh
  ISSUE_BODY="{plan-content}" # frontmatter + plan issue body from context
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-scope --add-label to-slice
  ```
- set-variables — if overlap should block the scoped issue
  ```sh
  ISSUE_TITLE="{current issue title} [await: #77, #83]"
  ```
- update-tracker — if overlap should block the scoped issue
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --title "$ISSUE_TITLE" --remove-label to-slice --add-label to-await-waves
  ```
- set-variables
  ```sh
  DURATION="{human-readable duration since START_TIME}" # e.g. "42s", "1m 12s"
  ISSUE_BODY="{current plan issue body with metrics section appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
  ```

### [/reef-land](./reef-land/SKILL.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # if passed directly or extracted from passed URL
  PR_ID="{pr-id}" # if passed directly or extracted from passed URL
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels # if ISSUE_ID known
  ./tracker.sh pr view "$PR_ID" --json number,body,headRefName,baseRefName,comments,reviews # if PR_ID known
  ```
- set-variables
  ```sh
  ISSUE_ID="{from PR body or already known}"
  PR_ID="{from plan issue body or already known}"
  BASE_BRANCH="{from plan issue body}"
  PR_BODY="{the PR body content — this contains the seal report}"
  ```
- phase-specific
- set-variables — if change-requests
  ```sh
  PR_BODY="{current PR body with gap report appended in <details><summary> block}"
  ```
- update-pr-body — if change-requests
  ```sh
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY"
  ```
- update-tracker — if change-requests
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-land --add-label to-rework
  ```
- update-plan-body — if change-requests and plan decisions changed
  ```sh
  PLAN_BODY=$(./tracker.sh issue view "$ISSUE_ID" --json body)
  ./tracker.sh issue edit "$ISSUE_ID" --body "$PLAN_BODY"
  ```
- sync-pr-label — if change-requests
  ```sh
  ./tracker.sh pr edit "$PR_ID" --remove-label to-land --add-label to-rework
  ```
- set-variables — if follow-up
  ```sh
  FOLLOW_UP_CONTEXT="{summary of PR comments and concerns from step 2}"
  ```
- create-tracker — if follow-up
  ```sh
  ./tracker.sh issue create --title "Follow-up: {summary of concerns}" --body "$FOLLOW_UP_CONTEXT" --label to-scope
  ```
- pre-merge-check — if approved
  ```sh
  ./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
  ```
- set-variables — if approved
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge — if approved
  ```sh
  ./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
  ./tracker.sh pr edit "$PR_ID" --remove-label to-land --add-label landed
  ```
- pull
  - contains: `Pull the merged changes into the current branch if it matches the base branch:`
  ```sh
  git fetch origin --prune
  CURRENT=$(git branch --show-current)
  if [ "$CURRENT" = "$BASE_BRANCH" ]; then
    git pull --ff-only origin "$BASE_BRANCH"
  fi
  ```
- update-tracker — if approved
  ```sh
  ./tracker.sh issue close "$ISSUE_ID"
  ```

## Phases

### [pulse-loop.md](./reef-pulse/pulse-loop.md)

- set-variables
  ```sh
  AGENT_COUNT_PULSE=0
  ```
- flow-wave-scan
  ```sh
  ./tracker.sh issue list --json number,title,labels --limit 100 \
    --search 'label:to-slice OR label:to-implement OR label:to-inspect OR label:to-rework OR label:to-seal'
  ```
- ebb-wave-scan
  ```sh
  ./tracker.sh issue list --json number,title,labels --limit 100 \
    --search 'label:to-await-waves OR label:to-merge'
  ```
- dependency-gate — if `to-await-waves`
  ```sh
  DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. #42
  ./tracker.sh issue view "$DEPENDENCY_ID" --json labels
  ```
- set-variables
  ```sh
  AGENT_COUNT_SESSION=$((AGENT_COUNT_SESSION + AGENT_COUNT_PULSE))
  if [ "$AGENT_COUNT_PULSE" -eq 0 ]; then
    IS_SESSION_COMPLETE=true
  else
    IS_SESSION_COMPLETE=false
    PULSE_NR=$((PULSE_NR + 1))
  fi
  ```
- set-variables — if `"$AGENT_COUNT_PULSE" -gt 0`
  ```sh
  ISSUE_ID="{from handoff ISSUE_ID}"
  NEXT_PHASE="{from handoff NEXT_PHASE}"
  PR_ID="{from handoff PR_ID}" # if returned; otherwise "—"
  SUMMARY="{from handoff SUMMARY}" # if returned
  SUBAGENT_DURATION="{duration of sub-agent total execution}" # if known; otherwise "—"
  SUBAGENT_TOKENS="{total token count used by the sub-agent}" # if known; otherwise "—"
  SUBAGENT_TOOL_USES="{tool use count for the sub-agent}" # if known; otherwise "—"
  ```
- set-variables — if `"$AGENT_COUNT_PULSE" -gt 0`
  ```sh
  PHASE_METRIC_RECORDS='[
    # {
    #   "ISSUE_ID": "#55",
    #   "ISSUE_PHASE": "to-implement",
    #   "NEXT_PHASE": "to-inspect",
    #   "PR_ID": "#72",
    #   "SUMMARY": "PR created",
    #   "SUBAGENT_DURATION": "42s",
    #   "SUBAGENT_TOKENS": 12340,
    #   "SUBAGENT_TOOL_USES": 18
    # }
  ]'
  ```
- metrics-subagent — if `"$AGENT_COUNT_PULSE" -gt 0`
  ```sh
  Read and follow $SKILL_DIR/metric-logger.md.

  PHASE_METRIC_RECORDS="$PHASE_METRIC_RECORDS"
  ```
- set-variables — if `"$AGENT_COUNT_PULSE" -gt 0`
  ```sh
  SUCCESS_COUNT="{from metrics logger handoff}" # e.g.: 2
  FAIL_COUNT="{from metrics logger handoff}" # e.g.: 0
  FAIL_IDS="{from metrics logger handoff}" # e.g.: #25, #89
  ```

### [slice.md](./reef-pulse/slice.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- update-tracker — if base-branch or pr-branch is missing
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-slice --add-label blocked-missing-scope --add-label to-scope
  ```
- handoff — if base-branch or pr-branch is missing
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-missing-scope"
  PR_ID="—"
  ```
- phase-specific
  - contains: `deep-research` + `feeling-lucky` + `feature (feeling-lucky)`
  - contains: `Compact research plans can stay as a single research issue`
  - contains: `angle-based or dependency-based research slices`
  - contains: `without asking the user follow-up questions`

### [slice-one-issue.md](./reef-pulse/slice-one-issue.md)

- phase-specific
  - contains: `inferred combined value before saving the issue body`
  - contains: `If the slice bearing is deep-research, the acceptance criteria must stay research-focused`
  - contains: `For deep-research, label the issue to-research instead of to-implement.`
- set-variables

  ```sh
  ISSUE_BODY="{plan issue body with scoped pr-branch and rewritten bearing preserved, plus acceptance criteria appended}"
  ```

- update-tracker
  ```sh
  NEXT_PHASE="{to-research for deep-research, otherwise to-implement}"
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label "$NEXT_PHASE"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-research"
  PR_ID="—"
  ```

### [slice-subissues.md](./reef-pulse/slice-subissues.md)

- set-variables
  ```sh
  PR_BRANCH="{from plan issue body pr-branch field}"
  BASE_BRANCH="{from plan issue body}"
  PLAN_BEARING="{from plan issue body bearing field}"
  EFFECTIVE_BEARING="{deep-research or inferred lane such as feature (feeling-lucky)}"
  WORKTREE_PATH=".worktrees/$ISSUE_ID-slice"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- create-remote-branch
  ```sh
  git push -u origin "$PR_BRANCH"
  ```
- set-variables
  ```sh
  SLICE_TITLE="{slice-title} [await: #{blocker-id}]"  # omit [await: ...] if unblocked
  SLICE_PR_BRANCH="{derived from plan issue pr-branch + slice title slug}"
  SLICE_BEARING="{per-slice bearing, usually $EFFECTIVE_BEARING unless a slice needs a narrower inferred lane}"
  SLICE_BODY="{slice-body}" # as per the template below, with pr-branch: $SLICE_PR_BRANCH and bearing: $SLICE_BEARING
  SLICE_LABEL="{to-research for unblocked deep-research slices, otherwise to-implement; or to-await-waves if blocked}"
  ```
- phase-specific
  - contains: `For deep-research, make the slices research-native`
  - contains: `bearing: $SLICE_BEARING`
- create-slices
  ```sh
  ./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
  ```
- set-variables
  ```sh
  ISSUE_BODY="{plan issue body with pr-branch in frontmatter and coverage matrix appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label in-progress
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="in-progress"
  PR_ID="—"
  ```

### [implement.md](./reef-pulse/implement.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-implement"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- handoff — if baseline-broken
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-rework"
  PR_ID="—"
  ```
- phase-specific
- commit-code
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: implementation"
  ```
- set-variables
  ```sh
  CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g.: #42
  REPORT="{implementation report}"
  PR_BODY_NEW="$CLOSES\n\n$REPORT"
  ./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
  ```
- set-variables
  ```sh
  PR_ID="{from pr create output}" # e.g.: #43
  ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}"
  # add to frontmatter (if not already): pr-branch: $PR_BRANCH
  # add to frontmatter:  pr-id: $PR_ID
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-implement --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-inspect"
  PR_ID="$PR_ID"
  ```

### [research.md](./reef-pulse/research.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-research"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- phase-specific
  - contains: `produce a durable research artifact instead of code`
  - contains: `lightweight source links near externally sourced findings`
- commit-code
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: research"
  ```
- set-variables
  ```sh
  CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g.: #42
  REPORT="{research report}"
  PR_BODY_NEW="$CLOSES\n\n$REPORT"
  ./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
  ```
- set-variables
  ```sh
  PR_ID="{from pr create output}" # e.g.: #43
  ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}"
  # add to frontmatter (if not already): pr-branch: $PR_BRANCH
  # add to frontmatter:  pr-id: $PR_ID
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-research --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-inspect"
  PR_ID="$PR_ID"
  ```


### [metric-logger.md](./reef-pulse/metric-logger.md)

- set-variables
  ```sh
  PHASE_METRIC_RECORDS='[
    # {
    #   "ISSUE_ID": "#55",
    #   "ISSUE_PHASE": "to-implement",
    #   "NEXT_PHASE": "to-inspect",
    #   "PR_ID": "#72",
    #   "SUMMARY": "PR created",
    #   "SUBAGENT_DURATION": "42s",
    #   "SUBAGENT_TOKENS": 12340,
    #   "SUBAGENT_TOOL_USES": 18
    # }
  ]'
  SUCCESS_COUNT="0" # mutate on every full record success
  FAIL_COUNT="0" # mutate on every failed record
  FAIL_IDS="" # append ISSUE_ID values for failed records
  ```
- phase-specific
- if any record
  ```sh
  ISSUE_BODY="$(./tracker.sh issue view "$ISSUE_ID" --json body -q .body)"
  ```
- if to-land record
  ```sh
  PR_BODY="$(./tracker.sh pr view "$PR_ID" --json body -q .body)"
  ```
- set-variables
  ```sh
  METRICS_TABLE="{md table found in ISSUE_BODY}"
  ```
- set-variables if metrics table missing

  ```sh
  METRICS_TABLE="### 🪼 Pulse metrics

  | Phase | Target | Duration | Tokens | Tool uses | Outcome | Date |
  | ----- | ------ | -------- | ------ | --------- | ------- | ---- |
  <!-- end metrics table -->"
  ```

- set-variables
  ```sh
  PHASE="${ISSUE_PHASE#to-}"
  TARGET="$ISSUE_ID"
  DURATION="${SUBAGENT_DURATION:-—}"
  TOKENS="${SUBAGENT_TOKENS:-—}"
  TOOL_USES="${SUBAGENT_TOOL_USES:-—}"
  OUTCOME="${SUMMARY:-${NEXT_PHASE#to-}}"
  METRICS_DATE="$(date '+%Y-%m-%d %H:%M')"
  METRIC_ROW="| $PHASE | $TARGET | $DURATION | $TOKENS | $TOOL_USES | $OUTCOME | $METRICS_DATE |"
  ```
- set-variables
  ```sh
  METRICS_TABLE_UPDATED="{current METRICS_TABLE with $METRIC_ROW inserted immediately above <!-- end metrics table -->}"
  ```
- if normal record
  ```sh
  ISSUE_BODY_UPDATED="{current issue body with METRICS_TABLE_UPDATED written back in place}"
  ```
- if normal record
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
  ```
- if normal record write failed
  ```sh
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
  ```
- if normal record write succeeded
  ```sh
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  ```
- if to-land record
  ```sh
  FINAL_METRICS_TABLE="{issue metrics table with $METRIC_ROW appended and a bold Total row added last}"
  ```
- if to-land record
  ```sh
  PR_BODY_UPDATED="{current PR body with FINAL_METRICS_TABLE appended at the end}"
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
  ```
- if to-land record
  ```sh
  ISSUE_BODY_CLEANED="{current issue body with the full metrics section removed}"
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_CLEANED"
  ```
- if to-land PR write failed
  ```sh
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
  ```
- if to-land cleanup write failed
  ```sh
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
  ```
- if to-land record fully succeeded
  ```sh
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  ```
- handoff
  ```sh
  SUCCESS_COUNT="$SUCCESS_COUNT"
  FAIL_COUNT="$FAIL_COUNT"
  FAIL_IDS="$FAIL_IDS"
  ```

### [inspect.md](./reef-pulse/inspect.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-inspect"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- handoff — if pr-missing
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="pr-missing"
  PR_ID="—"
  ```
- phase-specific
  - contains: `For deep-research, inspect the committed research artifact mechanically rather than treating it like code.`
  - contains: `If acceptance criteria are fuzzy because the issue was intentionally feeling-lucky, do not get fussy about their absence.`
- commit-code — if cleanup-needed
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "inspect: cleanup"
  ```
- update-pr-body
  ```sh
  PR_ID="{from issue frontmatter pr-id field}" # if not found, try ./tracker.sh pr list --search
  PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
  REPORT="{inspect-report}" # <details><summary><h3>🧿 Inspect review — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
  ```
- update-tracker pass case
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-inspect --add-label to-merge
  ./tracker.sh pr edit "$PR_ID" --remove-label to-inspect --add-label to-merge
  ```
- update-tracker fail case
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-inspect --add-label to-rework
  ./tracker.sh pr edit "$PR_ID" --remove-label to-inspect --add-label to-rework
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-merge" # or "to-rework" if gaps found
  PR_ID="$PR_ID"
  ```

### [rework.md](./reef-pulse/rework.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  PR_ID="{from issue frontmatter pr-id field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-rework"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="$PR_ID"
  ```
- phase-specific
  - contains: `For deep-research, rework means revising the committed research docs to close the flagged gaps.`
  - contains: `For feeling-lucky, rework may refine the inferred lane or bearing if QA surfaced a better interpretation.`
- commit-code
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "rework: address review feedback"
  ```
- update-pr-body
  ```sh
  PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
  REPORT="{rework-report}" # <details><summary><h3>🦀 Rework — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-rework --add-label to-inspect
  ./tracker.sh pr edit "$PR_ID" --remove-label to-rework --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-inspect"
  PR_ID="$PR_ID"
  ```

### [await-waves.md](./reef-pulse/await-waves.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title, stripping [await: ...] suffix}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  BEARING="{from issue frontmatter bearing field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-await-waves"
  ```
- set-variables
  ```sh
  DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. "#55"
  ```
- dep-check — checks each dependency for the `landed` label; if all carry `landed`, slice is promoted
  ```sh
  ./tracker.sh issue view "$DEPENDENCY_ID" --json labels
  ```
- handoff — if still-blocked
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-await-waves"
  PR_ID="—"
  ```
- update-tracker
  ```sh
  NEXT_LABEL="{to-research for deep-research, otherwise to-implement}"
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-await-waves --add-label "$NEXT_LABEL" --title "$ISSUE_TITLE"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- phase-specific
- set-variables
  ```sh
  ISSUE_BODY_UPDATED="{issue body, with updated acceptance criteria if changed}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-research" # or "to-implement" or "to-await-waves" depending on bearing and blockers
  PR_ID="—"
  ```

### [merge.md](./reef-pulse/merge.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_ID="{from issue frontmatter pr-id field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-merge"
  ```
- pre-merge-check
  ```sh
  ./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="$PR_ID"
  ```
- commit-code — if merge-needed
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts with $BASE_BRANCH"
  ```
- update-tracker — if tests-fail
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-rework
  ./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-rework
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff — if tests-fail
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-rework"
  PR_ID="$PR_ID"
  ```

### [merge-no-parent.md](./reef-pulse/merge-no-parent.md)

- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-seal
  ./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-seal
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-seal"
  PR_ID="$PR_ID" # inherited from router context
  ```

### [merge-has-parent.md](./reef-pulse/merge-has-parent.md)

- set-variables
  ```sh
  PARENT_ID="{from issue frontmatter parent-issue field}"
  PR_ID="{from issue frontmatter pr-id field}"
  ```
- set-variables
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge
  ```sh
  ./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
  ./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label landed
  ```
- set-variables
  ```sh
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  ```
- check-siblings-and-completion
  ```sh
  ./tracker.sh issue list --json number,labels,body
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label landed
  ./tracker.sh issue close "$ISSUE_ID"
  ```
- update-tracker — if all-siblings-landed
  ```sh
  ./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-seal
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-seal" # or "in-progress" if not all issues tagged 'landed'
  PR_ID="—" # sub-issue merge does not open the parent issue PR
  ```

### [seal.md](./reef-pulse/seal.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title}"
  BASE_BRANCH="{from issue frontmatter base-branch field}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_ID-seal"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- handoff — if blocked-with-conflicts
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="blocked-with-conflicts"
  PR_ID="—"
  ```
- phase-specific
  - contains: `For deep-research, review the written research holistically against the end goal, not just the slice acceptance criteria.`
  - contains: `For feeling-lucky, keep the normal mechanical quality bar but apply slightly softer strictness during holistic review.`
- commit-code — if documentation-added
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "seal: add documentation"
  ```
- submit-report
  ```sh
  REPORT="{seal-report}" # <details><summary><h3>🦭 Seal report — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  ```
- if PR exists
  ```sh
  PR_ID="{from pr create output or existing PR}"
  PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
  PR_BODY="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY"
  ```
- if PR needs creation
  ```sh
  CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g.: #42
  PR_BODY_NEW="$CLOSES\n\n$REPORT"
  ./tracker.sh pr create --base "$BASE_BRANCH" --head "$PR_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-seal
  # Persist the PR metadata on the plan issue so downstream human review can always find it:
  PR_ID="{from pr create output or existing PR}"
  ISSUE_BODY="{original issue body with added frontmatter values}"
  # add to frontmatter: pr-id: $PR_ID
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
  ```
- update-tracker pass case
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land
  ./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land
  ```
- update-tracker human-decision-needed case
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
  ./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
  ```
- update-tracker fail case
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-rework
  ./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-rework
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  ISSUE_ID="$ISSUE_ID"
  NEXT_PHASE="to-land" # or "to-rework" if gaps found; use to-land for human-decision-needed warnings
  PR_ID="$PR_ID"
  ```
