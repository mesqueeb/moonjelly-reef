---
name: reef-pulse
description: Run the Moonjelly Reef pulse, an orchestrator to scan and dispatch all automated work on autopilot.
---

# reef-pulse

## Input

Nothing, or a specific issue ID to focus the pulse on a single issue.

```sh
ONLY_ISSUE_ID="{issue-id or -}" # "-" if nothing provided
SKILL_DIR="{base directory for this skill}" # e.g. ~/.claude/skills/reef-pulse
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills. If the file doesn't exist, stop and tell the user: "🪼 `reef-pulse` requires setup. Run `reef-scope` first to configure the reef."

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. You are the orchestrator — scan, dispatch, and exit. You hold no state; labels are the state. When in doubt: check the labels, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

If `"$ONLY_ISSUE_ID" = "-"`, skip this step — the pulse-loop will scan all labels normally.

If `$ONLY_ISSUE_ID` is a specific ID, fetch that issue. The pulse-loop will process only this issue instead of scanning all labels:

```sh
./tracker.sh issue view "$ONLY_ISSUE_ID" --json body,title,labels
```

## 1. Session setup

```sh
TRACKER_BRANCH="{from config.md}" # e.g. "main"
LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
```

### Acquire lock

Check for an existing pulse.lock file.

If the pulse.lock file exists, another pulse may already be running (or a previous session crashed without cleaning up).

- If `pulse.lock` exists, read the start timestamp from it, calculate how long the existing pulse has been running, and report this to the user: "A pulse has been running for {elapsed}. This may be from a crashed session. Override?" In interactive use, ask the user. In cron/autopilot use, override automatically.
- If `pulse.lock` does not exist (or the user chose to override), create it with a start timestamp (ISO 8601 UTC) and continue.

### Sync tracker branch (local-tracker-committed only)

RUN ONLY IF the tracker is `local-tracker-committed`.

The tracker files live in a git-tracked directory on a specific branch. Sync it before scanning. `TRACKER_BRANCH` was already set above.

```sh
git fetch origin "$TRACKER_BRANCH" && git checkout "$TRACKER_BRANCH" && git pull
```

### Print session header

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

## 2. Start pulse loop

After the session is initialized, read and follow [`pulse-loop.md`](pulse-loop.md) from top to bottom for the first pulse-loop iteration.

## 3. Repeat pulse loop or finish

After each return from [`pulse-loop.md`](pulse-loop.md), decide whether to invoke another pulse-loop iteration or move to session completion.

**If `"$IS_SESSION_COMPLETE" = "false"` and `"$AGENT_COUNT_PULSE" -gt 0`**: the pulse dispatched automated work in this pulse-loop iteration. Re-run [`pulse-loop.md`](pulse-loop.md) on the main session without asking confirmation. The loop stays on the main session, never as a sub-agent — this keeps the sequence strictly serial (scan, dispatch, wait, scan again) instead of spawning nested agents. Do NOT release the lock between pulse-loop iterations; the lock persists across the entire session. Re-running `pulse-loop.md` means following that file again from top to bottom using the updated shell variables already present in the same session.

**If `"$IS_SESSION_COMPLETE" = "true"`**: no automated work was dispatched this iteration. The pulse has nothing left to do. Continue to step 4.

## 4. Session completion

RUN ONLY IF `"$IS_SESSION_COMPLETE" = "true"`.

### Print SESSION COMPLETE

Compute the final session duration from the session start timestamp:

```sh
SESSION_DURATION_SECS="$(( $(date +%s) - SESSION_START_TS ))"
SESSION_DURATION="{format SESSION_DURATION_SECS as XmYYs or HhMMmSSs}" # e.g. 17m00s
```

Print the SESSION COMPLETE box with session stats:

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

RUN ONLY IF `"$AGENT_COUNT_SESSION" -gt 0`.

prep:

```sh
SENTENCE_BALLPARK="$((PULSE_NR * 2))"
```

Dispatch a sub-agent:

```
Read and follow $SKILL_DIR/lore-writer.md.

SENTENCE_BALLPARK="$SENTENCE_BALLPARK"
```

The lore-writer sub-agent returns:

```sh
CHAPTER="{lore prose returned by the storytelling sub-agent}" # e.g. "The tide shifted as three issues moved from implement to inspect..."
```

Print the chapter:

```
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  $CHAPTER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### Print Next Up

Query for to-land and to-scope issues and say how many there are of those.

```sh
./tracker.sh issue list --json number,title,labels --limit 100 --search 'label:to-land OR label:to-scope'
X="{the amount of to-land issues}" # e.g. 3
Y="{the amount of to-scope issues}" # e.g. 2
```

Print:

```
The reef awaits new work. 🐚
You have $X open issues to land and $Y open issues to scope.
Run `reef-land` or `reef-scope` to start. 🤿
```

### Release lock

To release the lock, delete the `pulse.lock` file.

Exit.
