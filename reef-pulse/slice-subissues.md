# slice-subissues

Multi-slice flow — delegated from [slice.md](slice.md).

## Input (from context)

Context already fetched by `slice.md`.

```sh
ISSUE_ID="{from context}"           # e.g. "#42"
PR_BRANCH="{from context}"          # e.g. "feat/my-feature"
BASE_BRANCH="{from context}"        # e.g. "main"
HEADING="{from context}"            # e.g. "feature" — already resolved, never "feeling-lucky"
FEELING_LUCKY="{from context}"      # e.g. "true"
ISSUE_BODY_UPDATED="{from context}" # plan body with frontmatter already cleaned up
WORKTREE_PATH=".worktrees/$ISSUE_ID-slice"
```

## 1. Git prep

This is non-negotiable. Enter a worktree with the exact command below:

```sh
# Worktree gives a clean view of $BASE_BRANCH without switching branches in the main checkout — needed for reading fresh code and for initialising $PR_BRANCH.
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH") # e.g. "ready"
```

Read the output. On `ready`: continue.

If `$PR_BRANCH` does not exist on origin yet, initialise it:

```sh
# Not a commit — creates the remote branch pointer at the current HEAD
git push origin "HEAD:refs/heads/$PR_BRANCH"
```

## 2. Build the coverage matrix

For each User Story, Implementation Decision, and Testing Decision in the plan, map it to which slice(s) cover it and which acceptance criterion in that slice addresses it.

Architectural or non-testable implementation decisions that have no direct implementation output should be noted as "covered by design" in the Acceptance Criteria column.

<coverage-matrix-template>

## Coverage Matrix 🗺️

| Plan Item                                                                    | Slice                                | Acceptance Criteria                                 |
| ---------------------------------------------------------------------------- | ------------------------------------ | --------------------------------------------------- |
| User Story 1: Users can log in with email                                    | 001 Auth endpoint                    | POST /login returns token; invalid creds return 401 |
| Testing Decision 1: Session persists across refresh                          | 002 Token storage                    | token stored in httpOnly cookie                     |
| Implementation Decision 1: Legacy UI renders identically (covered by design) | 001 Auth endpoint, 003 Legacy compat | covered by design                                   |

</coverage-matrix-template>

**Verify completeness**: every plan item must appear in at least one row. If any item is uncovered, either add it to an existing slice's acceptance criteria or create a new slice. Do not proceed with gaps. (Prevents painpoint A3.)

## 3. Verify the breakdown

Verify internally:

- Is the granularity reasonable? (prefer many thin slices over few thick ones)
- Are the dependency relationships correct? Are there implicit deps not captured?
- Does every User Story, Implementation Decision, Testing Decision, and Research Question appear in the coverage matrix?

If anything looks off, adjust the breakdown. Do not ask the diver — reef-scope already iterated with the diver on the plan. Your job is to slice it mechanically.

## 4. Create slices

Create them in dependency order (blockers first) so you can reference real issue numbers in the `[await: ...]` title suffix.

Assemble each slice body:

Set `UNBLOCKED` based on whether this slice has any blocking dependencies in the plan:

```sh
SLICE_HAS_BLOCKERS="{true if this slice has blocking dependencies, false otherwise}" # e.g. "false"
if [ "$SLICE_HAS_BLOCKERS" = "false" ]; then
  UNBLOCKED=true
  SLICE_TITLE="{slice-title}" # e.g. "002 Token storage"
else
  UNBLOCKED=false
  SLICE_TITLE="{slice-title} [await: #{blocker-id}]" # e.g. "002 Token storage [await: #43]"
fi
SLICE_HEADING="{per-slice heading, usually $HEADING unless a slice needs a narrower inferred lane}" # e.g. "feature"
if [ "$UNBLOCKED" = "true" ] && [ "$SLICE_HEADING" = "deep-research" ]; then
  SLICE_LABEL="to-research"
elif [ "$UNBLOCKED" = "true" ]; then
  SLICE_LABEL="to-implement"
else
  SLICE_LABEL="to-await-waves"
fi
SLICE_PR_BRANCH="{derived from parent issue pr-branch + slice title slug}" # e.g. "feat/my-feature-002-token-storage"
```

If `"$FEELING_LUCKY" = "true"`, use best-effort acceptance criteria without bouncing the work back to scope. For deep-research slices, make them research-native: use research questions or investigation angles as the slice descriptions, and write acceptance criteria around what must be answered, clarified, or persisted.

Slice body template:

<slice-body-template>
## What to build

{description of this vertical slice — end-to-end behavior, not layer-by-layer}

## Acceptance criteria

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] {criterion 3}

</slice-body-template>

Create the slice:

```sh
SLICE_BODY="---
parent-issue: \"$ISSUE_ID\"
base-branch: \"$PR_BRANCH\"
pr-branch: \"$SLICE_PR_BRANCH\"
heading: \"$SLICE_HEADING\"

---

{<slice-body-template> with content filled in}"
./tracker.sh issue create --title "$SLICE_TITLE" --body "$SLICE_BODY" --label "$SLICE_LABEL"
```

## 5. Update the plan

Starting from `$ISSUE_BODY_UPDATED`, append the coverage matrix and a listing of all created sub-issues with their labels. Change label from `to-slice` to `in-progress`.

```sh
PARENT_ISSUE_BODY_UPDATED="{$ISSUE_BODY_UPDATED with pr-branch in frontmatter and coverage matrix appended}" # e.g. "---\nparent-issue: ...\n---\n\n## Coverage Matrix 🗺️\n\n..."
./tracker.sh issue edit "$ISSUE_ID" --body "$PARENT_ISSUE_BODY_UPDATED" --remove-label to-slice --add-label in-progress
```

## 6. Document judgment calls

Post a comment on the parent issue with this structure:

<judgment-calls-template>

### Judgment calls

- **{topic}**: chose {X} because {reason}. Differs from plan: {difference, if any}.

(If none, write "None.")

</judgment-calls-template>

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
