---
name: reef-pulse
description: The Moonjelly Reef orchestrator. A single pulse that scans all work items by tag, dispatches reef skills as sub-agents, and exits. Run manually or as a cron.
---

# reef-pulse

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, read and follow [setup.md](setup.md) first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

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
gh issue list --label "to-scope" --json number,title --limit 100
gh issue list --label "to-slice" --json number,title --limit 100
gh issue list --label "to-await-waves" --json number,title --limit 100
gh issue list --label "to-implement" --json number,title --limit 100
gh issue list --label "to-inspect" --json number,title --limit 100
gh issue list --label "to-rework" --json number,title --limit 100
gh issue list --label "to-merge" --json number,title --limit 100
gh issue list --label "to-ratify" --json number,title --limit 100
gh issue list --label "to-rescan" --json number,title --limit 100
gh issue list --label "to-land" --json number,title --limit 100
```

Run these queries in parallel where possible for performance.

### Local tracker

Read the local path from config. Scan all work item folders for tagged files:

- Parent plan files: look for `[to-*] plan.md` pattern
- Slice files: look for `[to-*] *.md` in `slices/` subfolders

### Step 2. Dispatch automated (🌊) work

**Do NOT ask the user for confirmation. Dispatch immediately.** The tags are the authorization — if an item is tagged for automated work, dispatch it without hesitation.

For each item found, dispatch the corresponding phase as a sub-agent. Use the Agent tool. Items that share no dependencies can be dispatched **in parallel**.

Dispatch by telling sub-agents to read and follow a specific file:

> "Read and follow the instructions in `reef-pulse/implement.md`. Your target is #55."

| Tag | File | Notes |
| --- | --- | --- |
| `to-slice` | [slice.md](slice.md) | One at a time per parent (creates feature branch + sub-issues) |
| `to-await-waves` | [await-waves.md](await-waves.md) | Parallel OK — each is independent |
| `to-implement` | [implement.md](implement.md) | Parallel OK for unrelated slices. Slices within the same parent may be dispatched as an **agent team** if multiple are ready |
| `to-inspect` | [inspect.md](inspect.md) | Parallel OK |
| `to-rework` | [rework.md](rework.md) | Parallel OK |
| `to-merge` | [merge.md](merge.md) | One at a time per parent (modifies feature branch) |
| `to-ratify` | [ratify.md](ratify.md) | One at a time per parent |
| `to-rescan` | [rescan.md](rescan.md) | One at a time per parent |

When dispatching, pass the item reference as a parameter: e.g. "Read and follow `reef-pulse/implement.md`. Target: #55."

**When to use agent teams vs sub-agents for `to-implement`:**

- **1-2 slices ready**: use regular sub-agents (Agent tool). Dispatch `reef-pulse/implement.md` for each with the slice reference.
- **3+ slices ready from the same parent**: use an agent team. Each teammate claims a slice and follows `reef-pulse/implement.md` with its slice reference. The instructions handle worktree setup, PR creation, and reporting — just pass the slice reference.

### Step 3. Present human (🤿) items (--hitl only)

If running in `--hitl` mode, present human-required items:

| Tag | Skill | Presentation |
| --- | --- | --- |
| `to-scope` | `/reef-scope` | "**{title}** needs scoping. Run `/reef-scope #{number}`." |
| `to-land` | `/reef-land` | "**{title}** is ready for your final review. Run `/reef-land #{number}`." |

> Note: reef-scope and reef-land remain user-facing skills invoked via slash commands. Only the automated (🌊) phases are dispatched via file references.

If running in `--afk` mode, skip this step entirely.

### Step 4. Report and exit

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

Exit.

## Design principles

These are reminders for the LLM executing this skill, not documentation:

- **You are stateless.** You scan tags, dispatch skills, and exit. You do not track what you dispatched last time. Tags are the state.
- **Don't do the work yourself.** You dispatch skills. You never implement, review, or merge directly.
- **Respect one-at-a-time constraints.** Slicing, merging, ratifying, and rescanning modify shared state (feature branch, parent issue). Only one sub-agent per parent for these.
- **Parallel is the default for implementation.** Unrelated slices tagged `to-implement` should be dispatched simultaneously.
- **If a dispatch fails, don't retry.** Report the failure in the summary and move on. The next pulse will pick it up if the tag is still set.
