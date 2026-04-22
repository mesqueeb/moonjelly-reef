---
name: reef-scope
description: Scope an issue into a plan with success criteria. Routes between feature, refactor, and bug approaches. The single entry point for turning ideas into plans.
---

# reef-scope

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, run the `reef-pulse` skill and follow `reef-pulse/setup.md` first, then return here after.

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

## Metrics

Record the start time at invocation:

```sh
START_TIME="{current UTC timestamp}"
```

## Input

This skill accepts:

- a specific issue: for example `reef-scope #42` or `reef-scope my-feature`
- Nothing: look for items tagged `to-scope`. If multiple, ask the user to pick. If none, ask: "Did you want to scope something new?"

Set the initial variables:

```sh
ISSUE_ID="{issue-id}" # pre-existing and passed or generate
```

## 0. Fetch context

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

## 1. Git prep

```sh
git fetch origin --prune
```

Check if the current branch is behind its remote counterpart. If it is, notify the user:

> "{branch-name} is {N} commits behind origin. Want me to pull first?"

Wait for the user's response before continuing.

## 2. Write the plan

Read the issue and any existing decision record. Assess: is this a **feature**, **refactor**, or **bug**? Then follow the type-specific guide.

- **Feature**: see [scope-feature.md](scope-feature.md)
- **Refactor**: see [scope-refactor.md](scope-refactor.md)
- **Bug**: see [triage-issue.md](triage-issue.md)

## 3. Branches

Suggest a base branch and a PR branch name in a single line. Derive the PR branch name from the issue title (kebab-case, short). For example:

> "Shall we branch off `main` and call the branch `guard-branch-locking`?"

The user confirms or adjusts. Both values are required before continuing.

## 3b. Conflict anticipation

After the branch discussion, scan for in-flight work that might overlap with this plan. List open issues that share the same `base-branch` and are past `to-scope` (i.e., already in-flight: `to-slice`, `in-progress`, `to-implement`, `to-inspect`, `to-rework`, `to-merge`, `to-seal`, `to-land`, `to-await-waves`).

```sh
BASE_BRANCH="{from branch discussion}"
```

```sh
for LABEL in to-slice in-progress to-implement to-inspect to-rework to-merge to-seal to-land to-await-waves; do
  ./tracker.sh issue list --label "$LABEL" --json number,title,body,labels
done
```

For each returned issue, parse the `base-branch` from its frontmatter. Keep only those whose `base-branch` matches the plan's `$BASE_BRANCH`. Skim each matching issue's plan body to assess whether it touches overlapping areas (same files, same modules, same concepts).

If overlapping in-flight work is found, surface it to the user:

> "From a quick look at current work in progress, this scope might lead to conflicts with #77 and #83. Shall I add them as `blocked-by` in the plan frontmatter so implementation won't start until those land?"

The user confirms or adjusts. If they confirm, the `blocked-by` field will be set in the frontmatter during step 4.

If no overlapping work is found, continue silently.

## 4. Persist the plan

Set variables from the discussion:

```sh
BASE_BRANCH="{from branch discussion}"
PR_BRANCH="{from branch discussion}"
```

The plan gets **prepended** to the evolving file (pushing the decision record down) which becomes our ISSUE_BODY variable. The decision record remains at the bottom for reference.

The plan body starts with frontmatter that downstream phases will read:

```markdown
---
base-branch: $BASE_BRANCH
pr-branch: $PR_BRANCH
---
```

```sh
ISSUE_BODY="{plan-content}" # frontmatter + plan body from context
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-scope --add-label to-slice
```

## 5. Append metrics

Compute the duration from `$START_TIME` to now. Read the current plan issue body, then append a metrics section at the bottom:

```sh
DURATION="{human-readable duration since START_TIME}" # e.g. "42s", "1m 12s"
ISSUE_BODY="{current plan issue body with metrics section appended}"
```

```sh
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

Metrics section format:

```markdown
### 🪼 Pulse metrics

| Phase | Target    | Duration  | Tokens | Tool uses | Outcome      | Date               |
| ----- | --------- | --------- | ------ | --------- | ------------ | ------------------ |
| scope | #$ISSUE_ID | $DURATION | —      | —         | plan created | {yyyy-MM-dd HH:mm} |

<!-- end metrics table -->
```

## Handoff

Tell the user:

> "Plan with success criteria saved. Run the `reef-pulse` skill to let the reef take it from here."
