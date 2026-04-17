---
name: reef-implement
description: Implement a slice using TDD in a git worktree. Opens a PR with a structured report. Use when a slice is tagged to-implement.
---

# reef-implement

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-setup` first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Document any judgment calls on the relevant PR or as a comment on the parent issue. Never block waiting for human input.

## Input

This skill requires a specific slice: `/reef-implement #55` or `/reef-implement my-feature/001-auth-endpoint`.

If no slice is given, look for slices tagged `to-implement`. If multiple, pick the first unblocked one (or ask).

Read the slice (issue or file). It must contain:
- Acceptance criteria
- Feature branch name (in "Plan context" section)
- Parent plan reference

If any of these are missing, check the parent plan for the feature branch. If you truly can't find the feature branch name, default to `main` and note this in your report.

## 1. Git prep

This is non-negotiable. Every step must pass before writing any code.

```sh
# Fetch latest and prune stale tracking branches
git fetch origin --prune

# Create a worktree from the feature branch
git worktree add ../worktree-{slice-name} -b {slice-branch} origin/{feature-branch}
cd ../worktree-{slice-name}
```

Verify:
- [ ] Worktree is based on the latest `origin/{feature-branch}`
- [ ] No unrelated commits are present (`git log --oneline -5` — should see only feature branch history)
- [ ] The project builds / compiles cleanly before you touch anything
- [ ] The full test suite passes before you touch anything (this is your baseline)

If the baseline is already broken, **stop and report this**. Do not try to fix pre-existing failures. Tag the slice `to-rework` with a note explaining what's broken. (Prevents painpoint D1 — solving problems in the wrong order.)

## 2. Read context

Before writing any code, read and understand:

- **This slice's acceptance criteria** — this is your checklist. Every criterion must be addressed.
- **The parent plan + success criteria** — understand the "why" behind this slice.
- **Sibling slices** — awareness of what others are doing or have done. Don't duplicate, don't conflict.
- **The probe session** — the original decisions that led here.

## 3. Implement with TDD

Invoke `/tdd` to do the implementation work. Before invoking, brief it with the context:

> "Implement the following acceptance criteria using TDD (red-green-refactor). The full project test suite must be green after each cycle — not just a subset.
>
> **Acceptance criteria:**
> {paste the acceptance criteria from the slice}
>
> **Context from parent plan:**
> {relevant section of the plan that explains the "why"}
>
> **What to be aware of:**
> {any relevant info from sibling slices, e.g. "slice 001 added a new `AuthService` interface — use it, don't create a new one"}
>
> **Non-negotiable rules:**
> - Run the FULL project test suite after each red-green cycle, not just the tests you wrote
> - If you get stuck on an acceptance criterion, do NOT skip it. Make your best judgment, document what you decided and why, then continue
> - Never silently skip an acceptance criterion"

If the `tdd` skill is not installed (check config), do the TDD work directly using this discipline:

1. For each acceptance criterion, work in vertical slices — one at a time, not all tests first.
2. **RED**: write a single test that captures the expected behavior for this acceptance criterion. Run it. It must fail.
3. **GREEN**: write the minimal code to make that test pass. No more.
4. Run the **full project test suite** (not just your new test). It must be green.
5. Repeat for the next acceptance criterion.
6. After all acceptance criteria pass: look for refactor opportunities (extract duplication, simplify interfaces). Run full suite after each refactor step. Never refactor while red.

Tests should verify behavior through public interfaces, not implementation details. A good test reads like a specification — it survives internal refactors because it doesn't care about structure.

## 4. Write the report

When implementation is complete, compose the PR description using this template:

```markdown
## Slice

{link to slice issue or file path}

## Parent

{link to parent plan issue or file path}

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
git push -u origin {slice-branch}
gh pr create --base {feature-branch} --title "{slice-name}" --body "{report}"
```

The PR targets the **feature branch**, not `main`.

## 6. Tag the slice

### GitHub tracker

Add label `to-inspect` to the slice issue. Remove `to-implement`.
Add a comment on the slice issue linking to the PR.

### Local tracker

Rename the slice file from `[to-implement] ...` to `[to-inspect] ...`.
Add the PR number/URL to the slice file body.

## Handoff

If dispatched by reef-pulse or an orchestrator, report completion. The next skill to run on this slice is `/reef-inspect`.
