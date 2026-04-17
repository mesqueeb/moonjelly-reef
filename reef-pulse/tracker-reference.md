# Tracker Reference

This document defines the operations reef skills perform on work items, with examples for each supported tracker type. Every reef skill that reads, writes, or tags items should follow these patterns.

The tracker type is defined in `.agents/moonjelly-reef/config.md`.

## Operations

### Read a work item

| Tracker | How |
| --- | --- |
| GitHub | `gh issue view <number> --json body,title,labels` |
| Local | Read the file (e.g. `{local-path}/{title}/[tag] plan.md`) |
| Jira | Use Atlassian MCP server or `jira-cli`: `jira issue view <key>` |
| Linear | Use Linear MCP tools: query the issue by identifier |
| Other | Use the relevant MCP tool or CLI. If none is available, ask the user how to access it. |

### Update a work item body

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
| GitHub | `gh issue create --title "..." --body "..." --label "to-implement"` + link to parent |
| Local | Create a file in `{title}/slices/[to-implement] slice-name.md` |
| Jira | Create a sub-task or linked issue under the parent |
| Linear | Create a sub-issue linked to the parent |
| Other | Equivalent "create child item" operation |

### Close a work item

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

## MCP setup

For non-GitHub, non-local trackers, the user should have the relevant MCP server configured in their Claude Code settings. The setup phase (`setup.md`) prompts for this during initial configuration.

Common MCP servers:
- Jira / Confluence: Atlassian's official remote MCP server at `https://mcp.atlassian.com/v1/sse` (or community `mcp-atlassian` package). CLI alternative: `jira-cli` by ankitpokhrel.
- Linear: community `linear-mcp-server` (no official Anthropic server). Or use the Linear API directly.
- ClickUp: official ClickUp MCP server — see `https://developer.clickup.com/docs/connect-an-ai-assistant-to-clickups-mcp-server`

If no MCP server is available for the chosen tracker, the user can use CLI tools or API calls directly.
