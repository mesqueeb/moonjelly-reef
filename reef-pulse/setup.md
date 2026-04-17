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

### 2. Check for tdd skill

Check if the `tdd` skill is installed (look for `tdd/SKILL.md` in the skills directories — `~/.claude/skills/`, `.claude/skills/`, or sibling directories to the reef skills).

If not found:

> "Moonjelly Reef uses the `tdd` skill for implementation. Want me to install it?"
>
> ```sh
> npx skills@latest add mattpocock/skills/tdd
> ```

If the user declines, that's fine — note it in config. The implement phase (`implement.md`) has built-in TDD instructions it uses when the skill isn't available.

### 3. Check for ubiquitous-language skill

Check if the `ubiquitous-language` skill is installed (same locations as tdd).

If not found:

> "Moonjelly Reef can optionally use the `ubiquitous-language` skill to harden domain terminology during scoping and review. Want me to install it?"
>
> ```sh
> npx skills@latest add mattpocock/skills/ubiquitous-language
> ```

If the user declines, that's fine — note it in config. The scope and ratify phases will skip the terminology steps.

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
