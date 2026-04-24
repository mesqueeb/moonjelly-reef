# slice

## Input

This skill accepts:

- a specific issue: e.g. `#42` or `my-feature`
- nothing: look for items labeled `to-slice`. If multiple, pick the first one. If none, hand off with:

  ```sh
  ISSUE_ID="-"
  NEXT_PHASE="—"
  PR_ID="—"
  SUMMARY="No issues labeled to-slice found."
  ```

  Report these variables to the caller and **do not continue**.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed, e.g. #42
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

Verify the issue carries the `to-slice` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-slice label."
```

Report these variables to the caller and **do not continue**.

Read the issue. It must contain a plan with `## What does done look like` (from reef-scope). The frontmatter block tells you the work type, `base-branch`, and `pr-branch`.

```sh
BASE_BRANCH="{from issue frontmatter base-branch field, or - if not present}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field, or - if not present}"     # e.g. "feat/my-feature"
BEARING="{from issue frontmatter bearing field, or - if not present}"         # e.g. "feature"
```

### Guard: verify branch frontmatter

RUN ONLY WHEN `"$BASE_BRANCH" = "-"` or `"$PR_BRANCH" = "-"`.

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

Report these variables to the caller and **do not continue**.

### Resolve bearing

If `"$BEARING" = "feeling-lucky"`, this is the first phase allowed to deeply interpret the ticket. Infer the real lane (`feature`, `refactor`, `bug`, or `deep-research`) from the issue title, body, and codebase context. Then:

```sh
BEARING="{inferred lane}"  # e.g. "feature" — replaces "feeling-lucky"
FEELING_LUCKY="true"
```

Rewrite the plan issue body frontmatter: replace `bearing: feeling-lucky` with `bearing: $BEARING` and add `feeling-lucky: true` as a separate line.

```sh
ISSUE_BODY_UPDATED="{issue body with rewritten frontmatter}"
# e.g.
# ...original content...
# bearing: "feature"
# feeling-lucky: "true"
# ...original content...
```

Otherwise:

```sh
FEELING_LUCKY="false"
ISSUE_BODY_UPDATED="{issue body unchanged}"
```

Do not write `$ISSUE_BODY_UPDATED` to the issue yet — the delegatee applies it as part of their own update.

## 1. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Use `$BEARING` to adjust slice behavior:

- `deep-research` — plan as research-native work
- `feature`, `refactor`, `bug` — keep their normal slice behavior

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- For refactors: slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.
- If `"$BEARING" = "deep-research"`, draft research questions rather than implementation work. Compact research plans can stay as a single research issue. Larger research plans can be split into angle-based or dependency-based research slices. Acceptance criteria should say what must be answered, clarified, or persisted.
- If `"$FEELING_LUCKY" = "true"`, produce acceptance criteria and dependencies with best-effort judgment without asking the user follow-up questions.

For small bugs (scope = quick fix in the plan): produce a single slice. The items in `## What does done look like` become the slice's acceptance criteria directly.

## 2. Delegate

Pass `ISSUE_BODY_UPDATED`, `BEARING`, and `FEELING_LUCKY` through context to the delegatee.

Check: **did you produce exactly 1 slice?**

- **1 slice** — read and execute [slice-one-issue.md](slice-one-issue.md) (no sub-issues: no worktree, no branch creation, label `to-implement`)
- **2+ slices** — read and execute [slice-subissues.md](slice-subissues.md) (creates sub-issues: worktree, branch, coverage matrix, label `in-progress`)
