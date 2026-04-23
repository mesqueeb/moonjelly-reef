# merge-no-parent

No-parent merge path — delegated from [merge.md](merge.md).

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. The PR targets the base branch. The human will merge it during the `reef-land` skill — do NOT merge it here.

## 1. Label to-seal

Remove `to-merge`, add `to-seal`:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-seal
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-seal
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-seal"
PR_ID="$PR_ID" # inherited from router context
SUMMARY="No parent — forwarding to seal for holistic review"
```

Report these three variables to the caller.
