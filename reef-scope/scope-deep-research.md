# Scoping deep research

Use this route when the main task is to investigate, compare, or answer a question rather than jump straight into implementation.

## 1. Interview

Grill the diver until the research target is sharp enough for downstream phases to execute without guessing.

Ask the questions one at a time and make progress without waiting on unnecessary follow-ups.

You must explicitly capture:

- what the diver wants researched
- why it matters
- what end goal the diver wants answered

If the issue already contains strong answers, confirm them briefly instead of re-asking verbatim.

## 2. Clarify the research target

Figure out the core question, what uncertainty needs to be reduced, and what would count as a useful outcome.

## 3. Define the research artifact

Plan for a durable Markdown deliverable in the repo. If external research will be needed, plan to keep lightweight `Sources:` links near the related findings.

## 4. Nail down Testing Decisions

Ask the diver (one at a time, skip any already answered):

- What must be answered or documented for this research to be complete?
- What open questions, if left unanswered, would make this research feel incomplete?
- Who will act on the findings, and what do they need from this research to move forward?

Fold the answers into the Testing Decisions section of the plan. Do not create a separate section.

## 5. Set the plan content

<plan-template>

## Problem Statement

The question or uncertainty the research must resolve.

## Research Questions

A numbered list of the specific questions this research must answer:

1. {question 1}
2. {question 2}
3. {question 3}

Every question must be answerable — it produces a concrete finding, decision, or documented outcome.

## Testing Decisions

What makes this research complete? Include:

- What must be answered or documented for this research to be complete
- What open questions, if left unanswered, would make the research feel incomplete
- Who will act on the findings and what they need to move forward

## Out of Scope

What this research does NOT need to answer.

</plan-template>

```sh
NEW_PLAN="{new plan content as per template above}" # e.g. "## Problem Statement\n\n..."
```
