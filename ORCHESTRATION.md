# Phase instructions

Source of truth for what each skill/phase .md file should contain.
Each entry is an ordered list of operations.
The test runner checks: (1) each command string exists in the .md file, (2) they appear in this order, (3) `contains` strings are present in the body.

`if` means the operation is conditional — it must exist in the .md but only runs when the condition holds.

Tracker commands use `./tracker.sh issue ...` and `./tracker.sh pr ...` syntax.
For GitHub: replace `./tracker.sh` with `gh`.
For MCP trackers (ClickUp, Jira, Linear): use equivalent MCP tool calls.

Only variables referenced in an op's cmd/tracker field belong in set-variables.
Phase-specific context (PLAN_TITLE for prose, BASE_BRANCH for reading) belongs in the .md, not here.

## Ticket types in the slice lifecycle

Three types of tickets flow through the slice lifecycle phases (implement → inspect → rework → merge):

| Type                                  | base-branch  | pr-branch   |
| ------------------------------------- | ------------ | ----------- |
| **A** Single-slice plan               | main         | feat/042    |
| **B** Multi-slice sub-issue           | feat/parent  | feat/part-1 |
| **C** Multi-slice plan (after rework) | main         | feat/parent |

All three use `$PR_BRANCH` — the branch the PR lives on — as the branch to fork from, commit to, and review.
`$BASE_BRANCH` is where the PR merges into. For type A and C: `main`. For type B: the parent plan's `pr-branch`.

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
- set-variables — ebb wave: per to-await-waves item
  ```sh
  DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. #42
  ```
- dep-check-ebb — gate dispatch: check each to-await-waves blocker before dispatching
  ```sh
  ./tracker.sh issue view "$DEPENDENCY_ID" --json labels
  ```
- set-variables
  ```sh
  AUTOMATED_DISPATCHES="{count of automated phases dispatched this iteration}"
  ```
- set-variables
  ```sh
  ISSUE_ID="{from dispatched items}"
  ISSUE_BODY="{current issue body with metrics rows inserted into the table}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
  ```
- set-variables
  ```sh
  PLAN_PR_NUMBER="$planPr" # from handoff — never read issue bodies for this
  PLAN_PR_BODY="{current plan PR body with metrics rows inserted into the table}"
  ```
- update-pr-body — if planPr is not "—"
  ```sh
  ./tracker.sh pr edit "$PLAN_PR_NUMBER" --body "$PLAN_PR_BODY"
  ```
- release-lock — if AUTOMATED_DISPATCHES == 0
  - contains: `delete the pulse.lock file`

### [/reef-scope](./reef-scope/SKILL.md)

- set-variables
  ```sh
  START_TIME="{current UTC timestamp}"
  ```
- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
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
  for LABEL in to-slice in-progress to-implement to-inspect to-rework to-merge to-ratify to-land to-await-waves; do
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
  ISSUE_BODY="{plan-content}" # frontmatter + plan body from context
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-scope --add-label to-slice
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
  PLAN_ID="{issue-id}" # if passed
  PR_NUMBER="{pr-number}" # if passed
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$PLAN_ID" --json body,title,labels # if PLAN_ID known
  ./tracker.sh pr view "$PR_NUMBER" --json number,body,headRefName,baseRefName,comments,reviews # if PR_NUMBER known
  ```
- set-variables
  ```sh
  PLAN_ID="{from PR body or already known}"
  PR_NUMBER="{from plan body or already known}"
  BASE_BRANCH="{from plan body}"
  PR_BODY="{the PR body content — this is the ratify report}"
  ```
- phase-specific
- set-variables — if change-requests
  ```sh
  PR_BODY="{current PR body with gap report appended in <details><summary> block}"
  ```
- update-pr-body — if change-requests
  ```sh
  ./tracker.sh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker — if change-requests
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --remove-label to-land --add-label to-rework
  ```
- update-plan-body — if change-requests and plan decisions changed
  ```sh
  PLAN_BODY=$(./tracker.sh issue view "$PLAN_ID" --json body)
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY"
  ```
- sync-pr-label — if change-requests
  ```sh
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-land --add-label to-rework
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
  ./tracker.sh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus
  ```
- set-variables — if approved
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge — if approved
  ```sh
  ./tracker.sh pr merge "$PR_NUMBER" --"$MERGE_STRATEGY" --delete-branch
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-land --add-label landed
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
  ./tracker.sh issue close "$PLAN_ID"
  ```

## Phases

### [slice.md](./reef-pulse/slice.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```

