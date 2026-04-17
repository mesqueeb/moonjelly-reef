---
name: reef-scope
description: Scope a probed work item into a plan with success criteria. Routes between feature, refactor, and bug approaches. Use when a work item is tagged to-scope, or directly after reef-probe.
---

# reef-scope

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-setup` first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

## Input

This skill accepts:

- A specific work item: `/reef-scope #42` or `/reef-scope my-feature`
- Nothing: look for items tagged `to-scope`. If multiple, ask the user to pick. If none, ask: "Did you want to scope something new?" and route to `/reef-probe`.

Read the work item. It must contain a probe session (from reef-probe). If there's no probe session, tell the user and route to `/reef-probe`.

## 1. Determine the type of work

Read the probe session and assess: is this a **feature**, **refactor**, or **bug**?

Tell the user your assessment and confirm:

> "This reads like a **refactor** — you're changing how X works without changing what it does. Sound right?"

The type determines which disciplines apply in step 3.

## 2. Branch strategy

Discuss with the user:

> "What branch should we work off of? Some options:"
> - "Create a new feature branch from `main` (e.g. `reef/my-feature`)"
> - "Work off the current branch (`branch-name`)"
> - "Something else?"

Also ask what the feature branch should be called if creating one. Don't enforce naming — just capture the decision.

This gets documented in the plan so every downstream skill knows where to branch from and where PRs target.

## 3. Write the plan

Based on the work type, produce a plan. The plan structure varies by type, but **success criteria** are mandatory for all types.

Follow the type-specific guidance:

- **Feature**: see [scope-feature.md](scope-feature.md)
- **Refactor**: see [scope-refactor.md](scope-refactor.md)
- **Bug**: see [scope-bug.md](scope-bug.md) — note: bugs require a codebase investigation BEFORE writing the plan

### Success criteria (mandatory for ALL types)

This section is the most important part of the plan. Every decision from the probe session must map to at least one success criterion.

```markdown
## Success Criteria

Testable conditions that must ALL be true for this work to be considered done.
Each criterion must be mechanically verifiable — an agent can check it by
reading code, running tests, or examining output.

1. {criterion} — verifiable by: {how}
2. {criterion} — verifiable by: {how}
...
```

Walk through every decision in the probe session's "Decisions" list. For each one, check: is there a success criterion that would catch it if it weren't implemented? If not, add one.

Also push on the consumer's perspective: if an external system, user, or downstream process depends on this work, add criteria from THEIR point of view. (Prevents painpoint A4.)

Present the success criteria to the user and confirm: "Are these the right conditions for 'done'? Anything missing?"

## 3b. Ubiquitous language (optional)

If the plan introduces domain-specific terminology, or if you notice the probe session used the same word for different concepts (or different words for the same concept), suggest running `/ubiquitous-language` to harden terms before persisting.

This is optional but valuable for larger features where multiple agents will work from this plan. Consistent terminology prevents agents from interpreting terms differently across slices.

## 4. Persist the plan

The plan gets **prepended** to the evolving file (pushing the probe session down). The probe session remains at the bottom as the decision record.

### GitHub tracker

1. Read the current issue body (which contains the probe session).
2. Prepend the plan above the probe session. Use `gh issue edit <number> --body "..."`.
3. Change label from `to-scope` to `to-slice`.

### Local tracker

1. Read the current file (e.g. `{path}/{title}/[to-scope] plan.md`).
2. Prepend the plan above the probe session content.
3. Rename to `[to-slice] plan.md`.

### Plan metadata

At the top of the plan, include a metadata block that downstream skills will read:

```markdown
| Field | Value |
| --- | --- |
| Type | feature / refactor / bug |
| Base branch | main |
| Feature branch | reef/my-feature |
```

## Handoff

Tell the user:

> "Plan with success criteria saved. Run `/reef-slice` to break this into implementable slices, or `/reef-pulse` to let the reef take it from here."
