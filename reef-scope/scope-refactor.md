# Scoping a refactor

## Input (from context)

## 1. Capture the problem

Ask the user for a long, detailed description of the problem they want to solve and any potential ideas for solutions.

## 2. Explore the repo

Explore the repo to verify their assertions and understand the current state of the codebase.

## 3. Consider alternatives

Ask whether they have considered other options, and present other options to them.

## 4. Interview the implementation

Interview the user about the implementation. Be extremely detailed and thorough.

## 5. Hammer out scope

Hammer out the exact scope of the implementation. Work out what you plan to change and what you plan NOT to change.

## 6. Assess test coverage

Look in the codebase to check for test coverage of this area. If there is insufficient test coverage, ask the user what their plans for testing are.

## 7. Design the commit plan

Break the implementation into a plan of tiny commits. Remember Martin Fowler's advice to "make each refactoring step as small as possible, so that you can always see the program working."

## 8. Write the plan

Write the plan using this template:

<plan-template>

## Problem Statement

The problem that the developer is facing, from the developer's perspective.

## Solution

The solution to the problem, from the developer's perspective.

## What Won't Change

Explicit scope of what remains untouched. This is as important as what changes.

## Commits

A LONG, detailed implementation plan. Write the plan in plain English, breaking down the implementation into the tiniest commits possible. Each commit should leave the codebase in a working state.

## Decision Document

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this refactor.

</plan-template>
