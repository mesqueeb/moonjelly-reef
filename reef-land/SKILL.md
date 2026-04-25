---
name: reef-land
description: Present the final report to the diver for review. The diver approves (merge to the base branch), requests changes, or sends back to rework. Use when an issue is labeled to-land.
---

# reef-land

## Input

Run the `reef-land` skill with either an issue or a PR, for example `reef-land #42` or `reef-land my-feature`.

Set whichever identifier was provided; use `"-"` for the one not provided:

```sh
ISSUE_ID="{issue-id or -}" # e.g. "#42"
PR_ID="{pr-id or -}"       # e.g. "#43"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type and merge strategy.

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}" # e.g. "squash"
```

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

## 0. Fetch context

If `$ISSUE_ID` is a specific ID, read the issue body to find the pr-id:

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

If `$PR_ID` is a specific ID, read the PR to find the issue reference:

```sh
./tracker.sh pr view "$PR_ID" --json number,body,headRefName,baseRefName,comments,reviews
```

Set all variables from the fetched data:

```sh
ISSUE_ID="{from PR body or already known}"  # e.g. "#42"
PR_ID="{from issue body or already known}"  # e.g. "#43"
BASE_BRANCH="{from issue frontmatter base-branch field, or from PR baseRefName}"  # e.g. "main"
PR_BODY="{the PR body content — this contains the seal report}"  # e.g. "closes #42 ...\n\n## Test results\n..."
```

Fetch PR review threads and filter to only active (unresolved + current) comments:

```sh
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

gh api graphql \
  -f owner="$OWNER" -f repo="$REPO" -F number="$PR_ID" \
  -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      comments(first: 50) {
        nodes { body author { login } createdAt }
      }
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          comments(first: 5) {
            nodes { body path line author { login } }
          }
        }
      }
    }
  }
}'
```

From the result, filter with jq:

- **PR comments** (conversation): `.comments.nodes` — these are always active (no outdated/resolved concept)
- **Review thread counts**: `.reviewThreads.nodes as $t | { active: [$t[] | select(.isResolved == false and .isOutdated == false)] | length, outdated: [$t[] | select(.isOutdated == true)] | length, resolved: [$t[] | select(.isResolved == true)] | length }`
- **Active review comments**: `.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false) | .comments.nodes[] | {body, path, line, author: .author.login}`

Both PR comments and active review comments count as PR comments for the steps below.

## 1. Summarize the report

Using `$PR_BODY` (already fetched), give the diver a brief summary:

- What happened — how many slices, test results, overall status.
- Whether there are active PR comments (unresolved + current) and how many. If there are also outdated/resolved threads, mention the count parenthetically (e.g. "2 active comments, 8 outdated/resolved").
- Your assessment — factor in active PR comments if they exist. E.g. "I think this is ready" vs "there are 3 active PR comments that suggest changes are needed."

## 2. Route

### If there are active PR comments

Acknowledge them: "You've left N comments on the PR." Then ask:

> 1. I'll investigate the comments, then we'll decide: gap report, fix right now, or clean merge → move to **step 3 (Clarify change requests)**
> 2. Merge first and capture PR concerns in a follow-up issue → move to **step 4 (Capture concerns in follow-up issue)**, then **step 5 (Approve)**, then **step 6 (Status report)**
> 3. Maybe later (exit) — the issue stays labeled `to-land` for next time.

### If there are NO active PR comments

Ask the diver:

> 1. Approve — looks good → move to **step 5 (Approve)**, then **step 6 (Status report)**
> 2. Open the PR in browser — I want to review the code first
> 3. I have concerns — let's discuss → move to **step 3 (Clarify change requests)**
> 4. Maybe later (exit) — the issue stays labeled `to-land` for next time.

If (2): open the PR in the browser:

```sh
./tracker.sh pr view "$PR_ID" --web
```

Then say:

> 🪼 Take your time diving in. Leave any comments on the PR, then surface when you're ready.

Wait for the diver. When they return, re-check for comments and return to the top of step 2.

## 3. Clarify change requests

RUN ONLY IF there are active PR comments, the diver raised concerns during steps 1–2, or the diver explicitly requests changes.

Collect all feedback from:

- Active (unresolved + current) PR review thread comments
- Anything the diver said during steps 1–2

