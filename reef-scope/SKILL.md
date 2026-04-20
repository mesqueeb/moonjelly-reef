---
name: reef-scope
description: Scope an issue into a plan with success criteria. Routes between feature, refactor, and bug approaches. The single entry point for turning ideas into plans.
---

# reef-scope

Before starting, read `.agents/moonjelly-reef/config.md` — it tells you the issue tracker type (GitHub, local, Jira, etc.) and any installed optional skills. If the file doesn't exist, run `/reef-pulse` and follow `reef-pulse/setup.md` first, then return here after.

> **Shell blocks are literal commands** — `./tracker.sh` is a real script next to this file. Execute it as written; do not substitute with raw git commands.
>
> **Tracker note**: Commands below use `./tracker.sh` syntax. For local-tracker projects, run `./tracker.sh` directly. For GitHub, replace `./tracker.sh` with `gh`. For MCP trackers (ClickUp, Jira, Linear), use equivalent MCP tool calls.

## Metrics

Record the start time at invocation:

```sh
START_TIME = {current UTC timestamp}
```

## Input

This skill accepts:

- a specific issue: `/reef-scope #42` or `/reef-scope my-feature`
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

## 3. Base branch

Ask the user which branch to work off of:

> "What branch should we work off of? Some options:"
>
> - "`main`"
> - "The current branch (`branch-name`)"
> - "Something else?"

The target branch is decided later during slicing — don't ask about it here.

## 4. Persist the plan

The plan gets **prepended** to the evolving file (pushing the decision record down) which becomes our PLAN_CONTENT variable. The decision record remains at the bottom for reference.

The plan body starts with frontmatter that downstream phases will read:

```markdown
---
base-branch: $BASE_BRANCH
type: $PLAN_TYPE

---
```

Set variables from the discussion:

```sh
PLAN_ID="$ISSUE_ID"
BASE_BRANCH="{from base branch discussion}"
PLAN_TYPE="{feature, refactor, or bug}"
PLAN_CONTENT="{plan-content}" # frontmatter + plan body from context
```

```sh
./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_CONTENT" --remove-label to-scope --add-label to-slice
```

## 5. Append metrics

Compute the duration from `$START_TIME` to now. Read the current plan issue body, then append a metrics section at the bottom:

```sh
DURATION = {human-readable duration since START_TIME, e.g. "42s", "1m 12s"}
PLAN_BODY = {current plan issue body with metrics section appended}
```

```sh
./tracker.sh issue edit "$PLAN_ID" --body "$PLAN_BODY"
```

Metrics section format:

```markdown
### 🪼 Pulse metrics

| Phase | Target    | Duration  | Tokens | Tool uses | Outcome      | Date               |
| ----- | --------- | --------- | ------ | --------- | ------------ | ------------------ |
| scope | #$PLAN_ID | $DURATION | —      | —         | plan created | {yyyy-MM-dd HH:mm} |
```

## Handoff

Tell the user:

> "Plan with success criteria saved. Run `/reef-pulse` to let the reef take it from here."
