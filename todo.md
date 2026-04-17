# Moonjelly Reef — Build Plan

## Understanding

### What we're building

An orchestration framework where state lives in tags (GitHub labels or local filename prefixes/frontmatter), a stateless "pulse" scans and dispatches, and skills transition work items through a defined lifecycle. Issue-tracker agnostic.

### Core design decisions

**One evolving file per work item.** Locally: `plan.md` in a work item folder. On GitHub: the issue body. The file grows through phases — probe session first, then plan + success criteria prepended on top, then coverage matrix appended. Most important content at the top.

**PRs are the universal handoff artifact.** Even for local-tracker projects, implementation work happens in git worktrees and is submitted as PRs toward the feature branch. The PR description carries the report (acceptance criteria checklist, ambiguous choices, test results). The slice file/issue is the task card; the PR is the work artifact.

**tdd is the only external skill invoked.** reef-implement wraps `/tdd` with git prep and reef context. All planning skills (write-a-prd, prd-to-plan, prd-to-issues, request-refactor-plan, triage-issue) are absorbed natively into reef-scope and reef-slice. Their templates and disciplines become reference material, not dependencies.

**Every skill is a forgiving entry point.** Any `/reef-*` skill can be called directly. If setup hasn't happened, it triggers reef-setup. If prerequisite artifacts are missing, it routes to the right prior skill. No skill crashes because "you should have run X first."

**Branch strategy is per-project, decided during scoping.** reef-scope discusses branching with the user and documents it in the plan. Downstream skills read the plan. No hardcoded naming conventions.

**Worktrees for all slice implementation.** Multiple slices may run in parallel. Each gets its own worktree branched from the feature branch. PRs target the feature branch, not main.

**Tags:**
- GitHub: labels on issues (`to-probe`, `to-scope`, `to-slice`, etc.)
- Local parent files: filename prefix `[to-scope] plan.md` (no frontmatter needed)
- Local slice files: filename prefix `[to-implement] slice-name.md`

**close-the-loop's CTO mindset** is absorbed into reef-inspect (per-PR review) and reef-ratify (holistic feature branch review). Not invoked as a dependency.

### Artifact chain

```
reef-probe:
  reads  → work item (issue or idea file)
  writes → probe session appended to the evolving file
  tags   → to-scope

reef-scope:
  reads  → evolving file with probe session
  writes → plan + success criteria PREPENDED to the evolving file
  tags   → to-slice

reef-slice:
  reads  → evolving file with plan + success criteria
  writes → slice files/issues with acceptance criteria + dep graph
           coverage matrix appended to the evolving file
           feature branch created
  tags   → parent stays at to-slice until slicing done
           slices tagged to-implement or to-await-waves

reef-await-waves:
  reads  → slice file/issue (blocked-by list)
  writes → possibly updated acceptance criteria if plan shifted
  tags   → to-implement (or no change if deps not done)

reef-implement:
  reads  → slice file/issue (acceptance criteria, parent plan link, feature branch)
  writes → code in worktree, PR toward feature branch with report
           may include screenshots/video if app is launchable (project-dependent)
  tags   → to-inspect

reef-inspect:
  reads  → slice's PR (code, report, acceptance criteria)
  writes → review comments, trivial cleanups committed
  tags   → to-merge or to-rework

reef-rework:
  reads  → PR review comments, original acceptance criteria
  writes → fixes on PR, updated report
  tags   → to-inspect

reef-merge:
  reads  → approved PR
  writes → merged PR, possibly unblocks siblings
           appends agent decisions summary from merged PR to parent plan/issue
  tags   → slice: done, siblings: to-await-waves, parent: to-ratify (if all done)

reef-ratify:
  reads  → feature branch (all merged code), plan success criteria,
           agent decisions already aggregated on parent by reef-merge
  writes → final report on the feature branch PR (not the full plan —
           highlights: what was implemented as expected, what drifted,
           what the human needs to know before hitting merge)
           may include screenshots/video if app is launchable
  tags   → to-finalise or to-rescan

reef-rescan:
  reads  → ratify report, entire parent plan/issue (not just matrix),
           success criteria, coverage matrix
  writes → new slice files/issues, updated coverage matrix,
           may also update plan sections above the matrix if gaps
           reveal planning-level issues (not just missing slices)
  tags   → new slices: to-implement or to-await-waves

reef-finalise:
  reads  → aggregate report
  writes → nothing (human decides)
  tags   → done, to-probe (re-probe), or to-rescan

reef-pulse:
  reads  → all tags across all work items
  writes → nothing directly (dispatches skills)
  tags   → none (skills set their own tags)
```

### Painpoints each skill must prevent

