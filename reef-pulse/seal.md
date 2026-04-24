# seal

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature`.

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

Verify the issue carries the `to-seal` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-seal label."
```

Report these variables to the caller and **do not continue**.

Read the plan. It must have:

- Success criteria
- Coverage matrix (if multi-slice)
- `pr-branch` in frontmatter
- Slice PRs with "Ambiguous choices" sections

```sh
ISSUE_TITLE="{from issue title}" # e.g. "My feature title"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/my-feature"
BEARING="{from issue frontmatter bearing field, or - if not present}" # e.g. "deep-research"
FEELING_LUCKY="{from issue frontmatter feeling-lucky field, or - if not present}" # e.g. "true"
WORKTREE_PATH=".worktrees/$ISSUE_ID-seal"
```

## Mindset — The Elephant Seal

You are **the Elephant Seal** — the holistic reviewer. Inspector Barreleye already checked the code line-by-line against acceptance criteria. Your job is fundamentally different: you check against **user stories** and the **problem statement** to answer "does this actually solve the user's problem?"

You are not re-inspecting code. You are:

- **Evaluating from the user's perspective.** Re-read the problem statement and user stories. Walk through the solution as the user would experience it. Does the implemented behavior match what the user needs?
- **Reviewing agent decisions for sanity.** Implementers made choices. Do those choices serve the user, or did they optimize for something else?
- **Looking for integration issues.** For multi-slice: do the slices compose correctly? For single-slice: does the change cohere with the rest of the codebase?
- **Checking documentation.** Is the change discoverable? Would a new contributor understand what changed and why?
- **Running the full test suite.** Belt and suspenders — you run it independently.

Think like a CTO doing a final walkthrough before shipping. Product-focused, big-picture, judgment-oriented.

## 1. Get on the `pr-branch`

Enter a worktree forked from $PR_BRANCH:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$PR_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$PR_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="—"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

Verify you have the latest — all slice PRs should be merged into this `pr-branch`.

## 2. Run the full test suite

Not negotiable. Record the result.

## 3. Check every success criterion holistically

For each success criterion in the plan:

- Read the actual code on the `pr-branch` that satisfies it. Trace the full path — don't check module by module, check end-to-end.
- Verify from the **consumer's perspective**. If the criterion says "the legacy UI must render identically", don't just check that the data is correct — check that it's in the format the legacy UI expects. (Prevents painpoint A4.)
- Cross-reference the coverage matrix: which issues were supposed to cover this criterion? Did they actually cover it when composed together?

If `"$BEARING" = "deep-research"`:

- Review the written research holistically against the end goal, not just the slice acceptance criteria.
- Check whether the full research answer is coherent, complete enough for the promised question, and sensible as a whole.

If `"$BEARING" != "deep-research"`:

- Apply the normal mechanical quality bar.
- If `"$FEELING_LUCKY" = "true"`, apply slightly softer strictness — ask whether the outcome makes good sense for the exploratory ticket the human tossed into the reef.

Mark each criterion: ✓ met, ✗ not met (with explanation).

## 4. Review all agent decisions

Read the "Ambiguous choices" section from each slice's merged PR. For each decision:

- Does it make sense?
- Did it introduce drift from the original success criteria or decision record?
- Would the human want to know about this?

## 5. Check for integration issues

Look for problems that only appear when slices are composed:

- Naming conflicts, duplicate definitions
- Inconsistent patterns between slices (one slice does auth one way, another does it differently)
- Shared resources that multiple slices touch — are they coherent?
- Are there any test gaps at the integration boundaries? (Prevents painpoint C3 — mocked-away bugs.)
- **Terminology inconsistencies**: did different slices use different words for the same concept? If terminology drifted across slices, run the `ubiquitous-language` skill against the `pr-branch` to flag ambiguities and include findings in the report.

## 6. Tighten the plan and classify findings

Use your findings from steps 3-5 to tighten the plan before deciding PASS vs GAPS:

