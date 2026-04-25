# research

## Input

This skill requires a specific issue: e.g. `#42` or `my-feature/001-auth-token-rotation`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id or -}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills.

**Shell blocks are literal commands** — run `./worktree-enter.sh`, `./worktree-exit.sh`, and `./commit.sh` exactly as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-research` label. If it does not, hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-research label."
```

Report these variables to the caller and **do not continue**.

Read the issue. It must contain:

- `base-branch` in frontmatter (where the PR merges into)
- `pr-branch` in frontmatter (the branch the PR lives on)

```sh
ISSUE_TITLE="{from issue title}" # e.g. "auth-token-rotation"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "research/001-auth-token-rotation"
FEELING_LUCKY="{from issue frontmatter feeling-lucky field, or - if not present}" # e.g. "true"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-research"
```

## 1. Git prep

Every step must pass before you write research artifacts.

Enter a worktree forked from `$BASE_BRANCH` so you start from a clean integration point:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH")
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree. If resolved, commit the merge and push to `origin/$BASE_BRANCH` using explicit refspec (no force), then continue. If unresolvable:

```sh
./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
```

Hand off with:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="blocked-with-conflicts"
PR_ID="—"
SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
```

Report these variables to the caller and **do not continue**.

## 2. Read context

Read and understand:

- **Your research checklist** — in priority order: `## Acceptance criteria` if present; else the `## Research Questions` from the plan. Every item must be answered or documented.
- **The plan** — understand the question the research must answer (Research Questions, Testing Decisions).
- **Sibling issues** — awareness of what others are doing or have done. Don't duplicate, don't conflict.
- **The decision record** — the original decisions that led here.

## 3. Execute the research

Investigate the issue and persist the findings in committed Markdown files in the repository. The goal is to produce a durable research artifact instead of code.

Research outputs must:

- live in committed Markdown files
- keep lightweight source links near externally sourced findings
- clearly answer the promised question, angle, or uncertainty from the issue

If external research is unnecessary, say so in the artifact and skip source links for that section. If the issue reveals follow-up questions, capture them in the artifact instead of leaving them implicit.

Commit your work when the research artifacts are complete.

## 4. Write the report

When research is complete, compose the PR description using this template:

This output will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

```markdown
## Ambiguous choices

Decisions made during research that weren't covered by the plan or acceptance criteria, or where judgment was needed:

- **{topic}**: chose {X} because {reason}. This differs from the plan in that {difference, if any}.

(If no ambiguous choices were made, write "None — research followed the plan exactly.")

## Research outputs

- `{path/to/artifact.md}` — {what it answers}
```

## 5. Open the PR

```sh
./commit.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: research"
```

The PR body must start with the "closes" reference, followed by the research report:

```sh
CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g. "closes #42 auth-token-rotation"
REPORT="{research report}"
PR_BODY_NEW="$CLOSES\n\n$REPORT"
./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
```

The PR targets `$BASE_BRANCH` — the branch it merges into.

## 6. Update the issue and label

Persist the PR metadata for the newly created PR on the issue body so downstream phases (inspect, rework, merge) can find it:

```sh
PR_ID="{from pr create output}" # e.g. "#43"
ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}"
# add to frontmatter (if not already): pr-branch: $PR_BRANCH
# add to frontmatter:  pr-id: $PR_ID
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-research --add-label to-inspect
```

## 7. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-inspect"
PR_ID="$PR_ID"
SUMMARY="Research complete for $ISSUE_TITLE"
```

Report these three variables to the caller.
