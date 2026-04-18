# ratify

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Document any judgment calls on the relevant PR or as a comment on the parent issue. Never block waiting for human input.

## Input

This skill requires a specific work item: e.g. `#42` or `my-feature`.

Read the parent plan. It must have:
- Success criteria
- Coverage matrix
- Target branch name (in metadata)
- Agent decisions section (appended by the merge phase from each slice)

## Mindset

You are checking the **whole**, not the parts. Each slice was already verified individually during inspection. Your job is different: does the aggregate work? Does the target branch, taken as a whole, meet every success criterion from the consumer's perspective?

Think like a CTO doing a final walkthrough before shipping.

## Process

### 1. Get on the target branch

Use a worktree so you don't disturb the main checkout or any other agent's work.

```sh
git fetch origin --prune
git worktree add ../worktree-ratify-{title} origin/{target-branch}
cd ../worktree-ratify-{title}
```

Verify you have the latest — all slice PRs should be merged into this branch.

When ratification is complete (after tagging), clean up the worktree:

```sh
cd ..
git worktree remove ../worktree-ratify-{title}
```

### 2. Run the full test suite

Not negotiable. Record the result.

### 3. Check every success criterion holistically

For each success criterion in the plan:

- Read the actual code on the target branch that satisfies it. Trace the full path — don't check module by module, check end-to-end.
- Verify from the **consumer's perspective**. If the criterion says "the legacy UI must render identically", don't just check that the data is correct — check that it's in the format the legacy UI expects. (Prevents painpoint A4.)
- Cross-reference the coverage matrix: which slices were supposed to cover this criterion? Did they actually cover it when composed together?

Mark each criterion: ✓ met, ✗ not met (with explanation).

### 4. Review all agent decisions

Read the "Agent decisions" section on the parent (aggregated by the merge phase from each slice's PR). For each decision:

- Does it make sense?
- Did it introduce drift from the original success criteria or decision record?
- Would the human want to know about this?

### 5. Check for integration issues

Look for problems that only appear when slices are composed:

- Naming conflicts, duplicate definitions
- Inconsistent patterns between slices (one slice does auth one way, another does it differently)
- Shared resources that multiple slices touch — are they coherent?
- Are there any test gaps at the integration boundaries? (Prevents painpoint C3 — mocked-away bugs.)
- **Terminology inconsistencies**: did different slices use different words for the same concept? If terminology drifted across slices, run `/ubiquitous-language` against the target branch to flag ambiguities and include findings in the report.

### 6. Produce the report

The report goes on a **PR from the target branch to the base branch** (usually `main`). This PR is what the human will ultimately merge or reject.

```sh
gh pr create --base {base-branch} --head {target-branch} --title "{work-item-title}" --body "{report}"
```

If a PR already exists for this target branch, update its description instead.

The report should be concise and focused on what the human needs to know. Do NOT dump the entire plan — the human can read the plan on the parent issue. Focus on:

```markdown
## Final Report

### Status: {PASS / GAPS FOUND}

### Success criteria

- ✓ SC1: {criterion} — verified: {one-line how}
- ✓ SC2: {criterion} — verified: {one-line how}
- ✗ SC3: {criterion} — GAP: {what's wrong}

### Agent decisions to review

{List only decisions that introduced drift or that the human should sanity-check. If none, write "All implementation decisions aligned with the plan."}

### Integration notes

{Anything you found when checking the composed whole that wasn't visible per-slice. If nothing, write "No integration issues found."}

### Test results

{Full suite: X passed, 0 failed, 0 skipped.}

### Screenshots / video

{If the app is launchable and the feature is visible, include screenshots or a screen recording demonstrating the end-to-end behavior. Omit if not applicable.}

### Parent plan

{link to parent issue or file}
```

### 7. Tag

**If all criteria met (PASS):**

### GitHub tracker

Add label `to-land` to the parent issue. Remove `to-ratify`.

### Local tracker

Rename parent from `[to-ratify] ...` to `[to-land] ...`.

**If gaps found:**

### GitHub tracker

Add label `to-rescan` to the parent issue. Remove `to-ratify`.
Add a comment on the parent listing the specific gaps.

### Local tracker

Rename parent from `[to-ratify] ...` to `[to-rescan] ...`.

## Documentation

When you find non-obvious behavior worth documenting during your holistic review:

1. **Code comments first.** If it can be clarified with a comment next to the code or above a test, add it yourself and commit to the target branch.
2. **Outside-of-code docs if warranted.** If the behavior is significant enough to document beyond a code comment, check the repo's `AGENTS.md`/`CLAUDE.md` for a documentation locations section. If it exists, follow it. If it doesn't, create a brief entry.

Don't document what's obvious from reading the code.

## Handoff

If pass: "Target branch reviewed and final report written on PR #{number}. Ready for `/reef-land` — human review."
If gaps: "Gaps found during holistic review. Tagged `to-rescan` for rescanning to create new slices."
