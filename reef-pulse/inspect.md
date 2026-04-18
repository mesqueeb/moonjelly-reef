# inspect

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the slice to find the PR reference. If the slice doesn't have a PR linked, check for open PRs referencing this slice:

```sh
gh pr list --search "slice-name"
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

Use a worktree so you don't disturb the main checkout or any other agent's work.

```sh
git fetch origin --prune

# Get the PR's branch name, create worktree on a local tracking branch
PR_BRANCH=$(gh pr view {pr-number} --json headRefName -q .headRefName)
git worktree add ../worktree-inspect-{slice-name} -b inspect-$PR_BRANCH origin/$PR_BRANCH
cd ../worktree-inspect-{slice-name}
```

Run the full project test suite. Record the result.

When inspection is complete (after tagging), clean up the worktree:

```sh
cd ..
git worktree remove ../worktree-inspect-{slice-name}
```

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
git push origin HEAD:$PR_BRANCH
```

### 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 6. Verdict

**If all acceptance criteria are met and the suite is green:**

### GitHub tracker

Add label `to-merge` to the slice issue. Remove `to-inspect`.

### Local tracker

Rename from `[to-inspect] ...` to `[to-merge] ...`.

**If gaps are found:**

### GitHub tracker

Add label `to-rework` to the slice issue. Remove `to-inspect`.
Leave specific review comments on the PR for each gap. Be precise — tell the implementer exactly what's wrong and what "fixed" looks like.

### Local tracker

Rename from `[to-inspect] ...` to `[to-rework] ...`.
Add the feedback to the slice file body.

## Handoff

If dispatched by reef-pulse, report the verdict and a one-line summary.
