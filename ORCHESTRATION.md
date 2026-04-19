# Phase instructions

Source of truth for what each skill/phase .md file should contain.
Each entry is an ordered list of operations.
The test runner checks: (1) each command string exists in the .md file, (2) they appear in this order.

`if` means the operation is conditional — it must exist in the .md but only runs when the condition holds.

Tracker commands use `tracker.sh issue ...` syntax.
For GitHub: replace `tracker.sh` with `gh`.
For MCP trackers (ClickUp, Jira, Linear): use equivalent MCP tool calls.

Only variables referenced in an op's cmd/tracker field belong in set-variables.
Phase-specific context (PLAN_TITLE for prose, BASE_BRANCH for reading) belongs in the .md, not here.

## Skills

### [/reef-pulse](./reef-pulse/SKILL.md)

- set-variables
  ```sh
  TRACKER_BRANCH = {from config.md} # e.g. main
  ```
- checkout-tracker-branch — if local-tracker-committed
  ```sh
  git fetch origin $TRACKER_BRANCH && git checkout $TRACKER_BRANCH && git pull
  ```
- phase-specific
- set-variables
  ```sh
  ISSUE_ID = {from dispatched items}
  ISSUE_BODY = {current issue body with metrics section appended}
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $ISSUE_ID --body "$ISSUE_BODY"
  ```

### [/reef-scope](./reef-scope/SKILL.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- phase-specific
- set-variables
  ```sh
  PLAN_ID = $ISSUE_ID
  PLAN_CONTENT = {plan-content} # assembled during phase-specific
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $PLAN_ID --body "$PLAN_CONTENT" --remove-label to-scope --add-label to-slice
  ```

## Phases

### [slice.md](./reef-pulse/slice.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  PLAN_ID = $ISSUE_ID
  TARGET_BRANCH = {from plan body}
  WORKTREE_PATH = ../worktree-$PLAN_ID-slice
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- create-remote-branch — if multi-slice
  ```sh
  git push -u origin $TARGET_BRANCH
  ```
- phase-specific
- set-variables
  ```sh
  PLAN_BODY = {plan body with coverage matrix appended}
  ```
- update-tracker — if multi-slice
  ```sh
  tracker.sh issue edit $PLAN_ID --body "$PLAN_BODY" --remove-label to-slice --add-label in-progress
  ```
