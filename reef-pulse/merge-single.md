# merge-single

Single-slice merge path — delegated from [merge.md](merge.md).

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context, set variables, and completed the pre-merge check. The PR targets the base branch. The human will merge it during `/reef-land` — do NOT merge it here.

Set the variables needed for this path:

```sh
PLAN_ID = {from slice/plan body}
```

## 1. Append metrics to plan PR

Compute the duration from the start of this phase to now. For single-slice, the slice PR is the plan PR — use `$PR_NUMBER`.

Read the plan PR body, then append a metrics row:

```sh
PLAN_PR_BODY = {current plan PR body with metrics row appended to the metrics table}
```

```sh
gh pr edit $PR_NUMBER --body "$PLAN_PR_BODY"
```

Metrics row format (append to the existing metrics table, or create one if none exists):

```markdown
| merge | #$SLICE_ID $SLICE_NAME | $DURATION | $TOKENS | $TOOL_USES | single-slice, tagged to-land |
```

Where `$DURATION` is human-readable (e.g. `42s`, `1m 12s`), `$TOKENS` is space-separated thousands from your session metadata (or `—` if unavailable), and `$TOOL_USES` is from your session metadata (or `—` if unavailable).

## 2. Tag plan to-land

Remove `to-merge`, add `to-land`:

```sh
tracker.sh issue edit $PLAN_ID --remove-label to-merge --add-label to-land
```

## Handoff

Report: "Single slice verified. PR stays open for human review. Run `/reef-land #{number}`." Include duration, token usage, and tool uses from this session.