```
reef-probe    → A1 (ephemeral decisions — now persisted in evolving file)
reef-scope    → A2 (no success criteria), A4 (builder's perspective), B1 (wrong skill routing)
reef-slice    → A3 (no coverage cross-check), D2 (implicit prerequisites)
reef-await-waves → D1 (wrong order), F3 (stale local state)
reef-implement → C1 (silent skip), C2 (partial test suite), F1-F2 (wrong base/target branch)
reef-inspect  → C3 (mocked bugs), C4 (responsibility diffusion), F4 (stale state)
reef-rework   → C1 (skip instead of fix)
reef-merge    → E1 (ticket lifecycle confusion), F5 (collapsed commits)
reef-ratify   → A4 (builder perspective), B2 (no re-grill), C2 (partial suite)
reef-rescan   → E1-E2 (ticket lifecycle), B2 (cold follow-ups)
reef-finalise → C4 (responsibility diffusion — human owns final call)
reef-pulse    → F3 (stale state), F6 (panic revert)
```

## Build order

Each skill is written, then reviewed against its painpoints before moving on.

### Phase 0: Foundation

- [x] **reef-setup** — `.agents/moonjelly-reef/config.md` creation, tracker type detection, ASCII art. Small, but every other skill depends on it existing.

### Phase 1: Human-facing skills (probe → scope)

- [x] **reef-probe** — entry point. Absorbs grill-me. Persists session to evolving file. Must handle both GitHub and local.
- [x] **reef-scope** — the router + planner. Biggest skill. Absorbs write-a-prd template, request-refactor-plan discipline, triage-issue investigation, prd-to-plan architectural decisions. Produces plan + success criteria. Discusses branch strategy. Reference: `write-a-prd/`, `request-refactor-plan/`, `triage-issue/`, `prd-to-plan/`.

### Phase 2: Slicing

- [x] **reef-slice** — absorbs prd-to-issues and prd-to-plan slicing mechanics. Vertical slices, dep graph, coverage matrix. Creates feature branch. Creates slice files/issues. Reference: `prd-to-issues/`, `prd-to-plan/`.

### Phase 3: Implementation loop

- [x] **reef-implement** — git prep contract, invokes `/tdd`, opens PR with report. Must be crystal clear on worktree setup, branch targets, what "done" means.
- [x] **reef-await-waves** — dep checker. Pulls remote, checks siblings, re-reviews plan. Simple but critical for F3 prevention.
- [x] **reef-inspect** — independent PR reviewer. CTO mindset from close-the-loop. Verifies acceptance criteria against code, not against PR description.
- [x] **reef-rework** — reads feedback, fixes, re-submits. Short skill.
- [x] **reef-merge** — merge + unblock siblings + check parent status. Git hygiene critical here.

### Phase 4: Closeout

- [x] **reef-ratify** — holistic review. CTO mindset. Aggregates all LLM decisions from slice PRs. Checks success criteria against actual merged code.
- [x] **reef-rescan** — gap analysis, new slices. Updates coverage matrix. Closes partial originals with references.
- [x] **reef-finalise** — human handoff. Present report, offer three options (approve, re-probe, re-scan).

### Phase 5: Orchestrator

- [x] **reef-pulse** — last. Scans all tags, dispatches skills as sub-agents, handles --hitl vs --afk modes. Triggers reef-setup if config missing.

### Phase 6: Cleanup

- [x] Remove matt planning skills (write-a-prd, prd-to-plan, prd-to-issues, request-refactor-plan, triage-issue, grill-me, improve-codebase-architecture, ubiquitous-language) from repo
- [x] Remove tdd (reef-setup prompts to install from matt)
- [x] Remove close-the-loop (absorbed into reef-inspect + reef-ratify)
- [x] Update README to reflect current state (install section, companion skill, one-evolving-file artifact paths)
- [x] Edit this todo.md to reflect remaining work

### Phase 7: Distribution

- [ ] Investigate: can `npx skills@latest add` install a bundle (all 13 reef skills + reef-setup at once)?
- [ ] If yes, define a single install command. If no, the README already lists individual commands.
- [x] reef-setup already prompts to install tdd + ubiquitous-language if not present

### Phase 8: Test the framework

- [ ] Dry run: create a `to-probe` item, walk through every skill manually on a real (small) project
- [ ] Verify: each skill produces the right artifacts, on the right branch, with the right tags
- [ ] Verify: the one-evolving-file pattern works end-to-end (probe → scope → slice → ... → finalise)
- [ ] Verify: reef-pulse scans and dispatches correctly
- [ ] Catch any skill instructions that are ambiguous or that an LLM misinterprets
- [ ] Identify skills that need supporting files (templates, examples) like reef-scope has

### Known gaps to revisit

- [x] reef-implement: tdd fallback — inline TDD discipline written for when tdd skill is not installed
- [x] reef-pulse: `--hitl` / `--afk` — detected from skill invocation args
- [x] reef-pulse: agent team dispatch — concrete instructions added (when to use teams vs sub-agents, team lead prompt template)
- [x] reef-scope: iteration loop reference — main SKILL.md now points to "Collaborating with the user" sections in sub-files
- [x] Local tracker: `[tag]` convention — documented as lowercase, hyphens only, no spaces in bracket
- [x] Cron setup: `cron.sh` + `launchd.plist` written, with PID-based lock file to prevent overlapping runs
- [x] orchestration.md and painpoints.md archived to `.github/`
- [x] All "AC" abbreviations expanded to "acceptance criteria" across all skills
