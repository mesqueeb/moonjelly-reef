# slice-single

Single-slice fast path — delegated from [slice.md](slice.md).

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context and drafted exactly 1 slice. Set post-fetch variables:

```sh
PLAN_ID="$ISSUE_ID"
```

## 1. Update the plan body

Take the fast path — skip the target branch, sub-issues, coverage matrix, and ratify. The plan becomes the slice:

1. **Target branch = base branch.** Do not create a new branch. Add `target branch` to the plan frontmatter, set to the same value as `base branch`.
2. **No sub-issues.** The plan IS the slice.
3. **Write acceptance criteria on the plan.** Append an `## Acceptance criteria` section to the plan body with the criteria you drafted for the single slice.
4. **No coverage matrix.** Success criteria and acceptance criteria are 1:1 — the mapping adds no information.

Assemble the updated plan body:

```sh
PLAN_BODY="{plan body with target branch added to frontmatter and acceptance criteria appended}"
```

## 2. Tag to-implement

```sh
./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-slice --add-label to-implement
```

## Handoff

Report: "Single slice — fast path. Plan is the slice. Tagged `to-implement`, targeting $BASE_BRANCH directly. Run `/reef-pulse` to kick it off."
