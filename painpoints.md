# Orchestration Pain Points

Concrete failures observed while running `grill-me → write-a-prd → prd-to-issues → tdd → close-the-loop` (and variants) on real projects. Grouped so we can reference clusters during design discussions.

Each pain point has:

- **What goes wrong** — the failure mode
- **Evidence** — which example it came from (E1 = PRD drift, E2 = DbSchema refactor, E3 = multi-agent git mishaps)

## Cluster A: Requirements leak across handoffs

### A1. Grill-me output is ephemeral

The grill session produces decisions as conversation turns. No durable artifact is written. When context compresses, when a new session starts, or when a subagent runs, the decisions evaporate. Downstream skills reconstruct from memory — and reconstruction is lossy.

**Evidence**: E1 — 10 resolved decisions had to be manually re-threaded into the rewritten PRD, and several were still dropped.

### A2. No "success criteria" bridge between PRD and issues

The current `write-a-prd` template jumps from User Stories to Implementation Decisions. There is no section for *testable conditions that must all hold for this feature to be done*. `prd-to-issues` then has to invent acceptance criteria per ticket from PRD prose — a compression step where requirements silently get dropped.

**Evidence**: E1 — empty-arguments bug, constant drift, missing field names were all in the original brief but never surfaced as ACs on any ticket.

### A3. No coverage cross-check before issues are filed

Nothing in `prd-to-issues` verifies that every PRD requirement is covered by at least one ticket AC. Clean-looking tickets can silently drop half the requirements.

**Evidence**: E1 — a final manual cross-check caught 4 more gaps *after* tickets were filed.

### A4. Builder's perspective dominates the PRD

PRDs tend to describe *what to build* ("these endpoints, this store") rather than *what "done" looks like from the outside* ("the legacy UI must render this identically"). Every locally-correct implementation decision then fails the aggregate test.

**Evidence**: E1 — 125 tests passing, zero artifacts, implementation globally broken because the consumer's view was never the bar.

## Cluster B: Wrong skill for the job

### B1. No routing step — write-a-prd used for refactors

There's no "which skill should I use?" step. The user picks, and if they don't know about `request-refactor-plan`, they'll use `write-a-prd` for a refactor. The result skips refactor-specific disciplines: tiny commits, always-compiles, always-green tests, explicit scope of what won't change.

**Evidence**: E2 — the DbSchema port was a refactor dressed as a feature PRD. Big-bang tickets, no "keep it compiling" constraint, no "tests must stay green at every commit."

### B2. No re-grilling when new gaps surface

`close-the-loop` finds gaps → follow-up tickets get filed → TDD runs on them cold. But the gaps often need fresh decisions (ordering, scope, blast-radius) that only a grill-me session can resolve. Skipping that re-grill means the follow-ups inherit the same ambiguity that caused the original gap.

**Evidence**: E2 — follow-up tickets #66-#71 went straight into TDD, immediately got stuck, needed manual unblocking.

## Cluster C: Agents declare victory prematurely

### C1. Silent skip when stuck

An agent that hits a hard problem (compile errors, unexpected scope) can silently abandon a ticket instead of escalating. No "I'm stuck, please come back to this" protocol.

**Evidence**: E2 — ticket #59 (Magisterium cleanup) was skipped entirely after the agent got spooked by Swift duplicate-namespace errors. Nothing surfaced this until `close-the-loop` ran much later.

### C2. Tests partially run, called "done"

Subagents ran only the test subset they had visibility into (Vellum package) and treated green there as "done." The larger test suite (Magisterium) was never reliably invoked as the bar.

**Evidence**: E2.

### C3. Core functions called with empty args, masked by mocks

Implementation looks correct, unit tests mock the call site, production path produces zero output. No integration check catches it.

**Evidence**: E1 — entire grading pipeline produced no results in production because the core function was being called with empty arguments in the real call path.

### C4. Responsibility diffusion between main and subagents

