# await-waves

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If deps are done, promote. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/002-token-storage`.

Read the slice. It must have a `blocked-by` frontmatter field referencing other slices (comma-separated issue IDs, e.g. `blocked-by: "#55, #56"`).

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the slice body):

```sh
SLICE_NAME="{from slice body}"
SLICE_ID="$ISSUE_ID"
BASE_BRANCH="{from slice/plan body}"
TARGET_BRANCH="{from slice/plan body}"
WORKTREE_PATH=".worktrees/$SLICE_NAME-await-waves"
```

## 1. Check dependencies

Parse the `blocked-by` field from the slice's frontmatter. For each dependency ID, check if the blocking slice is tagged `landed`:

```sh
DEPENDENCY_ID="{from frontmatter blocked-by field}"
```

```sh
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

**If any dependency does NOT have the `landed` label**: this slice stays `to-await-waves`. Skip to the handoff with `nextPhase: "to-await-waves"` and `summary: "still blocked by #N, #M"`.

**If ALL dependencies have the `landed` label**: continue to step 2.

## 2. Re-review the plan

Enter a worktree forked from $TARGET_BRANCH to be able to read up to date code (earlier slices may have changed the codebase):

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$TARGET_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$TARGET_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$SLICE_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

Earlier slices may have changed the codebase. Read this slice's acceptance criteria and compare against the current state of the code:

- Did earlier slices introduce interfaces, modules, or conventions this slice should use?
- Did earlier slices rename or restructure anything that affects this slice's approach?
- Are any of this slice's acceptance criteria already partially satisfied by earlier work?

**If the plan still holds**: no changes needed.

**If adjustments needed**: update the slice's acceptance criteria and description to reflect the current reality. Be specific about what changed and why.

```sh
SLICE_BODY="{slice body, with updated acceptance criteria if changed}"
```

```sh
./tracker.sh issue edit "$SLICE_ID" --body "$SLICE_BODY"
```

## 3. Promote

```sh
./tracker.sh issue edit "$SLICE_ID" --remove-label to-await-waves --add-label to-implement
```

## 4. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
nextPhase="to-implement" # or "to-await-waves" if still blocked
planPr="—"
summary="Slice {name} is unblocked and ready for implementation" # or "still blocked by #N, #M"
```

Report these three variables to the caller.
