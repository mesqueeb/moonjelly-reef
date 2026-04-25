# merge-has-parent

Has-parent merge flow — delegated from [merge.md](merge.md).

## Input (from context)

Context already fetched by `merge.md`.

```sh
ISSUE_ID="{from context}" # e.g. "#42"
PARENT_ID="{from context}" # e.g. "#3"
PR_ID="{from context}" # e.g. "#7"
BASE_BRANCH="{from context}" # e.g. "feat/my-feature"
MERGE_STRATEGY="{from context}" # e.g. "squash"
```

## 1. Merge

```sh
./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label landed
```

## 2. Check siblings and plan completion

List all open issues:

```sh
./tracker.sh issue list --json number,labels,body
```

Filter to issues whose `base-branch` frontmatter matches `$BASE_BRANCH` (these are the siblings — all sub-issues of the same parent issue share the same base-branch, which is the parent's pr-branch).

Note: no need to read the coverage matrix — the `$BASE_BRANCH` match is sufficient to identify all siblings agnostically.

Determine whether all siblings are labeled `landed`:

```sh
ALL_SIBLINGS_LANDED="{true if every sibling issue is labeled landed, false otherwise}"
```

## 3. Close the issue

Close the current issue and update its labels:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label landed
./tracker.sh issue close "$ISSUE_ID"
```

## 4. Update plan label

RUN ONLY IF `"$ALL_SIBLINGS_LANDED" = "true"`.

```sh
./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-seal
```

## 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## Handoff

```sh
if [ "$ALL_SIBLINGS_LANDED" = "true" ]; then
  NEXT_PHASE="to-seal"
else
  NEXT_PHASE="in-progress"
fi
```

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="$NEXT_PHASE"
PR_ID="-" # sub-issue merge does not open the parent issue PR
SUMMARY="{ISSUE_TITLE} merged — {N} of {total} issues complete" # e.g. "my-feature merged — 3 of 4 issues complete"
```

Report these variables to the caller.
