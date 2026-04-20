# ratify

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature`.

Read the plan. It must have:
- Success criteria
- Coverage matrix
- Target branch name (in metadata)
- Slice PRs with "Ambiguous choices" sections

Set the pre-fetch variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

## 0. Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

Set the post-fetch variables (after reading the plan body):

```sh
PLAN_ID = $ISSUE_ID
PLAN_TITLE = {from plan body}
BASE_BRANCH = {from plan body}
TARGET_BRANCH = {from plan body}
WORKTREE_PATH = ../worktree-$PLAN_ID-ratify
```

## Mindset

You are checking the **whole**, not the parts. Each slice was already verified individually during inspection. Your job is different: does the aggregate work? Does the target branch, taken as a whole, meet every success criterion from the consumer's perspective?

Think like a CTO doing a final walkthrough before shipping.

## Process

### 1. Get on the target branch

Enter a worktree forked from $TARGET_BRANCH because all slice PRs are merged there — you are reviewing the aggregate, not individual slices:

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

Verify you have the latest — all slice PRs should be merged into this branch.

### 2. Run the full test suite

Not negotiable. Record the result.

### 3. Check every success criterion holistically

For each success criterion in the plan:

- Read the actual code on the target branch that satisfies it. Trace the full path — don't check module by module, check end-to-end.
- Verify from the **consumer's perspective**. If the criterion says "the legacy UI must render identically", don't just check that the data is correct — check that it's in the format the legacy UI expects. (Prevents painpoint A4.)
- Cross-reference the coverage matrix: which slices were supposed to cover this criterion? Did they actually cover it when composed together?

Mark each criterion: ✓ met, ✗ not met (with explanation).

### 4. Review all agent decisions

Read the "Ambiguous choices" section from each slice's merged PR. For each decision:

- Does it make sense?
- Did it introduce drift from the original success criteria or decision record?
- Would the human want to know about this?

### 5. Check for integration issues

Look for problems that only appear when slices are composed:

- Naming conflicts, duplicate definitions
- Inconsistent patterns between slices (one slice does auth one way, another does it differently)
- Shared resources that multiple slices touch — are they coherent?
- Are there any test gaps at the integration boundaries? (Prevents painpoint C3 — mocked-away bugs.)
- **Terminology inconsistencies**: did different slices use different words for the same concept? If terminology drifted across slices, run `/ubiquitous-language` against the target branch to flag ambiguities and include findings in the report.

### 6. Documentation

When you find non-obvious behavior worth documenting during your holistic review:

1. **Code comments first.** If it can be clarified with a comment next to the code or above a test, add it yourself and push directly to the target branch:

```sh
commit.sh --branch $TARGET_BRANCH -m "ratify: add documentation"
```
2. **Outside-of-code docs if warranted.** If the behavior is significant enough to document beyond a code comment, check the repo's `AGENTS.md`/`CLAUDE.md` for a documentation locations section. If it exists, follow it. If it doesn't, create a brief entry.

Don't document what's obvious from reading the code.

### 7. Produce the report

The report goes on a **PR from the target branch to the base branch** (usually `main`). This PR is what the human will ultimately merge or reject.

The report should be concise and focused on what the human needs to know. Do NOT dump the entire plan — the human can read the plan. Focus on:

```markdown
## Final Report

### Status: {PASS / GAPS FOUND}

### Success criteria

- ✓ SC1: {criterion} — verified: {one-line how}
- ✓ SC2: {criterion} — verified: {one-line how}
- ✗ SC3: {criterion} — GAP: {what's wrong}

### Agent decisions to review

{List only decisions that introduced drift or that the human should sanity-check. If none, write "All implementation decisions aligned with the plan."}

### Integration notes

{Anything you found when checking the composed whole that wasn't visible per-slice. If nothing, write "No integration issues found."}

### Test results

{Full suite: X passed, 0 failed, 0 skipped.}

### Screenshots / video

{If the app is launchable and the feature is visible, include screenshots or a screen recording demonstrating the end-to-end behavior. Omit if not applicable.}

### Parent plan

{link to plan or file}
```

#### Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

#### Submit the report

```sh
REPORT = {report-content} # from context
```

```sh
gh pr create --base $BASE_BRANCH --head $TARGET_BRANCH --title "$PLAN_TITLE" --body "$REPORT"
# If a PR already exists for this target branch, update its description instead.
```

### 8. Tag

**If all criteria met (PASS):**

```sh
tracker.sh issue edit $PLAN_ID --remove-label to-ratify --add-label to-land
```

**If gaps found:**

```sh
tracker.sh issue edit $PLAN_ID --remove-label to-ratify --add-label to-rescan
```

Add a comment on the plan listing the specific gaps.

## Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

If pass: "Target branch reviewed and final report written on PR #{number}. Ready for `/reef-land` — human review."
If gaps: "Gaps found during holistic review. Tagged `to-rescan` for rescanning to create new slices."
