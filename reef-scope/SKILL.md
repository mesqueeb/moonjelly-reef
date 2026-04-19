---
name: reef-scope
description: Scope an issue into a plan with success criteria. Routes between feature, refactor, and bug approaches. The single entry point for turning ideas into plans.
---

# reef-scope

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, run `/reef-pulse` and follow `reef-pulse/setup.md` first, then return here after.

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

## Input

This skill accepts:

- a specific issue: `/reef-scope #42` or `/reef-scope my-feature`
- Nothing: look for items tagged `to-scope`. If multiple, ask the user to pick. If none, ask: "Did you want to scope something new?"

Set the initial variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

## 0. Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

## 1. Git prep

```sh
git fetch origin --prune
```

Check if the current branch is behind its remote counterpart. If it is, notify the user:

> "{branch-name} is {N} commits behind origin. Want me to pull first?"

Wait for the user's response before continuing.

## 2. Write the plan

Read the issue and any existing decision record. Assess: is this a **feature**, **refactor**, or **bug**? Then follow the type-specific guide.

- **Feature**: see [scope-feature.md](scope-feature.md)
- **Refactor**: see [scope-refactor.md](scope-refactor.md)
- **Bug**: see [triage-issue.md](triage-issue.md)

## 3. Branch strategy

Discuss with the user:

> "What branch should we work off of? Some options:"
>
> - "Create a new target branch from `main` (e.g. `reef/my-feature`)"
> - "Work off the current branch (`branch-name`)"
> - "Something else?"

Also ask what the target branch should be called if creating one. Don't enforce naming — just capture the decision.

This gets documented in the plan so every downstream phase knows where to branch from and where PRs target.

## 4. Persist the plan

The plan gets **prepended** to the evolving file (pushing the decision record down) which becomes our PLAN_CONTENT variable. The decision record remains at the bottom for reference.

At the top of the plan content, include a metadata block that downstream phases will read:

```sh
BASE_BRANCH=$BASE_BRANCH
TARGET_BRANCH=$TARGET_BRANCH
```

Set variables from the discussion:

```sh
PLAN_ID = $ISSUE_ID
PLAN_TITLE = {plan-title} # as per discussion context
BASE_BRANCH = {base-branch} # as per discussion context
TARGET_BRANCH = {target-branch} # as per discussion context
PLAN_CONTENT = {plan-content} # as per discussion context
WORKTREE_PATH = ../worktree-$PLAN_ID-scope
```

```sh
tracker.sh issue edit $PLAN_ID --body "$PLAN_CONTENT" --remove-label to-scope --add-label to-slice
```

## Handoff

Tell the user:

> "Plan with success criteria saved. Run `/reef-pulse` to let the reef take it from here."
