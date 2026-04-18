# merge

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Document any judgment calls on the relevant PR or as a comment on the parent issue. Never block waiting for human input.

## Input

A work item tagged `to-merge` with an open PR.

Read the item to find the PR reference. Check the Plan context to determine whether this is **single-slice** (target branch = base branch) or **multi-slice** (target branch forks from base branch).

## Single-slice

The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

1. Tag the parent `to-land`. Remove `to-merge`.
3. Report: "Single slice verified. PR stays open for human review. Run `/reef-land #{number}`."

### Handoff

Report: "PR stays open for human review. Run `/reef-land #{number}`."

## Multi-slice

### 1. Pre-merge checks

```sh
git fetch origin --prune
```

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
gh pr merge {pr-number} --squash --delete-branch
```

Use squash merge by default unless the project convention differs. `--delete-branch` deletes the remote slice branch.

### 3. Clean up local branch

```sh
git fetch origin --prune
git branch -d {slice-branch} 2>/dev/null || true
```

### 4. Verify post-merge

Use a temporary worktree to verify the target branch after merge.

```sh
git fetch origin --prune
git worktree add ../worktree-merge-verify-{slice-name} origin/{target-branch}
cd ../worktree-merge-verify-{slice-name}
```

Run the full test suite. If it fails, **do not proceed** — tag the slice `to-rework` with a note that the merge broke tests and what failed.

Clean up:

```sh
cd ..
git worktree remove ../worktree-merge-verify-{slice-name}
```

### 5. Append agent decisions to parent

Read the merged PR description. Extract the "Ambiguous choices" section.

If there are any ambiguous choices:

#### GitHub tracker

Add a comment on the parent issue:

```markdown
## Agent decisions from slice {slice-name} (#{slice-number})

{paste the ambiguous choices section from the PR}
```

#### Local tracker

Append to the parent plan file, in a section below the coverage matrix:

```markdown
## Agent decisions

### From slice {slice-name}

{paste the ambiguous choices section}
```

This aggregates decisions at merge time so the ratify phase doesn't have to hunt through all PRs later.

### 6. Close the slice

#### GitHub tracker

Close the slice issue with `gh issue close <number>`. Add label `done`. Remove `to-merge`.

#### Local tracker

Rename from `[to-merge] ...` to `[done] ...`.

### 7. Check siblings

Look at all sibling slices (other slices under the same parent). For any tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

### 8. Check parent completion

Are ALL slices for the parent now tagged `done`?

#### GitHub tracker

Check all sub-issues of the parent. If all are closed with `done` label:

- Change the parent issue label from `in-progress` to `to-ratify`.

#### Local tracker

Check all files in the `slices/` folder. If all have `[done]` prefix:

- Rename the parent plan from `[in-progress] plan.md` to `[to-ratify] plan.md`.

If not all done, do nothing — more slices are still in progress.

### Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If promoted to `to-ratify`: "All slices done — parent is ready for ratification."
