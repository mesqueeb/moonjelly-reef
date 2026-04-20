# Phase instructions

Source of truth for what each skill/phase .md file should contain.
Each entry is an ordered list of operations.
The test runner checks: (1) each command string exists in the .md file, (2) they appear in this order, (3) `contains` strings are present in the body.

`if` means the operation is conditional — it must exist in the .md but only runs when the condition holds.

Tracker commands use `./tracker.sh issue ...` syntax.
For GitHub: replace `./tracker.sh` with `gh`.
For MCP trackers (ClickUp, Jira, Linear): use equivalent MCP tool calls.

Only variables referenced in an op's cmd/tracker field belong in set-variables.
Phase-specific context (PLAN_TITLE for prose, BASE_BRANCH for reading) belongs in the .md, not here.

## Skills

### [/reef-pulse](./reef-pulse/SKILL.md)

- set-variables
  ```sh
  SKILL_DIR="{base directory for this skill}"
  TRACKER_BRANCH="{from config.md}" # e.g. main
  ```
- checkout-tracker-branch — if local-tracker-committed
  ```sh
  git fetch origin "$TRACKER_BRANCH" && git checkout "$TRACKER_BRANCH" && git pull
  ```
- phase-specific
  - contains: `$SKILL_DIR/{file}`
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
  gh pr edit "$PLAN_PR_NUMBER" --body "$PLAN_PR_BODY"
  ```

### [/reef-scope](./reef-scope/SKILL.md)

- set-variables
  ```sh
  START_TIME = {current UTC timestamp}
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
  PLAN_ID="$ISSUE_ID"
  BASE_BRANCH="{from base branch discussion}"
  TARGET_BRANCH="{from branch discussion}"
  PLAN_TYPE="{feature, refactor, or bug}"
  ```
- update-tracker
  ```sh
  PLAN_CONTENT="{plan-content}" # frontmatter + plan body from context
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_CONTENT" --remove-label to-scope --add-label to-slice
  ```
- set-variables
  ```sh
  DURATION = {human-readable duration since START_TIME, e.g. "42s", "1m 12s"}
  PLAN_BODY = {current plan issue body with metrics section appended}
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY"
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
  gh pr view "$PR_NUMBER" --json number,body,headRefName,baseRefName,comments,reviews # if PR_NUMBER known
  ```
- set-variables
  ```sh
  PLAN_ID="{from PR body or already known}"
  PR_NUMBER="{from plan body or already known}"
  BASE_BRANCH="{from plan body}"
  PR_BODY="{the PR body content — this is the ratify report}"
  ```
- fetch-pr-comments-and-reviews
  ```sh
  gh pr view "$PR_NUMBER" --json comments,reviews # if not already fetched
  ```
- phase-specific
- set-variables — if change-requests
  ```sh
  PR_BODY="{current PR body with gap report appended in <details><summary> block}"
  ```
- update-pr-body — if change-requests
  ```sh
  gh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker — if change-requests
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --remove-label to-land --add-label to-rescan
  ```
- update-plan-body — if change-requests and plan decisions changed
  ```sh
  PLAN_BODY=$(./tracker.sh issue view "$PLAN_ID" --json body)
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY"
  ```
- pre-merge-check — if approved
  ```sh
  gh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus
  ```
- set-variables — if approved
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge — if approved
  ```sh
  gh pr merge "$PR_NUMBER" --"$MERGE_STRATEGY" --delete-branch
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
- set-variables — if follow-up
  ```sh
  FOLLOW_UP_CONTEXT="{summary of PR comments and concerns from step 2}"
  ```
- create-tracker — if follow-up
  ```sh
  ./tracker.sh issue create --title "Follow-up: {summary of concerns}" --body "$FOLLOW_UP_CONTEXT" --label to-scope
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
  PLAN_ID="$ISSUE_ID"
  PLAN_BODY="{plan body with target branch added to frontmatter and acceptance criteria appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-slice --add-label to-implement
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
  PLAN_ID="$ISSUE_ID"
  TARGET_BRANCH="{from plan body}"
  BASE_BRANCH="{from plan body}"
  PLAN_TYPE="{from plan body}" # feature, refactor, or bug
  WORKTREE_PATH=".worktrees/$PLAN_ID-slice"
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $TARGET_BRANCH to read the codebase for informed slicing decisions`
  ```sh
  ./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH"
  ```
- create-remote-branch
  ```sh
  git push -u origin "$TARGET_BRANCH"
  ```
- phase-specific
- set-variables
  ```sh
  SLICE_TITLE="{slice-title}"
  SLICE_BODY="{slice-body}" # as per the template below
  SLICE_LABEL="to-implement" # or to-await-waves if blocked
  ```
- create-slices
  ```sh
  ./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
  ```
