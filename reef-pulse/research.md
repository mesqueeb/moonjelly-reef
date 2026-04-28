# research

## Input

This phase requires a specific issue: e.g. `#42` or `my-feature/001-auth-token-rotation`.

Set the input as a shell variable:

```sh
ISSUE_ID="{issue-id}" # e.g. "#42"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, assume `github` as the tracker type.

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

Verify the issue carries the `to-research` label.

If it does not, hand off and report these variables to the caller — **do not continue**:

```sh
ISSUE_ID="$ISSUE_ID"
NEXT_PHASE="—"
PR_ID="—"
SUMMARY="Skipped: issue does not carry the to-research label."
```

Else read the issue. It must contain:

- `base-branch` in frontmatter (where the PR merges into)
- `pr-branch` in frontmatter (the branch the PR lives on)

```sh
ISSUE_TITLE="{from issue title}" # e.g. "auth-token-rotation"
BASE_BRANCH="{from issue frontmatter base-branch field}" # e.g. "main"
PR_BRANCH="{from issue frontmatter pr-branch field}" # e.g. "research/001-auth-token-rotation"
WORKTREE_PATH=".worktrees/$(echo "$ISSUE_TITLE" | tr '/' '-')-research"
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

## 4. Write the report

When research is complete, compose the PR description using this template:

This output will be read by another agent session — no context from this conversation carries over. Be explicit and self-contained.

```sh
TIMESTAMP=$(date +"%Y/%m/%d %H:%M")
```

<report-template>
<details>
<summary><h3>🐬 Dolphin's findings — $TIMESTAMP</h3></summary>

### Judgment calls

- **{topic}**: chose {X} because {reason}. Differs from plan: {difference, if any}.

(If none, write "None — research followed the plan exactly.")

### Research outputs

- `{path/to/artifact.md}` — {what it answers}

</details>
</report-template>

```sh
REPORT="{research-report}" # e.g. <details><summary><h3>🐬 Dolphin's findings — {2012/12/21 12:00}</h3></summary>...</details>
```

## 5. Open the PR

```sh
./commit-push.sh --branch "$PR_BRANCH" -m "$ISSUE_TITLE: research"
CLOSES="closes $ISSUE_ID $ISSUE_TITLE" # e.g. "closes #42 auth-token-rotation"
PR_BODY_NEW="$CLOSES\n\n$REPORT"
./tracker.sh pr create --base "$BASE_BRANCH" --title "$ISSUE_TITLE" --body "$PR_BODY_NEW" --label to-inspect
PR_ID="{from pr create output}" # e.g. "#43"
```

## 6. Update the issue and label

Persist the PR metadata for the newly created PR on the issue body so downstream phases (inspect, rework, merge) can find it:

```sh
ISSUE_BODY_UPDATED="{original issue body with added frontmatter values}" # e.g. "---\npr-branch: research/001\npr-id: #43\n---\n..."
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

Report these variables to the caller.
