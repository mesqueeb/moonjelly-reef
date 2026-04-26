# merge-has-parent

Has-parent merge flow — delegated from [merge.md](merge.md).

## Input (from context)

Context already fetched by `merge.md`.

```sh
ISSUE_ID="{from context}" # e.g. "#42"
ISSUE_TITLE="{from context}" # e.g. "my-feature"
PARENT_ID="{from context}" # e.g. "#3"
PR_ID="{from context}" # e.g. "#7"
PR_BRANCH="{from context}" # e.g. "feat/my-feature"
MERGE_STRATEGY="{from context}" # e.g. "squash"
```

## 1. Merge

```sh
./merge.sh pr merge "$PR_BRANCH" --"$MERGE_STRATEGY" --delete-branch
```

If the merge command succeeds:

```sh
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label landed
```

If the merge command fails:

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="to-merge"
    PR_ID="$PR_ID"
    SUMMARY="Blocked: pr merge failed. Retry after resolving the underlying cause."
    ```

## 2. Check siblings

List all open issues:

```sh
./tracker.sh issue list --json labels,body
```

Filter to issues whose `base-branch` frontmatter matches `$BASE_BRANCH` (these are the siblings — all sub-issues of the same parent issue share the same base-branch, which is the parent's pr-branch).

Note: no need to read the coverage matrix — the `$BASE_BRANCH` match is sufficient to identify all siblings agnostically.

Determine whether all siblings are labeled `landed`:

```sh
ALL_SIBLINGS_LANDED="{true if every sibling issue is labeled landed, false otherwise}" # e.g. true
```

## 3. Close the issue

Close the current issue and update its labels:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label landed
./tracker.sh issue close "$ISSUE_ID"
```

## 4. Update parent issue label

RUN ONLY IF `"$ALL_SIBLINGS_LANDED" = "true"`.

```sh
./tracker.sh issue edit "$PARENT_ID" --remove-label in-progress --add-label to-seal
```

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
PR_ID="—" # sub-issue PR was merged and deleted; no PR remains open
SUMMARY="$ISSUE_TITLE merged — {N} of {total} sub-issues landed" # e.g. "my-feature merged — 3 of 4 sub-issues landed"
```

Report these variables to the caller.
