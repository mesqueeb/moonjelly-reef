# setup

You are setting up Moonjelly Reef for this project. This only runs once — when `.agents/moonjelly-reef/config.md` does not exist.

Start by printing this banner:

```
╔════════════════════════════════════════════════════╗
║ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~ ║
║                                                    ║
║      .  ·´¨`·.    ·´¨`·.  .  ·´¨`·.              ║
║       ( . · . )  ( · . · )  ( . · . )             ║
║        `·. .·´    `·. .·´    `·. .·´              ║
║          |·|        | |        |·|                 ║
║          | |       ·| |·       | |                 ║
║         ·|·|·      | | |      ·|·|·                ║
║          ' '       ' · '       ' '                 ║
║                                                    ║
║    .  ·´¨`·.              ·´¨`·.  .               ║
║     ( · . · )              ( · . · )              ║
║      `·. .·´                `·. .·´               ║
║        | |·                  ·| |                  ║
║       ·| | |                | | |·                 ║
║        ' · '                ' · '                  ║
║                                                    ║
║            M O O N J E L L Y  R E E F             ║
╚════════════════════════════════════════════════════╝

    Welcome to Moonjelly Reef 🪼
    Let's set up your project.
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
> Options: `github` · `jira` · `linear` · `local`

The user may also name a tracker not listed (ClickUp, Notion, etc.) — that's fine. Any system that supports creating items, updating descriptions, and tagging/labeling will work.

**For each tracker type, verify the tooling:**

- **GitHub**: confirm `gh` CLI is available and authenticated (`gh auth status`).
- **Jira / Linear / ClickUp / other**: suggest the user install the relevant MCP server so reef skills can interact with it. Check if one is already configured. See [tracker-reference.md](tracker-reference.md) for common MCP servers.
- **Local**: ask where they'd like work items stored (suggest `.agents/moonjelly-reef/issue-tracker/` as default).

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

### 4. Write config

Create `.agents/moonjelly-reef/config.md`:

```markdown
# Moonjelly Reef Config

| Setting                       | Value  |
| ----------------------------- | ------ |
| Tracker                       | github |
| Local path                    | —      |
| tdd installed                 | yes    |
| ubiquitous-language installed | yes    |
```

For local tracker, `Local path` would be the chosen directory (e.g. `.agents/moonjelly-reef/issue-tracker/`).

### 4. Confirm

> "You're all set. The reef is alive. 🪼"
>
> Run `/reef-scope` to start working on something, or `/reef-pulse` to scan for existing work.
