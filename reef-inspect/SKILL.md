---
name: reef-inspect
description: Independently verify a slice PR against its acceptance criteria and the full test suite. Do not trust the implementer's self-report. Use when a slice is tagged to-inspect.
---

# reef-inspect

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

## Input

This skill requires a specific slice: `/reef-inspect #55` or `/reef-inspect my-feature/001-auth-endpoint`.

Read the slice to find the PR reference. If the slice doesn't have a PR linked, check for open PRs referencing this slice:

```sh
gh pr list --search "slice-name"
```

## Mindset

You are a CTO independently verifying this work. You do not trust the implementer's self-report. You verify everything yourself by reading code and running tests. You use judgment, not checklists.

A few things you naturally do:

- **Check the implementation against each AC.** Read the code. Does it actually do what the AC says? Don't just read the PR description — it may be optimistic.
- **Spot drift.** The implementation may differ from the plan. That might be fine (the implementer found a better way) or it might be a gap. Surface it either way.
- **Run the full test suite yourself.** Don't trust "all tests pass" in the report.
- **Do trivial cleanups.** Stale TODOs, leftover debug prints, dead code from debugging, formatting — fix these yourself and commit. Don't ask permission.
- **Flag substantive gaps.** Missing tests, incomplete behavior, skipped ACs — these go in review comments, not silent fixes.
- **Read the ambiguous choices.** The implementer documented decisions they made. Flag anything that drifted too far from the success criteria or that the human should know about.

## Process

### 1. Pull and verify

```sh
git fetch origin
gh pr checkout {pr-number}
```

Run the full project test suite. Record the result.

### 2. Check each acceptance criterion

For each AC on the slice:

- Read the actual code that implements it. Trace the code path.
- Confirm the behavior is correct by reading the test that covers it.
- If there's no test for an AC, that's a gap — flag it.
- If the test exists but uses mocks where integration tests are expected, flag it. (Prevents painpoint C3.)

### 3. Review the report

Read the PR description's "Ambiguous choices" section. For each choice:

- Does it make sense given the constraints?
- Does it drift from the success criteria? If so, is the drift acceptable?
- Would the human want to know about this before merging?

### 4. Trivial cleanups

Do these yourself — commit directly to the PR branch:

- Remove debug prints, console.logs, commented-out code
- Fix formatting, remove trailing whitespace
- Remove stale TODO comments that were addressed
- Add code comments where non-obvious behavior exists

### 5. Verdict

**If all ACs are met and the suite is green:**

### GitHub tracker

Add label `to-merge`. Remove `to-inspect`.
Leave an approving review comment summarizing what you verified.

### Local tracker

Rename from `[to-inspect] ...` to `[to-merge] ...`.

**If gaps are found:**

### GitHub tracker

Add label `to-rework`. Remove `to-inspect`.
Leave specific review comments on the PR for each gap. Be precise — tell the implementer exactly what's wrong and what "fixed" looks like.

### Local tracker

Rename from `[to-inspect] ...` to `[to-rework] ...`.
Add the feedback to the slice file body.

## Handoff

If dispatched by reef-pulse, report the verdict and a one-line summary. Next skill: `/reef-merge` (if approved) or `/reef-rework` (if gaps).
