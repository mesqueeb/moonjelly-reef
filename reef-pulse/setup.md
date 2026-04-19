# setup

You are setting up Moonjelly Reef for this project. This only runs once — when `.agents/moonjelly-reef/config.md` does not exist.

Start by printing the banner. Do NOT try to reproduce the art manually — use `cat`:

```sh
printf '\033[36m'; cat reef-pulse/banner.txt; printf '\033[0m'
```

## Steps

### 1. Detect issue tracker

Look for clues in the repo:

- `.github/` directory or `gh` CLI available → likely **GitHub Issues**
- `atlassian` references, `jira` in config files → likely **Jira**
- `linear` references in config files → likely **Linear**
- Nothing detected → likely **local md files**

Present your best guess to the user:

> "It looks like this project uses **GitHub Issues**. Is that right, or would you prefer a different tracker?"
>
> Options: `github` · `jira` · `linear` · `clickup` · `local md files` · `other`

The user may also name a tracker not listed (Notion, etc.) — that's fine. Any system that supports creating items, updating descriptions, and tagging/labeling will work.

**For each tracker type, verify the tooling:**

- **GitHub**: confirm `gh` CLI is available and authenticated (`gh auth status`).
- **Jira / Linear / ClickUp / other**: suggest the user install the relevant MCP server so reef skills can interact with it. Check if one is already configured. Common MCP servers:
  - Jira / Confluence: Atlassian's official remote MCP server at `https://mcp.atlassian.com/v1/sse` (or community `mcp-atlassian` package). CLI alternative: `jira-cli` by ankitpokhrel.
  - Linear: community `linear-mcp-server` (no official Anthropic server). Or use the Linear API directly.
  - ClickUp: official ClickUp MCP server — see ClickUp developer docs for "connect an AI assistant to ClickUp's MCP server".
- **Local**: continue to step 1b.

### 1b. Local tracker options

If the user chose local, ask:

> "Two options for local tracker files:"
>
> 1. **Gitignored** — tracker files live in a directory that's `.gitignore`'d. Simple, no git noise. Works great for solo use on one machine.
> 2. **Committed** — tracker files are committed and pushed to a branch. Syncs across machines and agents automatically.
>
> "Which do you prefer?"

**If gitignored:**

1. Ask where to store tracker files. Suggest `.agents/moonjelly-reef/tracker/` as default.
2. Offer to add the path to `.gitignore`: "Want me to add `{path}` to `.gitignore`?"
3. If yes, append the path to `.gitignore` (create the file if needed).
4. Set tracker type to `local-tracker-gitignored`.

**If committed:**

1. Ask where to store tracker files. Suggest `.agents/moonjelly-reef/tracker/` as default.
2. Verify the chosen path is NOT already in `.gitignore`. If it is, warn the user and ask them to pick a different path or remove the gitignore rule.
3. Ask which branch to commit tracker updates to. Suggest `main`: "Which branch should tracker updates be committed to? (suggest: `main`)"
4. Set tracker type to `local-tracker-committed`.

### 2. Check for optional skills

Check which skills are installed:

```sh
npx skills@latest list
```

Look for `tdd` and `ubiquitous-language` in the output.

For each skill not found, tell the user it's optional and reef has a fallback:

> "Two optional skills can enhance the reef. Both have built-in fallbacks, so they're not required:"
>
> **tdd** — used by the implement phase for test-driven development. Without it, `implement.md` uses its own lightweight TDD instructions.
>
> ```sh
> npx skills@latest add mattpocock/skills/tdd
> ```
>
> **ubiquitous-language** — used by scope and ratify to harden domain terminology. Without it, those phases skip the terminology steps.
>
> ```sh
> npx skills@latest add mattpocock/skills/ubiquitous-language
> ```
>
> "Run the install commands above if you want them, or skip — the reef works fine without them."

### 3. Write config

Create `.agents/moonjelly-reef/config.md`:

```markdown
---
tracker: github
tracker-path: —
tracker-branch: —
tdd-installed: true
ubiquitous-language-installed: true
---
```

Values for `tracker`: `github`, `local-tracker-gitignored`, `local-tracker-committed`, `jira`, `linear`, `clickup`, or any custom name.

`tracker-path` is set when tracker is `local-tracker-gitignored` or `local-tracker-committed` (e.g. `.agents/moonjelly-reef/tracker/`). Otherwise `—`.

`tracker-branch` is set when tracker is `local-tracker-committed` (e.g. `main`). Otherwise `—`.

### 4. Offer autopilot

> "Want the reef to pulse on its own while you're away? I can set up a recurring cron that runs `/reef-pulse --afk` every hour (or any interval you prefer)."

If the user says yes, create a durable cron:

```
CronCreate cron="7 * * * *" prompt="/reef-pulse --afk" durable=true
```

Let the user pick the interval. Common choices:

- `"7 * * * *"` — hourly
- `"*/30 * * * *"` — every 30 minutes
- `"3 9 * * 1-5"` — weekday mornings

If the user declines, skip — they can always set it up later.

### 5. Confirm

> "You're all set. The reef is alive. 🪼"
>
> Run `/reef-scope` to start working on something, or `/reef-pulse` to scan for existing work.
