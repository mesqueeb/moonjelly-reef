---
name: reef-land
description: Present the final report to the human for review. Human approves (merge to main), requests changes, or sends back for re-probing. Use when a issue is tagged to-land.
---

# reef-land

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI.

## Input

This skill requires a specific issue: `/reef-land #42` or `/reef-land my-feature`.

Read the plan. Find the open PR associated with this issue — either a single-slice PR targeting the base branch, or a target branch PR targeting the base branch (created during the ratify phase).

## Present the report

Show the human:

1. **The PR link**: so the human can read the full diff.
2. **A summary**: what happened — how many slices, any ambiguous agent decisions, test results.
3. **The success/acceptance criteria** from the plan, with their status.

## Human decides

Present three options:

> **1. Approve** — merge the PR into {base-branch} and close the issue.
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

Pull the merged changes into the current branch if it matches the base branch:

```sh
git fetch origin --prune
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "{base-branch}" ]; then
  git pull --ff-only origin {base-branch}
fi
```

### GitHub tracker

Close the plan with `gh issue close`. Add a final comment: "Merged to {base-branch}. All success criteria met."

### Local tracker

Rename plan to `[done] plan.md`. Optionally move the folder to an `archive/` or `done/` directory if the user prefers.

### If re-scope

### GitHub tracker

Change the plan label to `to-scope`. Remove `to-land`.

### Local tracker

Rename plan to `[to-scope] plan.md`.

### If re-scan

### GitHub tracker

Change the plan label to `to-rescan`. Remove `to-land`.

### Local tracker

Rename plan to `[to-rescan] plan.md`.
