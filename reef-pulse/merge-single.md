# merge-single

Single-slice merge path — delegated from [merge.md](merge.md).

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

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
./tracker.sh issue edit "$PLAN_ID" --remove-label to-merge --add-label to-land
```

## Handoff

Return the structured handoff so reef-pulse can log metrics and route the next phase:

```sh
nextPhase="to-land"
planPr="{from slice/plan body PR: #N, or — if no plan PR exists yet}"
summary="single-slice — PR stays open for human review"
```
