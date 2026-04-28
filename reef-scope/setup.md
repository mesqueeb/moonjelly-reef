# setup

You are setting up Moonjelly Reef for this project. This only runs once — when `.agents/moonjelly-reef/config.md` does not exist.

Print the banner. Do NOT try to reproduce the art manually — use `cat`:

```sh
printf '\033[36m'; cat "$SKILL_DIR/banner.txt"; printf '\033[0m'
```

## 0. Check for git

Worktrees and branches (used by the reef's implement/inspect/merge cycle) require git. Check whether the current project has a git repository:

```sh
git rev-parse --git-dir 2>/dev/null
```

If git is present (command succeeds), continue to step 1. If git is missing (command fails), offer to initialize one. Present this message to the diver:

> "This project doesn't seem to use git. So I'll treat `{dir}` as the project root folder and init a `.git` folder, is that OK? (It's so the reef can better organise its efforts when multiple issues are worked on at once)."

Replace `{dir}` with the absolute path to the current working directory.

If the diver agrees, run:

```sh
git init
```

If the diver declines, warn them that the reef cannot function without git and stop setup.

## 1. Detect issue tracker

Look for clues in the repo:

- `.github/` directory or `gh` CLI available → likely **GitHub Issues**
- `atlassian` references, `jira` in config files → likely **Jira**
- `linear` references in config files → likely **Linear**
- Nothing detected → likely **local md files**

Present your best guess to the diver:

> "It looks like this project uses **GitHub Issues**. Is that right, or would you prefer a different tracker?"
>
> Options: `github` · `jira` · `linear` · `clickup` · `local md files` · `other`

The diver may also name a tracker not listed (Notion, etc.) — that's fine. Any system that supports creating items, updating descriptions, and labeling will work.

**For each tracker type, verify the tooling:**

- **GitHub**: confirm `gh` CLI is available and authenticated (`gh auth status`).
- **Jira / Linear / ClickUp / other**: suggest the diver install the relevant MCP server so the reef can interact with it. Check if one is already configured. Common MCP servers:
  - Jira / Confluence: Atlassian's official remote MCP server at `https://mcp.atlassian.com/v1/sse` (or community `mcp-atlassian` package). CLI alternative: `jira-cli` by ankitpokhrel.
  - Linear: community `linear-mcp-server` (no official Anthropic server). Or use the Linear API directly.
  - ClickUp: official ClickUp MCP server — see ClickUp developer docs for "connect an AI assistant to ClickUp's MCP server".
- **Local**: continue to step 1b.

### 1b. Local tracker options

If the diver chose local, ask:

> "Two options for local tracker files:"
>
> 1. **Gitignored** — tracker files live in a directory that's `.gitignore`'d. Simple, no git noise. Works great for solo use on one machine.
> 2. **Committed** — tracker files are committed and pushed to a branch. Syncs across machines and agents automatically.
>
> "Which do you prefer?"

**If gitignored:**

1. Ask where to store tracker files. Suggest `.agents/moonjelly-reef/tracker/` at project root as default.
2. Offer to add the path to `.gitignore`: "Want me to add `{path}` to `.gitignore`?"
3. If yes, append the path to `.gitignore` (create the file if needed).

```sh
TRACKER_TYPE="local-tracker-gitignored"
TRACKER_PATH="{path chosen by diver}" # e.g. ".agents/moonjelly-reef/tracker/"
TRACKER_BRANCH="-"
```

**If committed:**

1. Ask where to store tracker files. Suggest `.agents/moonjelly-reef/tracker/` at project root as default.
2. Verify the chosen path is NOT already in `.gitignore`. If it is, warn the diver and ask them to pick a different path or remove the gitignore rule.
3. Ask which branch to commit tracker updates to. Suggest `main`: "Which branch should tracker updates be committed to? (suggest: `main`)"

```sh
TRACKER_TYPE="local-tracker-committed"
TRACKER_PATH="{path chosen by diver}" # e.g. ".agents/moonjelly-reef/tracker/"
TRACKER_BRANCH="{branch chosen by diver}" # e.g. "main"
```

## 2. Check for optional skills

Check which skills are installed:

```sh
npx skills@latest list
```

```sh
TDD_INSTALLED="{true if tdd found in output, false otherwise}" # e.g. true
UL_INSTALLED="{true if ubiquitous-language found in output, false otherwise}" # e.g. true
```

For each skill not found, tell the diver it's optional and reef has a fallback:

> "Two optional skills can enhance the reef. Both have built-in fallbacks, so they're not required:"
>
> **tdd** — used by the implement phase for test-driven development. Without it, `implement.md` uses its own lightweight TDD instructions.
>
> ```sh
> npx skills@latest add mattpocock/skills/tdd
> ```
>
> **ubiquitous-language** — used by scope and seal to harden domain terminology. Without it, those phases skip the terminology steps.
>
> ```sh
> npx skills@latest add mattpocock/skills/ubiquitous-language
> ```
>
> "Run the install commands above if you want them, or skip — the reef works fine without them."

## 3. Merge strategy

Ask the diver:

> "What merge strategy should the reef use for PRs? (recommended: `squash`)"
>
> 1. `squash` — squash and merge (one clean commit per PR)
> 2. `merge` — merge commit (preserves full branch history)

```sh
MERGE_STRATEGY="{merge strategy chosen by diver}" # e.g. "squash"
```

## 4. Detect date format

Detect the user's preferred date/time format from the OS:

```sh
OS="$(uname -s 2>/dev/null || echo 'unknown')"
DATE_FORMAT="yyyy-MM-dd HH:mm"  # default fallback
if [ "$OS" = "Darwin" ]; then
  # macOS: read ICU date format from NSGlobalDomain
  RAW_DATE="$(defaults read NSGlobalDomain AppleICUDateFormatStrings 2>/dev/null | grep '"1"' | sed 's/.*"1" = "\(.*\)".*/\1/' || echo '')"
  FORCE_24H="$(defaults read NSGlobalDomain AppleICUForce24HourTime 2>/dev/null || echo '')"
  if [ -n "$RAW_DATE" ]; then
    DATE_FORMAT="$RAW_DATE"
  fi
  if [ "$FORCE_24H" = "1" ]; then
    DATE_FORMAT="$(echo "$DATE_FORMAT" | sed 's/h/H/g; s/ a//g; s/a //g')"
  elif [ "$FORCE_24H" = "0" ]; then
    DATE_FORMAT="$(echo "$DATE_FORMAT" | sed 's/H/h/g') a"
  fi
  # Append time component if not already present
  case "$DATE_FORMAT" in
    *H:mm*|*h:mm*) ;;
    *) DATE_FORMAT="$DATE_FORMAT HH:mm" ;;
  esac
elif [ "$OS" = "Linux" ]; then
  # Linux: translate LC_TIME strftime tokens to ICU
  D_FMT="$(locale -k LC_TIME 2>/dev/null | grep '^d_fmt=' | sed 's/d_fmt="\(.*\)"/\1/' || echo '')"
  T_FMT="$(locale -k LC_TIME 2>/dev/null | grep '^t_fmt=' | sed 's/t_fmt="\(.*\)"/\1/' || echo '')"
  if [ -n "$D_FMT" ] && [ -n "$T_FMT" ]; then
    ICU_DATE="$(echo "$D_FMT" | sed 's/%Y/yyyy/g; s/%m/MM/g; s/%d/dd/g; s/%e/d/g')"
    ICU_TIME="$(echo "$T_FMT" | sed 's/%H/HH/g; s/%M/mm/g; s/%S/ss/g; s/%I/hh/g; s/%p/ a/g')"
    DATE_FORMAT="$ICU_DATE $ICU_TIME"
  fi
fi
```

Present the detected format and ask the diver to confirm or override:

> "Detected your OS date format as: `{DATE_FORMAT}`
>
> This will be used as the default timestamp format in the reef (e.g. in reports and metrics).
>
> Press Enter to keep it, or type a different ICU format string (e.g. `MM/dd/yyyy h:mm a`):"

Record the diver's confirmed choice:

```sh
DATE_FORMAT="{confirmed or overridden value from diver}" # e.g. "yyyy-MM-dd HH:mm"
```

## 5. Ignore reef directories

Reef keeps its temporary git worktrees under `.worktrees/` and its agent files under `.agents/moonjelly-reef/` inside the repo.

1. Check whether `.agents/moonjelly-reef/` and `.worktrees/` are already in `.gitignore`. For each that isn't, append it to `.gitignore` (create the file if needed).
2. Tell the diver what was added, e.g. "Added `.agents/moonjelly-reef/` and `.worktrees/` to `.gitignore`, so reef's agent files and temporary worktrees won't show up as untracked files."

## 6. Write config

```sh
CONFIG="---
tracker: $TRACKER_TYPE
tracker-path: $TRACKER_PATH
tracker-branch: $TRACKER_BRANCH
merge-strategy: $MERGE_STRATEGY
date-format: $DATE_FORMAT
tdd-installed: $TDD_INSTALLED
ubiquitous-language-installed: $UL_INSTALLED
---"
mkdir -p .agents/moonjelly-reef
printf '%s\n' "$CONFIG" > .agents/moonjelly-reef/config.md
```

## 7. Initialize saga

Create the saga directory and bootstrap `world.md`:

```sh
mkdir -p .agents/moonjelly-reef/saga
cp "$SKILL_DIR/world-template.md" .agents/moonjelly-reef/saga/world.md
```

## 8. Confirm

> 🪼 "You're all set. The reef is alive."
>
> Run the `reef-scope` skill to start working on something, or run the `reef-pulse` skill to scan for existing work.
>
> - On Claude Code: `/reef-scope`
> - On Codex: `$reef-scope`
