# rescan

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature`.

Read the plan fully — the plan, success criteria, coverage matrix, and agent decisions. Then read the PR body for gap reports that triggered the rescan. Gap reports are `<details><summary>` blocks on the PR body, written either by ratify (automated holistic review) or by reef-land (human review).

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the plan body):

```sh
PLAN_ID="$ISSUE_ID"
PR_NUMBER="{from plan body frontmatter PR: \"#N\"}"
TARGET_BRANCH="{from plan body}"
WORKTREE_PATH=".worktrees/$PLAN_ID-rescan"
```

## Fetch PR

```sh
gh pr view "$PR_NUMBER" --json body
```

## Mindset

You are not just patching holes. You are re-reviewing the entire plan through the lens of what the holistic review revealed. The gaps might be:

- Missing slices (a success criterion wasn't covered)
- Slices that were implemented but didn't actually satisfy their acceptance criteria when composed
- Planning-level issues (the plan itself was ambiguous or missed something)
- Agent decisions that drifted too far

Do NOT ask a human. If the gaps need decisions that aren't in the success criteria, that means the planning phase (reef-scope) left ambiguity. The success criteria should be complete enough to be self-service. If they truly aren't, tag `to-scope` for a new scoping session — but try to resolve it yourself first.

## Process

### 0. Git prep

Enter a worktree forked from $TARGET_BRANCH to read the current state of the code:

```sh
./worktree-enter.sh --fork-from "$TARGET_BRANCH" --path "$WORKTREE_PATH"
```

### 1. Analyze the gaps

Read the gap report's entries. For each gap, classify it:

- **Missing coverage**: a success criterion has no slice addressing it → need a new slice
- **Incomplete implementation**: a slice was done but didn't fully satisfy an acceptance criterion → need a rework or new slice
- **Integration gap**: slices work individually but not together → need a new integration slice
- **Planning gap**: the plan or success criteria were ambiguous → update the plan first, then create slices

### 2. Re-review the plan

This is the step that makes rescanning different from just "create follow-up tickets."

Read the entire plan top to bottom. With the gap report's findings in mind:

- Are the success criteria still correct and complete? If the gap report found something that SHOULD have been a criterion but wasn't, add it.
- Does the coverage matrix need updating beyond just the new slices?
- Are there planning-level statements that turned out to be wrong or ambiguous? Update them.

If the plan or success criteria need updates:

```sh
./tracker.sh issue edit "$PLAN_ID" --body "{updated plan body}"
```

### 3. Create new slices

For each gap, create a new slice with acceptance criteria that explicitly address it.

Key discipline: if the gap was caused by an agent skipping something (painpoint C1), the new slice's acceptance criteria must call out what was skipped and why it matters. Don't let the same failure mode repeat.

Follow the same format as the slice phase:

- Acceptance criteria specific to the gap
- `blocked-by` references if the new slice depends on anything
- Reference to the success criteria it covers

Create new slices linked to the plan:

```sh
./tracker.sh issue create --title "{slice-title}" --body "{slice-body}" --label to-implement
```

Use `to-implement` if no blockers, `to-await-waves` if blocked.

### 4. Update the coverage matrix

Add rows for the new slices. Every gap must now map to an acceptance criterion on a new slice.

```sh
./tracker.sh issue edit "$PLAN_ID" --body "{plan body with updated coverage matrix}"
```

### 5. Handle original slices

If a gap relates to a slice that was marked `done` but is now revealed as incomplete:

- Do NOT reopen the original slice.
- The new slice references the original: "Addresses gap in {original-slice}: {description}."
- This keeps the history clean. (Prevents painpoint E1.)

### 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 7. Update plan and tag

Update the plan body with the revised criteria and coverage matrix. Change label from `to-rescan` to `in-progress`. The merge phase will change it to `to-ratify` when all slices (including new ones) are `done`.

```sh
PLAN_BODY="{plan body with updated criteria and coverage matrix}"
./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY" --remove-label to-rescan --add-label in-progress
```

## Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
nextPhase="in-progress"
planPr="$PR_NUMBER"
summary="Created {N} new slices to address gaps — coverage matrix updated"
```

Report these three variables to the caller.
