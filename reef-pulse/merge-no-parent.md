# merge-no-parent

No-parent merge path — delegated from [merge.md](merge.md).

## Input (from context)

Context already fetched by `merge.md`. The PR targets the base branch directly — do NOT merge it here. The human merges during the `reef-land` skill.

```sh
ISSUE_ID="{from context}" # e.g. "#42"
PR_ID="{from context}" # e.g. "#7"
```

## 1. Label to-seal

Remove `to-merge`, add `to-seal`:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-seal
./tracker.sh pr edit "$PR_ID" --remove-label to-merge --add-label to-seal
```

## 2. Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-seal"
PR_ID="$PR_ID"
SUMMARY="No parent — forwarding to seal for holistic review"
```

Report these variables to the caller.
