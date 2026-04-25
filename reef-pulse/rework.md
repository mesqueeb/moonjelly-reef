# rework

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature/001-auth-endpoint`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, assume `github` as the tracker type.

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-rework` label.

If it does not, hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-rework label."
```

Else set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}" # e.g. "001-auth-endpoint"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/001-auth-endpoint"
PR_ID="{from issue frontmatter pr-id field, or - if not present}" # e.g. "#7"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-rework"
```

## 1. Git prep

This is non-negotiable. Enter a worktree with the exact command below:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree.

If resolved:

```sh
./commit.sh --branch "$PR_BRANCH" -m "merge: resolve conflicts 🌊"
```

Then continue.

If unresolvable:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="blocked-with-conflicts"
    PR_ID="$PR_ID"
    SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
    ```

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
- For feeling-lucky, rework may refine the inferred heading if inspect surfaced a better interpretation.

Do NOT skip any feedback item. If a comment is unclear, make your best interpretation and note what you assumed.

## 4. Run the full test suite

Not a subset. The full project test suite must be green.

## 5. Push fixes

```sh
./commit.sh --branch "$PR_BRANCH" -m "rework: address review feedback"
```

## 6. Update the PR description

If `"$PR_ID" = "-"`, try `./tracker.sh pr list --search` to locate the PR.

If `$PR_ID` is nowhere to be found:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --add-label pr-missing
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="pr-missing"
    PR_ID="—"
    SUMMARY="Blocked: PR not found. pr-missing label applied."
    ```

Else write the report which will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

<report-template>
<details>
<summary><h3>🦀 Crab's rework — {yyyy/MM/dd HH:mm}</h3></summary>

### Judgment calls

- **{topic}**: chose {X} because {reason}. Differs from plan: {difference, if any}.

(If none, write "None.")

### Feedback addressed

- **{feedback item}**: {what was changed}

### Test results

{X tests passed, 0 failed.}

</details>
</report-template>

```sh
PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
REPORT="{rework-report}" # e.g. <details><summary><h3>🦀 Crab's rework — {2012/12/21 12:00}</h3></summary>...</details>
PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
```

## 7. Label

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-rework --add-label to-inspect
./tracker.sh pr edit "$PR_ID" --remove-label to-rework --add-label to-inspect
```

## 8. Clean up

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

Report these four variables to the caller.