- set-variables
  ```sh
  PLAN_BODY="{plan body with coverage matrix appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-slice --add-label in-progress
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="in-progress"
  planPr="—"
  summary="Slices created with acceptance criteria, dependency graph, and coverage matrix"
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
  SLICE_NAME="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  BASE_BRANCH="{from slice/plan body}"
  TARGET_BRANCH="{from slice/plan body}"
  SLICE_BRANCH="{PR branch, e.g. feat/001-auth-endpoint}"
  WORKTREE_PATH=".worktrees/$SLICE_NAME-implement"
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $TARGET_BRANCH so you start from a clean integration point`
  ```sh
  ./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- commit-code
  ```sh
  ./commit.sh --branch "$SLICE_BRANCH" -m "$SLICE_NAME: implementation"
  ```
- set-variables
  ```sh
  REPORT="{report-content}" # starts with: closes #$SLICE_ID $SLICE_NAME\n\n
  ```
- pr-create
  ```sh
  gh pr create --base "$TARGET_BRANCH" --title "$SLICE_NAME" --body "$REPORT"
  ```
- set-variables
  ```sh
  PR_NUMBER="{from gh pr create output}"
  SLICE_BODY="{slice body with PR reference appended}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$SLICE_ID" --body "$SLICE_BODY" --remove-label to-implement --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-inspect"
  planPr="$PR_NUMBER"
  summary="Implementation complete for $SLICE_NAME"
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
  SLICE_NAME="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  SLICE_BRANCH="{from slice body}"
  TARGET_BRANCH="{from slice/plan body}"
  WORKTREE_PATH=".worktrees/$SLICE_NAME-inspect"
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $SLICE_BRANCH to review the implementation`
  ```sh
  ./worktree-enter.sh --fork-from "$SLICE_BRANCH" --pull-latest "$TARGET_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- commit-code — if cleanup-needed
  ```sh
  ./commit.sh --branch "$SLICE_BRANCH" -m "inspect: cleanup"
  ```
- update-pr-body
  ```sh
  PR_NUMBER="{from slice body}" # if not found, try gh pr list --search
  PR_BODY=$(gh pr view "$PR_NUMBER" --json body -q .body)
  REPORT="{inspect-report}" # <details><summary><h3>🧿 Inspect review — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY="$PR_BODY\n\n$REPORT"
  gh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker
  - pass: `./tracker.sh issue edit "$SLICE_ID" --remove-label to-inspect --add-label to-merge`
  - fail: `./tracker.sh issue edit "$SLICE_ID" --remove-label to-inspect --add-label to-rework`
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-merge" # or "to-rework" if gaps found
  planPr="$PR_NUMBER"
  summary="{verdict}: {one-line summary of findings}"
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
  SLICE_NAME="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  SLICE_BRANCH="{from slice body}"
  TARGET_BRANCH="{from slice/plan body}"
  PR_NUMBER="{from slice body}"
  WORKTREE_PATH=".worktrees/$SLICE_NAME-rework"
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $SLICE_BRANCH to apply fixes to the existing PR branch`
  ```sh
  ./worktree-enter.sh --fork-from "$SLICE_BRANCH" --pull-latest "$TARGET_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- commit-code
  ```sh
  ./commit.sh --branch "$SLICE_BRANCH" -m "rework: address inspection feedback"
  ```
- update-pr-body
  ```sh
  PR_BODY=$(gh pr view "$PR_NUMBER" --json body -q .body)
  REPORT="{rework-report}" # <details><summary><h3>🦀 Rework — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  PR_BODY="$PR_BODY\n\n$REPORT"
  gh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$SLICE_ID" --remove-label to-rework --add-label to-inspect
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-inspect"
  planPr="$PR_NUMBER"
  summary="Rework complete — addressed inspection feedback"
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
  SLICE_NAME="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  BASE_BRANCH="{from slice/plan body}"
  TARGET_BRANCH="{from slice/plan body}"
  WORKTREE_PATH=".worktrees/$SLICE_NAME-await-waves"
  ```
- set-variables
  ```sh
  DEPENDENCY_ID="{from slice blocked-by list}"
  ```
- dep-check
  ```sh
  ./tracker.sh issue view "$DEPENDENCY_ID" --json labels
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $TARGET_BRANCH to be able to read up to date code`
  ```sh
  ./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- set-variables
  ```sh
  SLICE_BODY="{slice body, with updated acceptance criteria if changed}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$SLICE_ID" --body "$SLICE_BODY" --remove-label to-await-waves --add-label to-implement
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-implement" # or "to-await-waves" if still blocked
  planPr="—"
  summary="Slice {name} is unblocked and ready for implementation" # or "still blocked by #N, #M"
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
  SLICE_NAME="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  PR_NUMBER="{from slice body}"
  TARGET_BRANCH="{from slice/plan body}"
  SLICE_BRANCH="{from slice body}"
  WORKTREE_PATH=".worktrees/$SLICE_NAME-merge"
  ```
