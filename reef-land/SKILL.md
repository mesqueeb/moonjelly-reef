---
name: reef-land
description: Present the final report to the human for review. Human approves (merge to the base branch), requests changes, or sends back for re-probing. Use when an issue is labeled to-land.
---

# reef-land

## Input

Run the `reef-land` skill with either a plan issue or a PR, for example `reef-land #42` or `reef-land my-feature`.

Set whichever identifier was provided; use `"-"` for the one not provided:

```sh
ISSUE_ID="{issue-id or -}" # e.g. "#42"
PR_ID="{pr-id or -}"       # e.g. "#43"
```

## Rules

Before starting, read `.agents/moonjelly-reef/config.md` to learn the tracker type, merge strategy, and any installed optional skills.

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}" # e.g. "squash"
```

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

## 0. Fetch context

If `$ISSUE_ID` is a specific ID, read the plan body to find the PR number:

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

If `$PR_ID` is a specific ID, read the PR to find the plan issue reference:

```sh
./tracker.sh pr view "$PR_ID" --json number,body,headRefName,baseRefName,comments,reviews
```

Set all variables from the fetched data:

```sh
ISSUE_ID="{from PR body or already known}"  # e.g. "#42"
PR_ID="{from plan issue body or already known}"  # e.g. "#43"
BASE_BRANCH="{from plan issue body}"  # e.g. "main"
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

Using `$PR_BODY` (already fetched), give the human a brief summary:

- What happened — how many slices, test results, overall status.
- Whether there are active PR comments (unresolved + current) and how many. If there are also outdated/resolved threads, mention the count parenthetically (e.g. "2 active comments, 8 outdated/resolved").
- Your assessment — factor in active PR comments if they exist. E.g. "I think this is ready" vs "there are 3 active PR comments that suggest changes are needed."

## 2. Route

### If there are active PR comments

Acknowledge them: "You've left N comments on the PR." Then show a grouped summary of the comments. Then ask:

> I'd like to ask some questions so I can scope your concerns and change requests accurately.
>
> 1. Ask away → move to **step 3 (Scope change requests)**
> 2. Merge first but capture PR concerns and comments in a follow-up issue → move to **step 4 (Capture concerns in follow-up issue)**, then **step 5 (Approve)**, then **step 6 (Status report)**
> 3. Maybe later (exit) — the issue stays labeled `to-land` for next time.

### If there are NO active PR comments

Ask the human:

> 1. Approve — looks good → move to **step 5 (Approve)**, then **step 6 (Status report)**
> 2. Open the PR in browser — I want to review the code first
> 3. I have concerns — let's discuss → move to **step 3 (Scope change requests)**
> 4. Maybe later (exit) — the issue stays labeled `to-land` for next time.

If (2): open the PR in the browser:

```sh
./tracker.sh pr view "$PR_ID" --web
```

Then say: "Take your time reviewing. Leave any comments on the PR, then let me know when you're ready to continue." Wait for the human. When they return, re-check for comments and return to the top of step 2.

## 3. Scope change requests

RUN ONLY WHEN there are active PR comments, the human raised concerns during steps 1–2, or the human explicitly requests changes.

Collect all feedback from:

- Active (unresolved + current) PR review thread comments
- Anything the human said during steps 1–2

Then interview the human to refine the change requests into concrete, actionable gaps. The goal is alignment — you need to understand exactly what the human wants changed so the reef can act on it without further human input.

For each concern or comment:

1. Read all files and lines referenced in the comment.
2. Read related test files and codebase conventions relevant to the referenced area.
3. Form a hypothesis about the intent — decide whether the intent is clear or genuinely ambiguous.
4. Only surface a question to the human if the intent remains ambiguous after steps 1–3.
5. When asking, lead with your recommended answer that demonstrates the investigation.
6. Confirm your understanding of what change is needed.
7. Propose how it maps to work: code change? Restructuring? Naming fix?
8. Check whether it relates to an existing success criterion or needs a new one.

Ask questions one at a time.

### Trivial vs substantial changes

When all change requests are scoped, assess their size:

- **Trivial** (renames, typos, small restructures, comment fixes): offer to make the fixes right now on the `pr-branch`, run tests, and re-present for approval. If the human agrees, make the commits, push, and return to **step 2** to re-evaluate.
- **Substantial** (new logic, architectural changes, new acceptance criteria): write a gap report and send to rework.

### Writing the gap report (substantial changes only)

The gap report goes on the PR body in a `<details><summary>` block. Rework has no context from this conversation — be explicit and self-contained.

Append the gap report to the current PR body. Include original PR review comments (quoted, with file:line) and the refined context from your discussion.

```markdown
<details>
<summary><h3>📝 Change requests from human review — {yyyy/MM/dd HH:mm}</h3></summary>

### Gaps

- **Gap 1**: {description} — maps to SC{N} / new criterion

  > Original comment ({file}:{line}): {quoted PR review comment}

  Context: {what was clarified or decided}

### New or updated success criteria (if any)

- [ ] {new criterion}

</details>
```

Write this to the PR and update the label:

```sh
PR_BODY="{current PR body with gap report appended in <details><summary> block}"
```

```sh
./tracker.sh pr edit "$PR_ID" --body "$PR_BODY"
./tracker.sh issue edit "$ISSUE_ID" --remove-label to-land --add-label to-rework
```

If the discussion changed any plan-level Decisions, Stories, or Success Criteria, also update the plan body:

```sh
PLAN_BODY=$(./tracker.sh issue view "$ISSUE_ID" --json body)
./tracker.sh issue edit "$ISSUE_ID" --body "$PLAN_BODY"
./tracker.sh pr edit "$PR_ID" --remove-label to-land --add-label to-rework
```

Tell the human:

> "Change requests scoped and written to the PR. The reef will pick this up on the next pulse and rework them on the existing PR."

## 4. Capture concerns in follow-up issue (when chosen in step 2)

Create a new issue with the PR comments and concerns, labeled `to-scope`:

```sh
FOLLOW_UP_CONTEXT="{summary of PR comments and concerns from step 2}"  # e.g. "Reviewer noted the auth middleware doesn't handle expired tokens..."
```

```sh
./tracker.sh issue create --title "Follow-up: {summary of concerns}" --body "$FOLLOW_UP_CONTEXT" --label to-scope
```

Tell the human: "Created follow-up issue #{N}." Then continue to **step 5 (Approve)**.

## 5. Approve

Check merge status first:

```sh
./tracker.sh pr view "$PR_ID" --json mergeStateStatus -q .mergeStateStatus
```

If the PR cannot be merged (conflicts, failing checks, branch protection), tell the human what's blocking and exit. Do not force-merge.

Merge the PR using the strategy from config:

```sh
./tracker.sh pr merge "$PR_ID" --"$MERGE_STRATEGY" --delete-branch
./tracker.sh pr edit "$PR_ID" --remove-label to-land --add-label landed
```

Pull the merged changes into the current branch if it matches the base branch:

```sh
git fetch origin --prune
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BASE_BRANCH" ]; then
  git pull --ff-only origin "$BASE_BRANCH"
fi
```

Close the plan:

```sh
./tracker.sh issue close "$ISSUE_ID"
```

## 6. Status report

Summarize what happened:

- That the PR was merged and the plan closed.
- Whether a follow-up issue was created (and link to it).

If a follow-up issue was created and labeled `to-scope`, suggest:

> "Follow-up issue #{N} is ready for scoping. Want to run the `reef-scope` skill for it now?"
