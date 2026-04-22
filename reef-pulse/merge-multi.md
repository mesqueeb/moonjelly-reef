# merge-multi

Multi-slice merge flow — delegated from [merge.md](merge.md).

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. This is a multi-slice plan where the target branch forks from the base branch.

Set the variables needed for this path:

```sh
PARENT_ID="{from issue body parent-plan field}"
PR_NUMBER="{from issue body}"
```

## 1. Merge

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
./tracker.sh pr merge "$PR_NUMBER" --"$MERGE_STRATEGY" --delete-branch
./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label landed
```

## 2. Check siblings and plan completion

Fetch the parent plan body — it contains the coverage matrix with all sibling issue numbers:

```sh
./tracker.sh issue view "$PARENT_ID" --json body,title,labels
```

Extract the sibling issue IDs from the coverage matrix. For each sibling (excluding the current issue):

```sh
SIBLING_ID="{from coverage matrix}"
```

Fetch its labels:

```sh
./tracker.sh issue view "$SIBLING_ID" --json labels
```

For any sibling tagged `to-await-waves`, check their `blocked-by` list. If this merged issue was the last blocker, leave them as `to-await-waves` — the next pulse will dispatch the await-waves phase to re-review their plan before promoting.

Check: are ALL issues for the plan now tagged `landed`? If all are landed, change the plan label from `in-progress` to `to-ratify` (step 4). If not all landed, do nothing — more work is still in progress.

## 3. Close the issue

Close the current issue and update its labels:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label landed
./tracker.sh issue close "$ISSUE_ID"
```

## 4. Update plan label — if all issues labelled 'landed'

```sh
./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-ratify
```

## 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## Handoff

```sh
nextPhase="to-ratify" # or "in-progress" if not all issues tagged 'landed'
planPr="—" # multi-slice: no plan PR yet
summary="{ISSUE_TITLE} merged — {N} of {total} issues complete"
```

Report these three variables to the caller.
