# Tracker Reference

This document defines the operations reef skills perform on issues, with examples for each supported tracker type. Every reef skill that reads, writes, or tags items should follow these patterns.

The tracker type is defined in `.agents/moonjelly-reef/config.md`.

## Operations

### Read a issue

| Tracker | How |
| --- | --- |
| GitHub | `gh issue view <number> --json body,title,labels` |
| Local | Read the file (e.g. `{local-path}/{title}/[tag] plan.md`) |
| Jira | Use Atlassian MCP server or `jira-cli`: `jira issue view <key>` |
| Linear | Use Linear MCP tools: query the issue by identifier |
| Other | Use the relevant MCP tool or CLI. If none is available, ask the user how to access it. |

### Update a issue body

| Tracker | How |
| --- | --- |
| GitHub | `gh issue edit <number> --body "..."` |
| Local | Rewrite the file content |
| Jira | Use Jira MCP tools or API to update the description field |
| Linear | Use Linear MCP tools to update the description |
| Other | Equivalent "edit description" operation |

### Change a tag (status transition)

| Tracker | How |
| --- | --- |
| GitHub | Remove old label, add new label: `gh issue edit <number> --remove-label "to-scope" --add-label "to-slice"` |
| Local | Rename the file: `[to-scope] plan.md` → `[to-slice] plan.md`. Use lowercase tags, hyphens only, no spaces in the tag bracket. |
| Jira | Change the issue status or update a label field |
| Linear | Change the issue status or update labels |
| Other | Equivalent "change status/label" operation |

### Create a sub-item (slice)

| Tracker | How |
| --- | --- |
| GitHub | `gh issue create --title "..." --body "..." --label "to-implement"` + link to plan |
| Local | Create a file in `{title}/slices/[to-implement] slice-name.md` |
| Jira | Create a sub-task or linked issue under the plan |
| Linear | Create a sub-issue linked to the plan |
| Other | Equivalent "create child item" operation |

### Close a issue

| Tracker | How |
| --- | --- |
| GitHub | `gh issue close <number>` |
| Local | Rename prefix to `[done]` |
| Jira | Transition to "Done" status |
| Linear | Mark as "Done" |
| Other | Equivalent close/complete operation |

### Query items by tag

| Tracker | How |
| --- | --- |
| GitHub | `gh issue list --label "to-implement" --json number,title,labels` |
| Local | Glob for files matching `[to-implement] *.md` in the local path |
| Jira | JQL: `labels = "to-implement" AND project = X` |
| Linear | Filter issues by label |
| Other | Equivalent "search by status/label" query |

## Push convention: metadata vs code

There are two kinds of writes in a reef workflow. Each uses a different push strategy:

**Code changes** (implement, inspect cleanup, rework) need review. They push to a **slice branch** and go through a PR:

```sh
commit.sh --branch $SLICE_BRANCH -m "implement: ..."
```

**Metadata changes** (slice creation, coverage matrix updates, tag renames, rescan slices) are mechanical and need no review. They push **directly to the target branch**:

```sh
commit.sh --branch $TARGET_BRANCH -m "slice: update plan"
```

### Phase push targets

| Phase | What it writes | Push target | Branch arg |
| --- | --- | --- | --- |
| slice | plan updates, new slice files | target (direct) | `--branch $TARGET_BRANCH` |
| implement | code + tests | slice branch (PR) | `--branch $SLICE_BRANCH` |
| inspect | cleanup commits | slice branch (PR) | `--branch $SLICE_BRANCH` |
| rework | fix commits | slice branch (PR) | `--branch $SLICE_BRANCH` |
| await-waves | slice file updates | target (direct) | `--branch $TARGET_BRANCH` |
| merge | plan updates, coverage matrix | target (direct) | `--branch $TARGET_BRANCH` |
| rescan | plan updates, new slice files | target (direct) | `--branch $TARGET_BRANCH` |
| ratify | doc commits (if any) | target (direct) | `--branch $TARGET_BRANCH` |

GitHub tracker phases that only update issues (via `gh issue edit`) don't need to push at all — the changes live on GitHub, not in the repo.

Local tracker phases write plan/slice files to disk, so they must commit and push to keep other agents' worktrees in sync. Every local tracker write should be followed by a `commit.sh` call before exiting.

## MCP setup

For non-GitHub, non-local trackers, the user should have the relevant MCP server configured in their Claude Code settings. The setup phase (`setup.md`) prompts for this during initial configuration.

Common MCP servers:
- Jira / Confluence: Atlassian's official remote MCP server at `https://mcp.atlassian.com/v1/sse` (or community `mcp-atlassian` package). CLI alternative: `jira-cli` by ankitpokhrel.
- Linear: community `linear-mcp-server` (no official Anthropic server). Or use the Linear API directly.
- ClickUp: official ClickUp MCP server — see `https://developer.clickup.com/docs/connect-an-ai-assistant-to-clickups-mcp-server`

If no MCP server is available for the chosen tracker, the user can use CLI tools or API calls directly.
