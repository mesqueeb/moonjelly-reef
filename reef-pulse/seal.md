# seal

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type.

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

Verify the issue carries the `to-seal` label.

If it does not:

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="—"
    PR_ID="—"
    SUMMARY="Skipped: issue does not carry the to-seal label."
    ```

Else set the post-fetch variables (after reading the issue body):

```sh
ISSUE_TITLE="{from issue title}" # e.g. "My feature title"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "feat/my-feature"
PR_ID="{from issue frontmatter pr-id field, or - if not present}" # e.g. "#43"
HEADING="{from issue frontmatter heading field, or - if not present}" # e.g. "deep-research"
FEELING_LUCKY="{from issue frontmatter feeling-lucky field, or - if not present}" # e.g. "true"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-seal"
```

If `$PR_ID` is not present on the issue frontmatter:

    ```sh
    if [ "$PR_ID" = "-" ]; then
      ./tracker.sh pr list --search "head:$PR_BRANCH" --json number
      PR_ID="{located PR, or - if not found}" # e.g. "#43"
    fi
    ```

## Mindset — The Elephant Seal

You are **the Elephant Seal** — the holistic reviewer. Inspector Barreleye already checked the code line-by-line against acceptance criteria. Your job is fundamentally different: you check against **User Stories** and the **problem statement** to answer "does this actually solve the user's problem?"

You are not re-inspecting code. You are:

- **Evaluating from the user's perspective.** Re-read the problem statement and User Stories. Walk through the solution as the user would experience it. Does the implemented behavior match what the user needs?
- **Reviewing agent decisions for sanity.** Implementers made choices. Do those choices serve the user, or did they optimize for something else?
- **Looking for integration issues.** For multi-slice: do the slices compose correctly? For single-slice: does the change cohere with the rest of the codebase?
- **Checking documentation.** Is the change discoverable? Would a new contributor understand what changed and why?
- **Running the full test suite.** Belt and suspenders — you run it independently.

Think like a CTO doing a final walkthrough before shipping. Product-focused, big-picture, judgment-oriented.

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

Else verify you have the latest — all slice PRs should be merged into this `pr-branch`.

## 2. Run the full test suite

Not negotiable. Record the result.

If any tests fail: run each failing test against `$BASE_BRANCH`. If a test passes on `$BASE_BRANCH` and fails on `$PR_BRANCH`, it is a **regression introduced by this PR** — not pre-existing. Do not trust any upstream agent's characterization of test failures. Form your own judgment from the diff.

## 3. Check every plan item holistically

For each User Story, Implementation Decision, and Testing Decision in the plan:

- Read the actual code on the `pr-branch` that satisfies it. Trace the full path — don't check module by module, check end-to-end.
- Verify from the **consumer's perspective**. If a User Story says "the legacy UI must render identically", don't just check that the data is correct — check that it's in the format the legacy UI expects. (Prevents painpoint A4.)
- Cross-reference the coverage matrix: which issues were supposed to cover this plan item? Did they actually cover it when composed together?

If `"$HEADING" = "deep-research"`:

- Review the written research holistically against the end goal, not just the slice acceptance criteria.
- Check whether the full research answer is coherent, complete enough for the promised question, and sensible as a whole.

If `"$HEADING" != "deep-research"`:

- Apply the normal mechanical quality bar.
- If `"$FEELING_LUCKY" = "true"`, apply slightly softer strictness — ask whether the outcome makes good sense for the exploratory issue the diver tossed into the reef.

Mark each criterion: ✓ met, ✗ not met (with explanation).

## 4. Review all agent decisions

Read the "Judgment calls" section from each slice's merged PR. For each call:

- Does it make sense?
- Did it introduce drift from the original plan items or decision record?
- Would the diver want to know about this?

If any judgment call characterizes test failures as "pre-existing" or "existing before this change", cross-check against your own step 2 results. Your independent verification takes precedence over any upstream claim.

## 5. Check for integration issues

Look for problems that only appear when slices are composed:

- Naming conflicts, duplicate definitions
- Inconsistent patterns between slices (one slice does auth one way, another does it differently)
- Shared resources that multiple slices touch — are they coherent?
- Are there any test gaps at the integration boundaries? (Prevents painpoint C3 — mocked-away bugs.)
- **Terminology inconsistencies**: did different slices use different words for the same concept? If terminology drifted across slices, run the `ubiquitous-language` skill against the `pr-branch` to flag ambiguities and include findings in the report.

## 6. Tighten the plan and classify findings

Use your findings from steps 3-5 to tighten the plan before deciding PASS vs GAPS:

- If the review revealed something that SHOULD have been captured but wasn't, update the Testing Decisions or Implementation Decisions on the plan issue.
- Classify each gap found:
  - **Missing coverage**: a plan item has no slice addressing it
  - **Incomplete implementation**: a slice was done but didn't fully satisfy a plan item when composed
  - **Integration gap**: slices work individually but not together
  - **Planning gap**: the Testing Decisions or Implementation Decisions were ambiguous or missed something

If you updated the plan's Testing Decisions or Implementation Decisions:

```sh
ISSUE_BODY_UPDATED="{plan issue body with updated Testing Decisions or Implementation Decisions}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
```

If any gaps need decisions beyond what the plan covers (e.g. the plan itself is ambiguous about a design direction), treat that as a **human decision needed** case. Do NOT send it back to `to-scope`. Keep it moving to `to-land`, make the warning explicit in the seal report, and call out exactly which decision needs diver judgment before more automated work should happen.

## 7. Documentation

When you find non-obvious behavior worth documenting during your holistic review:

1. **Code comments first.** If it can be clarified with a comment next to the code or above a test, add it yourself and push directly to the `pr-branch`:

```sh
./commit.sh --branch "$PR_BRANCH" -m "seal: add documentation"
```

2. **Outside-of-code docs if warranted.** If the behavior is significant enough to document beyond a code comment, check the repo's `AGENTS.md`/`CLAUDE.md` for a documentation locations section. If it exists, follow it. If it doesn't, create a brief entry.

Don't document what's obvious from reading the code.

## 8. Write the report

The report should be concise and focused on what the diver needs to know. Do NOT dump the entire plan — the diver can read the plan.

This output will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

<report-template>
<details>
<summary><h3>🦭 Seal of approval — {yyyy/MM/dd HH:mm}</h3></summary>

## Final Report

### Status: {PASS / GAPS FOUND / HUMAN DECISION NEEDED}

### Plan items

- ✓ User Story 1: {user story} — verified: {one-line how}
- ✓ Implementation Decision 1: {implementation decision} — verified: {one-line how}
- ✗ Testing Decision 1: {testing decision} — GAP: {what's wrong}

### Judgment calls

- **{topic}**: chose {X} because {reason}. Drift or diver attention needed: {why}.

(Omit if no calls introduced drift or warrant diver review.)

### Integration notes

{Anything you found when checking the composed whole that wasn't visible per-slice. If nothing, write "No integration issues found. Omit if not applicable."}

### Test results

{Full suite: X passed, 0 failed, 0 skipped. Omit if not applicable.}

### Screenshots / video

{If the app is launchable and the feature is visible, include screenshots or a screen recording demonstrating the end-to-end behavior. Omit if not applicable.}

</details>
</report-template>

### Submit the report

```sh
REPORT="{seal-report}" # e.g. <details><summary><h3>🦭 Seal of approval — {2012/12/21 12:00}</h3></summary>...</details>
if [ "$PR_ID" = "-" ]; then
  CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g. "closes #42 My feature title"
  PR_BODY_NEW="$CLOSES\n\n$REPORT"
  ./tracker.sh pr create --base "$BASE_BRANCH" --head "$PR_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-seal
  # Persist the PR metadata on the plan issue so the diver can always find it:
  PR_ID="{from pr create output}" # e.g. "#43"
  ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}"
  # add to frontmatter: pr-id: $PR_ID
  ./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED"
else
  PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
  PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
  ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
fi
```

## 9. Label

**If all criteria met (PASS):**

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land
./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land
```

**If the remaining gap is a human decision beyond the current plan:**

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
./tracker.sh pr edit "$PR_ID" --remove-label to-seal --add-label to-land --add-label blocked-need-human-input
```

**If gaps found (fixable within the plan and without diver input needed):**

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
SUMMARY="Seal {PASS|GAPS FOUND|HUMAN DECISION NEEDED} — {one-line summary}" # e.g. "Seal PASS — all plan items verified, full suite green"
```

Report these four variables to the caller.
