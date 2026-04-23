# Ubiquitous Language

## Actors

| Term             | Definition                                                  | Aliases to avoid                                               |
| ---------------- | ----------------------------------------------------------- | -------------------------------------------------------------- |
| 🤿 **diver**     | The human operating the reef — scopes work, reviews results | user, developer, human                                         |
| 🪼 **moonjelly** | The orchestrator that scans labels and dispatches work      | jellyfish, pulse (when referring to the actor, not the action) |
| 🌊 **reef**      | The collection of automated phases that do the work         | pipeline, system, framework                                    |

## Work hierarchy

| Term          | Definition                                                                                                      | Aliases to avoid                      |
| ------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| **issue**     | A scoped unit of work tracked by the issue tracker — a bug, feature, or refactor                                | ticket, work item, task, epic, parent |
| **plan**      | The content written into an issue by reef-scope — success criteria, metadata, coverage matrix                   | spec, design, RFC                     |
| **sub-issue** | An issue created by the slice phase to implement one slice under a parent issue, also called a "vertical slice" | child task, child ticket, sub task    |

## Fields and identifiers

| Term                                | Definition                                                                                                         | Aliases to avoid                                                            |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| **issue-id** / **`ISSUE_ID`**       | The tracker-native identifier for an issue, such as `#42`.                                                         | issue id, issue number, numeric issue id, plan id, plan number, `PLAN_ID`   |
| **pr-id** / **`PR_ID`**             | The tracker-native identifier or handle for a PR artifact.                                                         | pull request id, pull request number, pr number, numeric PR id, `pr-number` |
| **pr-branch** / **`PR_BRANCH`**     | The branch the PR lives on.                                                                                        | PR branch, feature branch, work branch, slice branch, issue branch          |
| **base-branch** / **`BASE_BRANCH`** | The branch the PR merges into.                                                                                     | trunk, main branch, target branch                                           |
| **parent-issue**                    | The parent to which a sub-issues belongs to. The parent's pr-branch is the sub-issue's base-branch they merge into | epic, umbrella issue, parent ticket, parent plan                            |

Use the kebab-case form for canonical domain and frontmatter terms, and the constant-case form for shell variables that hold those values.

## Title suffixes

| Term               | Definition                                                                                                             | Aliases to avoid                 |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| **`[await: ...]`** | The issue-title suffix that encodes blockers for work that must wait on other issues to land before it can be promoted | blocked-by field, dependency tag |

## Planning

| Term                    | Definition                                                                                                                                 | Aliases to avoid                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| **problem statement**   | The plan section that describes the issue from the user's perspective                                                                      | bug write-up, design brief                        |
| **user story**          | A concise statement of user intent and benefit used to validate whether the planned solution solves the user's problem                     | requirement, use case (when referring to the row) |
| **decision record**     | The plan section that captures scoping decisions and constraints that downstream phases may need to revisit                                | notes, design log                                 |
| **success criteria**    | Plan-level testable conditions that define when the entire issue is done                                                                   | requirements, specs, definition of done           |
| **acceptance criteria** | Issue-level testable conditions that define when one implementation unit is done; on a parent issue they are written onto each sub-issue   | checklist, slice criteria, ACs (never abbreviate) |
| **coverage matrix**     | A table mapping each success criterion to which sub-issue(s) and acceptance criteria cover it — only used when an issue creates sub-issues | traceability matrix, mapping                      |

## Report sections

| Term                  | Definition                                                                                                            | Aliases to avoid          |
| --------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **Ambiguous choices** | The PR-report section where an agent records judgment calls not explicitly covered by the plan or acceptance criteria | assumptions, random notes |

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

| Term            | Definition                                                                                                                                    | Aliases to avoid                  |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **label**       | A marker on an issue that represents its current state in the lifecycle                                                                       | status, state, tag                |
| **in-progress** | The parent-issue label meaning slice work is underway on sub-issues and the parent issue is waiting for them to land                          | active, ongoing, underway         |
| **landed**      | The terminal label — a signal that a piece of work has reached its base branch. Once applied, the issue is considered complete and is closed. | done, completed, merged, finished |

## Orchestration lifecycle

| Term        | Definition                                                                                 | Aliases to avoid                    |
| ----------- | ------------------------------------------------------------------------------------------ | ----------------------------------- |
| **session** | A complete orchestration run — from the first pulse to lock release. May span many pulses. | run, execution                      |
| **pulse**   | One iteration within a session: scan → dispatch → metrics → recurse-or-exit                 | tick, cycle, run (that's a session) |

## Saga system

| Term            | Definition                                                                                                    | Aliases to avoid                            |
| --------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **saga**        | The persistent story that accumulates across sessions — the reef's ongoing narrative memory                   | story (too vague), lore (that's the format) |
| **chapter**     | The session's full lore piece, written once to `chapter-NNN.md` at session end                                | session story, log                          |
| **thread**      | An ongoing narrative element in `world.md` that persists across sessions and accumulates over time            | plot, arc, storyline                        |
| **lore writer** | The sub-agent invoked once at session end to write a chapter and update `world.md`                            | story agent, saga writer                    |

## Relationships

