# Scoping a refactor

Disciplines absorbed from: request-refactor-plan.

## Before writing

### Explore alternatives

Before committing to a plan, ask the user:
- "Have you considered other approaches?"
- Present at least one alternative you can think of

This prevents tunnel vision. The first idea isn't always the best, and the probe session may have locked in on one approach too early.

### Assess current test coverage

Look in the codebase for test coverage of the area being refactored. If there is insufficient test coverage, discuss with the user: the plan must include adding coverage BEFORE refactoring. Never refactor untested code — add tests first so you have a safety net.

## Plan structure

The plan covers everything in [scope-feature.md](scope-feature.md) (problem statement, solution, user stories, implementation decisions, testing decisions, out of scope), plus these refactor-specific sections:

- **What won't change**: explicit scope of what remains untouched. Hammer out the exact boundary — what you plan to change and what you plan NOT to change. This is as important as what changes.
- **Commit plan**: break the implementation into tiny commits. Remember Martin Fowler's advice: "make each refactoring step as small as possible, so that you can always see the program working." Each commit should:
  - Leave the codebase in a working state
  - Pass all tests
  - Be independently understandable
  - Write the plan in plain English, describing each commit step
- **Current test coverage**: document what tests exist for this area. If insufficient, the first commits in the plan add coverage for existing behavior before changing anything.

## Collaborating with the user

After drafting:

- Present the commit plan and ask: "Does the order make sense? Any steps that should be split or merged?"
- Specifically discuss the scope boundary: "I plan to change X, Y, Z and NOT touch A, B, C. Does that match your expectations?"
- For any area with duplicated code: agree on which copy is canonical and in what order duplicates get removed (painpoint G1)

Iterate until the user approves the plan and the commit order.

## What makes a good refactor plan

A good refactor plan is paranoid about breaking things. It assumes every step could go wrong and builds in checkpoints.

- Every commit compiles and passes tests. No "it'll be green at the end" — it must be green at every step
- The plan considers alternative approaches and documents why this one was chosen
- Scope is explicit in both directions: what changes AND what stays the same
- The order of operations matters — doing step A before step B might be trivial, but reversing them could cause a 100-file cascade (painpoint D1)
- If the refactor touches duplicated code, the plan specifies which copy is canonical and in what order duplicates get removed (painpoint G1)
- The plan accounts for the "blast radius" of each step — if a rename touches 50 files, that's one atomic commit, not 50 separate changes
