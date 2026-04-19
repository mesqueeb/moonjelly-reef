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

## Phases

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
  SLICE_BRANCH = {from slice body}
  WORKTREE_PATH = ../worktree-$SLICE_NAME-merge
  ```
- pre-merge-check
  ```sh
  gh pr view $PR_NUMBER --json mergeStateStatus -q .mergeStateStatus
  ```
- enter-worktree
  ```sh
  worktree-enter.sh --fork-from $SLICE_BRANCH --path $WORKTREE_PATH
  ```
- merge-target-into-slice
  ```sh
  git merge origin/$TARGET_BRANCH
  ```
- commit-code — if merge-needed
  ```sh
  commit.sh --branch $SLICE_BRANCH -m "merge: resolve conflicts with $TARGET_BRANCH"
  ```
- update-tracker — if tests-fail
  ```sh
  tracker.sh issue edit $SLICE_NUMBER --remove-label to-merge --add-label to-rework
  ```
- exit-worktree
  ```sh
  worktree-exit.sh --path $WORKTREE_PATH
  ```
- update-tracker — if single-slice (PR stays open for reef-land — stop here)
  ```sh
  tracker.sh issue edit $PLAN_ID --remove-label to-merge --add-label to-land
  ```
- pr-merge — if multi-slice
  ```sh
  gh pr merge $PR_NUMBER --squash --delete-branch
  ```
- check-siblings — if multi-slice
  ```sh
  tracker.sh issue list --json number,labels --search "parent:$PLAN_ID"
  ```
- check-completion — if multi-slice
  ```sh
  tracker.sh issue view $PLAN_ID --json body,title,labels
  ```
- update-tracker — if multi-slice
  ```sh
  tracker.sh issue close $SLICE_NUMBER
  ```
- update-tracker — if all-slices-done
  ```sh
  tracker.sh issue edit $PLAN_ID --remove-label in-progress --add-label to-ratify
  ```
