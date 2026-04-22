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

## 0a. Acquire lock

Before doing anything else, check for an existing pulse.lock file.

```sh
TRACKER_BRANCH="{from config.md}" # e.g. main
LOCK_FILE=".agents/moonjelly-reef/pulse.lock"
```

If the pulse.lock file exists, another pulse may already be running (or a previous session crashed without cleaning up).

- If `pulse.lock` exists, read the start timestamp from it, calculate how long the existing pulse has been running, and report this to the user: "A pulse has been running for {elapsed}. This may be from a crashed session. Override?" In AFK mode, override automatically (the lock is stale if we're in a cron). In HITL mode, ask the user.
- If `pulse.lock` does not exist (or the user chose to override), create it with a start timestamp (ISO 8601 UTC) and continue.

## 0b. Sync tracker branch (local-tracker-committed only)

If the tracker type in config is `local-tracker-committed`, the tracker files live in a git-tracked directory on a specific branch. Sync it before scanning. `TRACKER_BRANCH` was already set in the previous step.

```sh
git fetch origin "$TRACKER_BRANCH" && git checkout "$TRACKER_BRANCH" && git pull
```

If the tracker is `github`, `local-tracker-gitignored`, or any MCP-based tracker, skip this step.

## Mode

Detect the mode from how this skill was invoked:

- `/reef-pulse` or `/reef-pulse --hitl` → **HITL mode**: dispatch automated work + present human items.
- `/reef-pulse --afk` → **AFK mode**: dispatch automated work only. Skip human items. Designed for cron.

## The pulse

### Step 0c. Print session header (first iteration only)

If this is the first iteration of the pulse (not a recursive call), print the session header:

```
┌─────────────────────────────────────────────────────────────┐
│  🪼  MOONJELLY REEF  ·  SESSION LOG                         │
└─────────────────────────────────────────────────────────────┘
```

Initialize the pulse counter to 0.

### Step 0d. Print pulse header

At the start of each pulse iteration (including recursive calls), increment the pulse counter and print the pulse header with the current timestamp:

```
── PULSE {N} ──────────────────────────────────────── {HH:MM:SS} ──
```

### Step 1. Scan

Read the config to determine the tracker type, then scan for all tagged issues.

```sh
# Scan all reef-tagged issues in a single query
./tracker.sh issue list --json number,title,labels --limit 100 \
  --search 'label:to-scope OR label:to-slice OR label:to-await-waves OR label:to-implement OR label:to-inspect OR label:to-rework OR label:to-merge OR label:to-ratify OR label:to-land'
```

### Step 2. Dispatch automated (🌊) work — Flow wave

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
| `to-ratify`    | `$SKILL_DIR/ratify.md`    |

### Step 2a. Ebb wave — gated dispatch of to-await-waves items

After all flow agents complete, rescan `to-await-waves` items. For each item, parse the `[await: ...]` suffix from its title to find blocker IDs, then check each blocker's label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. #42
```

```sh
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

- If **all** blockers have the `landed` label: dispatch the item via sub-agent (`$SKILL_DIR/await-waves.md`).
- If **any** blocker is not `landed`: skip — do not dispatch. It stays `to-await-waves` and will be re-evaluated next pulse.

If the `[await: ...]` suffix is missing or malformed, dispatch anyway — `await-waves` itself catches problems before promoting.

### Step 2b. Print dispatched agents

Immediately after dispatching, print each dispatched agent with its phase emoji. Use the phase emoji from the README lore for each phase:

| Label            | Phase emoji |
| ---------------- | ----------- |
| `to-slice`       | `𐃆🐋`       |
| `to-implement`   | `🐙`        |
| `to-inspect`     | `🧿`        |
| `to-rework`      | `🦀`        |
| `to-merge`       | `🐢`        |
| `to-ratify`      | `🦭`        |
| `to-await-waves` | `🪸`        |

The narwhal (slice phase) always uses both characters `𐃆🐋`, not just the emoji.

```
  𐃆🐋  #34  "auth token rotation"
  🐙  #55  "user profile endpoint"
  🧿  #53  "db migration safety"
```

After both flow and ebb waves complete, record the combined count of automated phases dispatched this iteration:

```sh
AUTOMATED_DISPATCHES="{count of automated phases dispatched this iteration}"
```

### Step 2c. Print lore snippet

This step runs on every pulse, including empty ones. Generate a lore snippet by spawning a storytelling sub-agent (use `$SKILL_DIR/saga-writer.md`). Do not generate lore inline inside the pulse.

Choose a random number as-if you make a 2d6 roll (2-12) with slight wave progress influence:

- 6–8 for neutral or mixed results
- 2–5 when agents failed, were blocked, or nothing moved forward
- 9–12 when agents landed cleanly or a milestone was reached

Pass the storytelling sub-agent:

- `IS_FIRST_BEAT`: true if `N == 1`
- `IS_FINAL_BEAT`: true if `$AUTOMATED_DISPATCHES == 0`
- `BEAT_NUMBER`: `N`
- The 2d6 roll

The storytelling sub-agent returns:

- `BEAT:` followed by the lore prose

After the sub-agent returns, print the beat in the existing dashed lore box format:

```
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
  +8m00s  $BEAT
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
```

Leave dispatch lines, metrics tables, and return-result output unchanged.

### Step 2d. Print return results

After agents return, print each result with its phase emoji and a `›` transition arrow showing the phase transition:

```
𐃆🐋  #34   3m12s   18k   slice › implement
  🐙  #55   4m45s   24k   implement › inspect
  🦀  #53   1m08s    9k   inspect › rework
```

The narwhal (slice phase) always uses both characters `𐃆🐋`. Each line shows: phase emoji, issue number, duration, token count, and the transition (previous label `›` next label from handoff).

Also print human and idle items:

```
  🤿  #60  to-scope
  🤿  #48  to-land
  ·   #57  idle — awaiting #55
  ·   #56  idle
```

### Step 3. Log phase metrics

After all dispatched agents complete, collect from each: task notification metadata (duration, tokens, tool uses) and the structured handoff variables (`nextPhase`, `planPr`, `summary`). Group results by plan.

#### Metrics table format

```markdown
### 🪼 Pulse metrics

| Phase     | Target | Duration | Tokens | Tool uses | Outcome       | Date             |
| --------- | ------ | -------- | ------ | --------- | ------------- | ---------------- |
| implement | #55    | 42s      | 12 340 | 18        | ✅ PR created | 2026-04-20 14:30 |
| inspect   | #53    | 25s      | 8 200  | 12        | ✅ passed     | 2026-04-20 14:31 |

<!-- end metrics table -->
```

No timestamp in the header. Each row gets a `Date` column (`yyyy-MM-dd HH:mm`).

#### Rules

- Only log phases dispatched this pulse. If nothing was dispatched, skip this step entirely.
- Fall back to `—` for any missing metadata field (duration, tokens, tool uses).
- Duration: human-readable (`42s`, `1m 12s`). Tokens: space-separated thousands.
- Do NOT read issue bodies to discover PR numbers. Use `planPr` from the handoff.

#### 3a. Write metrics to the plan issue

Read the current plan issue body. If a `### 🪼 Pulse metrics` table exists, insert the new row(s) immediately above the `<!-- end metrics table -->` sentinel. If no table exists, append it to the end of the body (including the sentinel after the last row).

```sh
ISSUE_ID="{from dispatched items}"
ISSUE_BODY="{current issue body with metrics rows inserted into the table}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

#### 3b. Write metrics to the plan PR

Use `planPr` from the handoff to determine the target PR. If `planPr` is `—`, no plan PR exists yet — skip this sub-step. Otherwise, read the current plan PR body and insert the same metrics rows immediately above the `<!-- end metrics table -->` sentinel. If no table exists, append it to the end (including the sentinel after the last row).

```sh
PLAN_PR_NUMBER="$planPr" # from handoff — never read issue bodies for this
PLAN_PR_BODY="{current plan PR body with metrics rows inserted into the table}"
./tracker.sh pr edit "$PLAN_PR_NUMBER" --body "$PLAN_PR_BODY"
```

#### Total row on ratify-to-land

When a ratify handoff has `nextPhase: to-land`, use `planIssueMetrics` from the ratify handoff (scope/slice metrics rows from the plan issue). Prepend those rows to the PR's existing metrics table (dedup if already present), append the ratify row, then append a bold **Total** row summing all durations and tokens. Unknown values (`—`) are excluded from the total. This is the last automated edit to the metrics table.

Example:

```markdown
| scope | #15 | 1m 30s | — | — | plan created | 2026/04/18 | 09:00 |
| slice | #15 | 45s | 8 100 | 10 | slices created | 2026/04/18 | 09:05 |
| ratify | — | 1m 5s | 15 200 | 20 | pass | 2026/04/20 | 14:35 |
| **Total** | | **5m 30s** | **62 359** | **87** | | | |

<!-- end metrics table -->
```

### Step 4. Present human (🤿) items (first iteration only)

Skip this step if running in `--afk` mode or if this is a recursive iteration (not the first iteration).

Human items (`to-scope`, `to-land`) are presented only in the first iteration of the pulse, not in recursive AFK calls. This ensures that HITL items are shown once to the user and not repeated as the pulse recurses through automated work.

If running in `--hitl` mode and this is the first iteration, present human-required items immediately without waiting for dispatched agents to complete. Automated agents run in the background — metrics collection (Step 3) happens after agents complete but must not block the human workflow. Present human items as soon as dispatch is done:

| Label      | Skill         | Presentation                                                              |
| ---------- | ------------- | ------------------------------------------------------------------------- |
| `to-scope` | `/reef-scope` | "**{title}** needs scoping. Run `/reef-scope #{number}`."                 |
| `to-land`  | `/reef-land`  | "**{title}** is ready for your final review. Run `/reef-land #{number}`." |

> Note: reef-scope and reef-land remain user-facing skills invoked via slash commands. Only the automated (🌊) phases are dispatched via file references.

### Step 5. Recurse or exit

After metrics are logged, check whether to recurse or exit.

**If `$AUTOMATED_DISPATCHES > 0`**: the pulse dispatched automated work this iteration. After agents return and metrics are logged, recursively invoke `/reef-pulse --afk` on the main session. The recursive call is always `--afk`, even if the first invocation was HITL. The recursive call happens on the main session, never as a sub-agent — this ensures the loop runs sequentially (scan, dispatch, wait, scan again) rather than spawning nested agents. Do NOT release the lock between iterations; the lock persists across the entire recursive chain. Pass the pulse counter to the next iteration.

**If `$AUTOMATED_DISPATCHES == 0`**: no automated work was dispatched this iteration. The pulse has nothing left to do. Continue to Step 6.

### Step 6. Print SESSION COMPLETE and full story

This step only runs when `$AUTOMATED_DISPATCHES == 0` (the exit path from Step 5).

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

### Step 7. Release lock

This step only runs when `$AUTOMATED_DISPATCHES == 0` (the exit path from Step 5). To release the lock, delete the `pulse.lock` file.

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan labels, dispatch skills, and exit. You do not track what you dispatched last time. Labels are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the label is still set.
