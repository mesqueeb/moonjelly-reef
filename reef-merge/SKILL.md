---
name: reef-merge
description: Merge an approved slice PR into the feature branch. Update sibling and parent status. Append agent decisions to parent. Use when a slice is tagged to-merge.
---

# reef-merge

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Document any judgment calls on the relevant PR or as a comment on the parent issue. Never block waiting for human input.

## Input

This skill requires a specific slice: `/reef-merge #55` or `/reef-merge my-feature/001-auth-endpoint`.

Read the slice to find the PR reference and the parent plan reference.

## Process

### 1. Pre-merge checks

```sh
git fetch origin --prune
```

Verify:
- [ ] The PR is approved (has `to-merge` tag, inspector's approval)
- [ ] The slice branch is up to date with the feature branch:

```sh
# Check if the feature branch has commits not in the slice branch
gh pr view {pr-number} --json mergeStateStatus -q .mergeStateStatus
```

If the slice branch is behind the feature branch (merge conflicts or `BEHIND`):

1. Check out the implementation worktree (it should still exist from reef-implement)
2. Merge the feature branch into the slice branch: `git merge origin/{feature-branch}`
3. Resolve any conflicts
4. Run the full test suite — must be green with the merged code
5. Push the updated slice branch

If the suite fails after merging in the feature branch, tag the slice `to-rework` with a note explaining what broke. Do not proceed to merge.

### 2. Merge

```sh
gh pr merge {pr-number} --squash --delete-branch
```

Use squash merge by default unless the project convention differs. `--delete-branch` deletes the remote slice branch.

### 3. Clean up worktree

The slice was implemented in a worktree. Remove it now that the PR is merged.

```sh
# Remove the worktree (from the main checkout, not from inside the worktree)
git worktree remove ../worktree-{slice-name}

# Prune stale tracking branches
git fetch origin --prune

# Delete the local slice branch if it still exists
git branch -d {slice-branch} 2>/dev/null || true
```

### 4. Verify post-merge

Use a temporary worktree to verify the feature branch after merge.

```sh
git fetch origin --prune
git worktree add ../worktree-merge-verify-{slice-name} origin/{feature-branch}
cd ../worktree-merge-verify-{slice-name}
```

Run the full test suite on the feature branch. If it fails, **do not proceed** — tag the slice `to-rework` with a note that the merge broke tests and what failed. (Prevents painpoint C2.)

Clean up after verification:

```sh
cd ..
git worktree remove ../worktree-merge-verify-{slice-name}
```

### 5. Append agent decisions to parent

Read the merged PR description. Extract the "Ambiguous choices" section.

If there are any ambiguous choices:

### GitHub tracker

Add a comment on the parent issue:

```markdown
## Agent decisions from slice {slice-name} (#{slice-number})

{paste the ambiguous choices section from the PR}
```

### Local tracker

Append to the parent plan file, in a section below the coverage matrix:

```markdown
## Agent decisions

### From slice {slice-name}

{paste the ambiguous choices section}
```

This aggregates decisions at merge time so reef-ratify doesn't have to hunt through all PRs later.

### 6. Close the slice

### GitHub tracker

Close the slice issue with `gh issue close <number>`. Add label `done`. Remove `to-merge`.

### Local tracker

Rename from `[to-merge] ...` to `[done] ...`.

### 7. Check siblings

Look at all sibling slices (other slices under the same parent). For any that are tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, they may now be unblockable — but don't promote them directly. Leave them as `to-await-waves`. The next pulse will dispatch `/reef-await-waves` on them, which will re-review their plan against the now-changed feature branch before promoting.

### 8. Check parent completion

Are ALL slices for the parent work item now tagged `done`?

### GitHub tracker

Check all sub-issues of the parent. If all are closed with `done` label:
- Change the parent issue label from `in-progress` to `to-ratify`.

### Local tracker

Check all files in the `slices/` folder. If all have `[done]` prefix:
- Rename the parent plan from `[in-progress] plan.md` to `[to-ratify] plan.md`.

If not all done, do nothing — more slices are still in progress.

## Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If the parent was promoted to `to-ratify`, add: "All slices done — parent is ready for `/reef-ratify`."