### [slice-single.md](./reef-pulse/slice-single.md)

- set-variables
  ```sh
  ISSUE_BODY="{plan body with pr-branch added to frontmatter and acceptance criteria appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label to-implement
  ```
- handoff
  ```sh
  nextPhase="to-implement"
  planPr="—"
  summary="Single slice — fast path, targeting $BASE_BRANCH directly"
  ```

### [slice-multi.md](./reef-pulse/slice-multi.md)

- set-variables
  ```sh
  PR_BRANCH="{from plan body pr-branch field}"
  BASE_BRANCH="{from plan body}"
  WORKTREE_PATH=".worktrees/$ISSUE_ID-slice"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- create-remote-branch
  ```sh
  git push -u origin "$PR_BRANCH"
  ```
- phase-specific
- set-variables
  ```sh
  SLICE_TITLE="{slice-title} [await: #{blocker-id}]"  # omit [await: ...] if unblocked
  SLICE_BODY="{slice-body}" # as per the template below
  SLICE_LABEL="to-implement" # or to-await-waves if blocked
  ```
- create-slices
  ```sh
  ./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
  ```
- set-variables
  ```sh
  ISSUE_BODY="{plan body with pr-branch in frontmatter and coverage matrix appended}"
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
  nextPhase="in-progress"
  planPr="—"
  ```

### [implement.md](./reef-pulse/implement.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue body}"
  BASE_BRANCH="{from issue body}"
  PR_BRANCH="{from issue frontmatter pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-implement"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- phase-specific
- commit-code
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: implementation"
  ```
- set-variables
  ```sh
  REPORT="{report-content}" # starts with: closes #$ISSUE_ID $ISSUE_TITLE\n\n
  ```
- pr-create
  ```sh
  ./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$REPORT" --label to-inspect
  ```
- set-variables
  ```sh
  PR_NUMBER="{from pr create output}"
  ISSUE_BODY="{issue body with PR reference and pr-branch updated}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-implement --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-inspect"
  planPr="$PR_NUMBER"
  ```

### [inspect.md](./reef-pulse/inspect.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue body}"
  BASE_BRANCH="{from issue body}"
  PR_BRANCH="{from issue body pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-inspect"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- phase-specific
- commit-code — if cleanup-needed
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "inspect: cleanup"
  ```
- update-pr-body
  ```sh
  PR_NUMBER="{from issue body}" # if not found, try ./tracker.sh pr list --search
  PR_BODY=$(./tracker.sh pr view "$PR_NUMBER" --json body -q .body)
  REPORT="{inspect-report}" # <details><summary><h3>🧿 Inspect review — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker pass case
  - contains: `./tracker.sh issue edit "$ISSUE_ID" --remove-label to-inspect --add-label to-merge` + `./tracker.sh pr edit "$PR_NUMBER" --remove-label to-inspect --add-label to-merge`
- update-tracker fail case
  - contains: `./tracker.sh issue edit "$ISSUE_ID" --remove-label to-inspect --add-label to-rework` + `./tracker.sh pr edit "$PR_NUMBER" --remove-label to-inspect --add-label to-rework`
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-merge" # or "to-rework" if gaps found
  planPr="$PR_NUMBER"
  ```

### [rework.md](./reef-pulse/rework.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue body}"
  BASE_BRANCH="{from issue body}"
  PR_BRANCH="{from issue body pr-branch field}"
  PR_NUMBER="{from issue body}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-rework"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- phase-specific
- commit-code
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "rework: address review feedback"
  ```
