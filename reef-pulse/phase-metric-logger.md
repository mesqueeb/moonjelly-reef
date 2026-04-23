# phase-metric-logger

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this helper runs without human interaction. If one record fails validation or a write, report it and continue with the remaining records.

## Input

This helper receives the metrics records returned by the pulse.

Set the input variables:

```sh
AUTOMATED_DISPATCHES="{count of automated phases dispatched this iteration}"
METRICS_DATE="{current local timestamp for metrics rows}" # yyyy-MM-dd HH:mm
PHASE_METRIC_RECORDS='[{...}]' # JSON array of returned issue records using the handoff keys plus duration/tokens/tool uses
SUCCESS_COUNT="0"
FAIL_COUNT="0"
FAIL_IDS=""
```

## Metrics ownership

Before `to-land`, metrics live only on the issue body.

At `to-land`, move the full `### 🪼 Pulse metrics` section from the issue body to the PR body. This is a cut-and-paste flow, not copy-and-merge.

## Process

Handle each record in `PHASE_METRIC_RECORDS` independently. A failure for one record must not block the rest.

For every record, build a metrics row from the returned metadata:

- `Phase`: the dispatched phase
- `Target`: `ISSUE_ID`
- `Duration`, `Tokens`, `Tool uses`: fall back to `—` when missing
- `Outcome`: `SUMMARY`
- `Date`: `METRICS_DATE`

Keep the metrics table valid. Insert new rows immediately above `<!-- end metrics table -->`. If the issue has no metrics table yet, append one to the end of the issue body. Do not introduce blank lines above the sentinel.

### Normal record

If `NEXT_PHASE` is not `to-land`, only write to the issue body:

```sh
./tracker.sh issue view "$ISSUE_ID" --json body
```

Validate that the rewritten issue body preserves the old body except for the intended metrics insertion. If validation passes, write it back:

```sh
ISSUE_BODY="{current issue body with one metrics row inserted into the table}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

If validation or the write fails, count the record as failed and continue.

### `to-land` record

If `NEXT_PHASE` is `to-land`, read the issue and PR bodies first:

```sh
./tracker.sh issue view "$ISSUE_ID" --json body
./tracker.sh pr view "$PR_ID" --json body
```

Extract the full metrics table from the issue body, add the current seal row, append a bold `Total` row, validate that the original PR body stays unchanged, then append the final table to the end of the PR body:

```sh
PR_BODY="{current PR body with the final metrics table appended}"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY"
```

Only after the PR write succeeds, remove the full `### 🪼 Pulse metrics` section from the issue body. Validate that all non-metrics issue content is preserved:

```sh
ISSUE_BODY="{current issue body with the metrics section removed}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

If the PR write fails, do not attempt issue cleanup. If the PR write succeeds but issue cleanup fails, keep the PR write, leave the issue metrics in place, count the record as failed, and continue. Temporary duplication is acceptable. Data loss is not.

## Handoff

```sh
SUCCESS_COUNT="$SUCCESS_COUNT"
FAIL_COUNT="$FAIL_COUNT"
FAIL_IDS="$FAIL_IDS"
```

Report these three variables to the caller.
