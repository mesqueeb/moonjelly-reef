---
name: reef-finalise
description: Present the final report to the human for review. Human approves (merge to main), requests changes, or sends back for re-probing. Use when a work item is tagged to-finalise.
---

# reef-finalise

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

## Input

This skill requires a specific work item: `/reef-finalise #42` or `/reef-finalise my-feature`.

Read the parent plan to find the feature branch PR (created by reef-ratify). Read the final report on that PR.

## Present the report

Show the human:

1. **The final report** from the feature branch PR — success criteria status, agent decisions to review, integration notes, test results, screenshots if any.
2. **A summary**: "The reef processed {N} slices across {M} rounds. {X} ambiguous decisions were made by agents. Here's what you need to know before merging."
3. **The PR link**: so the human can read the full diff if they want.

## Human decides

Present three options:

> **1. Approve** — merge the feature branch into {base-branch} and close the work item.
>
> **2. Request changes (needs new decisions)** — something fundamental is off and we need to rethink. → Tags `to-scope` for a new scoping session.
>
> **3. Request changes (acceptance criteria are clear)** — specific gaps remain but we know what to fix. → Tags `to-rescan` for new slices.

Wait for the human's choice.

### If approved

```sh
gh pr merge {feature-pr-number} --merge --delete-branch
```

Use a regular merge (not squash) for the feature branch so the slice history is preserved.

### GitHub tracker

Close the parent issue with `gh issue close`. Add a final comment: "Merged to {base-branch}. All success criteria met."

### Local tracker

Rename parent to `[done] plan.md`. Optionally move the folder to an `archive/` or `done/` directory if the user prefers.

### If re-scope

### GitHub tracker

Change the parent issue label to `to-scope`. Remove `to-finalise`.

### Local tracker

Rename parent to `[to-scope] plan.md`.

### If re-scan

### GitHub tracker

Change the parent issue label to `to-rescan`. Remove `to-finalise`.

### Local tracker

Rename parent to `[to-rescan] plan.md`.
