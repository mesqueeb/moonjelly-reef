---
name: ocean-cleanup
description: Run all 9 quality lenses against every phase and skill file in the Moonjelly Reef. For each lens, dispatches one sub-agent per file in parallel, then advances to the next lens. Use when doing a periodic quality review of the reef's phase files.
---

# Reef Review

**AFK skill.** Iterates through 9 review lenses. For each lens, all files are improved in parallel. Each lens builds on the edits of the previous one, so all files must finish a lens before the next lens begins.

**No commits. No branch changes.** Sub-agents edit files in place and return. That is all.

## Input

```sh
SKILL_DIR="{base directory for this skill}" # e.g. ".agents/skills/reef-review"
```

## Files under review

```sh
FILES=$(find reef-scope reef-pulse reef-land -name "*.md" | sort)
```

## Execution

Read `$SKILL_DIR/lenses.md`. For each lens (1 through 9), in order:

1. Dispatch one sub-agent per file in parallel. Each sub-agent receives:

   ```
   Read WRITING_STYLE_GUIDE.md, UBIQUITOUS_LANGUAGE.md, and README.md (for the state machine).
   Then read {FILE}.
   Then apply this review lens:

   {LENS_PROMPT}

   Edit the file directly to fix any issues you find. Use your best judgment.
   Do not commit. Do not change branches.
   ```

2. **Wait for all sub-agents to complete before advancing to the next lens.**
