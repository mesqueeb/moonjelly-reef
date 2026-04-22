# Ubiquitous Language

## Actors

| Term             | Definition                                                  | Aliases to avoid                                               |
| ---------------- | ----------------------------------------------------------- | -------------------------------------------------------------- |
| 🤿 **diver**     | The human operating the reef — scopes work, reviews results | user, developer, human                                         |
| 🪼 **moonjelly** | The orchestrator that scans labels and dispatches work      | jellyfish, pulse (when referring to the actor, not the action) |
| 🌊 **reef**      | The collection of automated phases that do the work         | pipeline, system, framework                                    |

## Work hierarchy

| Term             | Definition                                                                                    | Aliases to avoid                      |
| ---------------- | --------------------------------------------------------------------------------------------- | ------------------------------------- |
| **issue**        | A scoped unit of work tracked by the issue tracker — a bug, feature, or refactor              | ticket, work item, task, epic, parent |
| **plan**         | The content written into an issue by reef-scope — success criteria, metadata, coverage matrix | spec, design, RFC                     |
| **slice**        | A thin vertical cut through all layers, implementing part of an issue end-to-end              | sub-task, chunk                       |
| **parent issue** | An issue that creates sub-issues and owns the integration branch they merge into              | epic, umbrella issue                  |
| **sub-issue**    | An issue created by the slice phase to implement one slice under a parent issue               | child task, child ticket              |

## Branches

| Term            | Definition                                                                                                                                                                                            | Aliases to avoid                                     |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **base branch** | The branch the PR merges into — stored in issue frontmatter as `base-branch`. For issues with no parent issue: usually `main`. For sub-issues: the parent issue's `pr-branch`.                        | trunk, main branch, target branch                    |
| **pr-branch**   | The branch the PR lives on — stored in issue frontmatter as `pr-branch`. Every issue owns its own `pr-branch`. If an issue creates sub-issues, its `pr-branch` also acts as their integration branch. | PR branch, feature branch, work branch, slice branch |

## Planning

| Term                    | Definition                                                                                                                                 | Aliases to avoid                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| **success criteria**    | Plan-level testable conditions that define when the entire issue is done                                                                   | requirements, specs, definition of done           |
| **acceptance criteria** | Issue-level testable conditions that define when one implementation unit is done; on a parent issue they are written onto each sub-issue   | checklist, slice criteria, ACs (never abbreviate) |
| **coverage matrix**     | A table mapping each success criterion to which sub-issue(s) and acceptance criteria cover it — only used when an issue creates sub-issues | traceability matrix, mapping                      |

## Phases

| Term                 | Definition                                                                                                                 | Aliases to avoid                           |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **phase**            | A step in the issue lifecycle, executed by reading an instruction file under `reef-pulse/`                                 | skill (for internal phases), step, stage   |
| **scope**            | The diver scopes an issue — determines type, writes plan with success criteria                                             | design, spec                               |
| **slice** (as phase) | Analyze a plan and either keep the work on the current issue or break it into sub-issues                                   | decompose, break down                      |
| **implement**        | Build a slice using TDD in a worktree, open a PR                                                                           | code, develop, build                       |
| **inspect**          | Independently verify a slice PR against acceptance criteria                                                                | review, QA, check                          |
| **rework**           | Fix issues flagged by the inspector                                                                                        | fix, address feedback                      |
| **merge**            | Merge an approved sub-issue PR into its parent issue's `pr-branch`, or hand off an issue with no parent issue to the diver | land (that's a different phase), integrate |
| **seal**             | Holistic review of an issue whose work was composed through sub-issues on its `pr-branch`                                  | final review, sign-off                     |
| **land**             | The diver reviews the finished work and merges to the base branch                                                          | finalise, approve, ship                    |

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
| **thread**      | An ongoing narrative element in `world.md` that persists across sessions and accumulates over time            | plot, arc, storyline                        |
| **saga writer** | The sub-agent invoked each pulse to write a beat, update `world.md`, and append to the chapter file           | story agent, lore agent                     |

## Relationships

