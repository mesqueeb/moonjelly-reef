<p align="center">
  <img alt="logo" src="./.github/assets/moonjelly.png" width="320" />
</p>

# Moonjelly Reef

An orchestration framework for AI agent workflows. A short-lived pulse scans for work, dispatches skills, and goes back to sleep. State lives in labels. The reef does the rest.

This framework is **Issue tracker agnostic**. GitHub Issues or simply local MD files. It can also handle others like Jira, ClickUp, Linear, as long as you have an MCP installed for those.

## Install

```sh
npx skills@latest add mesqueeb/moonjelly-reef
```

On first run, reef-pulse will prompt you to mention which issue tracker you want to use.

## 🪼 The moonjelly pulse

> _Through Moonjelly's pulse, the reef is orchestrated, creatures are set in motion, and Moonjelly recedes._

The moonjelly is the orchestrator. Label-driven orchestrator that routes work to different sub-agents based on labels and keeps looping until no automated work remains. It holds no state — labels are the state.

## State machine

> 🤿 = human (the diver)
> 🌊 = automated (the reef)

```mermaid
stateDiagram-v2
    direction TB

    classDef human fill:#ffeaa7,stroke:#fdcb6e,color:#2d3436
    classDef agent fill:#81ecec,stroke:#00cec9,color:#2d3436
    classDef arrow fill:#ececec,stroke:#ffffff00,color:#2d3436

    state "DELIVERY CYCLE" as work {

        state "🤿　to-scope" as to_scope
        state "🌊　to-slice" as to_slice
        state "🌊　to-seal" as to_seal
        state "🤿　to-land" as to_land

        [*] --> to_scope
        to_scope --> to_slice : reef-scope skill<br />scope the work, define success criteria
        to_slice --> slice_lifecycle : slice.md<br />🔷　creates sub-issues:<br />labels each sub-issue to-implement
<br />adds coverage matrix to parent issue
        to_slice --> slice_lifecycle : slice.md<br />🔶　no sub-issues needed:<br />labels the current issue to-implement
        slice_lifecycle --> to_seal
        slice_lifecycle --> to_land
        to_seal --> to_land : seal.md<br />holistic review on current issue pr-branch
        to_seal --> slice_lifecycle : seal.md<br />gaps found, add to-rework
        to_land --> [*] : reef-land skill<br />human approves, merges into base branch
        to_land --> slice_lifecycle : reef-land skill<br />human requests changes<br />add to-rework
    }

    state "IMPLEMENTATION CYCLE" as slice_lifecycle {

        state "🌊　to-await-waves" as to_await
        state "🌊　to-implement" as to_implement
        state "🌊　to-inspect" as to_inspect
        state "🌊　to-rework" as to_rework
        state "🌊　to-merge" as to_merge
        state "merge.md<br />🔷　has parent issue:<br />merge PR, when all sub-issues are landed → to-seal" as merge_multi
        state "merge.md<br />🔶　no parent issue:<br />PR stays open → to-seal" as merge_single
        [*] --> to_implement : no deps
        [*] --> to_await : has deps
        to_await --> to_implement : await-waves.md<br />check if deps are landed, re-review plan
        to_implement --> to_inspect : implement.md<br />TDD per slice, full suite green
        to_inspect --> to_merge : inspect.md<br />acceptance criteria met, PR clean
        to_inspect --> to_rework : inspect.md<br />gaps flagged
        to_rework --> to_inspect : rework.md<br />read feedback, fix, re-verify
        to_merge --> merge_multi
        to_merge --> merge_single
    }

    class to_scope,to_land human
    class to_slice,to_seal,plan_rework,to_await,to_implement,to_inspect,to_rework,to_merge agent
    class merge_multi,merge_single arrow
```

> While sub-issues are being worked, the parent issue sits in `in-progress`. It is promoted to `to-seal` by `merge.md` once all sub-issues are landed.
>
> Each issue has one `DELIVERY CYCLE`. It may contain one or many `IMPLEMENTATION CYCLE`s: one on the issue itself when no sub-issues are needed, or one per sub-issue when the work is split.

## Skills

<details>
<summary>🤿 <b><code>reef-scope</code></b> — scope an issue</summary>

The single entry point for turning ideas into plans. Determines whether the work is a feature, refactor, or bug, interviews the diver if needed, writes a plan with **success criteria**, and labels `to-slice`.

| source file | [`reef-scope/SKILL.md`](reef-scope/SKILL.md) |
| :---------- | :------------------------------------------- |

</details>

<p align="right">🪼<br /><sub>Moonjelly drifts beside the diver like a hand-lantern in blue water. Together they peer into the dimness until the shape of the work comes gently into view.</sub></p>

