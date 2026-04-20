# slice

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, read and follow [setup.md](setup.md) first and return here after.

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

> **AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## Input

This skill accepts:

- a specific issue: e.g. `#42` or `my-feature`
- nothing: look for items tagged `to-slice`. If multiple, pick the first one. If none, exit silently.

Set the pre-fetch variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Read the issue. It must contain a plan with success criteria (from reef-scope). Success criteria are plan-level; this skill breaks them into **acceptance criteria** per slice. The plan metadata block tells you the work type, base branch, and target branch name.

## 1. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- For refactors: slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.

For small bugs (scope = quick fix in the plan): produce a single slice. The plan's success criteria become the slice's acceptance criteria directly.

## 2. Delegate

After drafting, check: **did you produce exactly 1 slice?**

- **1 slice** — read and execute [slice-single.md](slice-single.md) (fast path: no worktree, no branch, tag `to-implement`)
- **2+ slices** — read and execute [slice-multi.md](slice-multi.md) (full flow: worktree, branch, coverage matrix, sub-issues, tag `in-progress`)
