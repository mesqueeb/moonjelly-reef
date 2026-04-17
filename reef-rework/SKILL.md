---
name: reef-rework
description: Fix issues flagged by the inspector on a slice PR. Address every review comment. Use when a slice is tagged to-rework.
---

# reef-rework

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Document any judgment calls on the relevant PR or as a comment on the parent issue. Never block waiting for human input.

## Input

This skill requires a specific slice: `/reef-rework #55` or `/reef-rework my-feature/001-auth-endpoint`.

Read the slice to find the PR reference.

## Process

### 0. Git prep

The implementation worktree should still exist from reef-implement. Find it and make sure it's current.

```sh
git fetch origin --prune

# Navigate to the existing worktree
cd ../worktree-{slice-name}

# Pull latest — the inspector may have pushed trivial cleanup commits
git pull origin {slice-branch}
```

If the worktree doesn't exist (e.g. it was cleaned up prematurely), recreate it:

```sh
git worktree add ../worktree-{slice-name} origin/{slice-branch}
cd ../worktree-{slice-name}
```

### 1. Read all feedback

Read every review comment on the PR. Read the full conversation — don't just skim.

Also re-read:
- The slice's acceptance criteria (including any new acceptance criteria the inspector added)
- The parent plan's success criteria (for broader context)

### 2. Fix

Address every comment. For each piece of feedback:

- Fix it if you can
- If you disagree with the feedback, fix it anyway and add a PR comment explaining your reasoning. Let the inspector decide on the next round. Don't argue — fix.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

### 3. Run the full test suite

Not a subset. The full project test suite must be green.

### 4. Push fixes

```sh
git push origin {slice-branch}
```

### 5. Update the PR description

Rewrite the report section of the PR description using the same template as reef-implement. This is a fresh report, not an append — the current state should be clear without reading history.

Add a section at the bottom:

```markdown
## Rework notes

Addressed feedback from inspection round {N}:

- {feedback item 1}: {what was done}
- {feedback item 2}: {what was done}
```

### 6. Tag

### GitHub tracker

Change label from `to-rework` to `to-inspect`. Remove `to-rework`.

### Local tracker

Rename from `[to-rework] ...` to `[to-inspect] ...`.

## Handoff

Report completion. Next skill: `/reef-inspect` (the inspector will re-review).