Then interview the diver to refine the change requests into concrete, actionable gaps. The goal is alignment — you need to understand exactly what the diver wants changed so the reef can act on it without further diver input.

For each concern or comment:

1. Read all files and lines referenced in the comment.
2. Read related test files and codebase conventions relevant to the referenced area.
3. Form a hypothesis about the intent — decide whether the intent is clear or genuinely ambiguous.
4. Only surface a question to the diver if the intent remains ambiguous after steps 1–3.
5. When asking, lead with your recommended answer that demonstrates the investigation.
6. Confirm your understanding of what change is needed.
7. Propose how it maps to work: code change? Restructuring? Naming fix?
8. Check whether it relates to an existing User Story, Implementation Decision, or Testing Decision in the plan, or needs a new one.

Ask questions one at a time.

### Trivial vs substantial changes

When all change requests are clarified, assess their size:

- **Trivial** (renames, typos, small restructures, comment fixes): offer to make the fixes right now on the `pr-branch`, run tests, and re-present for approval. If the diver agrees, make the commits, push, and return to **step 2** to re-evaluate.
- **Substantial** (new logic, architectural changes, new acceptance criteria): write a gap report and send to rework.

### Writing the gap report (substantial changes only)

The gap report goes on the PR body in a `<details><summary>` block. Rework has no context from this conversation — be explicit and self-contained.

Append the gap report to the current PR body. Include original PR review comments (quoted, with file:line) and the refined context from your discussion.

<report-template>
<details>
<summary><h3>🤿 Diver's notes — {yyyy/MM/dd HH:mm}</h3></summary>

### Gaps

- **Gap 1**: {description} — maps to user story {N} / implementation decision {N} / new acceptance criterion

  > Original comment ({file}:{line}): {quoted PR review comment}

  Context: {what was clarified or decided}

### New or updated User Stories, Implementation Decisions, or Testing Decisions (if any)

- [ ] {new criterion}

</details>
</report-template>

Write this to the PR and update the label:

```sh
REPORT="{gap-report}" # e.g. <details><summary><h3>🤿 Diver's notes — {2012/12/21 12:00}</h3></summary>...</details>
PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED" --remove-label to-land --add-label to-rework
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-land --add-label to-rework
```

If the discussion changed any plan-level User Stories, Implementation Decisions, or Testing Decisions, also update the plan body:

```sh
PLAN_BODY=$(./tracker.sh issue view "$ISSUE_ID" --json body -q .body)
PLAN_BODY_UPDATED="{original plan body with updated User Stories, Implementation Decisions, or Testing Decisions}" # e.g. "---\n...\n---\n\n## Problem Statement\n\n..."
./tracker.sh issue edit "$ISSUE_ID" --body "$PLAN_BODY_UPDATED"
```

Tell the diver:

> "Change requests charted. 🪼 The reef will carry them on the next pulse."

## 4. Capture concerns in follow-up issue (when chosen in step 2)

Create a new issue with the PR comments and concerns, labeled `to-scope`:

```sh
FOLLOW_UP_CONTEXT="{summary of PR comments and concerns from step 2}"  # e.g. "Reviewer noted the auth middleware doesn't handle expired tokens..."
./tracker.sh issue create --title "Follow-up: {summary of concerns}" --body "$FOLLOW_UP_CONTEXT" --label to-scope
```

Tell the diver: "Created follow-up issue #{N}." Then continue to **step 5 (Approve)**.

## 5. Approve

Check merge status first:

```sh
./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
```

If the PR cannot be merged (conflicts, failing checks, branch protection), tell the diver what's blocking and exit. Do not force-merge.

Merge the PR using the strategy from config:

```sh
./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
./tracker.sh pr edit "$PR_ID" --remove-label to-land --add-label landed
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-land --add-label landed
```

Pull the merged changes into the current branch if it matches the base branch:

```sh
git fetch origin --prune
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BASE_BRANCH" ]; then
  git pull --ff-only origin "$BASE_BRANCH"
fi
```

Close the issue:

```sh
./tracker.sh issue close "$ISSUE_ID"
```

## 6. Status report

Summarize what happened:

- That the PR was merged and the issue closed.
- Whether a follow-up issue was created (and link to it).

If a follow-up issue was created and labeled `to-scope`, suggest:

> "Follow-up issue #{N} is ready for scoping. Want to run the `reef-scope` skill for it now?"
