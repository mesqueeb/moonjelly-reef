# Scoping a bug

How to scope a bug fix into a plan.

## Investigation (before writing the plan)

This is a mostly hands-off workflow — minimize questions to the user. If they haven't described the bug yet, ask ONE question: "What's the problem you're seeing?" Then start investigating immediately. Do NOT ask follow-up questions yet.

Use the Agent tool with `subagent_type=Explore` to deeply investigate the codebase. Your goal is to find:

- **Where** the bug manifests (entry points, UI, API responses)
- **What** code path is involved (trace the flow)
- **Why** it fails (the root cause, not just the symptom)
- **What** related code exists (similar patterns, tests, adjacent modules)

Look at:
- Related source files and their dependencies
- Existing tests (what's tested, what's missing)
- Recent changes to affected files (`git log` on relevant files)
- Error handling in the code path
- Similar patterns elsewhere in the codebase that work correctly

### Determine fix approach

Based on your investigation, determine:
- The minimal change needed to fix the root cause
- Which modules/interfaces are affected
- What behaviors need to be verified via tests
- Whether this is a regression, missing feature, or design flaw — each has different implications for scope

### Scope assessment

Present your findings to the user and align on scope:
- "This looks like a quick fix — single slice, I'll verify the bug, find root cause, fix it, verify the fix."
- OR "This is more involved — it touches X, Y, Z and will need multiple slices. Here's what I recommend..."

For quick fixes, the plan can be minimal. For elaborate bugs, write a full plan.

## Plan structure

- **Problem**: actual behavior, expected behavior, how to reproduce.
- **Root cause analysis**: the code path involved, why the current code fails, any contributing factors. Describe modules, behaviors, and contracts — NOT file paths, line numbers, or implementation details that couple to current code layout. The plan should remain useful even after major refactors.
- **TDD fix approach**: concrete, ordered list of RED-GREEN cycles. Each cycle is one vertical slice:
  - **RED**: describe a specific test that captures the broken/missing behavior
  - **GREEN**: describe the minimal code change to make that test pass

  Rules:
  - Tests verify behavior through public interfaces, not implementation details
  - One test at a time, vertical slices (NOT all tests first, then all code)
  - Each test should survive internal refactors
  - Include a final refactor step if needed
  - **Durability**: only suggest fixes that would survive radical codebase changes. Describe behaviors and contracts, not internal structure. Tests assert on observable outcomes (API responses, UI state, user-visible effects), not internal state. A good suggestion reads like a spec; a bad one reads like a diff.

- **Acceptance criteria**: explicit checklist.
  - [ ] {criterion 1}
  - [ ] {criterion 2}
  - [ ] All new tests pass
  - [ ] Existing tests still pass

## What makes a good bug plan

A good bug plan starts with root cause, not symptoms. It's investigative journalism, not a repair manual.

- Root cause is clearly identified — not "the button doesn't work" but "the handler reads from cache before the cache is populated because the init order changed in commit X"
- The fix targets the root cause, not the symptom. A workaround is documented as such
- Tests are written to capture the broken behavior BEFORE fixing it — proving the test would have caught the bug
- The plan considers whether this is a regression, a missing feature, or a design flaw
- Only durable fix suggestions — describe behaviors and contracts, not internal structure
- For quick fixes: the plan is minimal but still has clear acceptance criteria
- For elaborate bugs: full plan with multiple RED-GREEN cycles ordered by dependency
