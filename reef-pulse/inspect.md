# inspect

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the slice to find the PR reference.

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
SLICE_BRANCH="{from slice body}"
WORKTREE_PATH="../worktree-$SLICE_NAME-inspect"
```

## Mindset

You are a CTO independently verifying this work. You do not trust the implementer's self-report. You verify everything yourself by reading code and running tests. You use judgment, not checklists.

A few things you naturally do:

- **Check the implementation against each acceptance criterion.** Read the code. Does it actually do what the criterion says? Don't just read the PR description — it may be optimistic.
- **Spot drift.** The implementation may differ from the plan. That might be fine (the implementer found a better way) or it might be a gap. Surface it either way.
- **Run the full test suite yourself.** Don't trust "all tests pass" in the report.
- **Do trivial cleanups.** Stale TODOs, leftover debug prints, dead code from debugging, formatting — fix these yourself and commit. Don't ask permission.
- **Flag substantive gaps.** Missing tests, incomplete behavior, skipped acceptance criteria — these go in review comments, not silent fixes.
- **Read the ambiguous choices.** The implementer documented decisions they made. Flag anything that drifted too far from the success criteria or that the human should know about.

## Process

### 1. Pull and verify

Enter a worktree forked from $SLICE_BRANCH to review the implementation without disturbing the main checkout:

```sh
./worktree-enter.sh --fork-from "$SLICE_BRANCH" --path "$WORKTREE_PATH"
```

Run the full project test suite. Record the result.

### 2. Check each acceptance criterion

For each acceptance criterion on the slice:

- Read the actual code that implements it. Trace the code path.
- Confirm the behavior is correct by reading the test that covers it.
- If there's no test for an acceptance criterion, that's a gap — flag it.
- If the test exists but uses mocks where integration tests are expected, flag it. (Prevents painpoint C3.)

### 3. Review the report

Read the PR description's "Ambiguous choices" section. For each choice:

- Does it make sense given the constraints?
- Does it drift from the success criteria? If so, is the drift acceptable?
- Would the human want to know about this before merging?

### 4. Trivial cleanups

Do these yourself — commit and push to the PR branch:

- Remove debug prints, console.logs, commented-out code
- Fix formatting, remove trailing whitespace
- Remove stale TODO comments that were addressed
- Add code comments where non-obvious behavior exists

```sh
# Only if you made cleanup commits
./commit.sh --branch "$SLICE_BRANCH" -m "inspect: cleanup"
```

### 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 6. Update the PR

Set the PR number from the slice body. If not found there, try `gh pr list --search`. If PR_NUMBER is nowhere to be found, tag the issue `pr-missing` and stop.

Read the current PR body, then append the inspect report as a collapsible block:

```sh
PR_NUMBER="{from slice body}" # if not found, try gh pr list --search
PR_BODY=$(gh pr view "$PR_NUMBER" --json body -q .body)
REPORT="{inspect-report}" # <details><summary><h3>🧿 Inspect review — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
PR_BODY="$PR_BODY\n\n$REPORT"
gh pr edit "$PR_NUMBER" --body "$PR_BODY"
```

### 7. Verdict

**If all acceptance criteria are met and the suite is green:**

```sh
./tracker.sh issue edit "$SLICE_ID" --remove-label to-inspect --add-label to-merge
```

**If gaps are found:**

```sh
./tracker.sh issue edit "$SLICE_ID" --remove-label to-inspect --add-label to-rework
```

Leave specific review comments on the PR for each gap. Be precise — tell the implementer exactly what's wrong and what "fixed" looks like.

## Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

Return the structured handoff so reef-pulse can log metrics and route the next phase:

```sh
nextPhase="{to-merge or to-rework}"
planPr="{from slice/plan body PR: #N, or — if no plan PR exists yet}"
summary="{one-line outcome, e.g. passed or gaps found}"
```
