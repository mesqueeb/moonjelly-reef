# merge-single

Single-slice merge path — delegated from [merge.md](merge.md).

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

Set the variables needed for this path:

```sh
PLAN_ID="{from slice/plan body}"
```

## 1. Tag plan to-land

Remove `to-merge`, add `to-land`:

```sh
tracker.sh issue edit "$PLAN_ID" --remove-label to-merge --add-label to-land
```

## Handoff

Return the structured handoff:

```sh
nextPhase="to-land"
planPr="$PR_NUMBER"
summary="single-slice — PR stays open for human review"
```
