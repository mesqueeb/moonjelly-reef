---
name: ocean-cleanup
description: Run all 9 quality lenses against every phase and skill file in the Moonjelly Reef. For each lens, dispatches one sub-agent per file in parallel, then advances to the next lens. Use when doing a periodic quality review of the reef's phase files.
internal: true
---

# Reef Review

## Input

```sh
SKILL_DIR="{base directory for this skill}" # e.g. ".agents/skills/ocean-cleanup"
```

## Rules

**Shell blocks are literal commands** — execute them as written.

**AFK skill.** No human interaction. Each lens builds on the edits of the previous one — all files must finish a lens before the next lens begins. No commits. No branch changes.

## 1. Discover files

```sh
FILES=$(find reef-scope reef-pulse reef-land -name "*.md" | sort)
```

## 2. Resume from progress

```sh
PROGRESS_FILE="$SKILL_DIR/.ocean-cleanup-progress"
LAST_COMPLETED_LENS=0  # 0 = no saved progress; overridden below
RESUME_FROM=1          # default; overridden below if progress file exists
```

RUN ONLY IF `"$PROGRESS_FILE"` exists:

```sh
LAST_COMPLETED_LENS=$(cat "$PROGRESS_FILE")
RESUME_FROM=$((LAST_COMPLETED_LENS + 1))
echo "🚢 Resuming ocean-cleanup from lens $RESUME_FROM."
```

## 3. Run lenses

Read `$SKILL_DIR/lenses.md`.

```sh
LENS_NR=$RESUME_FROM
```

Repeat while `$LENS_NR` ≤ 9:

```sh
LENS_PROMPT="{full text of the Lens $LENS_NR section from $SKILL_DIR/lenses.md}" # e.g. "Review this file against UBIQUITOUS_LANGUAGE.md and flag any misuse, drift, or missing canonical terms."
```

Dispatch one sub-agent per `$FILE` in `$FILES` in parallel. Each sub-agent receives:

```
Read WRITING_STYLE_GUIDE.md, UBIQUITOUS_LANGUAGE.md, and README.md (for the state machine).
Then read $FILE.
Then apply this review lens:

$LENS_PROMPT

Edit the file directly to fix any issues you find. Use your best judgment.
Do not commit. Do not change branches.
```

**Wait for all sub-agents to complete before advancing.**

## 4. Advance lens

```sh
echo "$LENS_NR" > "$PROGRESS_FILE"
LENS_NR=$((LENS_NR + 1))
```

After `$LENS_NR` > 8:

```sh
rm "$PROGRESS_FILE"
```
