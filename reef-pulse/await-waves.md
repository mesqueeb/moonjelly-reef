# await-waves

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If deps are done, promote. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `1-2`.

The slice title includes a `[await: ...]` suffix encoding its blockers: e.g. `"auth token storage [await: #55, #56]"`. Blockers are parsed from this suffix — not from the slice body.

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the slice title and body):

```sh
SLICE_NAME="{from slice title, stripping [await: ...] suffix}"
SLICE_ID="$ISSUE_ID"
BASE_BRANCH="{from slice/plan body}"
TARGET_BRANCH="{from slice/plan body}"
WORKTREE_PATH=".worktrees/$SLICE_NAME-await-waves"
```

## 1. Check dependencies (cheap label gate)

Parse the `[await: ...]` suffix from the slice title. For each blocker ID found, check whether that issue carries the `landed` label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. "#55"
```

```sh
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

**If any dependency does NOT have the `landed` label**: this slice stays `to-await-waves`. Skip to the handoff with `nextPhase: "to-await-waves"` and `summary: "still blocked by #N, #M"`.

**If the `[await: ...]` suffix is missing or malformed**: treat as "no blockers found" and continue to step 2 (safe fallback).

**If ALL dependencies have the `landed` label**: continue to step 2.

## 2. Promote

Strip the `[await: ...]` suffix from the title and flip the label:

```sh
SLICE_NAME="{stripped title without [await: ...] suffix}"
./tracker.sh issue edit "$SLICE_ID" --remove-label to-await-waves --add-label to-implement --title "$SLICE_NAME"
```

Promotion is final. The worktree step below is best-effort course correction.

## 3. Course correction

Enter a worktree forked from $TARGET_BRANCH to read up-to-date code (earlier slices may have changed the codebase):

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
