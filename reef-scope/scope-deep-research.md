# Scoping deep research

Use this route when the main task is to investigate, compare, or answer a question rather than jump straight into implementation.

## Input (from context)

## 1. Interview

Grill the user until the research target is sharp enough for downstream phases to execute without guessing.

Ask the questions one at a time and make progress without waiting on unnecessary follow-ups.

You must explicitly capture:

- what they want researched
- why it matters
- what end goal they want answered

If the issue already contains strong answers, confirm them briefly instead of re-asking verbatim.

## 2. Clarify the research target

Figure out the core question, what uncertainty needs to be reduced, and what would count as a useful outcome.

## 3. Define the research artifact

Plan for a durable Markdown deliverable in the repo. If external research will be needed, plan to keep lightweight `Sources:` links near the related findings.

## 4. Nail down completion criteria

Ask the user (one at a time, skip any already answered):

- What must be answered or documented for this research to be complete?
- What open questions, if left unanswered, would make this research feel incomplete?
- Who will act on the findings, and what do they need from this research to move forward?

Fold the answers into the Testing Decisions section of the plan. Do not create a separate section.

## 5. Write the plan

Write the scoped issue so the acceptance criteria describe what must be answered, clarified, or persisted, not what code must be written.

After writing the plan, append the full Q&A transcript from the interview:

```
<details><summary>Interview log</summary>

{full Q&A transcript}

</details>
```
