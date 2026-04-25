# Triage Issue

Investigate a reported problem, find its root cause, and write a fix plan calibrated to the agreed rigor level. Minimize questions to the diver.

## 1. Capture the problem

Get a brief description of the issue from the diver. If they haven't provided one, ask ONE question: "What's the problem you're seeing?"

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

## 4. What does done look like?

Present these four options to the diver. Recommend one based on your investigation findings:

1. **Theoretical fix** — fix identified and documented in the plan; no code or tests required
2. **Compile/Runtime-verified** — fix applied and confirmed to compile/run without errors
3. **TDD** — failing test written first, then fix applied; all tests pass
4. **Dive in together** — interactive debugging session; not suitable for AFK Reef flow

Present your investigation findings, then ask which option the diver wants. If your investigation was inconclusive or the fix requires live exploration, say so explicitly — that's the signal for option 4.

```sh
RIGOR_OPTION="{chosen option number}" # e.g. "3"
```

If `"$RIGOR_OPTION" = "4"`, do not label the issue `to-implement`.

Report these variables to the caller and **do not continue**.

## 5. Design fix plan

**RUN ONLY IF `"$RIGOR_OPTION" = "2"` or `"$RIGOR_OPTION" = "3"`.**

Create a concrete, ordered list of RED-GREEN cycles. Each cycle is one vertical slice:

- **Option 2 (Compile/Runtime-verified)**:
  - **RED**: Describe how to reproduce the issue — compile error, runtime crash, or observable browser/UI behavior
  - **GREEN**: Describe the fix and how it resolves the reproduction case

- **Option 3 (TDD)**:
  - **RED**: Describe a specific failing test that captures the broken behavior
  - **GREEN**: Describe the minimal code change to make that test pass

Rules (apply to both options):

- Describe behaviors and contracts, not internal structure
- One cycle at a time
- Include a final refactor step if needed
- **Durability**: Only suggest fixes that would survive radical codebase changes. Tests and reproduction steps assert on observable outcomes (API responses, UI state, user-visible effects), not internal state.

## 6. Set the plan content

<plan-template>

## Problem Statement

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

{IF option 2 or 3:}

## Fix Plan

A numbered list of RED-GREEN cycles:

1. **RED**: [Reproduce the issue / failing test]
   **GREEN**: [Minimal fix that resolves it]

2. **RED**: [Next reproduction case / failing test]
   **GREEN**: [Minimal change to make it pass]

...

{IF option 3: **REFACTOR**: [Any cleanup needed after all tests pass]}

{END IF}

## Acceptance Criteria

{Option 1}: `- [ ] Fix applied to the identified code path` and `- [ ] existing tests still pass`
{Option 2}: `- [ ] Fix applies and compiles/runs without errors` and `- [ ] existing tests still pass`
{Option 3}: `- [ ] Regression test exists covering the root cause` and `- [ ] All tests pass`

</plan-template>

```sh
NEW_PLAN="{new plan content as per template above}" # e.g. "## Problem\n\nLogin fails when..."
```
