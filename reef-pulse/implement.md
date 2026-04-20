# implement

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Tracker note**: Commands below use `tracker.sh` syntax. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/001-auth-endpoint`.

If no slice is given, look for slices tagged `to-implement`. If multiple, pick the first unblocked one. If none, exit silently.

Read the slice (issue or file). It must contain:

- Acceptance criteria
- Target branch name (in "Plan context" section)
- Parent plan reference

If the target branch is missing from the slice, check the plan metadata. The target branch is always set — for single-slice it equals the base branch, for multi-slice it's a dedicated branch.

Set the pre-fetch variables:

```sh
ISSUE_ID = {issue-id} # pre-existing and passed or generate
```

## 0. Fetch context

```sh
tracker.sh issue view $ISSUE_ID --json body,title,labels
```

Set the post-fetch variables (after reading the slice body):

```sh
SLICE_NAME = {from slice body}
SLICE_ID = $ISSUE_ID
TARGET_BRANCH = {from slice/plan body}
SLICE_BRANCH = {PR branch, e.g. feat/001-auth-endpoint}
WORKTREE_PATH = ../worktree-$SLICE_NAME-implement
```

## 1. Git prep

This is non-negotiable. Every step must pass before writing any code.

Enter a worktree forked from $TARGET_BRANCH so you start from a clean integration point (earlier slices' work is already merged there):

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

When implementation is complete, compose the PR description. The `closes` reference must be at the very top of the PR body so GitHub auto-closes the slice issue on merge:

```markdown
closes #$SLICE_ID $SLICE_NAME

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
```

```sh
REPORT = {report-content} # from context
```

```sh
gh pr create --base $TARGET_BRANCH --title "$SLICE_NAME" --body "$REPORT"
```

The PR targets the **target branch** (which equals `{base-branch}` for single-slice work).

```sh
PR_NUMBER = {from gh pr create output}
SLICE_BODY = {slice body with PR: #$PR_NUMBER added to frontmatter}
```

After creating the PR, persist `PR: #N` in the slice issue frontmatter so downstream phases can find it. Add the `PR:` field to the existing YAML frontmatter block in the slice body.

## 6. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 7. Append metrics to plan PR

Compute the duration from the start of this phase to now. Find the plan PR (the PR targeting the base branch from the plan issue). If the plan is single-slice (target branch = base branch), the slice PR is the plan PR — use `$PR_NUMBER`. If multi-slice, find the plan PR via `gh pr list --base $BASE_BRANCH --head $TARGET_BRANCH`.

Read the plan PR body, then append a metrics row:

```sh
PLAN_PR_NUMBER = {plan PR number — equals $PR_NUMBER for single-slice, or found via gh pr list for multi-slice}
PLAN_PR_BODY = {current plan PR body with metrics row appended to the metrics table}
```

```sh
gh pr edit $PLAN_PR_NUMBER --body "$PLAN_PR_BODY"
```

Metrics row format (append to the existing metrics table, or create one if none exists):

```markdown
| implement | #$SLICE_ID $SLICE_NAME | $DURATION | $TOKENS | $TOOL_USES | PR created |
```

Where `$DURATION` is human-readable (e.g. `42s`, `1m 12s`), `$TOKENS` is space-separated thousands from your session metadata (or `—` if unavailable), and `$TOOL_USES` is from your session metadata (or `—` if unavailable).

## 8. Update the slice and tag

Persist the PR reference on the slice body so downstream phases (inspect, rework, merge) can find it.

```sh
tracker.sh issue edit $SLICE_ID --body "$SLICE_BODY" --remove-label to-implement --add-label to-inspect
```

## 9. Clean up

```sh
worktree-exit.sh --path $WORKTREE_PATH
```

## Handoff

If dispatched by reef-pulse or an orchestrator, report completion including duration, token usage, and tool uses from this session. The next phase for this slice is inspection.
