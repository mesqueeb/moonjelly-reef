---
name: reef-pulse
description: The Moonjelly Reef orchestrator. A single pulse that scans all issues by label, dispatches reef skills as sub-agents, and exits. Run manually or as a cron.
---

# reef-pulse

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

You are the orchestrator. You scan, dispatch, and exit. You hold no state — labels are the state.

Capture the skill base directory (provided by the harness as "Base directory for this skill: {path}" at invocation time):

```sh
SKILL_DIR="{base directory for this skill}"
```

## Session setup

### Acquire lock

Before doing anything else, check for an existing pulse.lock file.

```sh
TRACKER_BRANCH="{from config.md}" # e.g. main
LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
```

If the pulse.lock file exists, another pulse may already be running (or a previous session crashed without cleaning up).

- If `pulse.lock` exists, read the start timestamp from it, calculate how long the existing pulse has been running, and report this to the user: "A pulse has been running for {elapsed}. This may be from a crashed session. Override?" In interactive use, ask the user. In cron/autopilot use, override automatically.
- If `pulse.lock` does not exist (or the user chose to override), create it with a start timestamp (ISO 8601 UTC) and continue.

### Sync tracker branch (local-tracker-committed only)

RUN IF the tracker is `github`, `local-tracker-gitignored`, or any MCP-based tracker, skip this step.

If the tracker type in config is `local-tracker-committed`, the tracker files live in a git-tracked directory on a specific branch. Sync it before scanning. `TRACKER_BRANCH` was already set in the previous step.

```sh
git fetch origin "$TRACKER_BRANCH" && git checkout "$TRACKER_BRANCH" && git pull
```

### Print session header (first iteration only)

RUN ONCE PER SESSION.

If this is the first iteration of the pulse (not a recursive call), print the session header:

```
┌─────────────────────────────────────────────────────────────┐
│  🪼  MOONJELLY REEF  ·  SESSION LOG                         │
└─────────────────────────────────────────────────────────────┘
```

Initialize the pulse counter to 0:

```sh
N=0
```

## Pulse loop

Every recursive call is still a full pulse iteration. Do not collapse a recursive call into a quick rescan or tracker-only follow-up. Each iteration must emit the same pulse transcript structure: pulse header, dispatch lines when applicable, lore beat, return results when applicable, then recurse or complete.

### 1. Print pulse header

RUN EVERY PULSE.

At the start of each pulse iteration (including recursive calls), increment the pulse counter and print the pulse header with the current timestamp:

```sh
N=$((N + 1))
```

```
── PULSE $N ──────────────────────────────────────── {HH:MM:SS} ──
```

### 2. Scan

RUN EVERY PULSE.

Read the config to determine the tracker type, then scan for all tagged issues.

```sh
# Scan all reef-tagged issues in a single query
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-scope OR label:to-slice OR label:to-await-waves OR label:to-implement OR label:to-inspect OR label:to-rework OR label:to-merge OR label:to-seal OR label:to-land'
```

### 3. Dispatch automated (🌊) work — Flow wave

RUN EVERY PULSE.

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

### 3a. Ebb wave — gated dispatch of to-await-waves items

RUN EVERY PULSE after the flow wave completes.

After all flow agents complete, rescan `to-await-waves` items. For each item, parse the `[await: ...]` suffix from its title to find blocker IDs, then check each blocker's label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. #42
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

- If **all** blockers have the `landed` label: dispatch the item via sub-agent (`$SKILL_DIR/await-waves.md`).
- If **any** blocker is not `landed`: skip — do not dispatch. It stays `to-await-waves` and will be re-evaluated next pulse.

If the `[await: ...]` suffix is missing or malformed, dispatch anyway — `await-waves` itself catches problems before promoting.

### 3b. Print dispatched agents

RUN EVERY PULSE if anything was dispatched in the flow or ebb wave.

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
ISSUE_PHASE_EMOJI="{phase emoji for ISSUE_PHASE}" # e.g.: 🐙
DISPATCH_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID  \"$ISSUE_TITLE\""
```

E.g.:

```
𐃆🐋  #34  "auth token rotation"
  🐙  #55  "user profile endpoint"
  🧿  #53  "db migration safety"
```

### 4. Print lore snippet

RUN EVERY PULSE, including empty ones.

Always generate lore by spawning the storytelling sub-agent. Do not generate lore inline inside the pulse.

Prep the storytelling input:

```sh
AUTOMATED_DISPATCHES="{count of automated phases dispatched this iteration}"
IS_FIRST_BEAT="{true if N == 1; otherwise false}"
IS_FINAL_BEAT="{true if AUTOMATED_DISPATCHES == 0; otherwise false}"
BEAT_NUMBER="$N"
LORE_ROLL="{2d6 roll, 2-12, with slight wave progress influence}" # e.g.: 12
LORE_AGENT_INPUT="{all lore input variables above with names and values}"
# e.g.:
#   AUTOMATED_DISPATCHES=4
#   IS_FIRST_BEAT=false
#   IS_FINAL_BEAT=false
#   BEAT_NUMBER=3
#   LORE_ROLL=12
```

Spawn a sub-agent with:

```
Read and follow $SKILL_DIR/saga-writer.md.

