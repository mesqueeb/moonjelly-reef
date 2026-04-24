# slice-subissues

Multi-slice flow — delegated from [slice.md](slice.md).

## Input (from context)

```sh
ISSUE_ID="{from context}"           # e.g. "#42"
PR_BRANCH="{from plan issue body pr-branch field}"
BASE_BRANCH="{from plan issue body}"
BEARING="{from plan issue body bearing field}"
FEELING_LUCKY="{from context}"      # e.g. "true"
ISSUE_BODY_UPDATED="{from context}" # plan body with frontmatter already cleaned up
WORKTREE_PATH=".worktrees/$ISSUE_ID-slice"
```

## 1. Enter worktree

Enter a worktree forked from `$BASE_BRANCH` to read the codebase for informed slicing decisions:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$PR_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="—"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

If `$PR_BRANCH` does not exist on origin yet, create it:

```sh
git push -u origin "$PR_BRANCH"
```

If the plan says to work on the current branch (no new `pr-branch`), skip the branch creation but still create a worktree to read the codebase.

## 2. Build the coverage matrix

For each item in `## What does done look like`, map it to which slice(s) and which acceptance criterion/criteria cover it. The agent infers the correct enumerable source from the prose in `## What does done look like` (user stories for features, commits for refactors, research questions for deep-research).

```markdown
## Coverage Matrix

| Done-looks-like item                 | Slice                                | Acceptance Criteria                                           |
| ------------------------------------ | ------------------------------------ | ------------------------------------------------------------- |
| Users can log in with email          | 001 Auth endpoint                    | AC1: POST /login returns token, AC2: invalid creds return 401 |
| Session persists across refresh      | 002 Token storage                    | AC1: token stored in httpOnly cookie                          |
| Legacy UI renders identically        | 001 Auth endpoint, 003 Legacy compat | AC3: response format matches legacy schema                    |
```

**Verify completeness**: every item from `## What does done look like` must appear in at least one row. If any item is uncovered, either add it to an existing slice's acceptance criteria or create a new slice. Do not proceed with gaps. (Prevents painpoint A3.)

## 3. Verify the breakdown

Verify internally:

- Is the granularity reasonable? (prefer many thin slices over few thick ones)
- Are the dependency relationships correct? Are there implicit deps not captured?
- Does every item from `## What does done look like` appear in the coverage matrix?

If anything looks off, adjust the breakdown. Do not ask the user — reef-scope already iterated with the user on the plan. Your job is to slice it mechanically.

## 4. Create slices

Create them in dependency order (blockers first) so you can reference real issue numbers in the `[await: ...]` title suffix.

Assemble each slice body:

Set `UNBLOCKED` based on whether this slice has any blocking dependencies in the plan:

```sh
if [ "{slice has no blockers}" = "true" ]; then
  UNBLOCKED=true
  SLICE_TITLE="{slice-title}" # e.g. "002 Token storage"
else
  UNBLOCKED=false
  SLICE_TITLE="{slice-title} [await: #{blocker-id}]"  # omit [await: ...] if unblocked
fi
```

```sh
SLICE_PR_BRANCH="{derived from plan issue pr-branch + slice title slug}"
SLICE_BEARING="{per-slice bearing, usually $BEARING unless a slice needs a narrower inferred lane}"
SLICE_BODY="{slice-body}" # as per the template below, with pr-branch: $SLICE_PR_BRANCH and bearing: $SLICE_BEARING
SLICE_LABEL="{to-research for unblocked deep-research slices, otherwise to-implement; or to-await-waves if blocked}"
```

If `"$FEELING_LUCKY" = "true"`, use best-effort acceptance criteria without bouncing the work back to scope. For deep-research slices, make them research-native: use research questions or investigation angles as the slice descriptions, and write acceptance criteria around what must be answered, clarified, or persisted.

Slice body template:

```markdown
---
parent-issue: "#$ISSUE_ID"
base-branch: $PR_BRANCH
pr-branch: $SLICE_PR_BRANCH
bearing: $SLICE_BEARING

---

## What to build

{description of this vertical slice — end-to-end behavior, not layer-by-layer}

## Acceptance criteria

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}
```

Create the slice:

```sh
./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
```

## 5. Update the plan

Starting from `$ISSUE_BODY_UPDATED`, append the coverage matrix and a listing of all created sub-issues with their labels. Change label from `to-slice` to `in-progress`.

```sh
ISSUE_BODY="{plan issue body with pr-branch in frontmatter and coverage matrix appended}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-slice --add-label in-progress
```

## 6. Document judgment calls

Document judgment calls made during this phase as a comment on the plan. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 7. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="in-progress"
PR_ID="—"
SUMMARY="Slices created with acceptance criteria, dependency graph, and coverage matrix"
```

Report these variables to the caller.
