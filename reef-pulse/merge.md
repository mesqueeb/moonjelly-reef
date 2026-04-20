# merge

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

An issue tagged `to-merge` with an open PR.

Read the item to find the PR reference. Check the Plan context to determine whether this is **single-slice** (target branch = base branch) or **multi-slice** (target branch forks from base branch).

Set the pre-fetch variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

## 0. Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

Set the post-fetch variables (after reading the slice body):

```sh
SLICE_NAME = {from slice body}
SLICE_NUMBER = $ISSUE_ID
PR_NUMBER = {from slice body}
PLAN_ID = {from slice/plan body}
TARGET_BRANCH = {from slice/plan body}
WORKTREE_PATH = ../worktree-$SLICE_NAME-merge
```

## Single-slice

The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

1. Tag the plan `to-land`. Remove `to-merge`.
2. Report: "Single slice verified. PR stays open for human review. Run `/reef-land #{number}`."

**Stop here — do not continue to multi-slice steps below.**

## Multi-slice

### 1. Pre-merge checks

Verify:

- [ ] The PR is approved (has `to-merge` tag, set by the inspector)
- [ ] The slice branch is up to date with the target branch:

```sh
gh pr view {pr-number} --json mergeStateStatus -q .mergeStateStatus
```

If the slice branch is behind the target branch (merge conflicts or `BEHIND`):

1. Check out the implementation worktree (it should still exist from the implement phase)
2. Merge the target branch into the slice branch: `git merge origin/{target-branch}`
3. Resolve any conflicts
4. Run the full test suite — must be green with the merged code
5. Push the updated slice branch

If the suite fails after merging, tag the slice `to-rework` with a note explaining what broke. Do not proceed.

### 2. Merge

```sh
MERGE_STRATEGY = {from .agents/moonjelly-reef/config.md merge-strategy field}
```

```sh
gh pr merge $PR_NUMBER --$MERGE_STRATEGY --delete-branch
```

### 3. Verify post-merge

Use a temporary worktree to verify the target branch after merge.

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

Run the full test suite. If it fails, **do not proceed** — tag the slice `to-rework` with a note that the merge broke tests and what failed.

### 4. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 5. Close the slice

Close the slice issue and update the plan label. Add label `done`. Remove `to-merge`.

```sh
tracker.sh issue close $SLICE_NUMBER
tracker.sh issue edit $PLAN_ID --remove-label in-progress --add-label to-ratify
```

### 6. Check siblings

Look at all sibling slices (other slices under the same plan). For any tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

### 7. Check plan completion

Are ALL slices for the plan now tagged `done`?

```sh
tracker.sh issue list --label done --parent $PLAN_ID
tracker.sh issue view $PLAN_ID --json body,labels
```

If all slices are done, change the plan label from `in-progress` to `to-ratify`. If not all done, do nothing — more slices are still in progress.

## Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

### Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If promoted to `to-ratify`: "All slices done — plan is ready for ratification."
