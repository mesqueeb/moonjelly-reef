# merge

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

An issue tagged `to-merge` with an open PR.

Read the item to find the PR reference. Check the Plan context to determine whether this is **single-slice** (target branch = base branch) or **multi-slice** (target branch forks from base branch).

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

### Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

### Variables

```sh
SLICE_NAME = {from slice body}
SLICE_NUMBER = $ISSUE_ID
PR_NUMBER = {from slice body}
PLAN_ID = {from slice/plan body}
TARGET_BRANCH = {from slice/plan body}
SLICE_BRANCH = {from slice body}
WORKTREE_PATH = ../worktree-$SLICE_NAME-merge
```

## Pre-merge check

Unconditional for both single-slice and multi-slice. Ensures the slice branch integrates cleanly with the target branch before proceeding.

Check the merge state of the PR:

```sh
gh pr view $PR_NUMBER --json mergeStateStatus -q .mergeStateStatus
```

Enter a worktree on the slice branch:

```sh
WORKTREE=$(reef-worktree-enter.sh \
  --base-branch {base-branch} --target-branch {target-branch} \
  --phase merge --slice {slice-name} \
  --slice-branch $SLICE_BRANCH --branch-op checkout)
cd "$WORKTREE"
```

Note: the worktree enters on `SLICE_BRANCH` via `worktree-enter.sh --fork-from $SLICE_BRANCH`, not on the target branch. This ensures you are testing the slice code with the latest target merged in.

Merge the target branch into the slice branch:

```sh
git merge origin/$TARGET_BRANCH
```

Run the full test suite. If the target branch merged cleanly and tests pass, commit and push:

```sh
commit.sh --branch $SLICE_BRANCH -m "merge: resolve conflicts with $TARGET_BRANCH"
```

If the test suite fails after merging, tag the slice `to-rework` and stop:

```sh
tracker.sh issue edit $SLICE_NUMBER --remove-label to-merge --add-label to-rework
```

Clean up the worktree:

```sh
reef-worktree-exit.sh --path "$WORKTREE"
```

If tests failed, stop here. Do not proceed to single-slice or multi-slice steps.

## Single-slice

The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

Tag the plan `to-land`. Remove `to-merge`:

```sh
tracker.sh issue edit $PLAN_ID --remove-label to-merge --add-label to-land
```

### Handoff

Report: "Single slice verified. PR stays open for human review. Run `/reef-land #{number}`."

## Multi-slice

### 1. Merge

```sh
gh pr merge $PR_NUMBER --squash --delete-branch
```

Use squash merge by default unless the project convention differs. `--delete-branch` deletes the remote slice branch.

### 2. Check siblings

Look at all sibling slices (other slices under the same plan):

```sh
tracker.sh issue list --json number,labels --search "parent:$PLAN_ID"
```

For any tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

### 3. Check plan completion

Are ALL slices for the plan now tagged `done`?

```sh
tracker.sh issue view $PLAN_ID --json body,title,labels
```

#### GitHub tracker

Check all sub-issues of the plan. If all are closed with `done` label:

- Change the plan issue label from `in-progress` to `to-ratify`.

#### Local tracker

Check all files in the `slices/` folder. If all have `[done]` prefix:

- Rename the plan from `[in-progress] plan.md` to `[to-ratify] plan.md`.

If not all done, do nothing — more slices are still in progress.

### 4. Close the slice

#### GitHub tracker

Close the slice issue with `tracker.sh issue close $SLICE_NUMBER`. Add label `done`. Remove `to-merge`.

#### Local tracker

Rename from `[to-merge] ...` to `[done] ...`.

### 5. Update plan tag — if all slices done

```sh
tracker.sh issue edit $PLAN_ID --remove-label in-progress --add-label to-ratify
```

### 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If promoted to `to-ratify`: "All slices done — plan is ready for ratification."
