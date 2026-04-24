---
name: reef-scope
description: Scope an issue into a plan, ready for the Moonjelly Reef to pick up. Route between a feature, refactor, a bug triage or deep research. Turn an idea into a plan.
---

# reef-scope

## Input

A specific issue ID, or nothing.

```sh
ISSUE_ID="{issue-id or -}" # e.g. "#42"; "-" if nothing provided
SKILL_DIR="{base directory for this skill}" # e.g. ".agents/skills/reef-scope"
```

## Rules

Read `.agents/moonjelly-reef/config.md` to learn the tracker type and any installed optional skills. If the file doesn't exist, read and follow `$SKILL_DIR/setup.md` first, then return here.

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For `local-tracker`, run `./tracker.sh` exactly as written.
- For GitHub, replace `./tracker.sh` with `gh`, then execute the command as written.
- For other trackers with MCP issue tools, replace `./tracker.sh pr` with `gh pr`, and replace `./tracker.sh issue` with the MCP equivalent for that tracker.

## 0. Fetch context

If `"$ISSUE_ID" = "-"`, look for items labeled `to-scope`:

```sh
./tracker.sh issue list --label to-scope --json number,title
```

If multiple, ask the user to pick. If none, ask: "🪼 Did you want to scope something new?"

Set `ISSUE_ID` to the picked or confirmed issue number. If $ISSUE_ID is a specific ID, use it directly.

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

## 1. Prep

Record the start time:

```sh
START_TIME="{current UTC timestamp}" # e.g. "2026-04-24T09:00:00Z"
```

Fetch remote and check branch status:

```sh
git fetch origin --prune
```

Check if the current branch is behind its remote counterpart. If it is, notify the user:

> "{branch-name} is {N} commits behind origin. Want me to pull first?"

Wait for the user's response before continuing.

## 2. Show interactive route picker

Read the issue title and body fetched in step 0. From that text alone, recommend the single best route.

Present the picker to the user — mark exactly one route as `(recommended)`:

- `scope a feature`
- `scope a refactor`
- `triage a bug`
- `I'm feeling lucky (hand over to the reef)`
- `deep research`

Wait for the user to confirm or pick a different route.

Set the selected route:

```sh
BEARING="{selected route}"
# e.g.
# BEARING="feature"        (scope a feature)
# BEARING="refactor"       (scope a refactor)
# BEARING="bug"            (triage a bug)
# BEARING="feeling-lucky"  (I'm feeling lucky)
# BEARING="deep-research"  (deep research)
```

## 3. Write the plan

Follow the route-specific guide:

- **Feature**: see [scope-feature.md](scope-feature.md)
- **Refactor**: see [scope-refactor.md](scope-refactor.md)
- **Bug**: see [triage-issue.md](triage-issue.md)
- **Feeling lucky**: no guide — go directly to step 4.
- **Deep research**: see [scope-deep-research.md](scope-deep-research.md)

## 4. Branches

Suggest a base branch and a `pr-branch` name in a single line. Derive the `pr-branch` name from the issue title (kebab-case, short). For example:

> "Shall we plan to branch off `main`, with PR branch name `guard-branch-locking`. Good?"

The user confirms or adjusts. Both values are required before continuing.

## 5. Conflict anticipation

Scan for in-flight work that might overlap with this plan. List open issues that share the same `base-branch` and are past `to-scope` (i.e., already in-flight: `to-slice`, `in-progress`, `to-implement`, `to-inspect`, `to-rework`, `to-merge`, `to-seal`, `to-land`, `to-await-waves`).

```sh
BASE_BRANCH="{from branch discussion}" # e.g. "main"
for LABEL in to-slice in-progress to-implement to-inspect to-rework to-merge to-seal to-land to-await-waves; do
  ./tracker.sh issue list --label "$LABEL" --json number,title,body,labels
done
```

For each returned issue, parse the `base-branch` from its frontmatter. Keep only those whose `base-branch` matches the plan's `$BASE_BRANCH`. Skim each matching issue's plan body to assess whether it touches overlapping areas (same files, same modules, same concepts).

## 6. Persist the plan

Set variables from the discussion:

```sh
BASE_BRANCH="{from branch discussion}" # e.g. "main"
PR_BRANCH="{from branch discussion}" # e.g. "guard-branch-locking"
```

The plan gets **prepended** to the evolving issue body (pushing any prior decision record down). The decision record remains at the bottom for reference.

The issue body starts with frontmatter that downstream phases will read:

```markdown
---
base-branch: $BASE_BRANCH
pr-branch: $PR_BRANCH
bearing: "{selected bearing}"

---
```

```sh
ISSUE_BODY="{frontmatter + plan content}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY" --remove-label to-scope --add-label to-slice
```

## 7. Check for potential overlap in other issues

If overlapping in-flight work was found in step 5, surface it to the user:

> "From a quick look at current work in progress, this scope might lead to conflicts with #77 and #83. Should this issue wait for them to land?"

If the user says **no**, go to step 8.

If the user says **yes**, mark the dependency in the title only — do not change labels:

```sh
ISSUE_TITLE_UPDATED="{current issue title} [await: #77, #83]" # e.g. "Guard branch locking [await: #77, #83]"
./tracker.sh issue edit "$ISSUE_ID" --title "$ISSUE_TITLE_UPDATED"
```

If no overlapping work was found, continue silently.

## 8. Append metrics

Compute the duration from `$START_TIME` to now. Read the current issue body, then append a metrics section at the bottom:

```sh
DURATION="{human-readable duration since START_TIME}" # e.g. "42s", "1m 12s"
ISSUE_BODY="{current issue body with metrics section appended}"
./tracker.sh issue edit "$ISSUE_ID" --body "$ISSUE_BODY"
```

Metrics section format:

```markdown
### 🪼 Pulse metrics

| Phase | Target     | Duration  | Tokens | Tool uses | Outcome      | Date               |
| ----- | ---------- | --------- | ------ | --------- | ------------ | ------------------ |
| scope | #$ISSUE_ID | $DURATION | —      | —         | plan created | {yyyy-MM-dd HH:mm} |

<!-- end metrics table -->
```

## Handoff

Tell the user:

> 🪼 The plan is charted. Run `reef-pulse` when you're ready to dive in.
