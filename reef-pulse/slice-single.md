# slice-single

Single-slice fast path — delegated from [slice.md](slice.md).

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context and drafted exactly 1 slice. Set post-fetch variables:

```sh
PLAN_ID = $ISSUE_ID
```

## 1. Update the plan body

Take the fast path — skip the target branch, sub-issues, coverage matrix, and ratify. The plan becomes the slice:

1. **Target branch = base branch.** Do not create a new branch. Add `target branch` to the plan frontmatter, set to the same value as `base branch`.
2. **No sub-issues.** The plan IS the slice.
3. **Write acceptance criteria on the plan.** Append an `## Acceptance criteria` section to the plan body with the criteria you drafted for the single slice.
4. **No coverage matrix.** Success criteria and acceptance criteria are 1:1 — the mapping adds no information.

Assemble the updated plan body:

```sh
PLAN_BODY = {plan body with target branch added to frontmatter and acceptance criteria appended}
```

## 2. Tag to-implement

```sh
tracker.sh issue edit $PLAN_ID --body "$PLAN_BODY" --remove-label to-slice --add-label to-implement
```

## 3. Append metrics to plan issue

Compute the duration from the start of this phase to now. Read the current plan issue body, then append a metrics row to the metrics section:

```sh
PLAN_ISSUE_BODY = {current plan issue body with metrics row appended to the metrics table}
```

```sh
tracker.sh issue edit $PLAN_ID --body "$PLAN_ISSUE_BODY"
```

Metrics row format (append to the existing metrics table, or create one if none exists):

```markdown
| slice | #$PLAN_ID | $DURATION | $TOKENS | $TOOL_USES | single-slice, tagged to-implement |
```

Where `$DURATION` is human-readable (e.g. `42s`, `1m 12s`), `$TOKENS` is space-separated thousands from your session metadata (or `—` if unavailable), and `$TOOL_USES` is from your session metadata (or `—` if unavailable).

## Handoff

Report: "Single slice — fast path. Plan is the slice. Tagged `to-implement`, targeting $BASE_BRANCH directly. Run `/reef-pulse` to kick it off." Include duration, token usage, and tool uses from this session.
