# rework

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the slice to find the PR reference.

## Process

### 0. Git prep

```sh
WORKTREE=$(worktree-enter.sh \
  --base-branch {base-branch} --target-branch {target-branch} \
  --phase rework --slice {slice-name} \
  --slice-branch {slice-branch} --branch-op checkout)
cd "$WORKTREE"
```

### 1. Read all feedback

Read every review comment on the PR. Read the full conversation — don't just skim.

Also re-read:
- The slice's acceptance criteria (including any new acceptance criteria the inspector added)
- The plan's success criteria (for broader context)

### 2. Fix

Address every comment. For each piece of feedback:

- Fix it if you can
- If you disagree with the feedback, fix it anyway and add a PR comment explaining your reasoning. Let the inspector decide on the next round. Don't argue — fix.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

### 3. Run the full test suite

Not a subset. The full project test suite must be green.

### 4. Push fixes

```sh
commit.sh --slice-branch {slice-branch} -m "rework: address inspection feedback"
```

### 5. Update the PR description

Rewrite the report section of the PR description using the same template as the implement phase. This is a fresh report, not an append — the current state should be clear without reading history.

Add a section at the bottom:

```markdown
## Rework notes

Addressed feedback from inspection round {N}:

- {feedback item 1}: {what was done}
- {feedback item 2}: {what was done}
```

### 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 7. Clean up

```sh
worktree-exit.sh --path "$WORKTREE"
```

### 8. Tag

### GitHub tracker

Change the slice issue label from `to-rework` to `to-inspect`.

### Local tracker

Rename from `[to-rework] ...` to `[to-inspect] ...`.

## Handoff

Report completion. The next phase is inspection (re-review).