- An **issue** has a **plan** with one set of **success criteria**
- A sub-issue has its own **acceptance criteria**, derived from the plan's **success criteria**
- If an issue has no sub-issues, its **success criteria** and **acceptance criteria** describe the same work directly
- If an issue creates sub-issues, the **coverage matrix** maps every **success criterion** to one or more sub-issues
- Every issue has a **pr-branch** (the branch the PR lives on) and a **base-branch** (where it merges into)
- For sub-issues, `base-branch` is the parent issue's `pr-branch`; for issues with no parent issue, `base-branch` is usually `main`
- A **session** produces exactly one **chapter**
- A **chapter** contains one **beat** per **pulse** that dispatched work, plus a final **beat** for the empty pulse
- `world.md` persists between **sessions**; the **chapter** is immutable after the **session** ends

## Example dialogue (saga)

> **Dev:** "The saga writer got called twice this pulse — which **beat** ends up in the **chapter**?"
>
> **Domain expert:** "Each **pulse** produces exactly one **beat**. The saga writer appends it to the current **chapter** file and updates `world.md` before returning. The **chapter** grows one **beat** at a time."
>
> **Dev:** "What's the difference between the **saga** and the **chapter**?"
>
> **Domain expert:** "The **chapter** is the archive for one **session** — immutable once written. The **saga** is all chapters together; `world.md` is the little memory the next session wakes up with."

## Example dialogue (phases)

> **Dev:** "This bug is tagged `to-slice`. How does the reef handle it?"
>
> **Domain expert:** "The slice phase reads the plan. If the work stays on the current issue, no sub-issues are created. The issue's **success criteria** become its **acceptance criteria**, and it gets tagged `to-implement` directly."
>
> **Dev:** "And if it needs two sub-issues?"
>
> **Domain expert:** "Then the current issue becomes a **parent issue**. Its `pr-branch` becomes the integration branch, it creates sub-issues with their own `pr-branch` and **acceptance criteria**, builds the **coverage matrix**, and labels them `to-implement` or `to-await-waves`."
>
> **Dev:** "When does the diver see it?"
>
> **Domain expert:** "At **land**. If the work stayed on one issue, that PR is still open and the diver merges it. If the issue created sub-issues, **seal** already composed everything on the parent issue's `pr-branch` and opened a PR to the **base branch** — the diver merges that."

## Flagged ambiguities (saga)

- **"lore"** vs **"beat"** vs **"saga"** — lore is the output aesthetic (dashed box format); a **beat** is a discrete prose entry; the **saga** is the long-running narrative accumulating across sessions. Don't use "lore" as a noun for the content itself.
- **"session"** vs **"pulse"** — a **session** spans from lock acquisition to lock release and contains multiple **pulses**. A **pulse** is one scan-dispatch-lore-metrics iteration. Don't say "pulse" when you mean "session."
- **"chapter"** vs **"session"** — a **chapter** is the narrative archive of one session. They are 1:1 but distinct: one is a story artifact, the other is an orchestration run.

## Flagged ambiguities

- **"slice"** is both a noun (a unit of work) and a phase name (the act of breaking a plan into slices). Context usually makes it clear, but when ambiguous, say "the slice phase" for the action and "a slice" for the work unit.
- **"merge"** is both a phase name and a git operation. The phase may or may not perform a git merge. When referring to the git operation specifically, say "merge the PR."
- **"feature branch"**, **"work branch"**, or **"target branch"** — do not use. The correct terms are **pr-branch** (the branch the PR lives on) and **base-branch** (where it merges into). Not all issues are features, and "target" is ambiguous once you realize base-branch serves that role for sub-issues.
- **"AC"** or **"SC"** — do not abbreviate. Always write **acceptance criteria** and **success criteria** in full. Abbreviations create ambiguity across contexts and hurt readability.
- **"plan"** vs **"parent issue"** — use **plan** for the content written into an issue, and **parent issue** only when you need to describe the relationship between one issue and its sub-issues.
- **"work item"** — do not use. The correct term is **issue**. "Work item" is generic project-management speak; **issue** is concrete and tracker-agnostic (GitHub Issues, Jira issues, Linear issues, local markdown files are all "issues").
