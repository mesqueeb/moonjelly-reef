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
| **plan**      | The content written into an issue by reef-scope — User Stories, Implementation Decisions, Testing Decisions, metadata, coverage matrix | spec, design, RFC                     |
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
| **`[await: ...]`** | The issue-title suffix that encodes blockers for work that must wait on other issues to land before it can be promoted | blocked-by field, dependency label |

## Planning

| Term                    | Definition                                                                                                                                 | Aliases to avoid                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- |
| **problem statement**          | The plan section that describes the issue from the user's perspective                                                                      | bug write-up, design brief                        |
| **user story** (US)            | A concise statement of user intent and benefit; a numbered plan item used as a coverage anchor for slicing                                 | requirement, use case (when referring to the row) |
| **implementation decision** (ID) | A plan item recording an architectural or technical choice made during scoping; used as a coverage anchor for slicing                    | design decision, architectural note               |
| **testing decision** (TD)      | A plan item that records expected testing behavior, rigor level, and what "done" looks like for this issue                                 | test plan, QA notes                               |
| **decision record**            | The plan section that captures scoping interview choices and constraints that downstream phases may need to revisit                         | notes, design log                                 |
| **acceptance criteria**        | Slice-level testable conditions synthesized by the slicer from User Stories, Implementation Decisions, and Testing Decisions               | checklist, slice criteria, ACs (never abbreviate) |
| **coverage matrix**            | A table mapping each plan item (US, ID, TD) to which sub-issue(s) and acceptance criteria cover it — only used when an issue creates sub-issues | traceability matrix, mapping               |

## Report sections

| Term                  | Definition                                                                                                            | Aliases to avoid          |
| --------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **Ambiguous choices** | The PR-report section where an agent records judgment calls not explicitly covered by the plan or acceptance criteria | assumptions, random notes |

## Phases

| Term                 | Definition                                                                                                                 | Aliases to avoid                           |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **phase**            | A step in the issue lifecycle, executed by reading an instruction file under `reef-pulse/`                                 | skill (for internal phases), step, stage   |
| **scope**            | The diver scopes an issue — determines type, writes plan with User Stories, Implementation Decisions, and Testing Decisions | design, spec                               |
| **slice** (as phase) | Analyze a plan and either keep the work on the current issue or break it into sub-issues                                   | decompose, break down                      |
| **implement**        | Build a slice using TDD in a worktree, open a PR                                                                           | code, develop, build                       |
| **inspect**          | Independently verify a slice PR against acceptance criteria                                                                | review, QA, check                          |
| **rework**           | Fix issues flagged by the inspector                                                                                        | fix, address feedback                      |
| **merge**            | Merge an approved sub-issue PR into its parent issue's `pr-branch`, or hand off an issue with no parent issue to the diver | land (that's a different phase), integrate |
| **seal**             | Holistic review of an issue whose work was composed through sub-issues on its `pr-branch`                                  | final review, sign-off                     |
| **land**             | The diver reviews the finished work and merges to the base branch                                                          | finalise, approve, ship                    |

## File types

| Term | Definition | Aliases to avoid |
| ---- | ---------- | ---------------- |
| **phase file** | A top-level instruction file executed by the reef for one phase of the lifecycle, e.g. `merge.md`, `slice.md`, `reef-scope/SKILL.md` | skill file (when referring to a phase), step file |
| **same-phase subfile** | An instruction file delegated to inline (in the same session) from a phase file. It omits `## Rules`, uses `## Input (from context)`, and all its input variables are resolved by the calling phase file. | sub-skill, child phase, router target |

Same-phase subfiles by phase:

- **merge** → `merge-has-parent.md`, `merge-no-parent.md`
- **slice** → `slice-one-issue.md`, `slice-subissues.md`
- **scope** → `scope-feature.md`, `scope-refactor.md`, `scope-deep-research.md`, `triage-issue.md`

## Labels

| Term            | Definition                                                                                                                                    | Aliases to avoid                  |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **label** / **labeled** | A marker on an issue that represents its current state in the lifecycle; *labeled* is the canonical verb form                                 | status, state, tag, tagged        |
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

- An **issue** has a **plan** with **User Stories**, **Implementation Decisions**, and **Testing Decisions**
- A sub-issue has its own **acceptance criteria**, synthesized from the plan's **User Stories**, **Implementation Decisions**, and **Testing Decisions**
- If an issue has no sub-issues, its **acceptance criteria** are synthesized from the plan items directly
- If an issue creates sub-issues, the **coverage matrix** maps every plan item (US, ID, TD) to one or more sub-issues
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

> **Dev:** "This bug is labeled `to-slice`. How does the reef handle it?"
>
> **Domain expert:** "The slice phase reads the plan. If the work stays on the current issue, no sub-issues are created. The slicer synthesizes **acceptance criteria** from the plan's **User Stories**, **Implementation Decisions**, and **Testing Decisions**, and the issue gets labeled `to-implement` directly."
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
- **"user story"** vs **"acceptance criteria"** — a **user story** is a plan item that captures user intent and benefit; **acceptance criteria** are the slicer's concrete, testable synthesis of the plan's User Stories, Implementation Decisions, and Testing Decisions. Do not use them interchangeably.
- **"success criteria"** — do not use as a plan-level section name. Plans contain **User Stories**, **Implementation Decisions**, and **Testing Decisions**. The term "success criteria" lives only in the glossary for legacy reference; it must not appear as a `##` section header in any plan or skill file.
- **"decision record"** vs **"Ambiguous choices"** — the **decision record** lives in the plan and captures scoping decisions; **Ambiguous choices** lives in a PR report and captures implementation-time judgment calls. Do not collapse them into one concept.
- **"AC"** — do not abbreviate. Always write **acceptance criteria** in full. Abbreviations create ambiguity across contexts and hurt readability.
- **"plan"** vs **"parent issue"** — use **plan** for the content written into an issue, and **parent issue** only when you need to describe the relationship between one issue and its sub-issues.
- **"work item"** — do not use. The correct term is **issue**. "Work item" is generic project-management speak; **issue** is concrete and tracker-agnostic (GitHub Issues, Jira issues, Linear issues, local markdown files are all "issues").
