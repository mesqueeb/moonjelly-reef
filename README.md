# Agent Skills

A collection of agent skills that extend capabilities across planning, development, and tooling.

## Development

These skills help you write, refactor, and fix code.

- **close-the-loop** — Review and close GitHub tickets, PRs, or local task files by verifying implementation, tests, and documentation.

```sh
npx skills@latest add mesqueeb/skills/close-the-loop
```

## Tooling & Setup

- **git-guardrails-claude-code** — Block dangerous git commands in Claude Code (force push, hard reset, force delete) while allowing safe everyday operations. When worktrees exist, also blocks pushing from the main checkout to keep agents in their lane. Based on [`mattpocock/skills/git-guardrails-claude-code`](https://github.com/mattpocock/skills/tree/main/git-guardrails-claude-code) (extended with worktree-aware push allowance and `[gone]`-only force delete).

```sh
npx skills@latest add mesqueeb/skills/git-guardrails-claude-code
```

## Other Skills

Other skills I use:

```sh
# Planning & Design
  # - **grill-me** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
npx skills@latest add mattpocock/skills/grill-me
  # - **write-a-prd** — Create a PRD through an interactive interview, codebase exploration, and module design. Filed as a GitHub issue.
npx skills@latest add mattpocock/skills/write-a-prd
  # - **prd-to-plan** — Turn a PRD into a multi-phase implementation plan using tracer-bullet vertical slices.
npx skills@latest add mattpocock/skills/prd-to-plan
  # - **prd-to-issues** — Break a PRD into independently-grabbable GitHub issues using vertical slices.
npx skills@latest add mattpocock/skills/prd-to-issues
  # - **request-refactor-plan** — Create a detailed refactor plan with tiny commits via user interview, then file it as a GitHub issue.
npx skills@latest add mattpocock/skills/request-refactor-plan

# Development
  # - **tdd** — Test-driven development with a red-green-refactor loop. Builds features or fixes bugs one vertical slice at a time.
npx skills@latest add mattpocock/skills/tdd
  # - **triage-issue** — Investigate a bug by exploring the codebase, identify the root cause, and file a GitHub issue with a TDD-based fix plan.
npx skills@latest add mattpocock/skills/triage-issue
  # - **improve-codebase-architecture** — Explore a codebase for architectural improvement opportunities, focusing on deepening shallow modules and improving testability.
npx skills@latest add mattpocock/skills/improve-codebase-architecture

# Tooling & Setup
  # - **git-guardrails-claude-code** — Set up Claude Code hooks to block dangerous git commands (push, reset --hard, clean, etc.) before they execute.
npx skills@latest add mattpocock/skills/git-guardrails-claude-code

# Writing & Knowledge
  # - **write-a-skill** — Create new skills with proper structure, progressive disclosure, and bundled resources.
npx skills@latest add mattpocock/skills/write-a-skill
  # - **ubiquitous-language** — Extract a DDD-style ubiquitous language glossary from the current conversation.
npx skills@latest add mattpocock/skills/ubiquitous-language
```
