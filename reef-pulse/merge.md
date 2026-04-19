# merge

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

An issue tagged `to-merge` with an open PR.

Read the item to find the PR reference. Check the Plan context to determine whether this is **single-slice** (target branch = base branch) or **multi-slice** (target branch forks from base branch).

Set the initial variables:

```sh
SLICE_NAME = {from slice metadata}
SLICE_NUMBER = {from slice metadata}
PR_NUMBER = {from slice metadata}
BASE_BRANCH = {from slice/plan metadata}
TARGET_BRANCH = {from slice/plan metadata}
WORKTREE_PATH = ../worktree-$SLICE_NAME-merge
```

## 0. Fetch context

### GitHub tracker

```sh
gh issue view $SLICE_NUMBER --json body,title,labels
```

### Local tracker

Read the file at:

```sh
$LOCAL_PATH/$PLAN_ID (\w+)/slices/[to-merge] $SLICE_NAME.md
```

## Single-slice

The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

1. Tag the plan `to-land`. Remove `to-merge`.
3. Report: "Single slice verified. PR stays open for human review. Run `/reef-land #{number}`."

### Handoff

Report: "PR stays open for human review. Run `/reef-land #{number}`."

## Multi-slice

### 1. Pre-merge checks

Verify:

- [ ] The PR is approved (has `to-merge` tag, inspector's approval)
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
gh pr merge $PR_NUMBER --squash --delete-branch
```

Use squash merge by default unless the project convention differs. `--delete-branch` deletes the remote slice branch.

### 3. Verify post-merge

Use a temporary worktree to verify the target branch after merge.

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

Run the full test suite. If it fails, **do not proceed** — tag the slice `to-rework` with a note that the merge broke tests and what failed.

### 4. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 5. Close the slice

#### GitHub tracker

Close the slice issue with `gh issue close <number>`. Add label `done`. Remove `to-merge`.

```sh
gh issue close $SLICE_NUMBER
```

#### Local tracker

Rename from `[to-merge] ...` to `[done] ...`.

For local tracker, commit the metadata writes:

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
mv "[to-merge]" "[done]"
commit.sh --branch $TARGET_BRANCH -m "merge: close $SLICE_NAME, update plan"
worktree-exit.sh --path $WORKTREE_PATH
```

### 6. Check siblings

Look at all sibling slices (other slices under the same plan). For any tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

### 7. Check plan completion

Are ALL slices for the plan now tagged `done`?

#### GitHub tracker

Check all sub-issues of the plan. If all are closed with `done` label:

- Change the plan issue label from `in-progress` to `to-ratify`.

#### Local tracker

Check all files in the `slices/` folder. If all have `[done]` prefix:

- Rename the plan from `[in-progress] plan.md` to `[to-ratify] plan.md`.

If not all done, do nothing — more slices are still in progress.

## Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

### Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If promoted to `to-ratify`: "All slices done — plan is ready for ratification."