- An **issue** has a **plan** with one set of **success criteria**
- A sub-issue has its own **acceptance criteria**, derived from the plan's **success criteria**
- If an issue has no sub-issues, its **success criteria** and **acceptance criteria** describe the same work directly
- If an issue creates sub-issues, the **coverage matrix** maps every **success criterion** to one or more sub-issues
- Every **issue-id** is a tracker-native string; **`ISSUE_ID`** keeps the full value, including `#` when the tracker uses it
- Every **pr-id** is also treated as a tracker-native string or handle; **`PR_ID`** stores that full value
- Every issue has a **pr-branch** (the branch the PR lives on) and a **base-branch** (where it merges into)
- For sub-issues, `base-branch` is the parent issue's `pr-branch`; for issues with no parent issue, `base-branch` is usually `main`
- A **session** produces exactly one **chapter**
- The **lore writer** is called once at session end
- `world.md` persists between **sessions**; the **chapter** is immutable after the **session** ends

## Example dialogue (saga)

> **Dev:** "How long should the chapter be?"
>
> **Domain expert:** "The **lore writer** runs once after the session ends and writes one **chapter** for that session."
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
> **Dev:** "How do I refer to the identifiers and branches in the plan?"
>
> **Domain expert:** "Use **issue-id** and **pr-id** for identifiers, plus **pr-branch** and **base-branch** for branches. Keep shell variables in uppercase as **`ISSUE_ID`**, **`PR_ID`**, **`PR_BRANCH`**, and **`BASE_BRANCH`**."
>
> **Dev:** "When does the diver see it?"
>
> **Domain expert:** "At **land**. If the work stayed on one issue, that PR is still open and the diver merges it. If the issue created sub-issues, **seal** already composed everything on the parent issue's `pr-branch` and opened a PR to the **base branch** — the diver merges that."

## Flagged ambiguities (saga)

- **"lore"** vs **"chapter"** vs **"saga"** — lore is the output mode and tone; a **chapter** is one session's written artifact; the **saga** is the long-running narrative accumulating across sessions.
- **"session"** vs **"pulse"** — a **session** spans from lock acquisition to lock release and contains multiple **pulses**. A **pulse** is one scan-dispatch-metrics iteration. Don't say "pulse" when you mean "session."
- **"chapter"** vs **"session"** — a **chapter** is the narrative archive of one session. They are 1:1 but distinct: one is a story artifact, the other is an orchestration run.

## Flagged ambiguities

- **"slice"** is both a noun (a unit of work) and a phase name (the act of breaking a plan into slices). Context usually makes it clear, but when ambiguous, say "the slice phase" for the action and "a slice" for the work unit.
- **"merge"** is both a phase name and a git operation. The phase may or may not perform a git merge. When referring to the git operation specifically, say "merge the PR."
- **"issue id"** vs **"issue-id"** — use **issue-id** as the canonical term. The unhyphenated form is understandable but not preferred in specs or glossary text.
- **"`PLAN_ID`"**, **"plan-id"**, or **"plan number"** — do not use. A plan is content written into an issue, not a separate identifier concept. Use **issue-id** / **`ISSUE_ID`** instead.
- **numeric issue variables** — use **`ISSUE_ID`** only. It stores the full tracker-native issue identifier string, such as `#42`. Do not introduce a separate numeric-only issue variable.
- **"pull request id"** or **"pull request number"** — do not use. The canonical abstraction is **pr-id**, which stays valid even when the local tracker uses a progress file instead of GitHub PRs.
- **numeric PR variables** — use **`PR_ID`** only. Treat it as an opaque PR identifier or handle, not as a guaranteed numeric value.
- **PR frontmatter naming** — use **`pr-id`** for the frontmatter field. Do not introduce `pr-number` or any numeric-only variant.
- **"PR branch"** — do not use. The canonical term is **pr-branch**, matching the frontmatter field and keeping it distinct from generic git-branch talk.
- **"feature branch"**, **"work branch"**, **"issue branch"**, or **"target branch"** — do not use. The correct terms are **pr-branch** (the branch the PR lives on) and **base-branch** (where it merges into). Not all issues are features, and "target" is ambiguous once you realize base-branch serves that role for sub-issues.
- **"merge to main"** — do not use as the generic description of landing. The correct term is **merge to the base branch**. Some repos do not use `main`, and for sub-issues the relevant destination is the issue's `base-branch`, which may be a parent issue's `pr-branch`.
- **"blocked-by"** — do not use as a dependency mechanism. The canonical dependency encoding is the **`[await: ...]`** issue-title suffix used with `to-await-waves`.
- **"user story"** vs **"success criterion"** — a **user story** captures user intent and benefit; a **success criterion** is the mechanically verifiable condition used to decide whether the issue is done. Do not use them interchangeably.
- **"decision record"** vs **"Ambiguous choices"** — the **decision record** lives in the plan and captures scoping decisions; **Ambiguous choices** lives in a PR report and captures implementation-time judgment calls. Do not collapse them into one concept.
- **"AC"** or **"SC"** — do not abbreviate. Always write **acceptance criteria** and **success criteria** in full. Abbreviations create ambiguity across contexts and hurt readability.
- **"plan"** vs **"parent issue"** — use **plan** for the content written into an issue, and **parent issue** only when you need to describe the relationship between one issue and its sub-issues.
- **"work item"** — do not use. The correct term is **issue**. "Work item" is generic project-management speak; **issue** is concrete and tracker-agnostic (GitHub Issues, Jira issues, Linear issues, local markdown files are all "issues").
