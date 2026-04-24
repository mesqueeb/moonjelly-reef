# slice-one-issue

Single-slice fast path — delegated from [slice.md](slice.md).

## Input (from context)

Context already fetched and resolved by `slice.md`.

```sh
ISSUE_ID="{from context}"          # e.g. "#42"
BEARING="{from context}"           # e.g. "feature" — already resolved, never "feeling-lucky"
FEELING_LUCKY="{from context}"     # e.g. "false"
ISSUE_BODY_UPDATED="{from context}" # plan body with frontmatter already cleaned up
```

## 1. Update the plan issue body

No sub-issues are needed — the plan becomes the slice. Skip sub-issues, coverage matrix, and seal.

Starting from `$ISSUE_BODY_UPDATED`:

1. **No sub-issues.** The plan IS the slice.
2. **Append acceptance criteria.** Add the acceptance criteria you drafted for the single slice to the issue body. Shape them to the lane: for deep-research, criteria must describe what must be answered, clarified, or persisted rather than implementation tasks.
3. **Route research slices into the research phase.** For deep-research, label the issue to-research instead of to-implement.
4. **No coverage matrix.** Acceptance criteria are sufficient — the mapping adds no information.

Assemble the updated plan issue body:

```sh
ISSUE_BODY="{plan issue body with scoped pr-branch, rewritten bearing, and appended Acceptance criteria}"
```

## 2. Label the next phase

```sh
if [ "$BEARING" = "deep-research" ]; then
  NEXT_PHASE="to-research"
else
  NEXT_PHASE="to-implement"
fi
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label "$NEXT_PHASE"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="$NEXT_PHASE"
PR_ID="—"
SUMMARY="No sub-issues needed — plan issue moves directly into research or implementation"
```

Report these variables to the caller.
