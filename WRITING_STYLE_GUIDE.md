# Writing Style Guide

Conventions for writing phase files and skills in the Moonjelly Reef framework. Phase files are instructions executed by an LLM agent — consistency makes them more predictable.

## First principle: battle vagueness with shell

When a step leaves the agent to figure out _what value_, _when_, or _where_, replace the prose with a shell variable assignment. An agent that reads a shell block cannot misread the order, the format, or the target. An agent that reads prose can.

**vague:** "Record the start time."
**shell:** `START_TIME="{current UTC timestamp}" # e.g. "2026-04-24T09:00:00Z"`

**vague:** footnote — "when persisting in step 6, use `to-implement` for bugs/refactors"
**shell:**

```sh
if [ "$HEADING" = "bug" ] || [ "$HEADING" = "refactor" ]; then
  NEXT_PHASE="to-implement"
else
  NEXT_PHASE="to-slice"
fi
```

**vague:** "Set the plan content. Append metrics. Edit title if conflicts found."
**shell:** one `ISSUE_BODY_UPDATED="..."` block assembling everything, followed by one `./tracker.sh issue edit` call.

All the micro-patterns in this guide are applications of this instinct.

## Structure

Every skill or phase file follows this top-level order:

1. `## Input` — declare all input variables upfront
2. `## Rules` — config reading, shell block note, tracker note, AFK or interactive note
3. `## 0. Fetch context` — first numbered step is always fetching from the tracker
4. `## 1.`, `## 2.`, … — remaining steps in execution order

Sub-sections within a step use `###`.

**Same-phase subfiles** (see Ubiquitous Language) omit `## Rules` entirely and use `## Input (from context)` instead of `## Input`. They run in the same session — `config.md` was already read and the tracker type is already known. Use `"{from context}"` as the placeholder for every input variable:

preferred: MERGE_STRATEGY="{from context}" # e.g. "squash"
anti-pattern: MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}" # e.g. "squash"

The first line of prose under `## Input (from context)` must state which file delegated to this one:

preferred: Context already fetched by `merge.md`.
anti-pattern: The router has already fetched context and set variables.

## Input section

Declare input variables and anything needed immediately (e.g. `SKILL_DIR`, a lock file path). Optional inputs use `"-"` as the nil sentinel:

preferred:

    ```sh
    ISSUE_ID="{issue-id or -}" # "-" if nothing provided
    SKILL_DIR="{base directory for this skill}"
    ```

anti-pattern: ISSUE_ID="{issue-id}" # if passed directly

All other variables are declared where they are first received or computed — not here.

## Rules section

The Rules section always contains these items, in this order:

1. Config reading — read `.agents/moonjelly-reef/config.md` to learn the tracker type and installed optional skills. State what to do if the file doesn't exist.
2. Shell block note — `**Shell blocks are literal commands** — execute them as written.`
3. Tracker note — bullet list of how to translate `./tracker.sh` per tracker type.
4. Behavior note — either `**AFK skill**` (no human interaction) or nothing (interactive).

## Variable declarations

Declare variables at the point where their value first becomes available — from a fetch or from a computation. Group all variables from a single source together immediately after that source is read, even if some are only used several steps later.

The most common case is the tracker fetch in step 0. Fetch once, then declare every variable you will need from it in a single block:

```sh
./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
```

```sh
ISSUE_TITLE="{from issue title}"
BASE_BRANCH="{from issue frontmatter base-branch field}"
PR_BRANCH="{from issue frontmatter pr-branch field}"
WORKTREE_PATH=".worktrees/$ISSUE_TITLE-{phase}"
```

anti-pattern: fetching the issue again later to read a field not extracted the first time
anti-pattern: declaring ISSUE_TITLE in step 0 and BASE_BRANCH in step 3, when both came from the same fetch

The same rule applies to `config.md`, which is read in `## Rules`. Declare every variable drawn from it right there — not deferred to the step that first uses it:

In `## Rules`:

