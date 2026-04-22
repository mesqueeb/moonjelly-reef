# Ubiquitous Language

## Actors

| Term             | Definition                                                  | Aliases to avoid                                               |
| ---------------- | ----------------------------------------------------------- | -------------------------------------------------------------- |
| 🤿 **diver**     | The human operating the reef — scopes work, reviews results | user, developer, human                                         |
| 🪼 **moonjelly** | The orchestrator that scans labels and dispatches work      | jellyfish, pulse (when referring to the actor, not the action) |
| 🌊 **reef**      | The collection of automated phases that do the work         | pipeline, system, framework                                    |

## Work hierarchy

| Term                | Definition                                                                                           | Aliases to avoid                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| **issue**           | A scoped unit of work tracked by the issue tracker — a bug, feature, or refactor                     | ticket, work item, task, epic, parent, parent issue |
| **plan**            | The content written into an issue by reef-scope — success criteria, metadata, coverage matrix        | spec, design, RFC                                   |
| **slice**           | A thin vertical cut through all layers, implementing part of an issue end-to-end                                                        | sub-task, sub-issue, child issue, chunk |
| 🔶 **single-slice** | An issue small enough that the issue itself IS the slice — no sub-items, `pr-branch` targets `base-branch` directly                      | quick fix, small, fast path             |

## Branches

| Term            | Definition                                                                                                                                                                             | Aliases to avoid                                            |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **base branch** | The branch the PR merges into — stored in issue frontmatter as `base-branch`. For single-slice and multi-slice plans: `main`. For multi-slice sub-issues: the parent plan's `pr-branch`. | trunk, main branch, target branch                           |
| **pr-branch**   | The branch the PR lives on — stored in issue frontmatter as `pr-branch`. All slice lifecycle phases fork from `$PR_BRANCH`. For sub-issues: a dedicated per-issue branch. For plans: the integration branch the sub-issue PRs merged into. | PR branch, feature branch, work branch, slice branch        |

## Ticket types in the slice lifecycle

Three types of tickets flow through the slice lifecycle phases (implement → inspect → rework → merge):

| Type                                  | base-branch  | pr-branch   |
| ------------------------------------- | ------------ | ----------- |
| **A** Single-slice plan               | main         | feat/042    |
| **B** Multi-slice sub-issue           | feat/parent  | feat/part-1 |
| **C** Multi-slice plan (after rework) | main         | feat/parent |


## Planning

| Term                    | Definition                                                                                                            | Aliases to avoid                                  |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **success criteria**    | Plan-level testable conditions that define when the entire issue is done                                                   | requirements, specs, definition of done           |
| **acceptance criteria** | Sub-issue-level testable conditions that define when a single sub-issue is done                                            | checklist, slice criteria, ACs (never abbreviate) |
| **coverage matrix**     | A table mapping each success criterion to which sub-issue(s) and acceptance criteria cover it — only used for multi-slice  | traceability matrix, mapping                      |

## Phases

