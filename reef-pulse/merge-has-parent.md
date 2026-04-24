# merge-has-parent

Has-parent merge flow — delegated from [merge.md](merge.md).

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. This issue has a `parent-issue` in its frontmatter — it is a sub-issue of a multi-slice plan.

Set the variables needed for this path:

```sh
PARENT_ID="{from issue frontmatter parent-issue field}"
PR_ID="{from issue frontmatter pr-id field}"
```

## 1. Merge

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}"
./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label landed
```

## 2. Check siblings and plan completion

Read `base-branch` from the current issue's frontmatter. List all open issues:

```sh
BASE_BRANCH="{from issue frontmatter base-branch field}"
./tracker.sh issue list --json number,labels,body
```

Filter to issues whose `base-branch` frontmatter matches `$BASE_BRANCH` (these are the siblings — all sub-issues of the same parent issue share the same base-branch, which is the parent's pr-branch).

Check: are ALL such issues labeled `landed`? If all siblings are landed, change the parent issue label from `in-progress` to `to-seal` (step 4). If any are still open, do nothing — more work is in progress.

Note: no need to read the coverage matrix — the `base-branch` match is sufficient to identify all siblings agnostically.

## 3. Close the issue

Close the current issue and update its labels:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label landed
./tracker.sh issue close "$ISSUE_ID"
```

## 4. Update plan label — if all siblings landed

```sh
./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-seal
```

## 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-seal" # or "in-progress" if not all issues labeled 'landed'
PR_ID="—" # sub-issue merge does not open the parent issue PR
SUMMARY="{ISSUE_TITLE} merged — {N} of {total} issues complete"
```

Report these three variables to the caller.
