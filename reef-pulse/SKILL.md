---
name: reef-pulse
description: The Moonjelly Reef orchestrator. A single pulse that scans all issues by tag, dispatches reef skills as sub-agents, and exits. Run manually or as a cron.
---

# reef-pulse

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

You are the orchestrator. You scan, dispatch, and exit. You hold no state — tags are the state.

## 0. Sync tracker branch (local-tracker-committed only)

If the tracker type in config is `local-tracker-committed`, the tracker files live in a git-tracked directory on a specific branch. Sync it before scanning:

```sh
TRACKER_BRANCH = {from config.md} # e.g. main
```

```sh
git fetch origin $TRACKER_BRANCH && git checkout $TRACKER_BRANCH && git pull
```

If the tracker is `github`, `local-tracker-gitignored`, or any MCP-based tracker, skip this step.

## Mode

Detect the mode from how this skill was invoked:

- `/reef-pulse` or `/reef-pulse --hitl` → **HITL mode**: dispatch automated work + present human items.
- `/reef-pulse --afk` → **AFK mode**: dispatch automated work only. Skip human items. Designed for cron.

## The pulse

### Step 1. Scan

Read the config to determine the tracker type, then scan for all tagged issues.

```sh
# Scan all reef-tagged issues
tracker.sh issue list --label "to-scope" --json number,title --limit 100
tracker.sh issue list --label "to-slice" --json number,title --limit 100
tracker.sh issue list --label "to-await-waves" --json number,title --limit 100
tracker.sh issue list --label "to-implement" --json number,title --limit 100
tracker.sh issue list --label "to-inspect" --json number,title --limit 100
tracker.sh issue list --label "to-rework" --json number,title --limit 100
tracker.sh issue list --label "to-merge" --json number,title --limit 100
tracker.sh issue list --label "to-ratify" --json number,title --limit 100
tracker.sh issue list --label "to-rescan" --json number,title --limit 100
tracker.sh issue list --label "to-land" --json number,title --limit 100
```

Run these queries in parallel where possible for performance.

### Step 2. Dispatch automated (🌊) work

**Do NOT ask the user for confirmation. Dispatch immediately.** The tags are the authorization — if an item is tagged for automated work, dispatch it without hesitation.

For each item found, dispatch the corresponding phase as a sub-agent. Use the Agent tool. Items that share no dependencies can be dispatched **in parallel**.

Dispatch by telling sub-agents to read and follow a specific file:

> "Read and follow the instructions in `reef-pulse/implement.md`. Your target is #55."

| Tag              | File                             | Notes                                                                                                                      |
| ---------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `to-slice`       | [slice.md](slice.md)             | One at a time per plan (creates target branch + sub-issues)                                                                |
| `to-await-waves` | [await-waves.md](await-waves.md) | Parallel OK — each is independent                                                                                          |
| `to-implement`   | [implement.md](implement.md)     | Parallel OK for unrelated slices. Slices within the same plan may be dispatched as an **agent team** if multiple are ready |
| `to-inspect`     | [inspect.md](inspect.md)         | Parallel OK                                                                                                                |
| `to-rework`      | [rework.md](rework.md)           | Parallel OK                                                                                                                |
| `to-merge`       | [merge.md](merge.md)             | One at a time per plan (modifies target branch)                                                                            |
| `to-ratify`      | [ratify.md](ratify.md)           | One at a time per plan                                                                                                     |
| `to-rescan`      | [rescan.md](rescan.md)           | One at a time per plan                                                                                                     |

When dispatching, pass the item reference as a parameter: e.g. "Read and follow `reef-pulse/implement.md`. Target: #55."

**When to use agent teams vs sub-agents for `to-implement`:**

- **1-2 slices ready**: use regular sub-agents (Agent tool). Dispatch `reef-pulse/implement.md` for each with the slice reference.
- **3+ slices ready from the same plan**: use an agent team. Each teammate claims a slice and follows `reef-pulse/implement.md` with its slice reference. The instructions handle worktree setup, PR creation, and reporting — just pass the slice reference.

### Step 3. Log phase metrics to plan issues

After all dispatched agents complete, collect the task notification metadata from each (duration, tokens, tool uses, and outcome). Group the results by plan issue:

- **Single-slice plans**: the plan issue itself is the target.
- **Multi-slice plans**: the slice issue body links back to its plan (look for the `Plan: #N` line).

Append **one metrics section per plan** to the plan issue body using `tracker.sh issue edit --body`. Read the current body first, then append the new metrics section at the bottom.

```sh
ISSUE_ID = {from dispatched items}
ISSUE_BODY = {current issue body with metrics section appended}
tracker.sh issue edit $ISSUE_ID --body "$ISSUE_BODY"
```

Metrics section format:

```markdown
### 🪼 Pulse metrics — {YYYY-MM-DD HH:MM UTC}

| Phase     | Target | Duration | Tokens | Tool uses | Outcome       |
| --------- | ------ | -------- | ------ | --------- | ------------- |
| implement | #55    | 42s      | 12 340 | 18        | ✅ PR created |
| implement | #56    | 38s      | 10 890 | 15        | ✅ PR created |
| inspect   | #53    | 25s      | 8 200  | 12        | ✅ passed     |
```

Rules:

- Only log phases that were dispatched this pulse. If nothing was dispatched, skip this step entirely.
- If a dispatch failed or the agent returned no metadata, log what you have with `—` for missing fields.
- Duration should be human-readable (e.g. `42s`, `1m 12s`). Tokens should use space-separated thousands.

### Step 4. Present human (🤿) items (--hitl only)

If running in `--afk` mode, skip this step entirely.

If running in `--hitl` mode, present human-required items:

| Tag        | Skill         | Presentation                                                              |
| ---------- | ------------- | ------------------------------------------------------------------------- |
| `to-scope` | `/reef-scope` | "**{title}** needs scoping. Run `/reef-scope #{number}`."                 |
| `to-land`  | `/reef-land`  | "**{title}** is ready for your final review. Run `/reef-land #{number}`." |

> Note: reef-scope and reef-land remain user-facing skills invoked via slash commands. Only the automated (🌊) phases are dispatched via file references.

### Step 5. Report and exit

Print a summary of what was dispatched:

```
🪼 Pulse complete.

  Dispatched:
    🌊 implement.md #55 (auth-endpoint)
    🌊 implement.md #56 (user-profile)
    🌊 inspect.md #53 (db-migration)
    🌊 merge.md #51 (schema-setup)

  Awaiting human:
    🤿 to-scope: #60 (new-dashboard-idea)
    🤿 to-land: #42 (token-auth-migration)

  Idle:
    ⏳ to-await-waves: #57 (legacy-compat) — blocked by #55, #56
```

If nothing was actionable:

```
🪼 Pulse complete. Nothing to dispatch.

  Run /reef-scope to start something new.
```

**Autopilot hint** (show only when pulse was triggered manually, not from a cron):

Check if a durable cron for `/reef-pulse --afk` already exists by calling `CronList`. If none exists, append to the summary:

```
  💡 Run this on autopilot:
     CronCreate cron="7 * * * *" prompt="/reef-pulse --afk" durable=true
```

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan tags, dispatch skills, and exit. You do not track what you dispatched last time. Tags are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the tag is still set.
