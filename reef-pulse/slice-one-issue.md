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
2. **Keep the scoped `pr-branch` and rewritten `bearing` preserved.** If the plan started as `feeling-lucky`, rewrite the frontmatter `bearing` to the inferred combined value before saving the issue body. If the plan is `deep-research`, preserve `bearing: "deep-research"`.
3. **No sub-issues.** The plan IS the slice.
4. **Write acceptance criteria on the plan issue.** Append an `## Acceptance criteria` section to the plan issue body with the criteria you drafted for the single slice.
5. **Shape the acceptance criteria to the lane.** If the slice bearing is deep-research, the acceptance criteria must stay research-focused and describe what must be answered, clarified, or persisted rather than implementation tasks.
6. **Route research slices into the research phase.** For deep-research, label the issue to-research instead of to-implement.
7. **No coverage matrix.** Success criteria and acceptance criteria are 1:1 — the mapping adds no information.

Assemble the updated plan issue body:

```sh
ISSUE_BODY="{plan issue body with scoped pr-branch and rewritten bearing preserved, plus acceptance criteria appended}"
```

## 2. Label the next phase

```sh
NEXT_PHASE="{to-research for deep-research, otherwise to-implement}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label "$NEXT_PHASE"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-research"
PR_ID="—"
SUMMARY="No sub-issues needed — plan issue moves directly into research or implementation"
```

Report these three variables to the caller.
