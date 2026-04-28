# await-waves

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature/001-auth-endpoint`.

The issue title includes a `[await: ...]` suffix encoding its blockers: e.g. `"auth token storage [await: #55, #56]"`. Blockers are parsed from this suffix — not from the issue body.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, assume `github` as the tracker type.

**Shell blocks are literal commands** — execute them as written.


**AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, hand off and do not continue. If dependencies are landed, promote. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-await-waves` label. If it does not, hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-await-waves label."
```

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title, stripping [await: ...] suffix}" # e.g. "auth token storage"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
HEADING="{from issue frontmatter heading field}" # e.g. "deep-research"
WORKTREE_PATH=".worktrees/$(echo "$ISSUE_TITLE" | tr '/' '-')-await-waves"
```

## 1. Check dependencies (cheap label gate)

Parse the `[await: ...]` suffix from the issue title. For each blocker ID found, check whether that issue carries the `landed` or `to-land` label:

```sh
DEPENDENCY_ID="{from [await: ...] title suffix}" # e.g. "#55"
./tracker.sh issue view "$DEPENDENCY_ID" --json labels
```

Accumulate any IDs that are not yet ready to unblock (i.e. carry neither `landed` nor `to-land`):

```sh
REMAINING_BLOCKERS="{space-separated list of blocker IDs that carry neither landed nor to-land}" # e.g. "#55 #56"
```

**If any dependency has neither `landed` nor `to-land`**: this issue stays `to-await-waves`. Hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-await-waves"
PR_ID="—"
SUMMARY="still blocked by $REMAINING_BLOCKERS"
```

**If the `[await: ...]` suffix is missing or malformed**: treat as "no blockers found" and continue to step 2 (safe fallback).

**If ALL dependencies have `landed` or `to-land`**: continue to step 2.

## 2. Promote

Strip the `[await: ...]` suffix from the title and flip the label. If `"$HEADING" = "deep-research"`, promote into `to-research`; otherwise promote into `to-implement`:

```sh
ISSUE_TITLE_UPDATED="{stripped title without [await: ...] suffix}" # e.g. "auth token storage"
if [ "$HEADING" = "deep-research" ]; then
  NEXT_LABEL="to-research"
else
  NEXT_LABEL="to-implement"
fi
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-await-waves --add-label "$NEXT_LABEL" --title "$ISSUE_TITLE_UPDATED"
```

Promotion is final. The worktree step below is best-effort course correction.

## 3. Git prep

This is non-negotiable. Enter a worktree with the exact command below:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree.

If resolved:

```sh
./commit-push.sh --branch "$BASE_BRANCH" -m "merge: resolve conflicts 🌊"
```

Then continue.

If unresolvable:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --remove-label "$NEXT_LABEL" --add-label blocked-with-conflicts
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="blocked-with-conflicts"
    PR_ID="—"
    SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
    ```

## 4. Course correction

Earlier work may have changed the codebase. Read this issue's acceptance criteria and compare against the current state of the code:

- Did earlier work introduce interfaces, modules, or conventions this issue should use?
- Did earlier work rename or restructure anything that affects this issue's approach?
- Are any of this issue's acceptance criteria already partially satisfied by earlier work?

**If the plan still holds**: no changes needed.

**If adjustments needed**: update the issue's acceptance criteria and description to reflect the current reality. Be specific about what changed and why.

```sh
ISSUE_BODY_UPDATED="{issue body, with updated acceptance criteria if changed}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
```

## 5. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="$NEXT_LABEL"
PR_ID="—"
SUMMARY="$ISSUE_TITLE_UPDATED is unblocked and labeled $NEXT_LABEL"
```

Report these variables to the caller.
