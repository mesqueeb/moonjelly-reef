# slice

## Input

This skill accepts:

- a specific issue: e.g. `#42` or `my-feature`
- nothing: look for items tagged `to-slice`. If multiple, pick the first one. If none, hand off with:

  ```sh
  ISSUE_ID="${ISSUE_ID:-—}"
  NEXT_PHASE="—"
  PR_ID="—"
  SUMMARY="No issues tagged to-slice found."
  ```

  Report these variables to the caller and **do not continue**.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed, e.g.: #42
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — run `./tracker.sh` exactly as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Read the issue. It must contain a plan with success criteria (from reef-scope). Success criteria are plan-level; this skill breaks them into **acceptance criteria** per slice. The frontmatter block tells you the work type, `base-branch`, and `pr-branch`.

Set the post-fetch variables:

```sh
BASE_BRANCH="{from issue frontmatter base-branch field}"
PR_BRANCH="{from issue frontmatter pr-branch field}"
BEARING="{from issue frontmatter bearing field}"
```

### Guard: verify branch frontmatter

Parse the plan frontmatter. If `base-branch` or `pr-branch` is missing, stop immediately:

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-slice --add-label blocked-missing-scope --add-label to-scope
```

Then hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-missing-scope"
PR_ID="—"
SUMMARY="Stopped: plan frontmatter is missing base-branch or pr-branch. Re-run /reef-scope to fix."
```

Report these three variables to the caller and **do not continue**.

## 1. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Use `$BEARING` (already set in step 0) to adjust slice behavior:

- `deep-research` — plan as research-native work
- `feeling-lucky` — deliberately under-scoped work that must be interpreted here
- `feature`, `refactor`, `bug` — keep their normal slice behavior

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- For refactors: slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.
- If the plan bearing is `deep-research`, draft research questions rather than implementation work. Compact research plans can stay as a single research issue. Larger research plans can be split into angle-based or dependency-based research slices. Acceptance criteria should say what must be answered, clarified, or persisted.
- If the plan bearing is `feeling-lucky`, this is the first phase allowed to deeply interpret the ticket using both the issue and the codebase. Infer the likeliest lane, set `bearing` to that value, and add `feeling-lucky: true` as a separate frontmatter flag. Produce acceptance criteria and dependencies with best-effort judgment without asking the user follow-up questions.

For small bugs (scope = quick fix in the plan): produce a single slice. The plan's success criteria become the slice's acceptance criteria directly.

## 2. Delegate

After drafting, check: **did you produce exactly 1 slice?**

- **1 slice** — read and execute [slice-one-issue.md](slice-one-issue.md) (no sub-issues: no worktree, no branch creation, label `to-implement`)
- **2+ slices** — read and execute [slice-subissues.md](slice-subissues.md) (creates sub-issues: worktree, branch, coverage matrix, label `in-progress`)