<details>
<summary>🤿 / 🌊 <b><code>reef-pulse</code></b> — the orchestrator</summary>

Runs pulse iterations inside one short-lived session: scan labels, route work to the appropriate sub-agent, recurse while automated work remains, then exit. Holds no state — labels are the state. Run it manually or from cron; the skill handles the same pulse flow either way.

If you've queued up enough issues with the `reef-scope` skill, running the `reef-pulse` skill will make the reef start the work, recursively pulsing through all automated phases until no automated work remains.

Design principles:

- **Testing at source**: each transition includes verification before tagging.
- **Small batches**: slices flow independently and concurrently.
- **Human = bottleneck**: minimize 🤿 states. Only two: scope, land.
- **No heroics**: agents that are stuck flag + move on, never spiral.
- **Make work visible**: the labels ARE the visibility.

| source file | [`reef-pulse/SKILL.md`](reef-pulse/SKILL.md) |
| :---------- | :------------------------------------------- |

</details>

<p align="right">🪼<br /><sub>When Moonjelly pulses, the reef wakes softly. Little lights blink on in hidden corners, and each creature knows which bit of the work to carry.</sub></p>

<details>
<summary>🤿 <b><code>reef-land</code></b> — review and land the work</summary>

Finds the open PR for the issue, summarizes the report, and checks for PR comments. If the diver has concerns or left PR comments, runs an interview to scope the change requests into concrete gaps, then labels `to-rework`. If approved, merges and closes.

| source file | [`reef-land/SKILL.md`](reef-land/SKILL.md) |
| :---------- | :----------------------------------------- |

</details>

<p align="right">🪼<br /><sub>At the end of the tide, Moonjelly returns with the reef's work tucked safely beneath its bell. The diver takes it ashore, to relish in what the reef has made.</sub></p>

## Pulse phase details

These are the 🌊 automated phases dispatched by the `reef-pulse` skill. Each phase reads its instructions from a file under `reef-pulse/`.

<details>
<summary>🌊 <b><code>to-slice</code></b> 🏷️</summary>

Automatically breaks the plan into vertical slices, or determines that the current issue can be implemented directly without sub-issues.

- 🔷　creates sub-issues: labels each sub-issue `to-implement`, adds coverage matrix to the parent issue
- 🔶　no sub-issues needed: labels the current issue `to-implement`

| source file | [`reef-pulse/slice.md`](reef-pulse/slice.md) |
| :---------- | :------------------------------------------- |

</details>

<p align="right">𐃆🐋<br /><sub>A narwhal drives its tusk through the ice ceiling in one clean thrust — the fracture lines radiate outward, each shard a perfect, independent piece.</sub></p>

<details>
<summary>🌊 <b><code>to-await-waves</code></b> 🏷️</summary>

Check if a blocked issue's dependencies are all landed. If yes, re-review the plan against current code and label `to-implement`. If not, exit — next pulse will check again.

| source file | [`reef-pulse/await-waves.md`](reef-pulse/await-waves.md) |
| :---------- | :------------------------------------------------------- |

</details>

<p align="right">🪸<br /><sub>A coral polyp sits anchored to the reef, patient and still, filtering the current — when the nutrients arrive, it's already open.</sub></p>

<details>
<summary>🌊 <b><code>to-implement</code></b> 🏷️</summary>

Implement an issue using TDD in a git worktree. Create worktree → read context → red-green-refactor for each acceptance criterion → write report → open PR → label `to-inspect`.

| source file | [`reef-pulse/implement.md`](reef-pulse/implement.md) |
| :---------- | :--------------------------------------------------- |

</details>

<p align="right">🐙<br /><sub>An octopus in a little workshop arranges shells, pebbles, and ribbons of kelp with patient hands. By dusk, a once-empty corner of the reef has become something useful and alive.</sub></p>

<details>
<summary>🌊 <b><code>to-inspect</code></b> 🏷️</summary>

Independently verify an issue's PR. Run the full test suite, check each acceptance criterion against actual code, do trivial cleanups. Label `to-merge` if approved, `to-rework` if gaps found.

| source file | [`reef-pulse/inspect.md`](reef-pulse/inspect.md) |
| :---------- | :----------------------------------------------- |

</details>

<p align="right">🧿<br /><sub>The barreleye hovers like a tiny lantern with watchful eyes, turning this way and that until even the smallest crooked shadow has nowhere left to hide.</sub></p>

<details>
<summary>🌊 <b><code>to-rework</code></b> 🏷️</summary>

