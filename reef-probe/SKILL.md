---
name: reef-probe
description: Interview the user about a feature, bug, or refactor idea until reaching shared understanding. Persists the full session. Use when a work item is tagged to-probe, or when starting something new.
---

# reef-probe

Before starting, verify `.agents/moonjelly-reef/config.md` exists. If not, run `/reef-setup` first and return here after.

> **Tracker note**: Examples below show GitHub and local file operations. For Jira, Linear, ClickUp, or other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](../reef-setup/tracker-reference.md).

## Input

This skill accepts:

- A specific work item: `/reef-probe #42` (GitHub issue) or `/reef-probe my-feature` (local folder name)
- Nothing: ask the user what they want to work on

If a specific item is given, read it first to understand the starting idea. If it's a GitHub issue, fetch it with `gh issue view <number>`. If it's a local folder, look for any existing file in it. If neither exists yet, that's fine — you'll create the artifact at the end.

**Branch check**: confirm you understand what branch the user is currently on. If it's a feature branch or something unexpected, ask: "I see you're on `branch-name` — should I be looking at this branch's code, or should we be thinking about `main`?" This matters because your codebase exploration needs to look at the right starting point.

## The interview

Interview the user relentlessly about every aspect of this idea until you reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one by one.

Rules:

- **Ask one question at a time.** Don't batch questions.
- **For each question, provide your recommended answer.** The user can accept, reject, or modify.
- **If a question can be answered by exploring the codebase, explore the codebase instead of asking.** Don't ask the user things you can verify yourself.
- **Push on the "consumer's perspective."** Who uses this? What do they see? What breaks if this is wrong? (Prevents painpoint A4 — builder's perspective dominating.)
- **Push on what "done" looks like.** If the user says "it should work like X", ask how they'd verify that. This seeds success criteria for reef-scope.
- **Don't let vagueness slide.** If an answer is hand-wavy, drill deeper. Vagueness here becomes ambiguity in every downstream skill.

Continue until you've resolved every branch. When you feel the tree is complete, say so and ask the user if they agree.

## Persist the session

Read the config to determine the tracker type.

### GitHub tracker

If the work item is an existing issue:

1. Rewrite the issue body to contain the full probe session (original idea text + all Q&A + all decisions resolved). Use `gh issue edit <number> --body "..."`.
2. Update the issue title if the original was vague (e.g. "idea: improve auth" → "Probe: token-based auth migration").
3. Add the label `to-scope`. Remove `to-probe` if present.

If no issue exists yet:

1. Create one with `gh issue create` containing the full probe session as the body.
2. Add the label `to-scope`.
3. Tell the user the issue number.

### Local tracker

Read the `Local path` from config (default: `.agents/moonjelly-reef/issue-tracker/`).

If a folder for this work item exists:

1. Find the main file in it (whatever file exists — could be `idea.md`, `plan.md`, anything).
2. Rewrite it as `[to-scope] plan.md` containing the full probe session.
3. Remove the old file if it had a different name.

If no folder exists:

1. Create `{local-path}/{title}/[to-scope] plan.md` with the full probe session.

### Session content format

The persisted probe session should be a clean document, not a raw chat log. Structure it as:

```markdown
## Probe Session

### Original idea

{the original idea text, verbatim}

### Decisions

For each decision resolved during the session:

**{topic}**: {what was decided}
- Context: {why — the key constraint or tradeoff}
- Verifiable as: {how to check this was implemented correctly}

### Open questions

{anything explicitly deferred or left unresolved, if any}
```

The "Verifiable as" field on each decision is critical — it feeds directly into success criteria during reef-scope.

## Handoff

Tell the user:

> "Probe session saved. Run `/reef-scope` when you're ready to turn this into a plan."
