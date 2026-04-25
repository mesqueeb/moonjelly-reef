# rework

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature/001-auth-endpoint`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — run `./worktree-enter.sh`, `./worktree-exit.sh`, and `./commit.sh` exactly as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-rework` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-rework label."
```

Report these variables to the caller and **do not continue**.

Set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}" # e.g. "001-auth-endpoint"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/001-auth-endpoint"
PR_ID="{from issue frontmatter pr-id field, or - if not present}" # e.g. "#7"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-rework"
```

## 1. Git prep

Enter a worktree forked from $PR_BRANCH to apply fixes to the existing PR:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to the working branch using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="$PR_ID"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

## 2. Read all feedback

Read every review comment on the PR. Read the full conversation — don't just skim.

Also read the gap report from the PR body (`<details><summary>` blocks written by seal or reef-land) if present.

Also re-read:

- The issue's acceptance criteria (if present), or the plan's User Stories, Implementation Decisions, Testing Decisions, Commits, or Research Questions — whichever applies
- The gap classification from the seal report if present (missing coverage, incomplete implementation, integration gap, planning gap)

## 3. Fix

Address every comment and gap. For each piece of feedback:

- Fix it if you can
- If you disagree with the feedback, fix it anyway and add a PR comment explaining your reasoning. Let the inspector decide on the next round. Don't argue — fix.
- For deep-research, rework means revising the committed research docs to close the flagged gaps.
- Typical research fixes include answering missed questions, tightening the writing, clarifying conclusions, or adding missing source links.
- For feeling-lucky, rework may refine the inferred lane or bearing if QA surfaced a better interpretation.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

## 4. Run the full test suite

Not a subset. The full project test suite must be green.

## 5. Document judgment calls

Document judgment calls made during this phase on the PR. Only document decisions that deviate from the plan, resolve ambiguity, or would surprise the human — not routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier.

## 6. Push fixes

```sh
./commit.sh --branch "$PR_BRANCH" -m "rework: address review feedback"
```

## 7. Update the PR description

Read the current PR body, then append the rework report as a collapsible block. The rework report should include judgment calls, what feedback was addressed, what was changed, and test results.

This output will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

```sh
PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
REPORT="{rework-report}" # <details><summary><h3>🦀 Rework — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
```

## 8. Label

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-rework --add-label to-inspect
./tracker.sh pr edit "$PR_ID" --remove-label to-rework --add-label to-inspect
```

## 9. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-inspect"
PR_ID="$PR_ID"
SUMMARY="Rework complete — addressed review feedback"
```

Report these three variables to the caller.