```sh
MERGE_STRATEGY="{from .agents/moonjelly-reef/config.md merge-strategy field}" # e.g. "squash"
```

anti-pattern: declaring MERGE_STRATEGY in step 5 when config.md was already read in ## Rules

When a field may be absent, use a nil sentinel in the placeholder:

```sh
PARENT_ISSUE="{from issue frontmatter parent-issue field, or - if not present}"
```

Use `"{from issue frontmatter X field}"` as the placeholder style — it tells the agent exactly where to read the value from.

Variables derived from a computation are declared at the step that computes them.

## Updating fetched content

When a variable holds a modified version of something fetched, name it with the `_UPDATED` suffix. Never reuse the original variable name — it makes the before/after relationship explicit:

preferred: PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
anti-pattern: PR_BODY="$PR_BODY\n\n$REPORT"

This applies to any fetched content: `PR_BODY_UPDATED`, `ISSUE_BODY_UPDATED`, `PLAN_BODY_UPDATED`, `ISSUE_TITLE_UPDATED`, etc.

## Shell block grouping

Keep logically related commands in a single `sh` block. Only split into separate blocks when there is a meaningful pause — prose explanation, a conditional branch, or a step boundary between them:

preferred:

    ```sh
    REPORT="{phase-report}" # e.g. ...
    PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
    PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
    ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
    ```

anti-pattern:

    ```sh
    REPORT="{phase-report}" # e.g. ...
    PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
    PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
    ```

    ```sh
    ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
    ```

## Variable examples

Every placeholder variable should have a `# e.g.` comment showing a realistic value. This tells the agent the expected type and format at a glance:

preferred: AGENT_COUNT_SESSION="{session-wide dispatch count so far}" # e.g. 4
anti-pattern: AGENT_COUNT_SESSION="{session-wide dispatch count so far}"

String values must be quoted in the example, exactly as they would appear in a real assignment:

preferred: ISSUE_ID="{from the fetched issue}" # e.g. "#42"
preferred: NEXT_PHASE="{from handoff NEXT_PHASE}" # e.g. "to-inspect"
anti-pattern: ISSUE_ID="{from the fetched issue}" # e.g. #42

`$ISSUE_ID` already contains the full tracker-native identifier including `#`. Do not prepend `#` in prose or templates:

preferred: dispatched work for `$ISSUE_ID`
anti-pattern: dispatched work for `#$ISSUE_ID`

Numeric values are unquoted:

preferred: PULSE_NR="{current pulse number}" # e.g. 2
preferred: SESSION_START_TS="{unix timestamp captured at session start}" # e.g. 1735000000

Skip `# e.g.` only for hardcoded literals (the value is already the example) and computed expressions (the formula is self-evident).

## Agent vs sub-agent

Use "sub-agent" when referring to a spawned agent dispatched by the current session. "Agent" alone is ambiguous — it could mean the main session itself.

preferred: Wait for all flow sub-agents to complete before proceeding.
preferred: Dispatch a sub-agent per issue in parallel.
anti-pattern: Wait for all flow agents to complete before proceeding.
anti-pattern: Dispatch an agent per issue in parallel.

Variable names (`AGENT_COUNT_PULSE`, `SUBAGENT_DURATION`) and directory paths (`.agents/`) are exempt — do not rename those.

## Redundant ordering phrases

Do not use phrases like "Before doing anything else," when the step order already makes the sequence clear. The numbered steps are the ordering — prose that restates it adds noise.

anti-pattern: Before doing anything else, check for an existing pulse.lock file.
preferred: Check for an existing pulse.lock file.

**Exception: sub-agent waits must always be stated explicitly.** An agent dispatching sub-agents will move on immediately unless told to wait. Never rely on step ordering to imply a wait — always write it out in bold:

required: **Wait for all flow agents to complete before proceeding to the ebb wave.**
required: **Wait for the metric-logger sub-agent to complete before proceeding.**

## Conditionals

Wrap inline shell conditions in backticks:

