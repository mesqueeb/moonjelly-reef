# Pulse loop

This file assumes the session was already initialized by [`./SKILL.md`](./SKILL.md). Before following this file, the main session must already have these shell variables set:

```sh
SKILL_DIR="{base directory for this skill}"
LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
PULSE_NR="{current pulse number}"
AGENT_COUNT_SESSION="{session-wide dispatch count so far}"
SESSION_START_TS="{unix timestamp captured at session start}"
```

Each time [`SKILL.md`](SKILL.md) invokes this file, execute exactly one full pulse-loop iteration. Do not collapse a pulse-loop iteration into a quick rescan or tracker-only follow-up. Each pulse-loop iteration must emit the same pulse transcript structure: pulse header, dispatch lines when applicable, return results when applicable, then return control to [`SKILL.md`](SKILL.md).

```sh
AGENT_COUNT_PULSE=0 # Reset per pulse-loop; Increment per sub-agent used
```

## 1. Print pulse header

RUN DURING EACH PULSE-LOOP ITERATION.

At the start of each pulse-loop iteration (including recursive calls), print the pulse header with the current timestamp:

```
── PULSE $PULSE_NR ───────────────────────────────── {HH:MM:SS} ──
```

## 2. Scan

RUN DURING EACH PULSE-LOOP ITERATION.

Read the config to determine the tracker type, then scan for all labeled issues.

```sh
# Scan all reef-labeled issues in a single query
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-slice OR label:to-await-waves OR label:to-implement OR label:to-inspect OR label:to-rework OR label:to-merge OR label:to-seal'
```

## 3. Dispatch automated (🌊) work — Flow wave

RUN DURING EACH PULSE-LOOP ITERATION.

**Do NOT ask the user for confirmation. Dispatch immediately.** The labels are the authorization — if an item is labelled for automated work, dispatch it without hesitation.

**CRITICAL: Do NOT use `isolation: "worktree"` when spawning sub-agents.** Each phase manages its own worktree via `worktree-enter.sh` (fetches from origin, forks from the correct remote branch). Platform isolation bypasses this and causes merge conflicts.

**Flow wave**: dispatch all non-`to-await-waves` items in parallel via sub-agents. When agent teams are supported in the environment, they can be used to parallelise items linked to the same plan. Wait for all flow agents to complete before proceeding to the ebb wave.

For each item, spawn a sub-agent with: `"Read and follow $SKILL_DIR/{file}. Target: #{number}."`

| Label          | File                      |
| -------------- | ------------------------- |
| `to-slice`     | `$SKILL_DIR/slice.md`     |
| `to-implement` | `$SKILL_DIR/implement.md` |
| `to-inspect`   | `$SKILL_DIR/inspect.md`   |
| `to-rework`    | `$SKILL_DIR/rework.md`    |
| `to-merge`     | `$SKILL_DIR/merge.md`     |
| `to-seal`      | `$SKILL_DIR/seal.md`      |

## 3a. Ebb wave — gated dispatch of to-await-waves items

RUN DURING EACH PULSE-LOOP ITERATION after the flow wave completes.

After all flow agents complete, rescan `to-await-waves` items. For each item, parse the `[await: ...]` suffix from its title to find blocker IDs, then check each blocker's label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. #42
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

- If **all** blockers have the `landed` label: dispatch the item via sub-agent (`$SKILL_DIR/await-waves.md`).
- If **any** blocker is not `landed`: skip — do not dispatch. It stays `to-await-waves` and will be re-evaluated next pulse.

If the `[await: ...]` suffix is missing or malformed, dispatch anyway — `await-waves` itself catches problems before promoting.

## 3b. Print dispatched agents

RUN DURING THIS PULSE-LOOP ITERATION if `$AGENT_COUNT_PULSE > 0`.

Immediately after dispatching, print each dispatched agent with its phase emoji. Use the phase emoji from the README lore for each phase:

| Label            | Phase emoji |
| ---------------- | ----------- |
| `to-slice`       | `𐃆🐋`       |
| `to-implement`   | `  🐙`      |
| `to-inspect`     | `  🧿`      |
| `to-rework`      | `  🦀`      |
| `to-merge`       | `  🐢`      |
| `to-seal`        | `  🦭`      |
| `to-await-waves` | `  🪸`      |

The narwhal (slice phase) always uses both characters `𐃆🐋`, not just the emoji.

For each dispatched issue, capture the display values used for both the dispatch line and the later return-result line:

```sh
ISSUE_ID="{from dispatched issue}"
ISSUE_TITLE="{from dispatched issue title}"
ISSUE_PHASE="{label that dispatched this issue, without the to- prefix}" # e.g.: implement
ISSUE_PHASE_EMOJI="{phase emoji for ISSUE_PHASE}" # e.g.: "  🐙"
DISPATCH_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID  \"$ISSUE_TITLE\""
```

E.g.:

```
𐃆🐋  #34  "auth token rotation"
  🐙  #55  "user profile endpoint"
  🧿  #53  "db migration safety"
```

## 3c. Increment pulse variables

RUN DURING EACH PULSE-LOOP ITERATION after the flow and ebb wave dispatch decisions are complete.

```sh
AGENT_COUNT_SESSION=$((AGENT_COUNT_SESSION + AGENT_COUNT_PULSE))
if [ "$AGENT_COUNT_PULSE" -eq 0 ]; then
  IS_SESSION_COMPLETE=true
else
  IS_SESSION_COMPLETE=false
  PULSE_NR=$((PULSE_NR + 1))
fi
```

## 4. Print all return results

RUN DURING THIS PULSE-LOOP ITERATION if `$AGENT_COUNT_PULSE > 0`.

After all dispatched agents complete, collect one execution record per returned sub-agent. Each record is keyed by the returned `ISSUE_ID` and is used for the return-result output and the metrics pageant.

```sh
ISSUE_ID="{from handoff ISSUE_ID}"
NEXT_PHASE="{from handoff NEXT_PHASE}"
PR_ID="{from handoff PR_ID}" # if returned; otherwise "—"
SUMMARY="{from handoff SUMMARY}" # if returned
SUBAGENT_DURATION="{duration of sub-agent total execution}" # if known; otherwise "—"
SUBAGENT_TOKENS="{total token count used by the sub-agent}" # if known; otherwise "—"
SUBAGENT_TOOL_USES="{tool use count for the sub-agent}" # if known; otherwise "—"
# And log one result row per sub-agent
RESULT_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID   $SUBAGENT_DURATION   $SUBAGENT_TOKENS   $ISSUE_PHASE › $NEXT_PHASE"
```

E.g.:

```
𐃆🐋  #34   3m12s   18k   slice › implement
  🐙  #55   4m45s   24k   implement › inspect
  🦀  #53   1m08s    9k   inspect › rework
```

## 5. Log all sub-agent metrics

RUN DURING THIS PULSE-LOOP ITERATION if `$AGENT_COUNT_PULSE > 0`.

Prep one JSON array for the metric-logger sub-agent:

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

Spawn the metric-logger sub-agent:

```sh
Read and follow $SKILL_DIR/metric-logger.md.

PHASE_METRIC_RECORDS="$PHASE_METRIC_RECORDS"
```

The metric-logger sub-agent returns aggregate write results for this pulse:

```sh
SUCCESS_COUNT="{from metrics logger handoff}"
FAIL_COUNT="{from metrics logger handoff}"
FAIL_IDS="{from metrics logger handoff}"
METRICS_RESULT_ROW="🪼  metrics ok=$SUCCESS_COUNT fail=$FAIL_COUNT ids=${FAIL_IDS:-—}"
```

Log the METRICS_RESULT_ROW.
