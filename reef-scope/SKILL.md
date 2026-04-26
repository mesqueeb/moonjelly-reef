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

## Setup Guard

Read `.agents/moonjelly-reef/config.md` to learn the tracker type. If the file doesn't exist, read and follow `$SKILL_DIR/setup.md` first, then return here.

```sh
TRACKER_TYPE="{from .agents/moonjelly-reef/config.md tracker field}" # e.g. "local-tracker-committed"
TRACKER_BRANCH="{from .agents/moonjelly-reef/config.md tracker-branch field, or empty string if not set}"
```

If `"$TRACKER_TYPE" != "local-tracker-committed"`, skip the rest of this section.

If `"$TRACKER_BRANCH"` is empty or missing from config, warn the user — **do not continue**:

> ⚠️ `tracker-branch` is not set in `.agents/moonjelly-reef/config.md`. Please add it, then try again.

```sh
CURRENT_BRANCH="$(git branch --show-current)"
```

If `"$CURRENT_BRANCH" != "$TRACKER_BRANCH"`, warn the user — **do not continue**:

> ⚠️ Current branch is `$CURRENT_BRANCH` but the tracker branch is `$TRACKER_BRANCH`. Please run `git checkout $TRACKER_BRANCH` first, then try again.

```sh
./pull.sh --branch "$TRACKER_BRANCH"
```

## Rules

**Shell blocks are literal commands** — execute them as written.

**Tracker note**:

- For local-tracker, run `./tracker.sh` and `./merge.sh` exactly as written.
- For GitHub, replace `./tracker.sh` and `./merge.sh` with `gh`
- For other trackers with MCP issue tools, replace `./tracker.sh issue` with their MCP equivalent and `./tracker.sh pr` and `./merge.sh pr` with `gh pr`

## 0. Fetch context

```sh
if [ "$ISSUE_ID" != "-" ]; then
  ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
  ISSUE_TITLE="{from issue title}" # e.g. "Guard branch locking"
  ISSUE_BODY="{from issue body}" # e.g. "## Problem\n\nUsers can't log in..."
else
  ./tracker.sh issue list --label to-scope --json number,title
fi
```

If `$ISSUE_ID` was provided (not `-`), go to step "1. Prep"

If the user picked a `to-scope` issue from the list:

    ```sh
    ISSUE_ID="{selected issue}" # e.g. "#42"
    ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
    ISSUE_TITLE="{from issue title}" # e.g. "Guard branch locking"
    ISSUE_BODY="{from issue body}" # e.g. "## Problem\n\nUsers can't log in..."
    ```

If there are no `to-scope` issues, ask:

    > 🗺️📍 Did you want to scope something new?

    ```sh
    ISSUE_ID="-" # set to "-" to signify a new issue may be created later
    ISSUE_TITLE="" # set to empty string
    ISSUE_BODY="" # set to empty string
    ```

## 1. Prep

```sh
START_TIME="{current UTC timestamp}" # e.g. "2026-04-24T09:00:00Z"
./fetch.sh
```

Check if the current branch is behind its remote counterpart. If it is, notify the diver:

> "{branch-name} is {N} commits behind origin. Want me to pull first?"

Wait for the diver's response before continuing.

## 2. Show route picker 🧭

Present an interactive picker and if the issue is known mark exactly one route as `(recommended)`.

> Setting our heading 🧭
>
> 1. `scope a feature`
> 2. `scope a refactor`
> 3. `triage a bug`
> 4. `deep research`
> 5. `I'm feeling lucky (toss it in as-is, see what the reef creates)`

Wait for the diver to confirm or pick a different route, and set:

```sh
HEADING="{selected route}"
# e.g.
# HEADING="feature"        (scope a feature)
# HEADING="refactor"       (scope a refactor)
# HEADING="bug"            (triage a bug)
# HEADING="feeling-lucky"  (I'm feeling lucky)
# HEADING="deep-research"  (deep research)
```

## 3. Think out the plan

Follow the route-specific guide:

