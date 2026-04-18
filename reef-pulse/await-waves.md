# await-waves

> **Tracker note**: Examples below show GitHub and local file operations. For other trackers, use the equivalent operations via MCP tools or CLI. See [tracker-reference.md](tracker-reference.md).

> **AFK skill**: this skill runs without human interaction. No judgment calls expected — if blocked, exit silently. If deps are done, promote. Never block waiting for human input.

## Input

This skill requires a specific slice: e.g. `#55` or `my-feature/002-token-storage`.

Read the slice. It must have a `blocked-by` list referencing other slices.

## 1. Check dependencies

For each dependency in the `blocked-by` list:

### GitHub tracker

Check if the blocking slice issue is tagged `done` (has the `done` label). Use `gh issue view <number>`.

### Local tracker

Check if the blocking slice file has the `[done]` prefix.

**If any dependency is NOT done**: exit silently. Do nothing. This slice stays `to-await-waves`. It will be checked again on the next pulse.

**If ALL dependencies are done**: continue to step 2.

## 2. Re-review the plan

Earlier slices may have changed the codebase. Use a temporary worktree to inspect the target branch without disturbing the main checkout:

```sh
WORKTREE=$(reef-worktree-enter.sh \
  --base-branch {base-branch} --target-branch {target-branch} \
  --phase await-waves --slice {slice-name})
cd "$WORKTREE"
```

Read this slice's acceptance criteria and compare against the current state of the code:

- Did earlier slices introduce interfaces, modules, or conventions this slice should use?
- Did earlier slices rename or restructure anything that affects this slice's approach?
- Are any of this slice's acceptance criteria already partially satisfied by earlier work?

**If the plan still holds**: no changes needed.

**If adjustments needed**: update the slice's acceptance criteria and description to reflect the current reality. Be specific about what changed and why.

### GitHub tracker

If acceptance criteria were updated, edit the slice issue body with `gh issue edit`. Add a comment explaining what changed and why.

### Local tracker

If acceptance criteria were updated, rewrite the slice file with the updated content.

## 3. Promote

### GitHub tracker

Change the slice issue label from `to-await-waves` to `to-implement`.

### Local tracker

Rename from `[to-await-waves] ...` to `[to-implement] ...`.

## 4. Clean up

```sh
reef-worktree-exit.sh --path "$WORKTREE"
```

## Handoff

If dispatched by reef-pulse, report: "Slice {name} is unblocked and ready for implementation."
