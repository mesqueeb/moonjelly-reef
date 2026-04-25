# slice-one-issue

Single-slice fast path — delegated from [slice.md](slice.md).

## Input (from context)

Context already fetched by `slice.md`.

```sh
ISSUE_ID="{from context}"           # e.g. "#42"
HEADING="{from context}"            # e.g. "feature" — already resolved, never "feeling-lucky"
ISSUE_BODY_UPDATED="{from context}" # plan body with frontmatter already cleaned up
```

## 1. Label the next phase

```sh
if [ "$HEADING" = "deep-research" ]; then
  NEXT_PHASE="to-research"
else
  NEXT_PHASE="to-implement"
fi
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-slice --add-label "$NEXT_PHASE"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="$NEXT_PHASE"
PR_ID="—"
SUMMARY="No sub-issues needed — issue moves directly to $NEXT_PHASE"
```

Report these variables to the caller.
