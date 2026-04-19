# rework

> **Tracker note**: Read `.agents/moonjelly-reef/config.md` for the tracker type. Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the slice to find the PR reference.

Set the pre-fetch variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
TRACKER_PATH = {from config.md} # set only for local tracker
TRACKER_BRANCH = {from config.md} # set only for local-tracker-committed
```

## 0. Fetch context

### GitHub tracker

```sh
gh issue view $ISSUE_ID --json body,title,labels
```

### Local tracker

Read the file at:

```sh
$TRACKER_PATH/*/slices/[to-rework] $ISSUE_ID*.md
```

Set the post-fetch variables (after reading the slice body):

```sh
SLICE_NAME = {from slice body}
SLICE_NUMBER = $ISSUE_ID
SLICE_BRANCH = {from slice body}
PR_NUMBER = {from slice body}
PLAN_ID = {from slice/plan body}
PLAN_TITLE = {from slice/plan body}
BASE_BRANCH = {from slice/plan body}
TARGET_BRANCH = {from slice/plan body}
WORKTREE_PATH = ../worktree-$SLICE_NAME-rework
```

## Process

### 1. Git prep

```sh
worktree-enter.sh --fork-from $SLICE_BRANCH --path $WORKTREE_PATH
```

### 2. Read all feedback

Read every review comment on the PR. Read the full conversation — don't just skim.

Also re-read:
- The slice's acceptance criteria (including any new acceptance criteria the inspector added)
- The plan's success criteria (for broader context)

### 3. Fix

Address every comment. For each piece of feedback:

- Fix it if you can
- If you disagree with the feedback, fix it anyway and add a PR comment explaining your reasoning. Let the inspector decide on the next round. Don't argue — fix.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

### 4. Run the full test suite

Not a subset. The full project test suite must be green.

### 5. Push fixes

```sh
commit.sh --branch $SLICE_BRANCH -m "rework: address inspection feedback"
```

### 6. Update the PR description

Rewrite the report section of the PR description using the same template as the implement phase. This is a fresh report, not an append — the current state should be clear without reading history.

```sh
gh pr edit $PR_NUMBER --body "$REPORT"
```

Add a section at the bottom:

```markdown
## Rework notes

Addressed feedback from inspection round {N}:

- {feedback item 1}: {what was done}
- {feedback item 2}: {what was done}
```

### 7. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 8. Tag

### GitHub tracker

```sh
gh issue edit $SLICE_NUMBER --remove-label to-rework --add-label to-inspect
```

### Local tracker (gitignored)

Rename from `[to-rework] ...` to `[to-inspect] ...`.

```sh
mv "$TRACKER_PATH/$PLAN_ID $PLAN_TITLE/slices/[to-rework] $SLICE_NAME.md" "$TRACKER_PATH/$PLAN_ID $PLAN_TITLE/slices/[to-inspect] $SLICE_NAME.md"
```

### Local tracker (committed)

Rename from `[to-rework] ...` to `[to-inspect] ...`.

```sh
worktree-enter.sh --fork-from $TRACKER_BRANCH --path $WORKTREE_PATH-tracker
mv "$TRACKER_PATH/$PLAN_ID $PLAN_TITLE/slices/[to-rework] $SLICE_NAME.md" "$TRACKER_PATH/$PLAN_ID $PLAN_TITLE/slices/[to-inspect] $SLICE_NAME.md"
commit.sh --branch $TRACKER_BRANCH -m "rework: update tracker for $SLICE_NAME"
worktree-exit.sh --path $WORKTREE_PATH-tracker
```

### 9. Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

Report completion. The next phase is inspection (re-review).