$LORE_AGENT_INPUT
```

The storytelling sub-agent returns:

```sh
BEAT="{lore prose returned by the storytelling sub-agent}"
```

After the sub-agent returns, print the beat in the existing dashed lore box format:

```
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
  +8m00s  $BEAT
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
```

Leave dispatch lines, metrics tables, and return-result output unchanged.

### 5. Print all return results

RUN EVERY PULSE if anything was dispatched in this iteration.

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

### 6. Log all sub-agent metrics

RUN EVERY PULSE if anything was dispatched in this iteration.

Prep one JSON array for the logger agent:

```sh
PHASE_METRIC_RECORDS='[
#  {
#    "ISSUE_ID": "#55",
#    "ISSUE_PHASE": "to-implement",
#    "NEXT_PHASE": "to-inspect",
#    "PR_ID": "#72",
#    "SUMMARY": "PR created",
#    "SUBAGENT_DURATION": "42s",
#    "SUBAGENT_TOKENS": 12340,
#    "SUBAGENT_TOOL_USES": 18
#  }
  {
    "ISSUE_ID": "#55",
    "ISSUE_PHASE": "to-implement",
    "NEXT_PHASE": "to-inspect",
    "PR_ID": "#72",
    "SUMMARY": "PR created",
    "SUBAGENT_DURATION": "42s",
    "SUBAGENT_TOKENS": 12340,
    "SUBAGENT_TOOL_USES": 18
  }
]'
```

Spawn the logger agent:

```sh
Read and follow $SKILL_DIR/phase-metric-logger.md.

AUTOMATED_DISPATCHES="$AUTOMATED_DISPATCHES"
PHASE_METRIC_RECORDS="$PHASE_METRIC_RECORDS"
```

The logger agent returns aggregate write results for this pulse:

```sh
SUCCESS_COUNT="{from metrics logger handoff}"
FAIL_COUNT="{from metrics logger handoff}"
FAIL_IDS="{from metrics logger handoff}"
```

Log the metrics write.

```sh
METRICS_RESULT_ROW="🪼  metrics ok=$SUCCESS_COUNT fail=$FAIL_COUNT ids=${FAIL_IDS:-—}"
```

### 7. Recurse or exit

RUN EVERY PULSE.

After metrics are logged, check whether to recurse or exit.

**If `$AUTOMATED_DISPATCHES > 0`**: the pulse dispatched automated work this iteration. After agents return and metrics are logged, recursively invoke the `reef-pulse` skill again on the main session without asking confirmation. The recursive call happens on the main session, never as a sub-agent — this ensures the loop runs sequentially (scan, dispatch, wait, scan again) rather than spawning nested agents. Do NOT release the lock between iterations; the lock persists across the entire recursive chain. Pass the pulse counter to the next iteration. Re-triggering the pulse means literally re-running this skill and following it again from top to bottom for the next pulse iteration, not doing a shorthand check.

**If `$AUTOMATED_DISPATCHES == 0`**: no automated work was dispatched this iteration. The pulse has nothing left to do. Continue to the completion steps below.

### Print SESSION COMPLETE and full story

RUN ONLY ON THE FINAL EMPTY PULSE.

This step only runs when `$AUTOMATED_DISPATCHES == 0` (the exit path from Step 7).

Then print the SESSION COMPLETE box with session stats:

```
┌─────────────────────────────────────────────────────────────┐
│  SESSION COMPLETE                                            │
│                                                              │
│  Duration    17m00s                                          │
│  Pulses      $N                                              │
│  Agents      7  dispatches across 3 active pulses            │
│  To Land     #34  #53                                        │
│  Landed      #33  #52                                        │
│  Blocked     #56  #57                                        │
└─────────────────────────────────────────────────────────────┘
```

- **Duration**: total wall-clock time since the session started (from the lock file timestamp)
- **Pulses**: total number of pulse iterations (including this final empty one)
- **Agents**: total number of sub-agent dispatches across all active pulses (pulses that dispatched at least one agent)
- **To Land**: issues that reached `to-land` during this session
- **Landed**: issues that reached `landed` during this session
- **Blocked**: issues that are blocked or have no actionable label

After the SESSION COMPLETE box, read the most recent `chapter-NNN.md` in `.agents/moonjelly-reef/saga/` and print its contents as a single block:

```
  $CHAPTER_CONTENTS
```

If the session dispatched no automated work at all, say so plainly and point the user at the next useful action:

```
No automated work is ready right now. Run `reef-scope` to start scoping new items for the reef to pick up.
```

### Release lock

RUN ONLY ON THE FINAL EMPTY PULSE.

This step only runs when `$AUTOMATED_DISPATCHES == 0` (the exit path from Step 7). To release the lock, delete the `pulse.lock` file.

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan labels, dispatch skills, and exit. You do not track what you dispatched last time. Labels are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the label is still set.
