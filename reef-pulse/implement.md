# implement

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, read and follow [setup.md](setup.md) first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

If no slice is given, look for slices tagged `to-implement`. If multiple, pick the first unblocked one (or ask).

Read the slice (issue or file). It must contain:

- Acceptance criteria
- Target branch name (in "Plan context" section)
- Parent plan reference

If the target branch is missing from the slice, check the plan metadata. The target branch is always set — for single-slice it equals the base branch, for multi-slice it's a dedicated branch.

Set the initial variables:

```sh
SLICE_NAME = {from slice metadata}
SLICE_NUMBER = {from slice metadata}
BASE_BRANCH = {from slice/plan metadata}
TARGET_BRANCH = {from slice/plan metadata}
SLICE_BRANCH = {PR branch, e.g. feat/001-auth-endpoint}
WORKTREE_PATH = ../worktree-$SLICE_NAME-implement
```

## 0. Fetch context

### GitHub tracker

```sh
gh issue view $SLICE_NUMBER --json body,title,labels
```

### Local tracker

Read the file at:

```sh
$LOCAL_PATH/$PLAN_ID (\w+)/slices/[to-implement] $SLICE_NAME.md
```

## 1. Git prep

This is non-negotiable. Every step must pass before writing any code.

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
```

Verify:

- [ ] The project builds / compiles cleanly before you touch anything
- [ ] The full test suite passes before you touch anything (this is your baseline)

If the baseline is already broken, **stop and report this**. Do not try to fix pre-existing failures. Tag the slice `to-rework` with a note explaining what's broken. (Prevents painpoint D1 — solving problems in the wrong order.)

## 2. Read context

Before writing any code, read and understand:

- **This slice's acceptance criteria** — this is your checklist. Every criterion must be addressed.
- **The plan + success criteria** — understand the "why" behind this slice.
- **Sibling slices** — awareness of what others are doing or have done. Don't duplicate, don't conflict.
- **The decision record** — the original decisions that led here.

## 3. Implement with TDD

Use `/tdd` to implement the acceptance criteria. If the `tdd` skill is not installed (check config), read and follow [tdd-lite.md](tdd-lite.md) instead.

Run the full project test suite after each red-green cycle — not just the tests you wrote. If you get stuck on an acceptance criterion, make your best judgment, document what you decided and why (see "6. Document judgment calls" below), and continue. Never silently skip an acceptance criterion.

Commit your work when implementation is complete.

## 4. Write the report

When implementation is complete, compose the PR description using this template:

```markdown
## Slice

{link to slice issue or file path}

## Parent

{link to plan or file path}

## Acceptance criteria

- [x] {AC1} — {brief note on how it's satisfied}
- [x] {AC2} — {brief note}
- [ ] {AC3} — NOT MET: {explanation of what happened}

## Ambiguous choices

Decisions made during implementation that weren't covered by the acceptance criteria or where judgment was needed:

- **{topic}**: chose {X} because {reason}. This differs from the plan in that {difference, if any}.

(If no ambiguous choices were made, write "None — implementation followed the plan exactly.")

## Test results

{Output of the full test suite run. If too long, summarize: "X tests passed, 0 failed, 0 skipped."}

## Screenshots / video

{If the app is launchable and the change is visual or user-facing, include a screenshot or screen recording demonstrating the behavior. If not applicable, omit this section entirely.}
```

## 5. Open the PR

```sh
commit.sh --branch $SLICE_BRANCH -m "$SLICE_NAME: implementation"
gh pr create --base $TARGET_BRANCH --title "$SLICE_NAME" --body "$REPORT"
```

The PR targets the **target branch** (which equals `{base-branch}` for single-slice work).

```sh
PR_NUMBER = {from gh pr create output}
```

## 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 7. Tag the slice

### GitHub tracker

```sh
gh issue edit $SLICE_NUMBER --remove-label to-implement --add-label to-inspect
```

Add a comment on the slice issue linking to the PR.

### Local tracker

Rename the slice file from `[to-implement] ...` to `[to-inspect] ...`.
Add the PR number/URL to the slice file body.

```sh
worktree-enter.sh --fork-from $TARGET_BRANCH --path $WORKTREE_PATH
mv "[to-implement]" "[to-inspect]"
commit.sh --branch $TARGET_BRANCH -m "implement: update tracker for $SLICE_NAME"
worktree-exit.sh --path $WORKTREE_PATH
```

## 8. Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

If dispatched by reef-pulse or an orchestrator, report completion. The next phase for this slice is inspection.
