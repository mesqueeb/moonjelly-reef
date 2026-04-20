# await-waves

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If deps are done, promote. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/002-token-storage`.

Read the slice. It must have a `blocked-by` list referencing other slices.

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
TARGET_BRANCH="{from slice/plan body}"
WORKTREE_PATH=".worktrees/$SLICE_NAME-await-waves"
```

## 1. Check dependencies

For each dependency in the `blocked-by` list, check if the blocking slice is tagged `done`:

```sh
DEPENDENCY_ID="{from slice blocked-by list}"
```

```sh
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

**If any dependency is NOT done**: this slice stays `to-await-waves`. Skip to the handoff with `nextPhase: "to-await-waves"` and `summary: "still blocked by #N, #M"`.

**If ALL dependencies are done**: continue to step 2.

## 2. Re-review the plan

Enter a worktree forked from $TARGET_BRANCH to be able to read up to date code (earlier slices may have changed the codebase):

```sh
./worktree-enter.sh --fork-from "$TARGET_BRANCH" --path "$WORKTREE_PATH"
```

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
nextPhase="to-implement"
planPr="—"
summary="Slice {name} is unblocked and ready for implementation"
```

Report these three variables to the caller.
