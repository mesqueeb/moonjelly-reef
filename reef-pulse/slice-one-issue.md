# slice-one-issue

Single-slice fast path — delegated from [slice.md](slice.md).

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context and drafted exactly 1 slice. No sub-issues are needed — the plan becomes the slice.

## 1. Update the plan issue body

Take the fast path — skip sub-issues, coverage matrix, and seal. The plan becomes the slice:

1. **Keep the scoped `pr-branch`.** Preserve the `pr-branch` already written by reef-scope in the plan frontmatter.
2. **Rewrite `bearing` if the plan started as `feeling-lucky`.** Infer the real lane (feature, refactor, bug, or deep-research), set `bearing` to that value, and add `feeling-lucky: true` as a separate frontmatter flag:

```sh
# example: plan started as feeling-lucky → inferred as feature
bearing: feature
feeling-lucky: true
```

If the bearing is already anything other than `feeling-lucky`, preserve it unchanged.

3. **No sub-issues.** The plan IS the slice.
4. **Rename `## Success criteria` to `## Success & Acceptance criteria`.** Append the acceptance criteria you drafted for the single slice to that section. Shape them to the lane: for deep-research, criteria must describe what must be answered, clarified, or persisted rather than implementation tasks.
5. **Route research slices into the research phase.** For deep-research, label the issue to-research instead of to-implement.
6. **No coverage matrix.** Success criteria and acceptance criteria are 1:1 — the mapping adds no information.

Assemble the updated plan issue body:

```sh
ISSUE_BODY="{plan issue body with scoped pr-branch, rewritten bearing, and updated Success & Acceptance criteria}"
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

Report these three variables to the caller.
