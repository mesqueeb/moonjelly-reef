# merge-multi

Multi-slice merge flow — delegated from [merge.md](merge.md).

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. This is a multi-slice plan where the target branch forks from the base branch.

Set the variables needed for this path:

```sh
PLAN_ID = {from slice/plan body}
PR_NUMBER = {from slice body}
SLICE_ID = $ISSUE_ID
```

## 1. Merge

```sh
MERGE_STRATEGY = {from .agents/moonjelly-reef/config.md merge-strategy field}
gh pr merge $PR_NUMBER --$MERGE_STRATEGY --delete-branch
```

## 2. Check siblings and plan completion

Fetch the plan body — it contains the coverage matrix with all slice issue numbers:

```sh
tracker.sh issue view $PLAN_ID --json body,title,labels
```

Extract the sibling slice IDs from the coverage matrix. For each sibling (excluding the current slice):

```sh
SIBLING_ID = {from coverage matrix}
```

Fetch its labels:

```sh
tracker.sh issue view $SIBLING_ID --json labels
```

For any sibling tagged `to-await-waves`, check their `blocked-by` list. If this merged slice was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

Check: are ALL slices for the plan now tagged `done`? If all slices are done, change the plan label from `in-progress` to `to-ratify` (step 4). If not all done, do nothing — more slices are still in progress.

## 3. Close the slice

Close the slice issue. Add label `done`. Remove `to-merge`:

```sh
tracker.sh issue close $SLICE_ID
```

## 4. Update plan tag — if all slices done

```sh
tracker.sh issue edit $PLAN_ID --remove-label in-progress --add-label to-ratify
```

## 5. Append metrics to plan PR

Compute the duration from the start of this phase to now. Find the plan PR (the PR targeting the base branch from the plan issue) via `gh pr list --base $BASE_BRANCH --head $TARGET_BRANCH`.

Read the plan PR body, then append a metrics row:

```sh
PLAN_PR_NUMBER = {plan PR number, found via gh pr list}
PLAN_PR_BODY = {current plan PR body with metrics row appended to the metrics table}
```

```sh
gh pr edit $PLAN_PR_NUMBER --body "$PLAN_PR_BODY"
```

Metrics row format (append to the existing metrics table, or create one if none exists):

```markdown
| merge | #$SLICE_ID $SLICE_NAME | $DURATION | $TOKENS | $TOOL_USES | merged, {N} of {total} done |
```

Where `$DURATION` is human-readable (e.g. `42s`, `1m 12s`), `$TOKENS` is space-separated thousands from your session metadata (or `—` if unavailable), and `$TOOL_USES` is from your session metadata (or `—` if unavailable).

## 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## Handoff

Report: "Slice {name} merged. {N} of {total} slices complete." If promoted to `to-ratify`: "All slices done — plan is ready for ratification." Include duration, token usage, and tool uses from this session.
