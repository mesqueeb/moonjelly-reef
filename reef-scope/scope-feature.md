# Scoping a feature

Disciplines absorbed from: write-a-prd, prd-to-plan.

## Before writing

Sketch out the major modules you will need to build or modify. Actively look for opportunities to extract **deep modules** — a deep module (as opposed to a shallow module) encapsulates a lot of functionality behind a simple, testable interface which rarely changes.

Check with the user:
- Do these modules match their expectations?
- Which modules do they want tests written for?

## Plan structure

The plan should cover:

- **Problem statement**: from the user/consumer's perspective, not the builder's. What's broken or missing today? (Prevents painpoint A4 — builder's perspective dominating.)
- **Solution**: what the user will experience when this is done.
- **User stories**: extensive numbered list. `As an <actor>, I want <feature>, so that <benefit>`. This list should be extremely thorough and cover all aspects of the feature. It's better to have too many than to miss one.
- **Durable architectural decisions**: high-level decisions unlikely to change during implementation:
  - Route structures / URL patterns
  - Database schema shape
  - Key data models
  - Authentication / authorization approach
  - Third-party service boundaries

  These go in the plan header so every slice can reference them. Do NOT include specific file names, function names, or implementation details that are likely to change as later slices are built. DO include durable decisions: route paths, schema shapes, data model names.
- **Implementation decisions**: from the probe session. Modules to build/modify, interfaces, API contracts, schema changes, specific interactions. Do NOT include specific file paths or code snippets — they go stale quickly.
- **Testing decisions**: what makes a good test for this feature (test external behavior, not implementation details), which modules to test, prior art for tests in the codebase.
- **Out of scope**: what this plan explicitly does NOT cover.

## Collaborating with the user

After drafting the plan, present it and iterate:

- For each major section, ask if it matches the user's expectations
- For user stories: "Are any scenarios missing? Any that don't belong?"
- For architectural decisions: "Do these feel durable, or is anything likely to change?"
- For testing: "Which modules do you want tests for? Any existing test patterns I should follow?"

Iterate until the user approves. Don't rush this — gaps here become silent failures downstream.

## What makes a good feature plan

A good feature plan reads like a product spec that an engineer can implement without guessing. It describes the **what** and **why** clearly enough that the **how** follows naturally.

- Problem and solution are written from the consumer's perspective, not the builder's
- User stories are exhaustive
- Architectural decisions are durable — they won't change as implementation details shift
- The plan actively looks for opportunities to extract deep modules (small interface, large implementation) that can be tested in isolation
- Each section of the plan could be handed to a different agent and they'd produce compatible work
