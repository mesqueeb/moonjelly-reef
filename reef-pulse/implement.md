# implement

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature/001-auth-endpoint`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, assume `github` as the tracker type.

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For local-tracker, run `./tracker.sh` and `./merge.sh` exactly as written.
- For GitHub, replace `./tracker.sh` and `./merge.sh` with `gh`
- For other trackers with MCP issue tools, replace `./tracker.sh issue` with their MCP equivalent and `./tracker.sh pr` and `./merge.sh pr` with `gh pr`

**AFK skill**: this skill runs without human interaction. When in doubt: check the plan, make your best judgment, move on. Never block waiting for human input.

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

Verify the issue carries the `to-implement` label.

If it does not, hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-implement label."
```

Else read the issue. It must contain:

- `base-branch` in frontmatter (where the PR merges into)
- `pr-branch` in frontmatter (the branch the PR lives on — chosen during scope for an issue with no `parent-issue`, or assigned during slice creation for an issue with `parent-issue`)
- `parent-issue` in frontmatter (if this is a sub-issue; absent otherwise)

Set the post-fetch variables:

```sh
ISSUE_TITLE="{from issue title}" # e.g. "add auth endpoint"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "my-feature/001-auth-endpoint"
PARENT_ISSUE="{from issue frontmatter parent-issue field, or - if not present}" # e.g. "#41"; "-"
WORKTREE_PATH=".worktrees/$(echo "$ISSUE_TITLE" | tr '/' '-')-implement"
```

## 1. Git prep

This is non-negotiable. Enter a worktree with the exact command below:

```sh
WORKTREE_STATUS=$(./worktree-enter.sh --fork-from "$BASE_BRANCH" --pull-latest "$BASE_BRANCH" --path "$WORKTREE_PATH") # e.g. "ready"
```

Read the output. On `ready` or `synced`: continue. On `conflicts`: attempt to resolve the conflicts in the worktree.

If resolved:

```sh
./commit-push.sh --branch "$BASE_BRANCH" -m "merge: resolve conflicts 🌊"
```

Then continue.

If unresolvable:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --add-label blocked-with-conflicts
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="blocked-with-conflicts"
    PR_ID="—"
    SUMMARY="Blocked: unresolvable merge conflicts. Resolve manually before retrying."
    ```

## 2. Initial verification

Verify:

- [ ] The project builds / compiles cleanly before you touch anything
- [ ] The full test suite passes before you touch anything (this is your baseline)

If the baseline is already broken, do not try to fix pre-existing failures. Label the issue `to-rework`:

    ```sh
    ./tracker.sh issue edit "$ISSUE_ID" --remove-label to-implement --add-label to-rework
    ./worktree-exit.sh --path "$WORKTREE_PATH"
    ```

    Hand off and report these variables to the caller — **do not continue**:

    ```sh
    ISSUE_ID="$ISSUE_ID"
    NEXT_PHASE="to-rework"
    PR_ID="—"
    SUMMARY="Blocked: baseline broken before implementation started. Pre-existing failures must be fixed first. (Prevents painpoint D1.)"
    ```

## 3. Read context

Read and understand:

- **Your implementation checklist** — in priority order: `## Acceptance criteria` if present; else `## Commits` for a refactor plan; else the User Stories, Implementation Decisions, and Testing Decisions directly. Every item must be addressed.
- **The plan** — understand the "why" behind this issue (User Stories, Implementation Decisions, Testing Decisions).
- **Sibling issues** — awareness of what others are doing or have done. Don't duplicate, don't conflict.
- **The decision record** — the original decisions that led here.

## 4. Implement with TDD

Use the `tdd` skill to implement each entry. If the `tdd` skill is not installed (check config), read and follow [tdd-lite.md](tdd-lite.md) instead.

Run the full project test suite after each red-green cycle — not just the tests you wrote. If an entry needs a human call, make your best judgment instead, note it for the `### Judgment calls` section of the report, and continue. Never silently skip an entry.

If any tests fail after implementation: run each failing test against `$BASE_BRANCH`. If the test also fails on `$BASE_BRANCH`, it is pre-existing — say so and include the evidence in the report. If the test passes on `$BASE_BRANCH` and fails on `$PR_BRANCH`, it is a regression you introduced — do not call it pre-existing.

## 5. Write the report

Compose the implementation report using this template. This output will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

```sh
DATE_FORMAT="{from .agents/moonjelly-reef/config.md date-format field, or 'yyyy-MM-dd HH:mm' if not set}"
TIMESTAMP=$(date +"$(echo "$DATE_FORMAT" | sed 's/yyyy/%Y/g;s/MM/%m/g;s/dd/%d/g;s/HH/%H/g;s/mm/%M/g')")
```

<report-template>
<details>
<summary><h3>🐙 Workshop report — $TIMESTAMP</h3></summary>

### Judgment calls

- **{topic}**: chose {X} because {reason}. Differs from plan: {difference, if any}.

(If none, write "None — implementation followed the plan exactly.")

### Test results

{Output of the full test suite run. If too long, summarize: "X tests passed, 0 failed, 0 skipped."}

### Screenshots / video

{If the app is launchable and the change is visual or user-facing, include a screenshot or screen recording demonstrating the behavior. If not applicable, omit this section entirely.}

</details>
</report-template>

```sh
REPORT="{implementation-report}" # e.g. <details><summary><h3>🐙 Workshop report — {2012/12/21 12:00}</h3></summary>...</details>
```

## 6. Open the PR

```sh
./commit-push.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: implementation"
CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g. "closes #42 add auth endpoint"
PR_BODY_NEW="$CLOSES\n\n$REPORT"
./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
PR_ID="{from pr create output}" # e.g. "#43"
```

## 7. Update the issue and label

Persist the PR metadata for the newly created PR on the issue body so downstream phases (inspect, rework, merge) can find it.

```sh
ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}" # e.g. "---\npr-branch: my-feature/001\npr-id: #43\n---\n..."
# add to frontmatter (if not already): pr-branch: $PR_BRANCH
# add to frontmatter:  pr-id: $PR_ID
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY_UPDATED" --remove-label to-implement --add-label to-inspect
```

## 8. Clean up

```sh
./worktree-exit.sh --path "$WORKTREE_PATH"
```

## Handoff

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="to-inspect"
PR_ID="$PR_ID"
SUMMARY="Implementation complete for $ISSUE_TITLE"
```

Report these four variables to the caller.
