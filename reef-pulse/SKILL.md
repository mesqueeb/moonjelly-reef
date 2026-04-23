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

Initialize the session bookkeeping variables:

```sh
PULSE_NR=1
AGENT_COUNT_SESSION=0
SESSION_START_TS="$(date +%s)"
```

## Pulse loop

Every recursive call is still a full pulse iteration. Do not collapse a recursive call into a quick rescan or tracker-only follow-up. Each iteration must emit the same pulse transcript structure: pulse header, dispatch lines when applicable, return results when applicable, then recurse or complete.

```sh
AGENT_COUNT_PULSE=0 # Increment per sub-agent used
```

### 1. Print pulse header

RUN EVERY PULSE.

At the start of each pulse iteration (including recursive calls), print the pulse header with the current timestamp:

```
── PULSE $PULSE_NR ───────────────────────────────── {HH:MM:SS} ──
```

### 2. Scan

RUN EVERY PULSE.

Read the config to determine the tracker type, then scan for all labeled issues.

```sh
# Scan all reef-labeled issues in a single query
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-slice OR label:to-await-waves OR label:to-implement OR label:to-inspect OR label:to-rework OR label:to-merge OR label:to-seal'
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

RUN EVERY PULSE if `$AGENT_COUNT_PULSE > 0`.

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

### 3c. Increment pulse variables

RUN EVERY PULSE after the flow and ebb wave dispatch decisions are complete.

```sh
AGENT_COUNT_SESSION=$((AGENT_COUNT_SESSION + AGENT_COUNT_PULSE))
if [ "$AGENT_COUNT_PULSE" -eq 0 ]; then
  IS_SESSION_COMPLETE=true
else
  IS_SESSION_COMPLETE=false
  PULSE_NR=$((PULSE_NR + 1))
fi
```

### 4. Print all return results

RUN EVERY PULSE if `$AGENT_COUNT_PULSE > 0`.

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

### 5. Log all sub-agent metrics

RUN EVERY PULSE if `$AGENT_COUNT_PULSE > 0`.

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

### 6. Recurse or exit

RUN EVERY PULSE

After metrics are logged, check whether to recurse or exit.

**If `"$IS_SESSION_COMPLETE" = "false"` and `"$AGENT_COUNT_PULSE" -gt 0`**: the pulse dispatched automated work this iteration. Recursively invoke the `reef-pulse` skill again on the main session without asking confirmation. The recursive call happens on the main session, never as a sub-agent — this ensures the loop runs sequentially (scan, dispatch, wait, scan again) rather than spawning nested agents. Do NOT release the lock between iterations; the lock persists across the entire recursive chain. Pass the updated pulse counter to the next iteration. Re-triggering the pulse means literally re-running this skill and following it again from top to bottom for the next pulse iteration, not doing a shorthand check.

**If `"$IS_SESSION_COMPLETE" = "true"`**: no automated work was dispatched this iteration. The pulse has nothing left to do. Continue to the completion steps below.

### Print SESSION COMPLETE

RUN ONLY WHEN `"$IS_SESSION_COMPLETE" = "true"`.

This step only runs when `"$IS_SESSION_COMPLETE" = "true"` (the exit path from Step 6).

First compute the final session duration from the session start timestamp:

```sh
SESSION_DURATION_SECS="$(( $(date +%s) - SESSION_START_TS ))"
SESSION_DURATION="{format SESSION_DURATION_SECS as XmYYs or HhMMmSSs}" # e.g. 17m00s
```

Then print the SESSION COMPLETE box with session stats:

```
┌─────────────────────────────────────────────────────────────┐
│  🪼 SESSION COMPLETE                                         │
│                                                              │
│  Duration    $SESSION_DURATION                               │
│  Pulses      $PULSE_NR                                       │
│  Agents      $AGENT_COUNT_SESSION  dispatches             │
│  To Land     #34  #53                                        │
│  Landed      #33  #52                                        │
│  Blocked     #56  #57                                        │
└─────────────────────────────────────────────────────────────┘
```

- **To Land**: issues that reached `to-land` during this session
- **Landed**: issues that reached `landed` during this session
- **Blocked**: issues that are blocked or have no actionable label

### Print Lore

RUN ONLY WHEN `"$IS_SESSION_COMPLETE" = "true"` and `"$AGENT_COUNT_SESSION" -gt 0`.

Prep the lore-writer sub-agent input:

```sh
SENTENCE_BALLPARK="$((PULSE_NR * 2))"
```

Spawn a sub-agent with:

```
Read and follow $SKILL_DIR/lore-writer.md.

SENTENCE_BALLPARK=$SENTENCE_BALLPARK
```

The lore-writer sub-agent returns:

```sh
CHAPTER="{lore prose returned by the storytelling sub-agent}"
```

After the sub-agent returns, print the chapter:

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  $CHAPTER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### Print Next Up

Query for to-land and to-scope issues and say how many there are of those.

```sh
# Scan all to-land and to-scope issues in a single query
./tracker.sh issue list --json number,title,labels --limit 100 --search 'label:to-land OR label:to-scope'
X="{the amount of to-land issues}"
Y="{the amount of to-scope issues}"
```

Print:

```
The reef awaits new work. 🐚
You have $X open issues to land and $Y open issues to scope.
Run `reef-land` or `reef-scope` to start. 🤿
```

### Release lock

RUN ONLY WHEN `"$IS_SESSION_COMPLETE" = "true"`.

This step only runs when `"$IS_SESSION_COMPLETE" = "true"` (the exit path from Step 6). To release the lock, delete the `pulse.lock` file.

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan labels, dispatch skills, and exit. You do not track what you dispatched last time. Labels are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the label is still set.