preferred: If `"$ISSUE_ID" = "-"`
anti-pattern: If "$ISSUE_ID" = "-"

Always reference variables with `$VAR` syntax in prose — never bare names:

preferred: If `$ISSUE_ID` is a specific ID,
anti-pattern: If you have `ISSUE_ID`:
anti-pattern: If ISSUE_ID is known

**Use intent-expressive prose for positive checks, shell syntax for nil and boolean checks:**

Checking a variable has a meaningful value:

preferred: If `$ISSUE_ID` is a specific ID,
anti-pattern: if `"$ISSUE_ID" != "-"`:

Checking a variable is absent (nil sentinel):

preferred: If `"$ISSUE_ID" = "-"`,
anti-pattern: If nothing was provided,

Checking a boolean flag:

preferred: If `"$IS_SESSION_COMPLETE" = "true"`,
anti-pattern: If IS_SESSION_COMPLETE is true,

Checking a count:

preferred: If `"$AGENT_COUNT_PULSE" -gt 0`,
anti-pattern: If AGENT_COUNT_PULSE > 0,

Make both branches of a conditional explicit:

preferred: If `"$ISSUE_ID" = "-"`, fetch via PR_ID. If `"$PR_ID" = "-"`, fetch via ISSUE_ID.
anti-pattern: Use whichever identifier you have to look up the other.

**Shell blocks must contain valid POSIX sh — no pseudo-code.** Three common mistakes:

preferred: `[ "$SOMETHING" = "something" ]`
anti-pattern: `[$SOMETHING == "something"]` — missing spaces, `==` instead of `=`, unquoted variable

preferred: `[ "$VAR" = "value" ]`
anti-pattern: `[ $VAR = "value" ]` — unquoted variable breaks on empty or space-containing values

preferred: `if [ "$VAR" = "value" ]; then`
anti-pattern: `if $VAR == "value"` — no brackets

## Step guards

Steps that only run under certain conditions open with an explicit guard line. Prefer shell variable checks over prose conditions:

best: RUN ONLY IF `"$IS_SESSION_COMPLETE" = "true"`.
ok: RUN ONLY IF the tracker is `local-tracker-committed`.
ok: RUN ONCE PER SESSION.

Always use `RUN ONLY IF` — never `RUN IF` or `RUN ONLY WHEN`.

preferred: RUN ONLY IF `"$IS_SESSION_COMPLETE" = "true"`.
anti-pattern: RUN IF `"$IS_SESSION_COMPLETE" = "true"`.
anti-pattern: RUN ONLY WHEN `"$IS_SESSION_COMPLETE" = "true"`.

The best form uses a shell variable set earlier in the file — unambiguous and machine-checkable. Use prose conditions only when no shell variable captures the condition.

## Boolean flags

Compute booleans explicitly with `if/else` — never embed branching logic as a comment:

preferred:

    ```sh
    if [ "$AGENT_COUNT_PULSE" -eq 0 ]; then
      IS_SESSION_COMPLETE=true
    else
      IS_SESSION_COMPLETE=false
      PULSE_NR=$((PULSE_NR + 1))
    fi
    ```

anti-pattern:

    ```sh
    AGENT_COUNT_SESSION=$((AGENT_COUNT_SESSION + AGENT_COUNT_PULSE))
    PULSE_NR=$((PULSE_NR + 1)) # skip if AGENT_COUNT_PULSE = 0 (session complete)
    ```

## Sub-agent spawning

Pass context as already-expanded shell variables. For simple values, expand inline:

preferred:

    Dispatch a sub-agent:

    ```
    Read and follow $SKILL_DIR/implement.md.

    ISSUE_ID="$ISSUE_ID"
    ```

For complex values, prep the variable first, then pass it:

preferred:

    prep:

    ```sh
    SENTENCE_BALLPARK="$((PULSE_NR * 2))"
    ```

    Dispatch a sub-agent:

    ```
    Read and follow $SKILL_DIR/lore-writer.md.

    SENTENCE_BALLPARK="$SENTENCE_BALLPARK"
    ```

