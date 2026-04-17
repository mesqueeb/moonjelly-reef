---
name: reef-slice
description: Break a scoped plan into vertical slices with acceptance criteria, dependency graph, and coverage matrix. Creates the feature branch. Use when a work item is tagged to-slice.
---

# reef-slice

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-setup` first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

## Input

This skill accepts:

- A specific work item: `/reef-slice #42` or `/reef-slice my-feature`
- Nothing: look for items tagged `to-slice`. If multiple, ask the user to pick. If none, explain that items need to be scoped first and suggest `/reef-scope`.

Read the work item. It must contain a plan with success criteria (from reef-scope). The plan metadata block tells you the work type, base branch, and feature branch name.

## 1. Create the feature branch

Read the base branch and feature branch name from the plan metadata.

```sh
git fetch origin
git checkout -b {feature-branch} origin/{base-branch}
git push -u origin {feature-branch}
```

If the plan says to work on the current branch (no new feature branch), skip this step. Note that slice PRs will target whatever branch is documented in the plan metadata.

## 2. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Reference disciplines from: prd-to-issues (vertical slice rules, HITL/AFK classification, blocked-by graph), prd-to-plan (phased approach, durable decisions).

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- For refactors: slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.

For small bugs (scope = quick fix in the plan): produce a single slice. The plan's acceptance criteria become the slice's acceptance criteria directly. Skip the coverage matrix.

## 3. Build the coverage matrix

For each success criterion in the plan, map it to which slice(s) and which acceptance criterion/criteria cover it.

```markdown
## Coverage Matrix

| Success Criterion | Slice | Acceptance Criteria |
| --- | --- | --- |
| SC1: Users can log in with email | 001 Auth endpoint | AC1: POST /login returns token, AC2: invalid creds return 401 |
| SC2: Session persists across refresh | 002 Token storage | AC1: token stored in httpOnly cookie |
| SC3: Legacy UI renders identically | 001 Auth endpoint, 003 Legacy compat | AC3: response format matches legacy schema |
```

**Verify completeness**: every success criterion must appear in at least one row. If any criterion is uncovered, either add it to an existing slice's ACs or create a new slice. Do not proceed with gaps. (Prevents painpoint A3.)

## 4. Present to user and iterate

Present the proposed breakdown. For each slice, show:

- **Number + title**: e.g. `001 — Auth endpoint`
- **Acceptance criteria**: the specific testable conditions
- **Blocked by**: which slices must complete first (or "none")
- **Success criteria covered**: which SCs from the plan this addresses

Then show the coverage matrix.

Ask:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct? Any implicit deps I missed?
- Should any slices be merged or split?

Iterate until the user approves.

## 5. Create slices

Read the config to determine tracker type.

### GitHub tracker

Create sub-issues with `gh issue create`. Create them in dependency order (blockers first) so you can reference real issue numbers in `blocked-by`.

Each sub-issue body:

```markdown
## Parent

#{parent-issue-number}

## Plan context

- **Feature branch**: {feature-branch}
- **Base branch**: {base-branch}
- **Type**: {feature/refactor/bug}
- **Parent plan**: #{parent-issue-number}

## What to build

{description of this vertical slice — end-to-end behavior, not layer-by-layer}

## Acceptance criteria

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}

## Blocked by

- #{issue-number} {title} (or "None — can start immediately")

## Success criteria covered

- SC{n}: {criterion text}
```

Label each slice: `to-implement` if no blockers, `to-await-waves` if blocked.

### Local tracker

Create slice files in `{path}/{title}/slices/`:

- Unblocked: `[to-implement] 001-auth-endpoint.md`
- Blocked: `[to-await-waves] 002-token-storage.md`

Each slice file follows the same body template as the GitHub issue above, but with local file references instead of issue numbers (e.g. `Blocked by: 001-auth-endpoint`).

## 6. Update the parent

### GitHub tracker

Append the coverage matrix to the parent issue body. Update the label from `to-slice` to reflect that slicing is done (remove `to-slice` — the parent's next transition happens when all slices are `done`, at which point reef-merge tags it `to-ratify`).

Add a comment listing all created sub-issues with their tags.

### Local tracker

Append the coverage matrix to `[to-slice] plan.md`. Rename the tag — the parent file stays as-is until reef-merge promotes it to `[to-ratify]` when all slices are done.

## Handoff

Tell the user:

> "Slices created with acceptance criteria, dependency graph, and coverage matrix. Unblocked slices are tagged `to-implement` and ready for `/reef-implement`. Run `/reef-pulse` to kick them all off."
