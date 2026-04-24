# Triage Issue

Investigate a reported problem, find its root cause, and write a plan with a TDD fix approach. This is a mostly hands-off workflow — minimize questions to the user.

## Input (from context)

```sh
ISSUE_ID="{from context}" # e.g. "#42"
```

## 1. Capture the problem

Get a brief description of the issue from the user. If they haven't provided one, ask ONE question: "What's the problem you're seeing?"

## 2. Explore and diagnose

Deeply investigate the codebase. If your environment supports explorer-style sub-agents, use one; otherwise do the exploration yourself. Your goal is to find:

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

## 3. Identify the fix approach

Based on your investigation, determine:

- The minimal change needed to fix the root cause
- Which modules/interfaces are affected
- What behaviors need to be verified via tests
- Whether this is a regression, missing feature, or design flaw

## 4. Design TDD fix plan

Create a concrete, ordered list of RED-GREEN cycles. Each cycle is one vertical slice:

- **RED**: Describe a specific test that captures the broken/missing behavior
- **GREEN**: Describe the minimal code change to make that test pass

### Rules

- Tests verify behavior through public interfaces, not implementation details
- One test at a time, vertical slices (NOT all tests first, then all code)
- Each test should survive internal refactors
- Include a final refactor step if needed
- **Durability**: Only suggest fixes that would survive radical codebase changes. Describe behaviors and contracts, not internal structure. Tests assert on observable outcomes (API responses, UI state, user-visible effects), not internal state. A good suggestion reads like a spec; a bad one reads like a diff.

## 5. What does done look like?

Present these four options to the user. Recommend one based on your investigation findings:

1. **Theoretical fix** — fix identified and documented in the plan; no code or tests required
2. **Compile-verified** — fix applied and confirmed to compile/run without errors
3. **TDD** — failing test written first, then fix applied; all tests pass
4. **Dive in together** — interactive debugging session; not suitable for AFK Reef flow

**How to recommend**: if you found a clear root cause with a known fix, recommend option 2 or 3. If the root cause is unclear or the fix requires exploration, recommend option 4. If the issue is well-understood but low-risk, option 1 may suffice.

If the user picks option 4, do not label the issue `to-implement`. Close out by explaining that this issue needs a live session and won't enter the Reef queue.

For options 1–3, the chosen option drives the `## Acceptance Criteria` checklist in the plan:

- **Option 1**: `- [ ] Fix applied to the identified code path`
- **Option 2**: `- [ ] Fix compiles and runs without errors`
- **Option 3**: `- [ ] Failing test written first` and `- [ ] All tests pass after fix`

## 6. Write the plan

Write the plan using this template:

<plan-template>

## Problem

A clear description of the bug or issue, including:
- What happens (actual behavior)
- What should happen (expected behavior)
- How to reproduce (if applicable)

## Root Cause Analysis

Describe what you found during investigation:
- The code path involved
- Why the current code fails
- Any contributing factors

Do NOT include specific file paths, line numbers, or implementation details that couple to current code layout. Describe modules, behaviors, and contracts instead. The plan should remain useful even after major refactors.

## TDD Fix Plan

A numbered list of RED-GREEN cycles:

1. **RED**: Write a test that [describes expected behavior]
   **GREEN**: [Minimal change to make it pass]

2. **RED**: Write a test that [describes next behavior]
   **GREEN**: [Minimal change to make it pass]

...

**REFACTOR**: [Any cleanup needed after all tests pass]

## Acceptance Criteria

- [ ] {criterion driven by the chosen rigor option from step 5}
- [ ] All new tests pass
- [ ] Existing tests still pass

</plan-template>

When persisting the plan in SKILL.md step 6 (for options 1–3), use `to-implement` instead of `to-slice`. A bug fix is a single branch, single PR — slicing adds overhead with no benefit.
