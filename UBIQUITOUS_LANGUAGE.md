# Ubiquitous Language

## Actors

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **diver** | The human operating the reef — scopes work, reviews results | user, developer, human |
| **moonjelly** | The orchestrator that scans tags and dispatches work | jellyfish, pulse (when referring to the actor, not the action) |
| **reef** | The collection of automated phases that do the work | pipeline, system, framework |

## Work hierarchy

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **work item** | A scoped unit of work tracked by the issue tracker — a bug, feature, or refactor | ticket, issue, task, epic |
| **slice** | A thin vertical cut through all layers, implementing part of a work item end-to-end | sub-task, sub-issue, child issue, chunk |
| **single-slice** | A work item small enough that the work item itself IS the slice — no sub-items, no work branch | quick fix, small, fast path |
| **multi-slice** | A work item broken into 2+ slices with a work branch composing them | standard, normal, full |

## Branches

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **base branch** | The branch where everything ultimately lands (usually `main`) | trunk, target branch, main branch |
| **work branch** | An intermediate branch (e.g. `reef/my-thing`) where multi-slice PRs compose before landing on the base branch — does not exist for single-slice work | feature branch, integration branch, dev branch |
| **slice branch** | A per-slice branch created in a worktree, PR'd against the work branch (multi-slice) or base branch (single-slice) | implementation branch, PR branch |

## Planning

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **success criteria** | Plan-level testable conditions that define when the entire work item is done | requirements, specs, definition of done |
| **acceptance criteria** | Slice-level testable conditions that define when a single slice is done | checklist, slice criteria, ACs |
| **coverage matrix** | A table mapping each success criterion to which slice(s) and acceptance criteria cover it — only used for multi-slice | traceability matrix, mapping |
| **plan metadata** | The table at the top of a plan with type, base branch, and work branch fields | header, config, frontmatter |

## Phases

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **phase** | A step in the work item lifecycle, executed by reading an instruction file under `reef-pulse/` | skill (for internal phases), step, stage |
| **scope** | The diver plans a work item — determines type, writes success criteria | plan, design, spec |
| **slice** (as phase) | Analyze a plan and break it into slices — or detect single-slice and fast-path | decompose, break down |
| **implement** | Build a slice using TDD in a worktree, open a PR | code, develop, build |
| **inspect** | Independently verify a slice PR against acceptance criteria | review, QA, check |
| **rework** | Fix issues flagged by the inspector | fix, address feedback |
| **merge** | Merge an approved slice PR (multi-slice) or hand off to the diver (single-slice) | land (that's a different phase), integrate |
| **ratify** | Holistic review of the entire work branch — only for multi-slice | final review, sign-off |
| **rescan** | Analyze gaps found by ratify and create new slices | remediate, patch |
| **land** | The diver reviews the finished work and merges to the base branch | finalise, approve, ship |

## Tags

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **tag** | A label on a work item that represents its current state in the lifecycle | status, state, label (though "label" is the GitHub implementation) |

## Relationships

- A **work item** has one set of **success criteria**
- A **slice** has its own **acceptance criteria**, derived from the parent's **success criteria**
- For **single-slice**, the **work item** IS the **slice** — **success criteria** and **acceptance criteria** are the same
- For **multi-slice**, the **coverage matrix** maps every **success criterion** to one or more **slices**
- A **work branch** only exists for **multi-slice** work
- A **slice branch** always exists — it targets the **work branch** (multi-slice) or **base branch** (single-slice)

## Example dialogue

> **Dev:** "This bug is tagged `to-slice`. How does the reef handle it?"
>
> **Domain expert:** "The slice phase reads the plan. If it drafts one **slice**, it takes the single-slice path — no **work branch**, no sub-items. The **work item** itself becomes the **slice**, and its **success criteria** become the **acceptance criteria**. It gets tagged `to-implement` directly."
>
> **Dev:** "And if it's two slices?"
>
> **Domain expert:** "Then it creates a **work branch**, creates the **slices** as separate items with their own **acceptance criteria**, builds the **coverage matrix**, and tags them `to-implement` or `to-await-waves`."
>
> **Dev:** "When does the diver see it?"
>
> **Domain expert:** "At **land**. For single-slice, the PR is still open — the diver merges it. For multi-slice, **ratify** already composed everything on the **work branch** and opened a PR to the **base branch** — the diver merges that."

## Flagged ambiguities

- **"slice"** is both a noun (a unit of work) and a phase name (the act of breaking a plan into slices). Context usually makes it clear, but when ambiguous, say "the slice phase" for the action and "a slice" for the work unit.
- **"merge"** is both a phase name and a git operation. The phase may or may not perform a git merge — for single-slice it doesn't. When referring to the git operation specifically, say "merge the PR."
- **"feature branch"** — do not use. The correct term is **work branch**. Not all work items are features.
