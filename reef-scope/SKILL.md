---
name: reef-scope
description: Scope a work item into a plan with success criteria. Routes between feature, refactor, and bug approaches. The single entry point for turning ideas into plans.
---

# reef-scope

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-pulse` and follow `reef-pulse/setup.md` first, then return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-pulse/tracker-reference.md).

## Input

This skill accepts:

- A specific work item: `/reef-scope #42` or `/reef-scope my-feature`
- Nothing: look for items tagged `to-scope`. If multiple, ask the user to pick. If none, ask: "Did you want to scope something new?"

Read the work item.

## 1. Write the plan

Read the issue and any existing decision record. Assess: is this a **feature**, **refactor**, or **bug**? Then follow the type-specific guide.

- **Feature**: see [scope-feature.md](scope-feature.md)
- **Refactor**: see [scope-refactor.md](scope-refactor.md)
- **Bug**: see [triage-issue.md](triage-issue.md)

## 2. Branch strategy

Discuss with the user:

> "What branch should we work off of? Some options:"
>
> - "Create a new work branch from `main` (e.g. `reef/my-feature`)"
> - "Work off the current branch (`branch-name`)"
> - "Something else?"

Also ask what the work branch should be called if creating one. Don't enforce naming — just capture the decision.

This gets documented in the plan so every downstream phase knows where to branch from and where PRs target.

## 3. Persist the plan

The plan gets **prepended** to the evolving file (pushing the decision record down). The decision record remains at the bottom for reference.

### GitHub tracker

1. Read the current issue body (which contains the decision record).
2. Prepend the plan above the decision record. Use `gh issue edit <number> --body "..."`.
3. Change the parent issue label from `to-scope` to `to-slice`.

### Local tracker

1. Read the current file (e.g. `{path}/{title}/[to-scope] plan.md`).
2. Prepend the plan above the decision record content.
3. Rename to `[to-slice] plan.md`.

### Plan metadata

At the top of the plan, include a metadata block that downstream skills will read:

```markdown
| Field          | Value                    |
| -------------- | ------------------------ |
| Type           | feature / refactor / bug |
| Base branch    | main                     |
| Work branch    | reef/my-feature          |
```

## Handoff

Tell the user:

> "Plan with success criteria saved. Run `/reef-pulse` to let the reef take it from here."
