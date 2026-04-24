# Scoping a feature

## Input (from context)

```sh
ISSUE_ID="{from context}" # e.g. "#42"
```

## 1. Interview

RUN ONLY IF the issue does not have decisions captured yet.

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

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

## What does done look like

Testable conditions that must ALL be true for this work to be considered done. Each criterion must be mechanically verifiable.

- [ ] {criterion 1}
- [ ] {criterion 2}
- [ ] ...

## Out of Scope

A description of the things that are out of scope for this feature.

<details><summary>Interview log</summary>

{A chronological summary of the key questions asked and answers given during the interview. Include the topic, the question, and the answer. Omit small talk and clarifications that did not affect the plan.}

</details>

</plan-template>

Do not persist `$PLAN_BODY` to the issue yet — first continue to the next step.

```sh
PLAN_BODY="{assembled plan content from the template above}"
```

## 5. Think about what done looks like

Read the plan you just wrote. Ask yourself: are the done criteria already obvious from the interview and the user stories?

- If yes — default to "all user stories satisfied" and do not ask the human. The `## What does done look like` section you already wrote covers this.
- If genuinely unclear — ask one focused question: "What does done look like for you?"

Then append the done criteria to `$PLAN_BODY`:

```sh
PLAN_BODY_WITH_DONE="{$PLAN_BODY with ## What does done look like section filled in}"
```
