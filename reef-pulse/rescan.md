# rescan

> **Tracker note**: Read `.agents/moonjelly-reef/config.md` for the tracker type. Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature`.

Read the plan fully — the plan, success criteria, coverage matrix, agent decisions, and the ratify report that identified the gaps.

Set the initial variables:

```sh
PLAN_ID = {from plan metadata}
PLAN_TITLE = {from plan metadata}
BASE_BRANCH = {from plan metadata}
TARGET_BRANCH = {from plan metadata}
WORKTREE_PATH = ../worktree-$PLAN_ID-rescan
```

## 0. Fetch context

### GitHub tracker

```sh
gh issue view $PLAN_ID --json body,title,labels
```

### Local tracker

Read the file at:

```sh
$LOCAL_PATH/$PLAN_ID (\w+)/[to-rescan] plan.md
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

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

### 1. Analyze the gaps

Read the ratify report's gaps. For each gap, classify it:

- **Missing coverage**: a success criterion has no slice addressing it → need a new slice
- **Incomplete implementation**: a slice was done but didn't fully satisfy an acceptance criterion → need a rework or new slice
- **Integration gap**: slices work individually but not together → need a new integration slice
- **Planning gap**: the plan or success criteria were ambiguous → update the plan first, then create slices

### 2. Re-review the plan

This is the step that makes rescanning different from just "create follow-up tickets."

Read the entire plan top to bottom. With the ratify report's findings in mind:

- Are the success criteria still correct and complete? If the ratify found something that SHOULD have been a criterion but wasn't, add it.
- Does the coverage matrix need updating beyond just the new slices?
- Are there planning-level statements that turned out to be wrong or ambiguous? Update them.

### GitHub tracker

If the plan or success criteria need updates, edit the plan body with `gh issue edit`.

### Local tracker

If the plan needs updates, edit the plan file directly.

### 3. Create new slices

For each gap, create a new slice with acceptance criteria that explicitly address it.

Key discipline: if the gap was caused by an agent skipping something (painpoint C1), the new slice's acceptance criteria must call out what was skipped and why it matters. Don't let the same failure mode repeat.

Follow the same format as the slice phase:

- Acceptance criteria specific to the gap
- `blocked-by` references if the new slice depends on anything
- Reference to the success criteria it covers

### GitHub tracker

Create sub-issues with `gh issue create`, linked to the plan. Label: `to-implement` or `to-await-waves`.

### Local tracker

Create new slice files in `{path}/{title}/slices/`. Prefix: `[to-implement]` or `[to-await-waves]`.

### 4. Update the coverage matrix

Add rows for the new slices. Every gap must now map to an acceptance criterion on a new slice.

### GitHub tracker

Edit the plan body to update the coverage matrix section.

### Local tracker

Update the coverage matrix in the plan file.

### 5. Handle original slices

If a gap relates to a slice that was marked `done` but is now revealed as incomplete:

- Do NOT reopen the original slice.
- The new slice references the original: "Addresses gap in {original-slice}: {description}."
- This keeps the history clean. (Prevents painpoint E1.)

### 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 7. Push and tag

### GitHub tracker

Change plan from `to-rescan` to `in-progress`. The merge phase will change it to `to-ratify` when all slices (including new ones) are `done`.

```sh
gh issue edit $PLAN_ID --remove-label to-rescan --add-label in-progress
```

### Local tracker

For local tracker, commit and push the updated plan files and new slice files:

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
commit.sh --branch $TARGET_BRANCH -m "rescan: update tracker for $PLAN_TITLE"
worktree-exit.sh --path $WORKTREE_PATH
```

## Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

Report: "Created {N} new slices to address gaps. Coverage matrix updated. The reef will pick these up on the next pulse."
