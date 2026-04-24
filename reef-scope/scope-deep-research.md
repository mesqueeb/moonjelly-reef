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

## 4. Write the plan

Write the plan using this template and store it in `$PLAN_BODY`:

Do not persist `$PLAN_BODY` to the issue yet — first continue to the next step.

<plan-template>

## Research Questions

A numbered list of the specific questions this research must answer.

## Why It Matters

The motivation and end goal behind this research.

## Research Artifact

Description of the durable Markdown deliverable: where it lives in the repo, what it must contain, and how findings should be linked to sources.

## What does done look like

All research questions answered and findings documented.

## Out of Scope

A description of the things that are out of scope for this research.

</plan-template>

## 5. Think about asking what done looks like

Default for deep-research: "all research questions answered and findings documented."

Consider whether the done criteria are already obvious from the interview. If the research questions and artifact definition make it clear what "done" means, use the default and do not ask the human. Only ask if the done criteria are genuinely ambiguous — for example, if there are competing definitions of success or if the human mentioned a specific threshold or deliverable format that isn't captured yet.

If you ask, incorporate the answer into the `## What does done look like` section of `$PLAN_BODY`. Update the variable:

```sh
PLAN_BODY="{updated plan body with What does done look like filled in}"
```

## 6. Append the interview log

Append an interview log block to `$PLAN_BODY` after the Out of Scope section:

```sh
PLAN_BODY="{$PLAN_BODY with interview log appended}"
```

The interview log format:

```markdown
<details><summary>Interview log</summary>

{full Q&A from the interview, verbatim}

</details>
```

Now persist `$PLAN_BODY` to the issue.
