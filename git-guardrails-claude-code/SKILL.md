---
name: git-guardrails-claude-code
description: Set up Claude Code hooks to block dangerous git commands (force push, reset --hard, clean, force-delete branches, etc.) before they execute, while still allowing safe everyday operations like pushing work branches from worktrees and cleaning up branches whose remote was deleted. Use when user wants to prevent destructive git operations, add git safety hooks, or block dangerous git in Claude Code.
---

# Setup Git Guardrails

Sets up a PreToolUse hook that intercepts and blocks dangerous git commands before Claude executes them — without getting in the way of normal work-branch workflows.

## What Gets Blocked

**Always blocked, everywhere:**

- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git checkout .` / `git restore .`
- `git push --force` / `git push -f`

**Context-aware:**

- `git push` — if at least one worktree exists, pushing from the main checkout is blocked (agents are kept in their worktree lane). With no worktrees around, push is allowed (force-push is covered separately above).
- `git branch -D <name>` — only allowed when the named branch's upstream is `[gone]` on the remote. Also recognizes the safe pipe pattern `git branch -v | grep ...gone... | xargs git branch -D` for cleaning up multiple stale branches at once. Force-deleting an active branch by name stays blocked.

When blocked, Claude sees a message telling it that it does not have authority to access these commands.

## Steps

### 1. Ask scope

Ask the user: install for **this project only** (`.claude/settings.json`) or **all projects** (`~/.claude/settings.json`)?

### 2. Copy the hook script

The bundled script is at: [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh)

Copy it to the target location based on scope:

- **Project**: `.claude/hooks/block-dangerous-git.sh`
- **Global**: `~/.claude/hooks/block-dangerous-git.sh`

Make it executable with `chmod +x`.

### 3. Add hook to settings

Add to the appropriate settings file:

**Project** (`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

**Global** (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

If the settings file already exists, merge the hook into existing `hooks.PreToolUse` array — don't overwrite other settings.

### 4. Ask about customization

Ask if user wants to add or remove any patterns from the blocked list. Edit the copied script accordingly.

### 5. Verify

Run a few quick tests:

```bash
# Should be BLOCKED (exit 2)
echo '{"tool_input":{"command":"git reset --hard HEAD~1"}}' | <path-to-script>
echo '{"tool_input":{"command":"git push --force"}}' | <path-to-script>

# Should be ALLOWED (exit 0) — no worktrees in play
echo '{"tool_input":{"command":"git push -u origin my-feature"}}' | <path-to-script>

# Should be BLOCKED (exit 2) — run from the main checkout when a worktree exists
echo '{"tool_input":{"command":"git push -u origin my-feature"}}' | <path-to-script>
```

The blocked commands exit with code 2 and print a `BLOCKED:` message to stderr.
