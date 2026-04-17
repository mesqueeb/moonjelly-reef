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
git fetch origin
```

Verify:
- [ ] The feature branch is up to date: `git log origin/{feature-branch}..HEAD` shows nothing unexpected
- [ ] The PR is approved (has `to-merge` tag, inspector's approval)
- [ ] The PR branch is up to date with the feature branch (rebase or merge if needed)

### 2. Merge

```sh
gh pr merge {pr-number} --squash --delete-branch
```

Use squash merge by default unless the project convention differs. Delete the slice branch after merge.

### 3. Verify post-merge

```sh
git checkout {feature-branch}
git pull origin {feature-branch}
```

Run the full test suite on the feature branch after merge. If it fails, **do not proceed** — tag the slice `to-rework` with a note that the merge broke tests and what failed. (Prevents painpoint C2.)

### 4. Append agent decisions to parent

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

### 5. Close the slice

### GitHub tracker

Close the slice issue with `gh issue close <number>`. Add label `done`. Remove `to-merge`.

### Local tracker

Rename from `[to-merge] ...` to `[done] ...`.

### 6. Check siblings

Look at all sibling slices (other slices under the same parent). For any that are tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, they may now be unblockable — but don't promote them directly. Leave them as `to-await-waves`. The next pulse will dispatch `/reef-await-waves` on them, which will re-review their plan against the now-changed feature branch before promoting.

### 7. Check parent completion

Are ALL slices for the parent work item now tagged `done`?

### GitHub tracker

Check all sub-issues of the parent. If all are closed with `done` label:
- Add label `to-ratify` to the parent issue.

### Local tracker

Check all files in the `slices/` folder. If all have `[done]` prefix:
- Rename the parent plan from its current tag to `[to-ratify] plan.md`.

If not all done, do nothing — more slices are still in progress.

## Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If the parent was promoted to `to-ratify`, add: "All slices done — parent is ready for `/reef-ratify`."
