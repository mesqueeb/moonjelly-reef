# Scoping a feature

## Input (from context)

```sh
ISSUE_ID="{from context}" # e.g. "#42"
```

## 1. Interview

RUN ONLY IF the issue does not have decisions captured yet.

Before asking anything, explore the codebase and answer every question you can from the code. Only bring questions to the diver that genuinely cannot be resolved by reading the repo.

Then interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

## 2. Explore the repo

Explore the repo to understand the current state of the codebase, if you haven't already.

## 3. Sketch modules

Sketch out the major modules you will need to build or modify. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

## 4. Write the plan

Write the plan using this template:

<plan-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an `<actor>`, I want a `<feature>`, so that `<benefit>`

This list should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

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

## Success Criteria

Testable conditions that must ALL be true for this work to be considered done. Each criterion must be mechanically verifiable.

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] ...

## Out of Scope

A description of the things that are out of scope for this feature.

</plan-template>