- pre-merge-check
  ```sh
  gh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $SLICE_BRANCH (not $TARGET_BRANCH) so you are testing the slice code with the latest target merged in`
  ```sh
  ./worktree-enter.sh --fork-from "$SLICE_BRANCH" --pull-latest "$TARGET_BRANCH" --path "$WORKTREE_PATH"
  ```
- commit-code — if merge-needed
  ```sh
  ./commit.sh --branch "$SLICE_BRANCH" -m "merge: resolve conflicts with $TARGET_BRANCH"
  ```
- update-tracker — if tests-fail
  ```sh
  ./tracker.sh issue edit "$SLICE_ID" --remove-label to-merge --add-label to-rework
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```

### [merge-single.md](./reef-pulse/merge-single.md)

- set-variables
  ```sh
  PLAN_ID="{from slice/plan body}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --remove-label to-merge --add-label to-land
  ```
- handoff
  ```sh
  nextPhase="to-land"
  planPr="$PR_NUMBER" # inherited from router context
  summary="Single slice verified — PR stays open for human review"
  ```

### [merge-multi.md](./reef-pulse/merge-multi.md)

- set-variables
  ```sh
  PLAN_ID="{from slice/plan body}"
  PR_NUMBER="{from slice body}"
  SLICE_ID="$ISSUE_ID"
  ```
- set-variables
  ```sh
  MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
  ```
- pr-merge
  ```sh
  gh pr merge "$PR_NUMBER" --"$MERGE_STRATEGY" --delete-branch
  ```
- check-siblings-and-completion
  ```sh
  ./tracker.sh issue view "$PLAN_ID" --json body,title,labels
  ```
- set-variables
  ```sh
  SIBLING_ID="{from coverage matrix}"
  ```
- update-tracker
  ```sh
  ./tracker.sh issue close "$SLICE_ID"
  ```
- update-tracker — if all-slices-done
  ```sh
  ./tracker.sh issue edit "$PLAN_ID" --remove-label in-progress --add-label to-ratify
  ```
- handoff
  ```sh
  nextPhase="to-ratify" # or "in-progress" if not all slices done
  planPr="—" # multi-slice: no plan PR yet
  summary="Slice {name} merged — {N} of {total} slices complete"
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
  PLAN_ID="$ISSUE_ID"
  PLAN_TITLE="{from plan body}"
  BASE_BRANCH="{from plan body}"
  TARGET_BRANCH="{from plan body}"
  WORKTREE_PATH=".worktrees/$PLAN_ID-ratify"
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $TARGET_BRANCH because all slice PRs are merged there`
  ```sh
  ./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- commit-code — if documentation-added
  ```sh
  ./commit.sh --branch "$TARGET_BRANCH" -m "ratify: add documentation"
  ```
- submit-report
  ```sh
  REPORT="{ratify-report}" # <details><summary><h3>🦭 Ratify report — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
  # if no PR exists:
  gh pr create --base "$BASE_BRANCH" --head "$TARGET_BRANCH" --title "$PLAN_TITLE" --body "$REPORT"
  # if PR exists, append:
  PR_NUMBER="{from pr create output or existing PR}"
  PR_BODY=$(gh pr view "$PR_NUMBER" --json body -q .body)
  PR_BODY="$PR_BODY\n\n$REPORT"
  gh pr edit "$PR_NUMBER" --body "$PR_BODY"
  ```
- update-tracker
  - pass: `./tracker.sh issue edit "$PLAN_ID" --remove-label to-ratify --add-label to-land`
  - fail: `./tracker.sh issue edit "$PLAN_ID" --remove-label to-ratify --add-label to-rescan`
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="to-land" # or "to-rescan" if gaps found
  planPr="$PR_NUMBER"
  summary="Ratify {PASS|GAPS FOUND} — {one-line summary}"
  planIssueMetrics="{metrics rows from plan issue body, or empty if none}"
  ```

### [rescan.md](./reef-pulse/rescan.md)

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
  PLAN_ID="$ISSUE_ID"
  PR_NUMBER="{from plan body frontmatter PR: \"#N\"}"
  BASE_BRANCH="{from plan body}"
  TARGET_BRANCH="{from plan body}"
  WORKTREE_PATH=".worktrees/$PLAN_ID-rescan"
  ```
- fetch-pr
  ```sh
  gh pr view "$PR_NUMBER" --json body
  ```
- enter-worktree
  - contains: `Enter a worktree forked from $TARGET_BRANCH to read the current state of the code`
  ```sh
  ./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH"
  ```
- phase-specific
- update-tracker
  ```sh
  PLAN_BODY="{plan body with updated criteria and coverage matrix}"
  ./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-rescan --add-label in-progress
  ```
- exit-worktree
  ```sh
  ./worktree-exit.sh --path "$WORKTREE_PATH"
  ```
- handoff
  ```sh
  nextPhase="in-progress"
  planPr="$PR_NUMBER"
  summary="Created {N} new slices to address gaps — coverage matrix updated"
  ```
