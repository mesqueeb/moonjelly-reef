# Agents Guide

## ORCHESTRATION.md is not documentation

It is a machine-readable contract consumed by `tests/orchestration.test.sh`. The test extracts every shell line and `- contains:` directive from each phase section and checks they appear literally and in order in the corresponding phase `.md` file.

It's purpose is to capture the I/O, Git and persistence layers: tracker calls, worktree entry/exit, commit/push calls, handoff variables. Not prose, not prompting instructions.

**When changing I/O, git, or persistence in a phase:** look at ORCHESTRATION.md first to understand the current contract, then update it alongside the phase file as a red-green TDD step. The exception is when the exact variable names or syntax can't be known upfront — in that case implement first, then update ORCHESTRATION.md to match.
