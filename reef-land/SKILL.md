---
name: reef-land
description: Present the final report to the human for review. Human approves (merge to main), requests changes, or sends back for re-probing. Use when an issue is tagged to-land.
---

# reef-land

> **Tracker note**: Commands below use `tracker.sh` syntax for issue operations. For GitHub, replace `tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls. PR operations always use `gh` directly regardless of tracker.

## Input

This skill accepts either a plan issue or a PR: `/reef-land #42` or `/reef-land my-feature`.

Determine which you received — a plan issue ID or a PR number/URL. Set whichever is known:

```sh
PLAN_ID = {issue-id} # if passed
PR_NUMBER = {pr-number} # if passed
```

## 0. Fetch context

Use whichever identifier you have to look up the other:

- If you have `PLAN_ID`: read the plan body to find the PR number.
  ```sh
  tracker.sh issue view $PLAN_ID --json body,title,labels
  ```
- If you have `PR_NUMBER`: read the PR to find the plan issue reference.
  ```sh
  gh pr view $PR_NUMBER --json number,body,headRefName,baseRefName,comments,reviews
  ```

Now set all variables:

```sh
PLAN_ID = {from PR body or already known}
PR_NUMBER = {from plan body or already known}
BASE_BRANCH = {from plan body}
PR_BODY = {the PR body content — this is the ratify report}
```

Fetch PR comments and reviews:

```sh
gh pr view $PR_NUMBER --json comments,reviews # if not already fetched above
```

## 1. Summarize the report

Using `$PR_BODY` (already fetched), give the human a brief summary:

- What happened — how many slices, test results, overall status.
- Whether there are existing PR comments (and how many).
- Your assessment — factor in PR comments if they exist. E.g. "I think this is ready" vs "there are 3 PR comments that suggest changes are needed."

## 2. Route

### If there are PR comments

Acknowledge them: "You've left N comments on the PR." Then show a grouped summary of the comments. Then ask:

> I'd like to ask some questions so I can scope your concerns and change requests accurately.
>
> 1. Ask away → move to **step 3 (Scope change requests)**
> 2. Merge first but capture PR concerns and comments in a follow-up issue → move to **step 4 (Capture concerns in follow-up issue)**, then **step 5 (Approve)**, then **step 6 (Status report)**
> 3. Maybe later (exit) — the issue stays tagged `to-land` for next time.

### If there are NO PR comments

Ask the human:

> 1. Approve — looks good → move to **step 5 (Approve)**, then **step 6 (Status report)**
> 2. Open the PR in browser — I want to review the code first
> 3. I have concerns — let's discuss → move to **step 3 (Scope change requests)**
> 4. Maybe later (exit) — the issue stays tagged `to-land` for next time.

If (2): open the PR in the browser:

```sh
gh pr view $PR_NUMBER --web
```

Then say: "Take your time reviewing. Leave any comments on the PR, then let me know when you're ready to continue." Wait for the human. When they return, re-check for comments and return to the top of step 2.

## 3. Scope change requests

This section activates when there are PR comments, the human raised concerns during the report discussion, or the human explicitly requests changes.

Collect all feedback from:

- PR line comments
- PR review comments
- Anything the human said during steps 1–2

Then interview the human to refine the change requests into concrete, actionable gaps. The goal is alignment — you need to understand exactly what the human wants changed so the reef can act on it without further human input.

For each concern or comment:

- Confirm you understand it correctly
- Ask clarifying questions if the intent is ambiguous
- Propose how it maps to work: is it a code change? A restructuring? A naming fix?
- Check if it relates to an existing success criterion or needs a new one

Ask questions one at a time. For each question, provide your recommended answer.

If a question can be answered by exploring the codebase, explore the codebase instead of asking.

### Trivial vs substantial changes

When all change requests are scoped, assess their size:

- **Trivial** (renames, typos, small restructures, comment fixes): offer to make the fixes right now on the PR branch, run tests, and re-present for approval. If the human agrees, make the commits, push, and return to **step 2** to re-evaluate.
- **Substantial** (new logic, architectural changes, new acceptance criteria): write a gap report and send to rescan.

### Writing the gap report (substantial changes only)

Write the gap report as a comment on the plan issue. The reader of this report is a different agent (rescan) that has no context from this conversation — be explicit and self-contained.

```sh
tracker.sh issue comment $PLAN_ID --body "$GAP_REPORT"
```

The gap report format:

```markdown
## Change requests from human review

### Gaps

- **Gap 1**: {description} — maps to SC{N} / new criterion
- **Gap 2**: {description} — maps to SC{N} / new criterion
- ...

### New or updated success criteria (if any)

- [ ] {new criterion}

### Context

{Any relevant context from the discussion that would help the implementing agent.}
```

Then tag for rescan:

```sh
tracker.sh issue edit $PLAN_ID --remove-label to-land --add-label to-rescan
```

Tell the human:

> "Change requests scoped and written to the plan. The reef will pick this up on the next pulse and create new slices to address them."

## 4. Capture concerns in follow-up issue (when chosen in step 2)

Create a new issue with the PR comments and concerns, tagged `to-scope`:

```sh
FOLLOW_UP_CONTEXT = {summary of PR comments and concerns from step 2}
```

```sh
tracker.sh issue create --title "Follow-up: {summary of concerns}" --body "$FOLLOW_UP_CONTEXT" --label to-scope
```

Tell the human: "Created follow-up issue #{N}." Then continue to **step 5 (Approve)**.

## 5. Approve

Check merge status first:

```sh
gh pr view $PR_NUMBER --json mergeStateStatus -q .mergeStateStatus
```

If the PR cannot be merged (conflicts, failing checks, branch protection), tell the human what's blocking and exit. Do not force-merge.

Merge the PR using the strategy from config:

```sh
MERGE_STRATEGY = {from .agents/moonjelly-reef/config.md merge-strategy field}
```

```sh
gh pr merge $PR_NUMBER --$MERGE_STRATEGY --delete-branch
```

Pull the merged changes into the current branch if it matches the base branch:

```sh
git fetch origin --prune
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BASE_BRANCH" ]; then
  git pull --ff-only origin $BASE_BRANCH
fi
```

Close the plan:

```sh
tracker.sh issue close $PLAN_ID
```

## 6. Status report

Summarize what happened:

- That the PR was merged and the plan closed.
- Whether a follow-up issue was created (and link to it).

If a follow-up issue was created and tagged `to-scope`, suggest:

> "Follow-up issue #{N} is ready for scoping. Want to start `/reef-scope #{N}` now?"