- If the review revealed something that SHOULD have been a criterion but wasn't, update the success criteria on the plan issue.
- Classify each gap found:
  - **Missing coverage**: a success criterion has no slice addressing it
  - **Incomplete implementation**: a slice was done but didn't fully satisfy a criterion when composed
  - **Integration gap**: slices work individually but not together
  - **Planning gap**: the plan or success criteria were ambiguous or missed something

If you updated the plan's success criteria:

```sh
ISSUE_BODY="{plan issue body with updated success criteria}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

If any gaps need decisions beyond what success criteria cover (e.g. the plan itself is ambiguous about a design direction), treat that as a **human decision needed** case. Do NOT send it back to `to-scope`. Keep it moving to `to-land`, make the warning explicit in the seal report, and call out exactly which decision needs human judgment before more automated work should happen.

## 7. Documentation

When you find non-obvious behavior worth documenting during your holistic review:

1. **Code comments first.** If it can be clarified with a comment next to the code or above a test, add it yourself and push directly to the `pr-branch`:

```sh
./commit.sh --branch "$PR_BRANCH" -m "seal: add documentation"
```

2. **Outside-of-code docs if warranted.** If the behavior is significant enough to document beyond a code comment, check the repo's `AGENTS.md`/`CLAUDE.md` for a documentation locations section. If it exists, follow it. If it doesn't, create a brief entry.

Don't document what's obvious from reading the code.

## 8. Produce the report

The report goes on a **PR from the `pr-branch` to the `base-branch`** (usually `main` for issues with no parent issue). This PR is what the human will ultimately merge or reject.

The report should be concise and focused on what the human needs to know. Do NOT dump the entire plan — the human can read the plan. Focus on:

```markdown
## Final Report

### Status: {PASS / GAPS FOUND / HUMAN DECISION NEEDED}

### Success criteria

- ✓ SC1: {criterion} — verified: {one-line how}
- ✓ SC2: {criterion} — verified: {one-line how}
- ✗ SC3: {criterion} — GAP: {what's wrong}

### Agent decisions to review

{List only decisions that introduced drift, resolved ambiguity, or that the human should sanity-check. Do not include routine implementation choices. If a decision is best explained next to the code it affects, write a code comment instead. If your context was compacted during this session, scan pre-compaction reference files for judgment calls made earlier. Omit if not applicable.}

### Integration notes

{Anything you found when checking the composed whole that wasn't visible per-slice. If nothing, write "No integration issues found. Omit if not applicable."}

### Test results

{Full suite: X passed, 0 failed, 0 skipped. Omit if not applicable.}

### Screenshots / video

{If the app is launchable and the feature is visible, include screenshots or a screen recording demonstrating the end-to-end behavior. Omit if not applicable.}
```

### Submit the report

Format the report as a collapsible block with local timestamp (`yyyy/MM/dd HH:mm`):

```sh
REPORT="{seal-report}" # <details><summary><h3>🦭 Seal report — {yyyy/MM/dd HH:mm}</h3></summary>{report-content}</details>
```

**If PR exists, append:**

```sh
PR_ID="{from pr create output or existing PR}" # e.g. "#43"
PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
PR_BODY="$PR_BODY\n\n$REPORT"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY"
```

**If no PR exists, create and update the plan issue body as well:**

```sh
CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g. "closes #42 My feature title"
PR_BODY_NEW="$CLOSES\n\n$REPORT"
./tracker.sh pr create --base "$BASE_BRANCH" --head "$PR_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-seal
# Persist the PR metadata on the plan issue so downstream human review can always find it:
PR_ID="{from pr create output or existing PR}" # e.g. "#43"
ISSUE_BODY="{original issue body with added frontmatter values}"
# add to frontmatter: pr-id: $PR_ID
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

## 9. Label

**If all criteria met (PASS):**

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land
./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land
```

**If the remaining gap is a human decision beyond current success criteria:**

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
```

**If gaps found (fixable within success criteria and without human input needed):**

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-rework
./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-rework
```

## Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-land" # or "to-rework" if gaps found; use to-land for human-decision-needed warnings
PR_ID="$PR_ID"
SUMMARY="Seal {PASS|GAPS FOUND|HUMAN DECISION NEEDED} — {one-line summary}"
```

Report these four variables to the caller.