- update-tracker — if single-slice
  ```sh
  tracker.sh issue edit $PLAN_ID --body "$PLAN_BODY" --remove-label to-slice --add-label to-implement
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [implement.md](./reef-pulse/implement.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  SLICE_NAME = {from slice body}
  SLICE_NUMBER = $ISSUE_ID
  TARGET_BRANCH = {from slice/plan body}
  SLICE_BRANCH = {PR branch, e.g. feat/001-auth-endpoint}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-implement
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- commit-code
  ```sh
  commit.sh --branch $SLICE_BRANCH -m "$SLICE_NAME: implementation"
  ```
- set-variables
  ```sh
  REPORT = {implementation report assembled during phase-specific}
  ```
- pr-create
  ```sh
  gh pr create --base $TARGET_BRANCH --title "$SLICE_NAME" --body "$REPORT"
  ```
- set-variables
  ```sh
  PR_NUMBER = {from gh pr create output}
  SLICE_BODY = {slice body with PR reference appended}
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $SLICE_NUMBER --body "$SLICE_BODY" --remove-label to-implement --add-label to-inspect
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [inspect.md](./reef-pulse/inspect.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  SLICE_NAME = {from slice body}
  SLICE_NUMBER = $ISSUE_ID
  SLICE_BRANCH = {from slice body}
  PR_NUMBER = {from slice body}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-inspect
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $SLICE_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- commit-code — if cleanup-needed
  ```sh
  commit.sh --branch $SLICE_BRANCH -m "inspect: cleanup"
  ```
- set-variables
  ```sh
  REPORT = {inspection report assembled during phase-specific}
  ```
- update-pr-body
  ```sh
  gh pr edit $PR_NUMBER --body "$REPORT"
  ```
- update-tracker
  - pass: `tracker.sh issue edit $SLICE_NUMBER --remove-label to-inspect --add-label to-merge`
  - fail: `tracker.sh issue edit $SLICE_NUMBER --remove-label to-inspect --add-label to-rework`
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [rework.md](./reef-pulse/rework.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  SLICE_NAME = {from slice body}
  SLICE_NUMBER = $ISSUE_ID
  SLICE_BRANCH = {from slice body}
  PR_NUMBER = {from slice body}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-rework
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $SLICE_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- commit-code
  ```sh
  commit.sh --branch $SLICE_BRANCH -m "rework: address inspection feedback"
  ```
- set-variables
  ```sh
  REPORT = {updated implementation report with rework notes}
  ```
- update-pr-body
  ```sh
  gh pr edit $PR_NUMBER --body "$REPORT"
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $SLICE_NUMBER --remove-label to-rework --add-label to-inspect
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [await-waves.md](./reef-pulse/await-waves.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  SLICE_NAME = {from slice body}
  SLICE_NUMBER = $ISSUE_ID
  TARGET_BRANCH = {from slice/plan body}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-await-waves
  ```
- dep-check
  ```sh
  tracker.sh issue view $DEP_ID --json labels
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- set-variables
  ```sh
  SLICE_BODY = {slice body, with updated acceptance criteria if changed}
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $SLICE_NUMBER --body "$SLICE_BODY" --remove-label to-await-waves --add-label to-implement
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [merge.md](./reef-pulse/merge.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  SLICE_NAME = {from slice body}
  SLICE_NUMBER = $ISSUE_ID
  PR_NUMBER = {from slice body}
  PLAN_ID = {from slice/plan body}
  TARGET_BRANCH = {from slice/plan body}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-merge
  ```
- update-tracker — if single-slice (PR stays open for reef-land — stop here)
  ```sh
  tracker.sh issue edit $PLAN_ID --remove-label to-merge --add-label to-land
  ```
- pr-merge — if multi-slice
  ```sh
  gh pr merge $PR_NUMBER --squash --delete-branch
  ```
- enter-worktree — if multi-slice
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific — if multi-slice
- update-tracker — if multi-slice
  ```sh
  tracker.sh issue close $SLICE_NUMBER
  ```
- update-tracker — if all-slices-done
  ```sh
  tracker.sh issue edit $PLAN_ID --remove-label in-progress --add-label to-ratify
  ```
- exit-worktree — if multi-slice
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [ratify.md](./reef-pulse/ratify.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  PLAN_ID = $ISSUE_ID
  PLAN_TITLE = {from plan body}
  BASE_BRANCH = {from plan body}
  TARGET_BRANCH = {from plan body}
  WORKTREE_PATH = ../worktree-$PLAN_ID-ratify
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- commit-code — if documentation-added
  ```sh
  commit.sh --branch $TARGET_BRANCH -m "ratify: add documentation"
  ```
- set-variables
  ```sh
  REPORT = {ratify report assembled during phase-specific}
  ```
- pr-create — if pass
  ```sh
  gh pr create --base $BASE_BRANCH --head $TARGET_BRANCH --title "$PLAN_TITLE" --body "$REPORT"
  ```
- update-tracker
  - pass: `tracker.sh issue edit $PLAN_ID --remove-label to-ratify --add-label to-land`
  - fail: `tracker.sh issue edit $PLAN_ID --body "$REPORT" --remove-label to-ratify --add-label to-rescan`
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```

### [rescan.md](./reef-pulse/rescan.md)

- set-variables
  ```sh
  ISSUE_ID = {issue-id} # pre-existing and passed or generate
  ```
- fetch-context
  ```sh
  tracker.sh issue view $ISSUE_ID --json body,title,labels
  ```
- set-variables
  ```sh
  PLAN_ID = $ISSUE_ID
  TARGET_BRANCH = {from plan body}
  WORKTREE_PATH = ../worktree-$PLAN_ID-rescan
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
  ```
- phase-specific
- set-variables
  ```sh
  PLAN_BODY = {plan body with updated criteria and coverage matrix}
  ```
- update-tracker
  ```sh
  tracker.sh issue edit $PLAN_ID --body "$PLAN_BODY" --remove-label to-rescan --add-label in-progress
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```
