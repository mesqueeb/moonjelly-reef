# Pulse loop

## Input (from context)

Context already set by [`SKILL.md`](SKILL.md) before invoking this file:

```sh
SKILL_DIR="{from context}" # e.g. "~/.claude/skills/reef-pulse"
ONLY_ISSUE_ID="{from context}" # e.g. "-"
LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
PULSE_NR="{from context}" # e.g. 2
AGENT_COUNT_SESSION="{from context}" # e.g. 4
SESSION_START_TS="{from context}" # e.g. 1735000000
```

## Rules

**Shell blocks are literal commands** — execute them as written.

**AFK skill**: this file runs without human interaction. When in doubt: check the labels, make your best judgment, move on. Never block waiting for human input.

Each time [`SKILL.md`](SKILL.md) invokes this file, execute exactly one full pulse-loop iteration. Do not collapse a pulse-loop iteration into a quick rescan or tracker-only follow-up. Each pulse-loop iteration must emit the same pulse transcript structure: pulse header, dispatch lines when applicable, return results when applicable, then return control to [`SKILL.md`](SKILL.md).

## 1. Print pulse header

Reset the per-pulse dispatch counter, then print the pulse header:

```sh
AGENT_COUNT_PULSE=0 # Reset per pulse-loop; increment per sub-agent dispatched
```

Print the pulse header with the current timestamp:

```
── PULSE $PULSE_NR ───────────────────────────────── {HH:MM:SS} ──
```

## 2. Dispatch Automated Work

**Do NOT ask the diver for confirmation. Dispatch immediately.** The labels are the authorization — if an item is labeled for automated work, dispatch it without hesitation.

**CRITICAL: Do NOT use `isolation: "worktree"` when spawning sub-agents.** Each phase manages its own worktree via `worktree-enter.sh` (fetches from origin, forks from the correct remote branch). Platform isolation bypasses this and causes merge conflicts.

### 2a. Flow wave

If `$ONLY_ISSUE_ID` is a specific ID, skip the label scan and use only that issue and its sub-issues. Otherwise scan:

```sh
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-slice OR label:to-implement OR label:to-research OR label:to-inspect OR label:to-rework OR label:to-seal'
```

Dispatch a sub-agent per issue in parallel. When sub-agent teams are supported in the environment, they can be used to parallelise items linked to the same plan.

Per sub-agent define all display and routing variables at dispatch time:

```sh
ISSUE_ID="{from the fetched issue}" # e.g. "#42"
ISSUE_TITLE="{from the fetched issue title}" # e.g. "auth token rotation"
ISSUE_PHASE="{label that dispatched this issue, without the to- prefix}" # e.g. "implement"
ISSUE_PHASE_EMOJI="{phase emoji for ISSUE_PHASE}"
# e.g.
# ISSUE_PHASE_EMOJI="𐃆🐋" (if label `to-slice`)
# ISSUE_PHASE_EMOJI="  🐙" (if label `to-implement`)
# ISSUE_PHASE_EMOJI="  🐬" (if label `to-research`)
# ISSUE_PHASE_EMOJI="  🧿" (if label `to-inspect`)
# ISSUE_PHASE_EMOJI="  🦀" (if label `to-rework`)
# ISSUE_PHASE_EMOJI="  🦭" (if label `to-seal`)
FILENAME="{based on the label as per the example below}" # e.g. "implement.md"
# e.g.
# FILENAME="slice.md" (if label `to-slice`)
# FILENAME="implement.md" (if label `to-implement`)
# FILENAME="research.md" (if label `to-research`)
# FILENAME="inspect.md" (if label `to-inspect`)
# FILENAME="rework.md" (if label `to-rework`)
# FILENAME="seal.md" (if label `to-seal`)
DISPATCH_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID  \"$ISSUE_TITLE\""
AGENT_COUNT_PULSE=$((AGENT_COUNT_PULSE + 1))
```

Dispatch a sub-agent:

```
Read and follow $SKILL_DIR/$FILENAME.

ISSUE_ID="$ISSUE_ID"
```

**Wait for all flow sub-agents to complete before proceeding to the ebb wave.**

### 2b. Ebb wave — dispatch `to-await-waves` and `to-merge`

```sh
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-await-waves OR label:to-merge'
```

Dispatch a sub-agent per issue in parallel.

Per `to-await-waves` issue, first parse the `[await: ...]` suffix from its title to find blocker IDs, then check each blocker's label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. "#42"
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

- If **all** blockers have the `landed` or `to-land` label: dispatch the item via sub-agent (`$SKILL_DIR/await-waves.md`).
- If **any** blocker has neither `landed` nor `to-land`: skip — do not dispatch. It stays `to-await-waves` and will be re-evaluated next pulse.
- If the `[await: ...]` suffix is missing or malformed: dispatch anyway — `await-waves` itself catches problems before promoting.

