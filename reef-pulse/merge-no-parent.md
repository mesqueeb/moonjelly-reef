# merge-no-parent

No-parent merge path — delegated from [merge.md](merge.md).

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. The PR targets the base branch. The human will merge it during the `reef-land` skill — do NOT merge it here.

## 1. Label to-seal

Remove `to-merge`, add `to-seal`:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-seal
./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label to-seal
```

## Handoff

```sh
nextPhase="to-seal"
planPr="$PR_NUMBER" # inherited from router context
summary="No parent — forwarding to seal for holistic review"
```

Report these three variables to the caller.
