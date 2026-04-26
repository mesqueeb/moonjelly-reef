# Review Lenses

## Lens 1: Writing style

Read `WRITING_STYLE_GUIDE.md` in full. Then review this file and flag every violation of the rules defined there.

## Lens 2: Ubiquitous language

Review this file against `UBIQUITOUS_LANGUAGE.md` and flag any misuse, drift, or missing canonical terms.

## Lens 3: Input declaration

Review the Input section and all variable declarations. Are all variables declared at the point they first become available, not deferred? Does the Input section only contain what is known before any fetch?

## Lens 4: Handoff completeness

Review every exit path, including blocked and error paths. Does each one emit a complete handoff with `ISSUE_ID`, `NEXT_PHASE`, `PR_ID`, and `SUMMARY`?

## Lens 5: Tracker commands

Review all `./tracker.sh` calls. Are there any bare `gh` calls? Are `--json` fields only what is actually used downstream? Are `--remove-label`/`--add-label` pairs complete and in sync?

## Lens 6: Label transitions

First read the state machine in `README.md`. Then review every label transition in this file. Does each one correspond to a valid edge in the state machine?

## Lens 7: Git hygiene

Review all git-related shell calls for correctness and completeness:

- **Worktree enter/exit**: Are all `worktree-enter.sh` calls present before any work begins (including before any commit or push)? Is `--fork-from` pointing at the correct branch for this phase (base branch vs PR branch)? Is `worktree-exit.sh` called on every exit path, including early blocked handoffs?
- **Commits**: Are all commits made via `commit-push.sh`? Flag any bare `git commit` or `git push` calls, and any prose instructions that vaguely say things like "commit and push" without referencing an explicit shell command.
- **PR operations**: Are all PR-related operations (create, update, merge, view) done via `tracker.sh pr …`? Flag any bare `gh pr` calls or vague prose like "open a PR" or "merge the PR" without an explicit `tracker.sh pr` command.

## Lens 8: Prose clarity

Review all prose instructions. Are there any steps a sub-agent could misread or execute ambiguously? Flag vague steps, implicit assumptions, or anything that relies on the agent using its own judgment without guidance.
