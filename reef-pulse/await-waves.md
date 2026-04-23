# await-waves

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If dependencies are landed, promote. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#55` or `1-2`.

The issue title includes a `[await: ...]` suffix encoding its blockers: e.g. `"auth token storage [await: #55, #56]"`. Blockers are parsed from this suffix — not from the issue body.

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the issue title and body):

```sh
ISSUE_TITLE="{from issue title, stripping [await: ...] suffix}"
BASE_BRANCH="{from issue frontmatter base-branch field}"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-await-waves"
```

## 1. Check dependencies (cheap label gate)

Parse the `[await: ...]` suffix from the issue title. For each blocker ID found, check whether that issue carries the `landed` label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. "#55"
```

```sh
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

**If any dependency does NOT have the `landed` label**: this issue stays `to-await-waves`. Skip to the handoff with `nextPhase: "to-await-waves"` and `summary: "still blocked by #N, #M"`.

**If the `[await: ...]` suffix is missing or malformed**: treat as "no blockers found" and continue to step 2 (safe fallback).

**If ALL dependencies have the `landed` label**: continue to step 2.

## 2. Promote

Strip the `[await: ...]` suffix from the title and flip the label:

```sh
ISSUE_TITLE="{stripped title without [await: ...] suffix}"
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-await-waves --add-label to-implement --title "$ISSUE_TITLE"
```

Promotion is final. The worktree step below is best-effort course correction.

## 3. Course correction

Enter a worktree forked from $BASE_BRANCH to read up-to-date code (earlier work may have changed the codebase):

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$BASE_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

Earlier work may have changed the codebase. Read this issue's acceptance criteria and compare against the current state of the code:

- Did earlier work introduce interfaces, modules, or conventions this issue should use?
- Did earlier work rename or restructure anything that affects this issue's approach?
- Are any of this issue's acceptance criteria already partially satisfied by earlier work?

**If the plan still holds**: no changes needed.

**If adjustments needed**: update the issue's acceptance criteria and description to reflect the current reality. Be specific about what changed and why.

```sh
ISSUE_BODY_UPDATED="{issue body, with updated acceptance criteria if changed}"
```

```sh
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
```

## 4. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
NEXT_PHASE="to-implement" # or "to-await-waves" if still blocked
PR_ID="—"
summary="{ISSUE_TITLE} is unblocked and ready for implementation" # or "still blocked by #N, #M"
```

Report these three variables to the caller.
