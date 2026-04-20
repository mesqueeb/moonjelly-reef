# slice-multi

Multi-slice flow — delegated from [slice.md](slice.md).

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input (from router)

The router has already fetched context and drafted 2+ slices. Set post-fetch variables:

```sh
PLAN_ID="$ISSUE_ID"
TARGET_BRANCH="{from plan body}"
BASE_BRANCH="{from plan body}"
PLAN_TYPE="{from plan body}" # feature, refactor, or bug
WORKTREE_PATH=".worktrees/$PLAN_ID-slice"
```

## 1. Enter worktree

Enter a worktree forked from $TARGET_BRANCH to read the codebase for informed slicing decisions:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$TARGET_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$PLAN_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

If the target branch does not exist on origin yet, create it:

```sh
git push -u origin "$TARGET_BRANCH"
```

If the plan says to work on the current branch (no new target branch), skip the branch creation but still create a worktree to read the codebase.

## 2. Build the coverage matrix

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

## 3. Verify the breakdown

Before creating slices, verify internally:

- Is the granularity reasonable? (prefer many thin slices over few thick ones)
- Are the dependency relationships correct? Are there implicit deps not captured?
- Does every success criterion appear in the coverage matrix?

If anything looks off, adjust the breakdown. Do not ask the user — reef-scope already iterated with the user on the plan. Your job is to slice it mechanically.

## 4. Create slices

Create them in dependency order (blockers first) so you can reference real issue numbers in `blocked-by`.

Assemble each slice body:

```sh
SLICE_TITLE="{slice-title}"
SLICE_BODY="{slice-body}" # as per the template below
SLICE_LABEL="to-implement" # or to-await-waves if blocked
```

Slice body template:

```markdown
---
parent-plan: "#$PLAN_ID"
base-branch: $BASE_BRANCH
target-branch: $TARGET_BRANCH
type: $PLAN_TYPE

---

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

Create the slice:

```sh
./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
```

Label each slice: `to-implement` if no blockers, `to-await-waves` if blocked.

## 5. Update the plan

Append the coverage matrix and a listing of all created sub-issues with their tags to the plan body. Change label from `to-slice` to `in-progress`. It will be promoted to `to-ratify` once all slices are done.

```sh
PLAN_BODY="{plan body with coverage matrix appended}"
```

```sh
./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-slice --add-label in-progress
```

## 6. Document judgment calls

Document judgment calls made during this phase as a comment on the plan. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 7. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
nextPhase="in-progress"
planPr="—"
summary="Slices created with acceptance criteria, dependency graph, and coverage matrix"
```

Report these three variables to the caller.