`to-merge` items do not use the dependency gate above; they simply run during ebb instead of flow.

Per sub-agent define all display and routing variables at dispatch time:

```sh
ISSUE_ID="{from the fetched issue}" # e.g. "#42"
ISSUE_TITLE="{from the fetched issue title}" # e.g. "auth token rotation"
ISSUE_PHASE="{label that dispatched this issue, without the to- prefix}" # e.g. "merge"
ISSUE_PHASE_EMOJI="{phase emoji for ISSUE_PHASE}"
# e.g.
# ISSUE_PHASE_EMOJI="  🐢" (if label `to-merge`)
# ISSUE_PHASE_EMOJI="  🪸" (if label `to-await-waves`)
FILENAME="{based on the label as per the example below}" # e.g. "merge.md"
# e.g.
# FILENAME="await-waves.md" (if label `to-await-waves` and eligible after dependency gate)
# FILENAME="merge.md" (if label `to-merge`)
DISPATCH_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID  \"$ISSUE_TITLE\""
AGENT_COUNT_PULSE=$((AGENT_COUNT_PULSE + 1))
```

Dispatch a sub-agent:

```
Read and follow $SKILL_DIR/$FILENAME.

ISSUE_ID="$ISSUE_ID"
```

**Wait for all ebb sub-agents to complete before proceeding.**

## 3. Print dispatched sub-agents

RUN ONLY IF `"$AGENT_COUNT_PULSE" -gt 0`.

Print each `$DISPATCH_ROW` captured at dispatch time. E.g.:

```
𐃆🐋  #34  "auth token rotation"
  🐙  #55  "user profile endpoint"
  🧿  #53  "db migration safety"
```

## 4. Increment pulse variables

```sh
AGENT_COUNT_SESSION=$((AGENT_COUNT_SESSION + AGENT_COUNT_PULSE))
if [ "$AGENT_COUNT_PULSE" -eq 0 ]; then
  IS_SESSION_COMPLETE=true
else
  IS_SESSION_COMPLETE=false
  PULSE_NR=$((PULSE_NR + 1))
fi
```

## 5. Print all return results

RUN ONLY IF `"$AGENT_COUNT_PULSE" -gt 0`.

Collect one execution record per returned sub-agent. Each record is keyed by the returned `ISSUE_ID` and is used for the return-result output and metric logging.

```sh
ISSUE_ID="{from handoff ISSUE_ID}" # e.g. "#42"
ISSUE_PHASE="{from dispatch record for this ISSUE_ID}" # e.g. "implement"
ISSUE_PHASE_EMOJI="{phase emoji for ISSUE_PHASE}" # e.g. "  🐙"
NEXT_PHASE="{from handoff NEXT_PHASE}" # e.g. "to-inspect"
PR_ID="{from handoff PR_ID}" # e.g. "#72"; "—" if not returned
SUMMARY="{from handoff SUMMARY}" # e.g. "PR created"
SUBAGENT_DURATION="{duration of sub-agent total execution}" # e.g. "3m12s"; "—" if unknown
SUBAGENT_TOKENS="{total token count used by the sub-agent}" # e.g. "18k"; "—" if unknown
SUBAGENT_TOOL_USES="{tool use count for the sub-agent}" # e.g. 24; "—" if unknown
RESULT_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID   $SUBAGENT_DURATION   $SUBAGENT_TOKENS   $ISSUE_PHASE › $NEXT_PHASE"
```

Print each `$RESULT_ROW`. E.g.:

```
𐃆🐋  #34   3m12s   18k   slice › implement
  🐙  #55   4m45s   24k   implement › inspect
  🦀  #53   1m08s    9k   inspect › rework
```

## 6. Log all sub-agent metrics

RUN ONLY IF `"$AGENT_COUNT_PULSE" -gt 0`.

Prep one JSON array for the metric-logger sub-agent that includes the key variables and metrics gathered per sub-agent dispatched in this pulse-loop iteration:

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

Dispatch a sub-agent:

```
Read and follow $SKILL_DIR/metric-logger.md.

PHASE_METRIC_RECORDS="$PHASE_METRIC_RECORDS"
```

**Wait for the metric-logger sub-agent to complete before proceeding.**

The metric-logger sub-agent returns aggregate write results for this pulse:

```sh
SUCCESS_COUNT="{from metrics logger handoff}" # e.g. 2
FAIL_COUNT="{from metrics logger handoff}" # e.g. 0
FAIL_IDS="{from metrics logger handoff}" # e.g. "#25, #89"
METRICS_RESULT_ROW="🪼 ~~ METRICS ⟦ $SUCCESS_COUNT written ⟧ ⟦ $FAIL_COUNT failed · ids: ${FAIL_IDS:-—} ⟧"
```

Print `$METRICS_RESULT_ROW`. E.g.:

```
🪼 ~~ METRICS ⟦ 3 written ⟧ ⟦ 0 failed · ids: — ⟧
```
