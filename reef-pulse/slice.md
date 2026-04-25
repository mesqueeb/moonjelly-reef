# slice

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature/001-auth-endpoint`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, default to `local-tracker` and assume no optional skills are installed.

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this phase runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-slice` label.

If it does not, hand off and report these variables to the caller — **do not continue**:

    	```sh
    	ISSUE_ID="$ISSUE_ID"
    	NEXT_PHASE="—"
    	PR_ID="—"
    	SUMMARY="Skipped: issue does not carry the to-slice label."
    	```

Read the issue. It must contain a plan with User Stories, Implementation Decisions, and Testing Decisions (from reef-scope). If the plan needs multiple slices, this phase synthesizes those plan items into **acceptance criteria** per sub-issue. The frontmatter block tells you the work type, `base-branch`, and `pr-branch`.

```sh
ISSUE_BODY="{from issue body}"                                                 # e.g. "---\nheading: feature\n---\n..."
BASE_BRANCH="{from issue frontmatter base-branch field, or - if not present}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field, or - if not present}"     # e.g. "feat/my-feature"
HEADING="{from issue frontmatter heading field, or - if not present}"         # e.g. "feature"
```

### Guard: verify branch frontmatter

RUN ONLY IF `"$BASE_BRANCH" = "-"` or `"$PR_BRANCH" = "-"`.

```sh
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-slice --add-label blocked-missing-scope --add-label to-scope
```

Then hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-missing-scope"
PR_ID="—"
SUMMARY="Stopped: plan frontmatter is missing base-branch or pr-branch. Re-run /reef-scope to fix."
```

### Resolve heading

If `"$HEADING" = "feeling-lucky"`, this is the first phase allowed to deeply interpret the issue. Infer the real lane (`feature`, `refactor`, `bug`, or `deep-research`) from the issue title, body, and codebase context. Then:

```sh
HEADING="{inferred lane}"  # e.g. "feature" — replaces "feeling-lucky"
FEELING_LUCKY="true"
```

Rewrite the plan issue body frontmatter: replace `heading: feeling-lucky` with `heading: $HEADING` and add `feeling-lucky: true` as a separate line.

```sh
ISSUE_BODY_UPDATED="{issue body with rewritten frontmatter}" # e.g. "---\nheading: feature\nfeeling-lucky: true\n---\n..."
```

Otherwise:

```sh
FEELING_LUCKY="false"
ISSUE_BODY_UPDATED="$ISSUE_BODY"
```

Do not write `$ISSUE_BODY_UPDATED` to the issue yet — the delegatee applies it as part of their own update.

## 1. Draft vertical slices

Break the plan into slices. Each slice is a thin vertical cut through ALL integration layers end-to-end — not a horizontal slice of one layer.

Rules:

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests).
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.
- Do NOT include specific file names, function names, or implementation details likely to change.
- DO include durable decisions: route paths, schema shapes, data model names.
- Surface **implicit prerequisites**. If multiple slices depend on a shared dependency (a new table, a utility module, an API client, a piece of research), that dependency is its own slice and the others are blocked by it. (Prevents painpoint D2.)
- If `"$FEELING_LUCKY" = "true"`, produce acceptance criteria and dependencies with best-effort judgment without asking the user follow-up questions.

Use `$HEADING` to adjust slice behavior:

- If `"$HEADING" = "refactor"`, slices must respect the tiny-commit discipline. Each slice leaves the codebase compiling and tests green.
- If `"$HEADING" = "bug"`, depending on the nature of the plan, in most cases a single slice might be sufficient. The triage-written acceptance criteria in the plan become the sub-issue's acceptance criteria directly.
- If `"$HEADING" = "deep-research"`, focus on the research questions, and think how they can be split up from different perspectives or angles. Acceptance criteria should cover what must be answered, clarified, or persisted.

## 2. Delegate

Pass `ISSUE_BODY_UPDATED`, `HEADING`, and `FEELING_LUCKY` through context to the delegatee.

Check: **did you produce exactly 1 slice?**

- **1 slice** — read and execute [slice-one-issue.md](slice-one-issue.md) (no sub-issues: no worktree, no branch creation, label `to-implement`)
- **2+ slices** — read and execute [slice-subissues.md](slice-subissues.md) (creates sub-issues: worktree, branch, coverage matrix, label `in-progress`)
