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

## 5. Think about what done looks like

Before writing the plan, decide how much rigor the fix needs. Present these 4 options to the user with your recommendation:

1. **Theoretical fix** — explain the root cause and fix approach in writing, no code written
2. **Compile-verified** — write the fix, confirm it compiles/runs, no tests
3. **TDD** — red-green-refactor cycle with tests
4. **Dive in together** — exit Reef flow; this is interactive debugging, not async work

Base your recommendation on what you found during investigation. A clear, isolated bug with an obvious fix warrants option 2 or 3. A hard-to-reproduce or multi-system issue may call for option 1. A problem that needs real-time exploration and iteration is option 4.

**If the user picks option 4**: hand off control to the user directly. Do not create a plan or sub-issue. Say something like: "Got it — let's dig into this together. Here's what I found so far: {summary of investigation}. Where would you like to start?"

For options 1–3, continue to step 6.

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

## What does done look like

{Prose description of the chosen rigor level and what a successful fix looks like. For example: "The fix is TDD-verified — a failing test that captures the broken behavior is written first, then the minimal code change is made to pass it. The fix is complete when all tests pass and no existing tests regress."}

## Acceptance Criteria

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] All new tests pass
- [ ] Existing tests still pass

</plan-template>
