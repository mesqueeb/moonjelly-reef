# await-waves

## Input

This skill requires a specific issue: e.g. `#42` or `1-2`.

The issue title includes a `[await: ...]` suffix encoding its blockers: e.g. `"auth token storage [await: #55, #56]"`. Blockers are parsed from this suffix — not from the issue body.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id or -}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — run `./worktree-enter.sh`, `./worktree-exit.sh`, and `./commit.sh` exactly as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, hand off and do not continue. If dependencies are landed, promote. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-await-waves` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-await-waves label."
```

Report these variables to the caller and **do not continue**.

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title, stripping [await: ...] suffix}" # e.g. "auth token storage"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
BEARING="{from issue frontmatter bearing field}" # e.g. "deep-research"
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

**If any dependency does NOT have the `landed` label**: this issue stays `to-await-waves`. Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-await-waves"
PR_ID="—"
SUMMARY="still blocked by #N, #M"
```

Report these variables to the caller and **do not continue**.

**If the `[await: ...]` suffix is missing or malformed**: treat as "no blockers found" and continue to step 2 (safe fallback).

**If ALL dependencies have the `landed` label**: continue to step 2.

## 2. Promote

Strip the `[await: ...]` suffix from the title and flip the label. If `"$BEARING" = "deep-research"`, promote into label `to-research`; otherwise promote into label `to-implement`:

```sh
ISSUE_TITLE="{stripped title without [await: ...] suffix}" # e.g. "auth token storage"
if [ "$BEARING" = "deep-research" ]; then
  NEXT_LABEL="to-research"
else
  NEXT_LABEL="to-implement"
fi
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-await-waves --add-label "$NEXT_LABEL" --title "$ISSUE_TITLE"
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

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="—"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

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
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-research" # or "to-implement" or "to-await-waves" depending on bearing and blockers
PR_ID="—"
SUMMARY="{ISSUE_TITLE} is unblocked and ready for research or implementation" # or "still blocked by #N, #M"
```

Report these three variables to the caller.
