# merge

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

An issue tagged `to-merge` with an open PR.

Read the item to find the PR reference. Check the Plan context to determine whether this is **single-slice** (target branch = base branch) or **multi-slice** (target branch forks from base branch).

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue body}"
BASE_BRANCH="{from issue body}"
PR_NUMBER="{from issue body}"
PR_BRANCH="{from issue body pr-branch field}"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-merge"
```

## Pre-merge check

Unconditional. Ensures the PR branch integrates cleanly with the base branch before proceeding.

Check the merge state of the PR:

```sh
./tracker.sh pr view "$PR_NUMBER" --json mergeStateStatus -q .mergeStateStatus
```

Enter a worktree forked from $PR_BRANCH so you are testing the PR code with the latest base merged in:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$PR_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

Run the full test suite. If tests pass, commit and push:

```sh
./commit.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts with $BASE_BRANCH"
```

If the test suite fails after merging, label the issue `to-rework` and stop:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-merge --add-label to-rework
./tracker.sh pr edit "$PR_NUMBER" --remove-label to-merge --add-label to-rework
```

Clean up the worktree:

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

If tests failed, stop here. Do not proceed to single-slice or multi-slice steps.

## Delegate

After the pre-merge check passes, check: **does the issue have a `parent-plan` field in frontmatter?**

- **No `parent-plan`** — read and execute [merge-single.md](merge-single.md) (fast path: label `to-ratify`, human merges via `/reef-land`)
- **Has `parent-plan`** — read and execute [merge-multi.md](merge-multi.md) (full flow: squash merge PR, check siblings, check completion)
