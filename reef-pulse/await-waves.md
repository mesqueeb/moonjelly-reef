# await-waves

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If deps are done, promote. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/002-token-storage`.

Read the slice. It must have a `blocked-by` list referencing other slices.

Set the pre-fetch variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

## 0. Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

Set the post-fetch variables (after reading the slice body):

```sh
SLICE_NAME = {from slice body}
SLICE_NUMBER = $ISSUE_ID
TARGET_BRANCH = {from slice/plan body}
WORKTREE_PATH = ../worktree-$SLICE_NAME-await-waves
```

## Enter worktree

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

## 1. Check dependencies

For each dependency in the `blocked-by` list:

### GitHub tracker

Check if the blocking slice issue is tagged `done` (has the `done` label). Use `gh issue view <number>`.

### Local tracker

Check if the blocking slice file has the `[done]` prefix.

**If any dependency is NOT done**: exit silently. Do nothing. This slice stays `to-await-waves`. It will be checked again on the next pulse.

**If ALL dependencies are done**: continue to step 2.

## 2. Re-review the plan

Earlier slices may have changed the codebase. Read this slice's acceptance criteria and compare against the current state of the code:

- Did earlier slices introduce interfaces, modules, or conventions this slice should use?
- Did earlier slices rename or restructure anything that affects this slice's approach?
- Are any of this slice's acceptance criteria already partially satisfied by earlier work?

**If the plan still holds**: no changes needed.

**If adjustments needed**: update the slice's acceptance criteria and description to reflect the current reality. Be specific about what changed and why.

```sh
SLICE_BODY = {slice body with updated acceptance criteria}
```

```sh
tracker.sh issue edit $SLICE_NUMBER --body "$SLICE_BODY"
```

## 3. Promote

```sh
tracker.sh issue edit $SLICE_NUMBER --remove-label to-await-waves --add-label to-implement
```

## 4. Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

If dispatched by reef-pulse, report: "Slice {name} is unblocked and ready for implementation."
