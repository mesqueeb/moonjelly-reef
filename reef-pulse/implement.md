# implement

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the issue. It must contain:

- Acceptance criteria
- `base-branch` in frontmatter (where the PR merges into)
- `pr-branch` in frontmatter (the branch the PR lives on — chosen during scope for an issue with no `parent-issue`, or assigned during slice creation for an issue with `parent-issue`)
- Parent issue reference (if this is a sub-issue)

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}"
BASE_BRANCH="{from issue frontmatter base-branch field}"
PR_BRANCH="{from issue frontmatter pr-branch field}"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-implement"
```

## 1. Git prep

This is non-negotiable. Every step must pass before writing any code.

Enter a worktree forked from $BASE_BRANCH so you start from a clean integration point:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$BASE_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

Verify:

- [ ] The project builds / compiles cleanly before you touch anything
- [ ] The full test suite passes before you touch anything (this is your baseline)

If the baseline is already broken, **stop and report this**. Do not try to fix pre-existing failures. Label the issue `to-rework` with a note explaining what's broken. (Prevents painpoint D1 — solving problems in the wrong order.)

## 2. Read context

Before writing any code, read and understand:

- **This issue's acceptance criteria** — this is your checklist. Every criterion must be addressed.
- **The plan + success criteria** — understand the "why" behind this issue.
- **Sibling issues** — awareness of what others are doing or have done. Don't duplicate, don't conflict.
- **The decision record** — the original decisions that led here.

## 3. Implement with TDD

Use the `tdd` skill to implement the acceptance criteria. If the `tdd` skill is not installed (check config), read and follow [tdd-lite.md](tdd-lite.md) instead.

Run the full project test suite after each red-green cycle — not just the tests you wrote. If you get stuck on an acceptance criterion, make your best judgment, document what you decided and why (see "6. Document judgment calls" below), and continue. Never silently skip an acceptance criterion.

Commit your work when implementation is complete.

## 4. Write the report

When implementation is complete, compose the PR description using this template:

```markdown
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
./commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: implementation"
```

The PR body must start with the "closes" reference, followed by the implementation report:

Document judgment calls in that implementation report. Only include decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

```sh
CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g.: #42
REPORT="{implementation report}"
PR_BODY_NEW="$CLOSES\n\n$REPORT"
./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
```

The PR targets `$BASE_BRANCH` — the branch it merges into.

## 6. Update the issue and label

Persist the PR metadata for the newly created PR on the issue body so downstream phases (inspect, rework, merge) can find it.

```sh
PR_ID="{from pr create output}" # e.g.: #43
ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}"
# add to frontmatter (if not already): pr-branch: $PR_BRANCH
# add to frontmatter:  pr-id: $PR_ID
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-implement --add-label to-inspect
```

## 7. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
NEXT_PHASE="to-inspect"
PR_ID="$PR_ID"
summary="Implementation complete for $ISSUE_TITLE"
```

Report these three variables to the caller.