- If `"$HEADING" = "feature"`: see [scope-feature.md](scope-feature.md). On return, `$NEW_PLAN` is set.
- If `"$HEADING" = "refactor"`: see [scope-refactor.md](scope-refactor.md). On return, `$NEW_PLAN` is set.
- If `"$HEADING" = "bug"`: see [triage-issue.md](triage-issue.md). On return, `$NEW_PLAN` is set. If `triage-issue.md` reported `NEXT_PHASE="—"` (diver chose option 4), do not continue — stop here.
- If `"$HEADING" = "feeling-lucky"`: no guide — set `NEW_PLAN="$ISSUE_BODY"` and go directly to step 4.
- If `"$HEADING" = "deep-research"`: see [scope-deep-research.md](scope-deep-research.md). On return, `$NEW_PLAN` is set.

## 4. Branches

Suggest a `base-branch` and a `pr-branch` name in a single line. Derive the `base-branch` from the current branch and the `pr-branch` from the issue title (kebab-case, short). For example:

> "Shall we plan to branch off `main`, with pr-branch `guard-branch-locking`. Good?"

The diver confirms or adjusts. Both values are required before continuing.

```sh
BASE_BRANCH="{from branch discussion}" # e.g. "main"
PR_BRANCH="{from branch discussion}" # e.g. "guard-branch-locking"
```

## 5. Conflict anticipation

Scan for in-flight work that might overlap with this plan. List open issues that share the same `base-branch` and are past `to-scope` (i.e., already in-flight: `to-slice`, `in-progress`, `to-implement`, `to-inspect`, `to-rework`, `to-merge`, `to-seal`, `to-land`, `to-await-waves`).

```sh
for LABEL in to-slice in-progress to-implement to-inspect to-rework to-merge to-seal to-land to-await-waves; do
  ./tracker.sh issue list --label "$LABEL" --json number,title,body,labels
done
```

For each returned issue, parse the `base-branch` from its frontmatter. Keep only those whose `base-branch` matches `$BASE_BRANCH`. Skim each matching issue's plan body to assess whether it touches overlapping areas (same files, same modules, same concepts).

If overlapping work is found, ask:

> "From a quick look at current work in progress, this scope might lead to conflicts with #77 and #83. Should this issue wait for them to land?"

```sh
CONFLICTS="{issue numbers to await, or -}" # e.g. "#77, #83"; "-" if none or diver said no
```

## 6. Persist the plan

```sh
if [ "$CONFLICTS" = "-" ]; then
  # Set updated title now that you have all the info:
  ISSUE_TITLE_UPDATED="{updated $ISSUE_TITLE}" # e.g. "ACL based branch locking feature"
else
  # Suffix the title with the await annotation:
  ISSUE_TITLE_UPDATED="{updated $ISSUE_TITLE} [await: $CONFLICTS]" # e.g. "ACL based branch locking feature [await: #77, #83]"
fi

DURATION="{human-readable duration since $START_TIME}" # e.g. "42s", "1m 12s"
TIMESTAMP="{yyyy/MM/dd HH:mm}" # e.g. "2012/12/21 12:00"
INTERVIEW_TRANSCRIPT="{full interview Q&A transcript}" # e.g. Q: What are you trying to Build? A: ...
ISSUE_BODY_UPDATED="---
base-branch: $BASE_BRANCH
pr-branch: $PR_BRANCH
heading: $HEADING

---

$NEW_PLAN

### 🪼 Pulse metrics

| Phase | Target     | Duration  | Tokens | Tool uses | Outcome      | Date       |
| ----- | ---------- | --------- | ------ | --------- | ------------ | ---------- |
| scope | $ISSUE_ID  | $DURATION | —      | —         | plan created | $TIMESTAMP |

<!-- end metrics table -->

<details>
<summary><h3>🤿 Original interview — $TIMESTAMP</h3></summary>
$INTERVIEW_TRANSCRIPT
</details>

"

if [ "$HEADING" = "bug" ] || [ "$HEADING" = "refactor" ]; then
  NEXT_PHASE="to-implement"
else
  NEXT_PHASE="to-slice"
fi

./tracker.sh issue edit "$ISSUE_ID" --title "$ISSUE_TITLE_UPDATED" --body "$ISSUE_BODY_UPDATED" --remove-label to-scope --add-label "$NEXT_PHASE"
```

## Handoff

Tell the diver:

> 🧭 Heading set. The plan is charted. Run `reef-pulse` when you're ready to dive in.
