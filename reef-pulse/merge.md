# merge

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, assume `github` as the tracker type.

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}" # e.g. "squash"
```

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For local-tracker, run `./tracker.sh` and `./merge.sh` exactly as written.
- For GitHub, replace `./tracker.sh` and `./merge.sh` with `gh`
- For other trackers with MCP issue tools, replace `./tracker.sh issue` with their MCP equivalent and `./tracker.sh pr` and `./merge.sh pr` with `gh pr`

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-merge` label.

If it does not, hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-merge label."
```

Else set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}" # e.g. "my-feature"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_ID="{from issue frontmatter pr-id field}" # e.g. "#7"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/my-feature"
PARENT_ISSUE="{from issue frontmatter parent-issue field, or - if not present}" # e.g. "#3"
WORKTREE_PATH=".worktrees/$(echo "$ISSUE_TITLE" | tr '/' '-')-merge"
```

## 1. Git prep

Check the merge state of the PR:

```sh
./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
```

This is non-negotiable. Enter a worktree with the exact command below:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree.

If resolved:

```sh
./commit-push.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts 🌊"
```

Then continue.

If unresolvable:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="blocked-with-conflicts"
    PR_ID="$PR_ID"
    SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
    ```

## 2. Run tests

Run the full test suite. If tests pass, continue to step 3.

If the test suite fails after merging, label the issue `to-rework`:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-rework
    ./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-rework
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="to-rework"
    PR_ID="$PR_ID"
    SUMMARY="Merge blocked: test suite failed."
    ```

## 3. Delegate

Clean up the worktree:

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

If `"$PARENT_ISSUE" = "-"`, read and execute [merge-no-parent.md](merge-no-parent.md) with:

```
ISSUE_ID="$ISSUE_ID"
PR_ID="$PR_ID"
```

If `$PARENT_ISSUE` is a specific ID, read and execute [merge-has-parent.md](merge-has-parent.md) with:

```
ISSUE_ID="$ISSUE_ID"
ISSUE_TITLE="$ISSUE_TITLE"
PARENT_ID="$PARENT_ISSUE"
PR_ID="$PR_ID"
PR_BRANCH="$PR_BRANCH"
BASE_BRANCH="$BASE_BRANCH"
MERGE_STRATEGY="$MERGE_STRATEGY"
```
