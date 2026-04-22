# rework

> **Shell blocks are literal commands** — `./worktree-enter.sh`, `./worktree-exit.sh`, `./commit.sh`, and `./tracker.sh` are real scripts next to this file. Execute them as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax for both issue and PR operations. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill requires a specific issue: e.g. `#55` or `my-feature/001-auth-endpoint`.

Read the issue to find the PR reference.

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Set the post-fetch variables (after reading the issue body). Extract from frontmatter — works for single-slice plans and multi-slice sub-issues:

```sh
ISSUE_TITLE="{from issue title}"
BASE_BRANCH="{from issue frontmatter base-branch field}"
PR_BRANCH="{from issue frontmatter pr-branch field}"
PR_NUMBER="{from issue frontmatter pr-number field}"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-rework"
```

For plan issues, read success criteria from the plan body instead of acceptance criteria.

## Process

### 1. Git prep

Enter a worktree forked from $PR_BRANCH to apply fixes to the existing PR:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to the working branch using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Stop — do not proceed.

### 2. Read all feedback

Read every review comment on the PR. Read the full conversation — don't just skim.

Also read the gap report from the PR body (`<details><summary>` blocks written by seal or reef-land) if present.

Also re-read:
- The issue's acceptance criteria or plan's success criteria
- The gap classification from the seal report if present (missing coverage, incomplete implementation, integration gap, planning gap)

### 3. Fix

Address every comment and gap. For each piece of feedback:

- Fix it if you can
- If you disagree with the feedback, fix it anyway and add a PR comment explaining your reasoning. Let the inspector decide on the next round. Don't argue — fix.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

### 4. Run the full test suite

Not a subset. The full project test suite must be green.

### 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

### 6. Push fixes

```sh
./commit.sh --branch "$PR_BRANCH" -m "rework: address review feedback"
```

### 7. Update the PR description

Read the current PR body, then append the rework report as a collapsible block. The rework report should include judgment calls, what feedback was addressed, what was changed, and test results.

```sh
PR_BODY=$(./tracker.sh pr view "$PR_NUMBER" --json body -q .body)
REPORT="{rework-report}" # <details><summary><h3>🦀 Rework — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
PR_BODY="$PR_BODY\n\n$REPORT"
./tracker.sh pr edit "$PR_NUMBER" --body "$PR_BODY"
```

### 8. Label

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-rework --add-label to-inspect
./tracker.sh pr edit "$PR_NUMBER" --remove-label to-rework --add-label to-inspect
```

### 9. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
nextPhase="to-inspect"
planPr="$PR_NUMBER"
summary="Rework complete — addressed review feedback"
```

Report these three variables to the caller.
