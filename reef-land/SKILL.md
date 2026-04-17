---
name: reef-land
description: Present the final report to the human for review. Human approves (merge to main), requests changes, or sends back for re-probing. Use when a work item is tagged to-land.
---

# reef-land

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-pulse/tracker-reference.md).

## Input

This skill requires a specific work item: `/reef-land #42` or `/reef-land my-feature`.

Read the parent plan. Find the open PR associated with this work item — either a single-slice PR targeting the base branch, or a work branch PR targeting the base branch (created during the ratify phase).

## Present the report

Show the human:

1. **The PR link**: so the human can read the full diff.
2. **A summary**: what happened — how many slices, any ambiguous agent decisions, test results.
3. **The success/acceptance criteria** from the parent issue, with their status.

## Human decides

Present three options:

> **1. Approve** — merge the work branch into {base-branch} and close the work item.
>
> **2. Request changes (needs new decisions)** — something fundamental is off and we need to rethink. → Tags `to-scope` for a new scoping session.
>
> **3. Request changes (acceptance criteria are clear)** — specific gaps remain but we know what to fix. → Tags `to-rescan` for new slices.

Wait for the human's choice.

### If approved

Merge the PR:

```sh
gh pr merge {pr-number} --merge --delete-branch
```

### GitHub tracker

Close the parent issue with `gh issue close`. Add a final comment: "Merged to {base-branch}. All success criteria met."

### Local tracker

Rename parent to `[done] plan.md`. Optionally move the folder to an `archive/` or `done/` directory if the user prefers.

### If re-scope

### GitHub tracker

Change the parent issue label to `to-scope`. Remove `to-land`.

### Local tracker

Rename parent to `[to-scope] plan.md`.

### If re-scan

### GitHub tracker

Change the parent issue label to `to-rescan`. Remove `to-land`.

### Local tracker

Rename parent to `[to-rescan] plan.md`.