anti-pattern: Spawn a sub-agent and tell it to process the current issue.

The sub-agent receives unambiguous, already-resolved values — it should never have to infer context from prose.

## Result rows

Define `RESULT_ROW` with named fields, then print it — never describe output with a bare literal block:

preferred:

    ```sh
    RESULT_ROW="$ISSUE_PHASE_EMOJI  $ISSUE_ID   $SUBAGENT_DURATION   $SUBAGENT_TOKENS   $ISSUE_PHASE › $NEXT_PHASE"
    ```

    Print each `$RESULT_ROW`. E.g.:

    ```
    𐃆🐋  #34   3m12s   18k   slice › implement
      🐙  #55   4m45s   24k   implement › inspect
      🦀  #53   1m08s    9k   inspect › rework
    ```

anti-pattern:

    Print the results:

    ```
    𐃆🐋  #34   3m12s   18k   slice › implement
      🐙  #55   4m45s   24k   implement › inspect
      🦀  #53   1m08s    9k   inspect › rework
    ```

## Template blocks

When a step requires the agent to produce a specific piece of structured content — a PR description, issue body, config file, coverage matrix — show the expected structure using a named XML-style tag:

preferred:

    <pr-description-template>

    ## Judgment calls

    - **{topic}**: chose {X} because {reason}.

    </pr-description-template>

anti-pattern:

    ```markdown
    ## Judgment calls

    - **{topic}**: chose {X} because {reason}.
    ```

The tag name describes what the content is for. A code fence says "here is some markdown" — a named tag says "here is the template for X." Name the tag after the content's purpose: `<plan-template>`, `<pr-description-template>`, `<slice-body-template>`, `<config-template>`, `<coverage-matrix-template>`, etc.

## Report templates

Reports are collapsible blocks appended to a PR body after a phase completes (inspect, rework, seal, gap reports). Use `<report-template>` with `<details>/<summary>` inside so the agent knows the full output structure including the wrapper:

Before the template, set the timestamp in a `sh` code block:

    ```sh
    TIMESTAMP=$(date +"%Y/%m/%d %H:%M")
    ```

    <report-template>
    <details>
    <summary><h3>{emoji} {Phase name} — $TIMESTAMP</h3></summary>

    ### Section

    {content}

    </details>
    </report-template>

The `REPORT=` variable immediately below the template shows the expected shape via `# e.g.`. Use `{2012/12/21 12:00}` as the example date — it is obviously fake and cannot be mistaken for a real timestamp:

preferred: REPORT="{phase-report}" # e.g. <details><summary><h3>🧿 Inspect review — {2012/12/21 12:00}</h3></summary>...</details>
anti-pattern: REPORT="{phase-report}"
anti-pattern: REPORT="{phase-report}" # wrap content in a <details> block

Then fetch the current PR body and append:

    ```sh
    PR_BODY=$(./tracker.sh pr view "$PR_ID" --json body -q .body)
    PR_BODY_UPDATED="$PR_BODY\n\n$REPORT"
    ./tracker.sh pr edit "$PR_ID" --body "$PR_BODY_UPDATED"
    ```

## Tracker abstraction

Always use `./tracker.sh` for issue and PR operations:

preferred: ./tracker.sh issue view "$ISSUE_ID" --json body,title,labels
anti-pattern:  gh issue view "$ISSUE_ID" --json body,title,labels

The Rules section's tracker note tells the agent how to translate `./tracker.sh` for each tracker type.

When writing to or editing the issue, always show the `./tracker.sh` command — never describe the operation in prose:

preferred:

      ```sh
      ISSUE_ID_UPDATED="{$ISSUE_BODY updated with ...}" # short example
      ./tracker.sh issue edit "$ISSUE_ID_UPDATED" --body-file body.md
      ```

anti-pattern: Append the result to the issue body.