| Term                 | Definition                                                                                 | Aliases to avoid                           |
| -------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------ |
| **phase**            | A step in the issue lifecycle, executed by reading an instruction file under `reef-pulse/` | skill (for internal phases), step, stage   |
| **scope**            | The diver scopes an issue — determines type, writes plan with success criteria             | design, spec                               |
| **slice** (as phase) | Analyze a plan and break it into slices — or detect single-slice and fast-path             | decompose, break down                      |
| **implement**        | Build a slice using TDD in a worktree, open a PR                                           | code, develop, build                       |
| **inspect**          | Independently verify a slice PR against acceptance criteria                                | review, QA, check                          |
| **rework**           | Fix issues flagged by the inspector                                                        | fix, address feedback                      |
| **merge**            | Merge an approved sub-issue PR (has parent-plan) or hand off to the diver (no parent-plan) | land (that's a different phase), integrate |
| **ratify**           | Holistic review of the entire plan PR branch — only for multi-slice plans                  | final review, sign-off                     |
| **land**             | The diver reviews the finished work and merges to the base branch                          | finalise, approve, ship                    |

## Labels

| Term       | Definition                                                                                                                                      | Aliases to avoid                  |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **label**  | A marker on an issue that represents its current state in the lifecycle                                                                         | status, state, tag                |
| **landed** | The terminal label — a signal that a piece of work has reached its target branch. Once applied, the issue is considered complete and is closed. | done, completed, merged, finished |

## Orchestration lifecycle

| Term        | Definition                                                                                 | Aliases to avoid                    |
| ----------- | ------------------------------------------------------------------------------------------ | ----------------------------------- |
| **session** | A complete orchestration run — from the first pulse to lock release. May span many pulses. | run, execution                      |
| **pulse**   | One iteration within a session: scan → dispatch → lore → metrics → recurse-or-exit         | tick, cycle, run (that's a session) |

## Saga system

| Term            | Definition                                                                                                    | Aliases to avoid                            |
| --------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **saga**        | The persistent story that accumulates across sessions — the reef's ongoing narrative memory                   | story (too vague), lore (that's the format) |
| **beat**        | A single 1–3 sentence prose fragment written by the saga writer during one pulse; the atomic unit of the saga | snippet, entry, lore snippet                |
| **chapter**     | The compiled archive of all beats from one session, written to `chapter-NNN.md` at session end                | session story, log                          |
| **world state** | The persistent narrative memory between sessions: characters, threads, mood, current act, and next-beat hook  | world, context, state                       |
| **act**         | The Kishōtenketsu stage (Ki / Sho / Ten / Ketsu) tracked in `world.md` — distinct from a lifecycle phase      | phase (reserved for issue lifecycle), step  |
| **thread**      | An ongoing narrative element in `world.md` that persists across sessions and accumulates over time            | plot, arc, storyline                        |
| **hook**        | The one-line forward-pointer at the end of `world.md` that seeds the next session's opening beat              | prompt, hint, seed                          |
| **roll**        | A 2d6 value (2–12) calculated by the orchestrator from wave progress; sets the emotional key of a beat        | score, result, outcome                      |
| **lore box**    | The dashed terminal format in which a beat is displayed during a session                                      | lore snippet, story box                     |
| **saga writer** | The sub-agent invoked each pulse to write a beat, update `world.md`, and append to the chapter file           | story agent, lore agent                     |

## Relationships

- An **issue** has a **plan** with one set of **success criteria**
- A sub-issue has its own **acceptance criteria**, derived from the plan's **success criteria**
- For **single-slice**, the **issue** IS the sub-issue — **success criteria** and **acceptance criteria** are the same
- For **multi-slice**, the **coverage matrix** maps every **success criterion** to one or more sub-issues
- Every issue has a **pr-branch** (the branch the PR lives on) and a **base-branch** (where it merges into)
- For sub-issues, `base-branch` is the parent plan's `pr-branch`; for plans, `base-branch` is `main`
- A **session** produces exactly one **chapter**
- A **chapter** contains one **beat** per **pulse** that dispatched work, plus a final **beat** for the empty pulse
- The **world state** persists between **sessions**; the **chapter** is immutable after the **session** ends
- The **roll** is recalculated each **pulse** by the orchestrator; it influences but does not dictate the **beat**

## Example dialogue (saga)

> **Dev:** "The saga writer got called twice this pulse — which **beat** ends up in the **chapter**?"
>
> **Domain expert:** "Each **pulse** produces exactly one **beat**. The saga writer appends it to the current **chapter** file and updates the **world state** before returning. The **chapter** grows one **beat** at a time."
>
> **Dev:** "What's the difference between the **saga** and the **chapter**?"
>
> **Domain expert:** "The **chapter** is the archive for one **session** — immutable once written. The **saga** is all chapters together; it's the reef's memory across sessions. The **world state** is what carries the **saga** forward."
>
> **Dev:** "And the **roll** — does the writer narrate it?"
>
> **Domain expert:** "No. The **roll** is the emotional key. A 2 means something should feel like loss or friction. The writer uses that to choose the _tone_ of the beat — not to announce 'things went badly.'"

## Example dialogue (phases)

> **Dev:** "This bug is tagged `to-slice`. How does the reef handle it?"
>
> **Domain expert:** "The slice phase reads the plan. If it drafts one sub-issue, it takes the single-slice path — no sub-items, the **issue** itself becomes the sub-issue. Its **success criteria** become the **acceptance criteria**. It gets tagged `to-implement` directly."
>
> **Dev:** "And if it needs two sub-issues?"
>
> **Domain expert:** "Then it creates a dedicated **pr-branch** as the integration branch for the plan, creates the sub-issues with their own **pr-branch** and **acceptance criteria**, builds the **coverage matrix**, and labels them `to-implement` or `to-await-waves`."
>
> **Dev:** "When does the diver see it?"
>
> **Domain expert:** "At **land**. For single-slice, the PR is still open — the diver merges it. For multi-slice, **ratify** already composed everything on the plan's **pr-branch** and opened a PR to the **base branch** — the diver merges that."

## Flagged ambiguities (saga)

- **"lore"** vs **"beat"** vs **"saga"** — lore is the output aesthetic (dashed box format); a **beat** is a discrete prose entry; the **saga** is the long-running narrative accumulating across sessions. Don't use "lore" as a noun for the content itself.
- **"act"** vs **"phase"** — these are completely different. **Act** is a Kishōtenketsu stage (Ki/Sho/Ten/Ketsu) tracked in `world.md`. **Phase** is a step in the issue lifecycle (implement, inspect, etc.). Never use them interchangeably.
- **"session"** vs **"pulse"** — a **session** spans from lock acquisition to lock release and contains multiple **pulses**. A **pulse** is one scan-dispatch-lore-metrics iteration. Don't say "pulse" when you mean "session."
- **"chapter"** vs **"session"** — a **chapter** is the narrative archive of one session. They are 1:1 but distinct: one is a story artifact, the other is an orchestration run.

## Flagged ambiguities

- **"slice"** is both a noun (a unit of work) and a phase name (the act of breaking a plan into slices). Context usually makes it clear, but when ambiguous, say "the slice phase" for the action and "a slice" for the work unit.
- **"merge"** is both a phase name and a git operation. The phase may or may not perform a git merge — for single-slice it doesn't. When referring to the git operation specifically, say "merge the PR."
- **"feature branch"**, **"work branch"**, or **"target branch"** — do not use. The correct terms are **pr-branch** (the branch the PR lives on) and **base-branch** (where it merges into). Not all issues are features, and "target" is ambiguous once you realize base-branch serves that role for sub-issues.
- **"AC"** or **"SC"** — do not abbreviate. Always write **acceptance criteria** and **success criteria** in full. Abbreviations create ambiguity across contexts and hurt readability.
- **"parent"** or **"parent issue"** — do not use. Say **plan** (for the content) or **issue** (for the tracked entity). "Parent" implies a hierarchy that doesn't always exist (single-slice has no parent/child relationship).
- **"work item"** — do not use. The correct term is **issue**. "Work item" is generic project-management speak; **issue** is concrete and tracker-agnostic (GitHub Issues, Jira issues, Linear issues, local markdown files are all "issues").
