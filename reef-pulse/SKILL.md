---
name: reef-pulse
description: The Moonjelly Reef orchestrator. A single pulse that scans all work items by tag, dispatches reef skills as sub-agents, and exits. Run manually or as a cron.
---

# reef-pulse

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-setup` first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

You are the orchestrator. You scan, dispatch, and exit. You hold no state — tags are the state.

## Mode

Detect the mode from how this skill was invoked:

- `/reef-pulse` or `/reef-pulse --hitl` → **HITL mode**: dispatch automated work + present human items.
- `/reef-pulse --afk` → **AFK mode**: dispatch automated work only. Skip human items. Designed for cron.

If the argument contains `--afk`, run in AFK mode. Otherwise, default to HITL.

## The pulse

### Step 1. Scan

Read the config to determine the tracker type, then scan for all tagged items.

### GitHub tracker

```sh
# Scan all reef-tagged issues
gh issue list --label "to-probe" --json number,title --limit 100
gh issue list --label "to-scope" --json number,title --limit 100
gh issue list --label "to-slice" --json number,title --limit 100
gh issue list --label "to-await-waves" --json number,title --limit 100
gh issue list --label "to-implement" --json number,title --limit 100
gh issue list --label "to-inspect" --json number,title --limit 100
gh issue list --label "to-rework" --json number,title --limit 100
gh issue list --label "to-merge" --json number,title --limit 100
gh issue list --label "to-ratify" --json number,title --limit 100
gh issue list --label "to-rescan" --json number,title --limit 100
gh issue list --label "to-finalise" --json number,title --limit 100
```

Or more efficiently:

```sh
gh issue list --label "to-probe,to-scope,to-slice,to-await-waves,to-implement,to-inspect,to-rework,to-merge,to-ratify,to-rescan,to-finalise" --json number,title,labels --limit 200
```

### Local tracker

Read the local path from config. Scan all work item folders for tagged files:

- Parent plan files: look for `[to-*] plan.md` pattern
- Slice files: look for `[to-*] *.md` in `slices/` subfolders

### Step 2. Dispatch automated (🌊) work

For each item found, dispatch the corresponding skill as a sub-agent. Use the Agent tool. Items that share no dependencies can be dispatched **in parallel**.

| Tag | Skill | Notes |
| --- | --- | --- |
| `to-slice` | `/reef-slice` | One at a time per parent (creates feature branch + sub-issues) |
| `to-await-waves` | `/reef-await-waves` | Parallel OK — each is independent |
| `to-implement` | `/reef-implement` | Parallel OK for unrelated slices. Slices within the same parent may be dispatched as an **agent team** if multiple are ready |
| `to-inspect` | `/reef-inspect` | Parallel OK |
| `to-rework` | `/reef-rework` | Parallel OK |
| `to-merge` | `/reef-merge` | One at a time per parent (modifies feature branch) |
| `to-ratify` | `/reef-ratify` | One at a time per parent |
| `to-rescan` | `/reef-rescan` | One at a time per parent |

When dispatching, pass the item reference as a parameter: e.g. dispatch `/reef-implement #55`.

**When to use agent teams vs sub-agents for `to-implement`:**

- **1-2 slices ready**: use regular sub-agents (Agent tool). Dispatch `/reef-implement {slice-ref}` for each.
- **3+ slices ready from the same parent**: use an agent team. Each teammate claims a slice and runs `/reef-implement {slice-ref}`. The skill handles worktree setup, PR creation, and reporting — just pass the slice reference.

### Step 3. Present human (🤿) items (--hitl only)

If running in `--hitl` mode, present human-required items:

| Tag | Skill | Presentation |
| --- | --- | --- |
| `to-probe` | `/reef-probe` | "**{title}** needs a probe session. Run `/reef-probe #{number}` to start." |
| `to-scope` | `/reef-scope` | "**{title}** has been probed and needs scoping. Run `/reef-scope #{number}`." |
| `to-finalise` | `/reef-finalise` | "**{title}** is ready for your final review. Run `/reef-finalise #{number}`." |

If running in `--afk` mode, skip this step entirely.

### Step 4. Report and exit

Print a summary of what was dispatched:

```
🪼 Pulse complete.

  Dispatched:
    🌊 reef-implement #55 (auth-endpoint)
    🌊 reef-implement #56 (user-profile)
    🌊 reef-inspect #53 (db-migration)
    🌊 reef-merge #51 (schema-setup)

  Awaiting human:
    🤿 to-probe: #60 (new-dashboard-idea)
    🤿 to-finalise: #42 (token-auth-migration)

  Idle:
    ⏳ to-await-waves: #57 (legacy-compat) — blocked by #55, #56
```

If nothing was actionable:

```
🪼 Pulse complete. Nothing to dispatch.

  Run /reef-probe to start something new.
```

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan tags, dispatch skills, and exit. You do not track what you dispatched last time. Tags are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **Respect one-at-a-time constraints.** Slicing, merging, ratifying, and rescanning modify shared state (feature branch, parent issue). Only one sub-agent per parent for these.
- **Parallel is the default for implementation.** Unrelated slices tagged `to-implement` should be dispatched simultaneously.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the tag is still set.