- update-pr-body
  ```sh
  PR_BODY=$(./tracker.sh pr view "$PR_NUMBER" --json body -q .body)
  REPORT="{rework-report}" # <details><summary><h3>🦀 Rework — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-rework --add-label to-inspect
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-rework --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-inspect"
  planPr="$PR_NUMBER"
  ```

### [await-waves.md](./reef-pulse/await-waves.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue title, stripping [await: ...] suffix}"
  BASE_BRANCH="{from issue body}"
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
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-await-waves --add-label to-implement --title "$ISSUE_TITLE"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- phase-specific
- set-variables
  ```sh
  ISSUE_BODY="{issue body, with updated acceptance criteria if changed}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-implement" # or "to-await-waves" if still blocked
  planPr="—"
  ```

### [merge.md](./reef-pulse/merge.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue body}"
  BASE_BRANCH="{from issue body}"
  PR_NUMBER="{from issue body}"
  PR_BRANCH="{from issue body pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_TITLE-merge"
  ```
- pre-merge-check
  ```sh
  ./tracker.sh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- commit-code — if merge-needed
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts with $BASE_BRANCH"
  ```
- update-tracker — if tests-fail
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-rework
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label to-rework
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```

### [merge-no-parent.md](./reef-pulse/merge-no-parent.md)

- update-tracker
  ```sh
  ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-ratify
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label to-ratify
  ```
- handoff
  ```sh
  nextPhase="to-ratify"
  planPr="$PR_NUMBER" # inherited from router context
  ```

### [merge-has-parent.md](./reef-pulse/merge-has-parent.md)

- set-variables
  ```sh
  PARENT_ID="{from issue body parent-plan field}"
  PR_NUMBER="{from issue body}"
  ```
- set-variables
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge
  ```sh
  ./tracker.sh pr merge "$PR_NUMBER" --"$MERGE_STRATEGY" --delete-branch
  ./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label landed
  ```
- set-variables
  ```sh
  BASE_BRANCH="{from issue body}"
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
  ./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-ratify
  ```
- handoff
  ```sh
  nextPhase="to-ratify" # or "in-progress" if not all issues tagged 'landed'
  planPr="—" # multi-slice: no plan PR yet
  ```

### [ratify.md](./reef-pulse/ratify.md)

- set-variables
  ```sh
  ISSUE_ID="{issue-id}" # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  ISSUE_TITLE="{from issue body}"
  BASE_BRANCH="{from issue body}"
  PR_BRANCH="{from issue body pr-branch field}"
  WORKTREE_PATH=".worktrees/$ISSUE_ID-ratify"
  ```
- enter-worktree
  ```sh
  WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
  ```
- phase-specific
- commit-code — if documentation-added
  ```sh
  ./commit.sh --branch "$PR_BRANCH" -m "ratify: add documentation"
  ```
- submit-report
  ```sh
  REPORT="{ratify-report}" # <details><summary><h3>🦭 Ratify report — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  # if no PR exists:
  ./tracker.sh pr create --base "$BASE_BRANCH" --head "$PR_BRANCH" --title "$ISSUE_TITLE" --body "$REPORT" --label to-ratify
  # if PR exists, append:
  PR_NUMBER="{from pr create output or existing PR}"
  PR_BODY=$(./tracker.sh pr view "$PR_NUMBER" --json body -q .body)
  PR_BODY="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker pass case
  - contains: `./tracker.sh issue edit "$ISSUE_ID" --remove-label to-ratify --add-label to-land` + `./tracker.sh pr edit "$PR_NUMBER" --remove-label to-ratify --add-label to-land`
- update-tracker fail case
  - contains: `./tracker.sh issue edit "$ISSUE_ID" --remove-label to-ratify --add-label to-rework` + `./tracker.sh pr edit "$PR_NUMBER" --remove-label to-ratify --add-label to-rework`
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-land" # or "to-rework" if gaps found, "to-scope" if safety valve
  planPr="$PR_NUMBER"
  planIssueMetrics="{metrics rows from plan issue body, or empty if none}"
  ```
