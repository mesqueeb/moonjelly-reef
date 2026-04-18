# slice

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, read and follow [setup.md](setup.md) first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill accepts:

- a specific issue: e.g. `#42` or `my-feature`
- nothing: look for items tagged `to-slice`. If multiple, ask the user to pick. If none, explain that items need to be scoped first and suggest `/reef-scope`.

Read the issue. It must contain a plan with success criteria (from reef-scope). Success criteria are plan-level; this skill breaks them into **acceptance criteria** per slice. The plan metadata block tells you the work type, base branch, and target branch name.

## 1. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Slicing rules:

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- For refactors: slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.

For small bugs (scope = quick fix in the plan): produce a single slice. The plan's success criteria become the slice's acceptance criteria directly.

## Single-slice fast path

After drafting, check: **did you produce exactly 1 slice?**

If yes, take the fast path — skip the target branch, sub-issues, coverage matrix, and ratify. The plan becomes the slice:

1. **Target branch = base branch.** Do not create a new branch. Set `Target branch` to the same value as `Base branch` in the plan context.
2. **No sub-issues.** The plan IS the slice.
3. **Write acceptance criteria on the plan.** Append an `## Acceptance criteria` section to the plan body with the criteria you drafted for the single slice. Also append a `## Plan context` section with the base branch, target branch (= base branch), and type.
4. **No coverage matrix.** Success criteria and acceptance criteria are 1:1 — the mapping adds no information.
5. **Tag `to-implement`.** Change the plan label from `to-slice` to `to-implement`. Do NOT use `in-progress`.
6. **Report and exit.** "Single slice — fast path. Plan is the slice. Tagged `to-implement`, targeting {base-branch} directly. Run `/reef-pulse` to kick it off."

If you drafted **2+ slices**, continue with the multi-slice flow below.

## 2. Create the target branch (multi-slice)

Read the base branch and target branch name from the plan metadata.

```sh
WORKTREE=$(reef-worktree-enter.sh \
  --base-branch {base-branch} --target-branch {target-branch} \
  --phase slice --slice {title} \
  --slice-branch {target-branch} --branch-op create)
cd "$WORKTREE"
git push -u origin {target-branch}
```

If the plan says to work on the current branch (no new target branch), use this alternative instead — skip the branch creation but still create a worktree to read the codebase:

```sh
WORKTREE=$(reef-worktree-enter.sh \
  --base-branch {base-branch} --target-branch {target-branch} \
  --phase slice --slice {title})
cd "$WORKTREE"
```

## 3. Build the coverage matrix

For each success criterion in the plan, map it to which slice(s) and which acceptance criterion/criteria cover it.

```markdown
## Coverage Matrix

| Success Criterion                    | Slice                                | Acceptance Criteria                                           |
| ------------------------------------ | ------------------------------------ | ------------------------------------------------------------- |
| SC1: Users can log in with email     | 001 Auth endpoint                    | AC1: POST /login returns token, AC2: invalid creds return 401 |
| SC2: Session persists across refresh | 002 Token storage                    | AC1: token stored in httpOnly cookie                          |
| SC3: Legacy UI renders identically   | 001 Auth endpoint, 003 Legacy compat | AC3: response format matches legacy schema                    |
```

**Verify completeness**: every success criterion must appear in at least one row. If any criterion is uncovered, either add it to an existing slice's acceptance criteria or create a new slice. Do not proceed with gaps. (Prevents painpoint A3.)

## 4. Verify the breakdown

Before creating slices, verify internally:

- Is the granularity reasonable? (prefer many thin slices over few thick ones)
- Are the dependency relationships correct? Are there implicit deps not captured?
- Does every success criterion appear in the coverage matrix?

If anything looks off, adjust the breakdown. Do not ask the user — reef-scope already iterated with the user on the plan. Your job is to slice it mechanically.

## 5. Create slices

Read the config to determine tracker type.

### GitHub tracker

Create sub-issues with `gh issue create`. Create them in dependency order (blockers first) so you can reference real issue numbers in `blocked-by`.

Each sub-issue body:

```markdown
## Plan

#{plan-issue-number}

## Plan context

- **Target branch**: {target-branch}
- **Base branch**: {base-branch}
- **Type**: {feature/refactor/bug}
- **Plan**: #{plan-issue-number}

## What to build

{description of this vertical slice — end-to-end behavior, not layer-by-layer}

## Acceptance criteria

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}

## Blocked by

- #{issue-number} {title} (or "None — can start immediately")

## Success criteria covered

- Success criterion {n}: {criterion text}
```

Label each slice: `to-implement` if no blockers, `to-await-waves` if blocked.

### Local tracker

Create slice files in `{path}/{title}/slices/`:

- Unblocked: `[to-implement] 001-auth-endpoint.md`
- Blocked: `[to-await-waves] 002-token-storage.md`

Each slice file follows the same body template as the GitHub issue above, but with local file references instead of issue numbers (e.g. `Blocked by: 001-auth-endpoint`).

## 6. Update the plan

### GitHub tracker

Append the coverage matrix to the plan body. Change label from `to-slice` to `in-progress`. It will be promoted to `to-ratify` once all slices are done.

Add a comment listing all created sub-issues with their tags.

### Local tracker

Append the coverage matrix to the plan file. Rename from `[to-slice] plan.md` to `[in-progress] plan.md`. It will be renamed to `[to-ratify] plan.md` once all slices are done.

Commit and push the plan and slice files so other agents see them:

```sh
reef-worktree-commit.sh --target-branch {target-branch} -m "slice: create slices for {title}"
```

## 7. Document judgment calls

Document judgment calls made during this phase as a comment on the plan. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 8. Clean up

```sh
reef-worktree-exit.sh --path "$WORKTREE"
```

## Handoff

Report: "Slices created with acceptance criteria, dependency graph, and coverage matrix. Unblocked slices are tagged `to-implement` and ready for implementation. Run `/reef-pulse` to kick them all off."