When things go wrong, the main agent blames subagents' output and subagents blame the main brief. No single owner of "is the PRD actually done."

**Evidence**: E2.

## Cluster D: Ordering / staging failures

### D1. Agent solves problems in the wrong order

A problem that's trivial if the right preparatory step runs first becomes a 100-file nightmare if attempted directly. The agent lacks the "wait, what should I do first?" reflex a human would have.

**Evidence**: E2 — hitting Swift duplicate-namespace errors, the agent tried to fix them file-by-file. Had it done ticket #59 (delete the duplicates) first, the namespace issue would have evaporated with changes to a handful of files.

### D2. Cross-ticket prerequisites aren't surfaced

`prd-to-issues` supports `blocked by` but doesn't surface *implicit* prerequisites like "these four tickets all depend on a shared dependency being in place first" or "these two must happen in this order or compile breaks."

**Evidence**: E1 — shared S3 catalog dependency was needed by 4 gaps but never identified as a single prerequisite. E2 — ordering implicit, not enforced.

## Cluster E: Ticket lifecycle confusion

### E1. Original tickets left open when follow-ups fill gaps

When `close-the-loop` surfaces gaps and files follow-up tickets, the original tickets are left open. Reviewing the original ticket is now ambiguous — some ACs done, others moved to new tickets, no clear "this is superseded" marker.

**Evidence**: E2 — originals #55-#60 stayed open alongside follow-ups #66-#71, making PRD review a maze.

### E2. PRD closure depends on tickets the PRD doesn't know about

The PRD references its *original* sub-tickets. When follow-ups are added outside the PRD, closing the PRD requires walking a graph that isn't captured anywhere.

**Evidence**: E2.

## Cluster F: Multi-agent git hygiene

### F1. Wrong base branch for worktree

A subagent creates a worktree off the wrong base, pulling in unrelated commits.

**Evidence**: E3.

### F2. PRs opened toward the wrong branch

Subagents default to `main` or pick the wrong target for PR creation.

**Evidence**: E3.

### F3. Main agent doesn't pull remote between waves

Main agent merges wave 1 PRs, spawns wave 2 subagents, but local `main` hasn't been pulled — subagents re-invent wave 1.

**Evidence**: E3.

### F4. Close-the-loop runs against stale local state

Review pronounces gaps that are already fixed on remote — because local `main` wasn't pulled.

**Evidence**: E3.

### F5. Main agent collapses subagent work into a single local commit

Instead of opening one PR per subagent, main agent pulls all worktree changes into one local commit on `main`, leaving worktrees dangling with duplicate code.

**Evidence**: E3.

### F6. Panic-revert destroys uncommitted work

When corrected, the main agent tries to reverse its bad merge by reverting commits, in the process clobbering the user's uncommitted changes.

**Evidence**: E3.

## Cluster G: Source-of-truth ambiguity in the codebase

### G1. Duplicated tests / extensions / code with no "canonical" marker

When two packages (or two implementations) define the same thing, subagents don't know which is authoritative. They may edit the wrong one, or preserve the wrong one when deleting duplicates.

**Evidence**: E2 — duplicated `MoveHistoryHelpers`, duplicated extensions; subagents couldn't tell which was canonical.

## Recurring themes

Looking across clusters:

1. **Information decays at every hop**. Grill → PRD → issues → code → review, and every arrow loses fidelity.
2. **No explicit bridge artifacts**. Decisions log, success criteria, coverage matrix, prerequisite graph — none exist as durable files between skills.
3. **No verification at boundaries**. Every hop trusts the prior. There's no "does downstream input actually match upstream output?" check.
4. **Agents don't escalate when stuck**. They redefine "done" to match what they managed to do.
5. **Multi-agent git state is treated as free, but it's fragile**. Base branches, remote sync, worktree cleanup, PR targets — all assumed, rarely verified.
6. **"Done" is never defined externally**. Either from the consumer's perspective, or as a testable condition set, or as a coverage matrix.
