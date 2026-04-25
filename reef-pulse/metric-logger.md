# metric-logger

## Input

```sh
PHASE_METRIC_RECORDS='[
  # {
  #   "ISSUE_ID": "#55",
  #   "ISSUE_PHASE": "to-implement",
  #   "NEXT_PHASE": "to-inspect",
  #   "PR_ID": "#72",
  #   "SUMMARY": "PR created",
  #   "SUBAGENT_DURATION": "42s",
  #   "SUBAGENT_TOKENS": 12340,
  #   "SUBAGENT_TOOL_USES": 18
  # }
]'
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. If one record fails validation or a write, report it and continue with the remaining records.

## 0. Read issue and PR bodies

Initialize loop counters before iterating:

```sh
SUCCESS_COUNT="0" # mutate on every full record success
FAIL_COUNT="0" # mutate on every failed record
FAIL_IDS="" # append ISSUE_ID values for failed records
```

Handle each record in `$PHASE_METRIC_RECORDS` independently. A failure for one record must not block the rest.

For each record:

- If `"$NEXT_PHASE" != "to-land"`, read the issue body only.
- If `"$NEXT_PHASE" = "to-land"`, read the issue body first, then read the PR body.

```sh
ISSUE_BODY="$(./tracker.sh issue view "$ISSUE_ID" --json body -q .body)"
if [ "$NEXT_PHASE" = "to-land" ]; then
  PR_BODY="$(./tracker.sh pr view "$PR_ID" --json body -q .body)"
fi
```

If either read fails (empty result, command error, issue or PR not found), count the record as failed and continue:

```sh
FAIL_COUNT=$((FAIL_COUNT + 1))
FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
```

Search the issue body for the full `### 🪼 Pulse metrics` section until `<!-- end metrics table -->`. Work with that section as one variable:

```sh
METRICS_TABLE="{md table found in ISSUE_BODY}" # e.g. "### 🪼 Pulse metrics\n\n| Phase | ... |\n<!-- end metrics table -->"
```

If the issue body has no metrics table yet, create one before inserting the current row:

```sh
METRICS_TABLE="### 🪼 Pulse metrics

| Phase | Target | Duration | Tokens | Tool uses | Outcome | Date |
| ----- | ------ | -------- | ------ | --------- | ------- | ---- |
<!-- end metrics table -->"
```

## 1. Build the metrics row

For every record, compute the row values:

```sh
PHASE="${ISSUE_PHASE#to-}" # e.g. ISSUE_PHASE="to-seal" -> PHASE="seal"
TARGET="$ISSUE_ID"
DURATION="${SUBAGENT_DURATION:-—}"
TOKENS="${SUBAGENT_TOKENS:-—}"
TOOL_USES="${SUBAGENT_TOOL_USES:-—}"
OUTCOME="${SUMMARY:-${NEXT_PHASE#to-}}"
METRICS_DATE="$(date '+%Y/%m/%d %H:%M')"
METRIC_ROW="| $PHASE | $TARGET | $DURATION | $TOKENS | $TOOL_USES | $OUTCOME | $METRICS_DATE |"
```

Insert the new row immediately above `<!-- end metrics table -->`. Do not leave a blank line above the sentinel:

```sh
METRICS_TABLE_UPDATED="{current METRICS_TABLE with $METRIC_ROW inserted immediately above <!-- end metrics table -->}"
```

## 2. Write metrics

### Write to issue only

RUN ONLY IF `"$NEXT_PHASE" != "to-land"`.

Write the updated metrics to the issue body only. Validate that the rewritten issue body preserves the old body except for the intended metrics insertion, then write it back:

```sh
ISSUE_BODY_UPDATED="{current issue body with METRICS_TABLE_UPDATED written back in place}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
```

If validation or the write fails, count the record as failed and continue:

```sh
FAIL_COUNT=$((FAIL_COUNT + 1))
FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
```

If the issue write succeeds, count the record as success:

```sh
SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
```

### Move metrics to PR

RUN ONLY IF `"$NEXT_PHASE" = "to-land"`.

Metrics move from the issue body to the PR body. This is a cut-and-paste flow, not copy-and-merge.

Extract the full metrics table from the issue body, add the current row (`$METRIC_ROW`), then append a bold `Total` row. Validate that the original PR body stays unchanged, then append the final metrics table to the end of the PR body:

```sh
FINAL_METRICS_TABLE="{issue metrics table with $METRIC_ROW appended and a bold Total row added last}"
PR_BODY_UPDATED="{current PR body with FINAL_METRICS_TABLE appended at the end}"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
```

Only after the PR write succeeds, remove the full `### 🪼 Pulse metrics` section from the issue body. Validate that all non-metrics issue content is preserved, then write the cleaned issue body:

```sh
ISSUE_BODY_CLEANED="{current issue body with the full metrics section removed}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_CLEANED"
```

If the PR write fails, do not attempt issue cleanup:

```sh
FAIL_COUNT=$((FAIL_COUNT + 1))
FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
```

If the PR write succeeds but the issue cleanup fails, keep the PR write, leave the issue metrics in place, count the record as failed, and continue. Temporary duplication is acceptable. Data loss is not:

```sh
FAIL_COUNT=$((FAIL_COUNT + 1))
FAIL_IDS="${FAIL_IDS:+$FAIL_IDS,}$ISSUE_ID"
```

If both writes succeed, count the record as success:

```sh
SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
```

## Handoff

```sh
SUCCESS_COUNT="$SUCCESS_COUNT"
FAIL_COUNT="$FAIL_COUNT"
FAIL_IDS="$FAIL_IDS"
```

Report these three variables to the caller.