Fix every issue flagged by the inspector. Address all PR comments, run the full suite, update the report, label `to-inspect` for re-review.

| source file | [`reef-pulse/rework.md`](reef-pulse/rework.md) |
| :---------- | :--------------------------------------------- |

</details>

<p align="right">🦀<br /><sub>A crab drags home a shell that pinches in all the wrong places, then spends the afternoon nudging, sanding, and trying again. By evening it has made a snugger little house and walks more easily in it.</sub></p>

<details>
<summary>🌊 <b><code>to-merge</code></b> 🏷️</summary>

🔶　no parent issue: leave the PR open, verify suite, and label the issue `to-seal`. 🔷　has parent issue: merge the PR into the parent issue's `pr-branch`, verify suite, close the sub-issue, and label the parent issue `to-seal` when all sub-issues are landed.

| source file | [`reef-pulse/merge.md`](reef-pulse/merge.md) |
| :---------- | :------------------------------------------- |

</details>

<p align="right">🐢<br /><sub>A sea turtle gathers the stragglers beneath her flipper and takes the long safe route home. What was scattered across the reef arrives together at the same quiet shore.</sub></p>

<details>
<summary>🌊 <b><code>to-seal</code></b> 🏷️</summary>

Holistic review of the current issue's `pr-branch` — checking the composed whole, not the parts. Verify every success criterion end-to-end, run the full suite, produce the aggregate report, label `to-land` or `to-rework` on gaps.

| source file | [`reef-pulse/seal.md`](reef-pulse/seal.md) |
| :---------- | :----------------------------------------- |

</details>

<p align="right">🦭<br /><sub>An elephant seal heaves up beside the finished work and presses his warm weight along every seam. He listens, waits, and listens again. Only when the whole thing holds together does he let it drift on.</sub></p>

## Phase metrics

Every phase tracks its duration and token usage. Metrics are written exclusively by reef-pulse after each dispatched sub-agent completes — individual phase files do not self-report metrics. Metrics accumulate in a single table on the plan issue (and the plan PR once one exists), giving the reviewer a complete cost/time breakdown from scoping through landing. reef-scope is the only exception: because it runs in the user's session (not as a sub-agent), it records its own wall-clock duration on the plan issue. Once the issue is landed, a bold **Total** row sums durations and tokens across the entire lifecycle.

## Orchestration accuracy

The reason this orchestration framework works is explicit boundaries. Each phase has four well-defined concerns:

1. **Variables** — what each phase needs is declared up front.
2. **Context source** — where each phase reads its input (tracker issue, PR, plan issue body) is well-defined.
3. **Code persistence** — where code changes get committed and pushed is well-defined.
4. **Progress metadata** — where labels, issue bodies, and PR bodies get updated is well-defined.

[`ORCHESTRATION.md`](ORCHESTRATION.md) is the single source of truth for these four concerns across all phases. It outlines purely the deterministic orchestration boundaries in a holistic view — not the phase logic itself, just the variables, context fetches, commits, PR operations, and tracker updates in their correct order.

[`tests/test-orchestration.sh`](tests/test-orchestration.sh) verifies that each phase's `.md` instructions include these deterministic parts of the orchestration in the correct order. If a phase drifts — missing a variable declaration, reordering a commit and PR create, or dropping a tracker update — the test catches it.

To further ensure no sub-agent messes up worktree creation, branch targeting, or commit flow, all git operations are wrapped in shell scripts (`worktree-enter.sh`, `worktree-exit.sh`, `commit.sh`) with extra sanitisation. Reef keeps its temporary worktrees under `.worktrees/` inside the repo, and `base-branch` values and paths are passed via shell variables so that sub-agents never have to reason about git orchestration themselves.

## Autopilot

Run the reef on autopilot so it pulses while you're away. If you've queued up enough issues with the `reef-scope` skill, running the `reef-pulse` skill will keep the reef pulsing recursively until no automated work remains.

## Remote Machine Cron

You could also set up a remote machine with eg. a Claude Code cron that continuously runs pulses. When a pulse is running already, when the cron pulses, we have a lock to prevent double work.

```sh
CronCreate cron="7 * * * *" prompt="Run the reef-pulse skill." durable=true
```

## Companion skill

<details>
<summary>🛡️ <b><code>git-guardrails-claude-code</code></b></summary>

Blocks dangerous git commands (force push, hard reset, force delete) while allowing safe everyday operations like pushing from worktrees and cleaning up merged branches — exactly what reef agents do all day.

```sh
npx skills@latest add mesqueeb/moonjelly-reef/git-guardrails-claude-code
# Then run it once via
/git-guardrails-claude-code
```

</details>
