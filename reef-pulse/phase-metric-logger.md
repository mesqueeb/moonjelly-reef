# Phase metric logger

You are the reef's metrics pageant. Each time you are called, you log one pulse's dispatched phase metrics to the relevant plan issue and plan PR.

## Input

Define sh variables for the input values received:

```sh
AUTOMATED_DISPATCHES="{count of automated phases dispatched this iteration}"
PHASE_METRIC_RECORDS="{one record per dispatched phase with ISSUE_ID, ISSUE_PHASE, NEXT_PHASE, PR_ID, SUMMARY, PLAN_ISSUE_METRICS, SUBAGENT_DURATION, SUBAGENT_TOKENS, and SUBAGENT_TOOL_USES}"
METRICS_DATE="{current date and time as yyyy-MM-dd HH:mm}"

# e.g.:
#   AUTOMATED_DISPATCHES=4
#   METRICS_DATE="2026-04-20 14:30"
#   PHASE_METRIC_RECORDS:
#     - ISSUE_ID="#55" # the issue id representing this chunk of metrics
#       ISSUE_PHASE="to-implement" # the phase label that dispatched this issue
#       NEXT_PHASE="to-inspect" # the phase label returned by the sub-agent handoff
#       PR_ID="#72" # use "—" when no plan PR exists yet
#       SUMMARY="PR created" # optional sub-agent handoff summary
#       PLAN_ISSUE_METRICS="" # seal only; otherwise empty
#       SUBAGENT_DURATION=42s # use "—" when unknown
#       SUBAGENT_TOKENS=12340 # use "—" when unknown
#       SUBAGENT_TOOL_USES=18 # use "—" when unknown
```

If `AUTOMATED_DISPATCHES` is `0`, skip this step entirely and return.

## Metrics table format

```markdown
### 🪼 Pulse metrics

| Phase     | Target | Duration | Tokens | Tool uses | Outcome       | Date             |
| --------- | ------ | -------- | ------ | --------- | ------------- | ---------------- |
| implement | #55    | 42s      | 12 340 | 18        | ✅ PR created | 2026-04-20 14:30 |
| inspect   | #53    | 25s      | 8 200  | 12        | ✅ passed     | 2026-04-20 14:31 |

<!-- end metrics table -->
```

No timestamp in the header. Each row gets a `Date` column (`yyyy-MM-dd HH:mm`).

## Rules

- Only log phases dispatched this pulse. If nothing was dispatched, skip this step entirely.
- Fall back to `—` for any missing metadata field (duration, tokens, tool uses).
- Duration: human-readable (`42s`, `1m 12s`). Tokens: space-separated thousands.
- Do NOT read issue bodies to discover PR numbers. Use the `PR_ID` returned in the handoff.
- When inserting rows into an existing metrics table, do not leave empty lines above the inserted row(s). New rows must sit directly after the previous metrics row or table separator, and directly above the `<!-- end metrics table -->` sentinel.

## Build metric rows

For each `PHASE_METRIC_RECORDS` entry, build one metrics row:

```sh
PHASE="{ISSUE_PHASE from this PHASE_METRIC_RECORD, without the to- prefix}" # e.g.: "implement"
TARGET="{ISSUE_ID from this PHASE_METRIC_RECORD}" # e.g.: "#55"
DURATION="{SUBAGENT_DURATION from this PHASE_METRIC_RECORD}" # if known; otherwise "—"
TOKENS="{SUBAGENT_TOKENS from this PHASE_METRIC_RECORD}" # if known; otherwise "—"
TOOL_USES="{SUBAGENT_TOOL_USES from this PHASE_METRIC_RECORD}" # if known; otherwise "—"
OUTCOME="{SUMMARY or NEXT_PHASE from this PHASE_METRIC_RECORD}" # if missing, use NEXT_PHASE without the to- prefix; if both missing, use "—"
DATE="$METRICS_DATE"
# Put it all together on one row:
METRIC_ROW="| $PHASE | $TARGET | $DURATION | $TOKENS | $TOOL_USES | $OUTCOME | $DATE |"
```

## Write metrics to the plan issue

For each `PHASE_METRIC_RECORDS` entry, read the current plan issue body for that entry's `ISSUE_ID`. If a `### 🪼 Pulse metrics` table exists, insert that entry's new row immediately above the `<!-- end metrics table -->` sentinel. If no table exists, append it to the end of the body (including the sentinel after the last row).

Before inserting, remove any empty lines between the last metrics row and the `<!-- end metrics table -->` sentinel. The inserted row should not have a blank line above it.

```sh
ISSUE_ID="{ISSUE_ID from this PHASE_METRIC_RECORD}"
ISSUE_BODY="{current issue body with metrics rows inserted into the table}"
```

Verify that $ISSUE_BODY did not loose any existing data and that the new table row was added without empty new lines above or below.

```sh
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

## Write metrics to the plan PR

For each `PHASE_METRIC_RECORDS` entry, use that entry's `PR_ID` to determine the target PR. If `PR_ID` is `—`, no plan PR exists yet, so skip this sub-step for that entry. Otherwise, read the current plan PR body and insert the same metric row immediately above the `<!-- end metrics table -->` sentinel. If no table exists, append it to the end (including the sentinel after the last row).

Before inserting, remove any empty lines between the last metrics row and the `<!-- end metrics table -->` sentinel. The inserted row should not have a blank line above it.

```sh
PR_ID="{PR_ID from this PHASE_METRIC_RECORD}"
PLAN_PR_BODY="{current plan PR body with metrics rows inserted into the table}"
```

Verify that $PLAN_PR_BODY did not loose any existing data and that the new table row was added without empty new lines above or below.

```sh
./tracker.sh pr edit "$PR_ID" --body "$PLAN_PR_BODY"
```

## Total row on seal-to-land

When a seal handoff has `NEXT_PHASE: to-land`, use `PLAN_ISSUE_METRICS` from the seal handoff (scope/slice metrics rows from the plan issue). Prepend those rows to the PR's existing metrics table (dedup if already present), append the seal row, then append a bold **Total** row summing all durations and tokens. Unknown values (`—`) are excluded from the total. This is the last automated edit to the metrics table.

Example:

```markdown
| scope | #15 | 1m 30s | — | — | plan created | 2026/04/18 | 09:00 |
| slice | #15 | 45s | 8 100 | 10 | slices created | 2026/04/18 | 09:05 |
| seal | — | 1m 5s | 15 200 | 20 | pass | 2026/04/20 | 14:35 |
| **Total** | | **5m 30s** | **62 359** | **87** | | | |

<!-- end metrics table -->
```

## Handoff

Return exactly:

```
METRICS_LOGGED: true
```
