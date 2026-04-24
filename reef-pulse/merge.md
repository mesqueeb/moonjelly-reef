# merge

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — run `./worktree-enter.sh`, `./worktree-exit.sh`, and `./commit.sh` exactly as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-merge` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-merge label."
```

Report these variables to the caller and **do not continue**.

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}" # e.g. "my-feature"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_ID="{from issue frontmatter pr-id field}" # e.g. "#7"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/my-feature"
PARENT_ISSUE="{from issue frontmatter parent-issue field, or - if not present}" # e.g. "#3"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-merge"
```

## 1. Pre-merge check

Check the merge state of the PR:

```sh
./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
```

Enter a worktree forked from `$PR_BRANCH` so you are testing the `$PR_BRANCH` with the latest `$BASE_BRANCH` merged in:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$PR_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="$PR_ID"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

Run the full test suite. If tests pass, commit and push:

```sh
./commit.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts with $BASE_BRANCH"
```

If the test suite fails after merging, label the issue `to-rework`:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-rework
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-rework
```

Clean up the worktree:

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-rework"
PR_ID="$PR_ID"
SUMMARY="Merge blocked: test suite failed after conflict resolution."
```

Report these variables to the caller and **do not continue**.

## 2. Delegate

If `"$PARENT_ISSUE" = "-"`, read and execute [merge-no-parent.md](merge-no-parent.md) with:

```
ISSUE_ID="$ISSUE_ID"
PR_ID="$PR_ID"
```

If `$PARENT_ISSUE` is a specific issue ID, read and execute [merge-has-parent.md](merge-has-parent.md) with:

```
ISSUE_ID="$ISSUE_ID"
PARENT_ID="$PARENT_ISSUE"
PR_ID="$PR_ID"
BASE_BRANCH="$BASE_BRANCH"
MERGE_STRATEGY="$MERGE_STRATEGY"
```
