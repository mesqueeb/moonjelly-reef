# Lore writer

## Input

```sh
SENTENCE_BALLPARK="{approximate sentence count to aim for}" # e.g. 8
```

## 0. Fetch context

Read:

- `.agents/moonjelly-reef/saga/world.md` — current reef setting, active characters, and ongoing threads
- The most recent `chapter-NNN.md` in `.agents/moonjelly-reef/saga/` (if one exists) — for the prior chapter's context and continuity

```sh
CHAPTER_NR="{next sequential chapter number}" # e.g. 4
CHAPTER_FILE=".agents/moonjelly-reef/saga/chapter-$(printf '%03d' $CHAPTER_NR).md"
```

## 1. Write the chapter

```sh
CHAPTER="{the next chapter of the ongoing saga}" # e.g. "Pip the mantis shrimp found the broken sensor before anyone else noticed..."
```

### Chapter rules

- Choose one character as the clear center of the chapter
- Give unnamed but prominent characters fun names
- Allow for dialog between characters to exist
- Give that character a small want, worry, task, mistake, or decision that shapes the chapter
- Give the character a small arc: show what they want or resist, put that under pressure, then let something shift by the end
- Make the central character do something specific on the page
- Include at least one short line of dialogue unless there is a strong reason not to
- Make the chapter actually go somewhere
- Make something happen that changes the situation, not just the mood
- By the end, the character should have said, done, chosen, found, broken, fixed, admitted, or refused something
- Let specific characters carry the scene so the reader can follow who is doing or feeling what
- Let at least one moment land concretely enough that a reader could picture it
- Write only as things happening in the reef

### World-building rules

- Respect established character personalities; let them grow, not reset
- Carry forward what already matters in the reef instead of starting from scratch
- Keep imagery clear enough to picture — strange is welcome, incoherent is not
- Focus on a small handful of characters; let the rest stay offscreen
- Supporting characters should react to the central character, not compete with them for attention

### Anti-patterns

- Do not reduce characters to their function — they have moods, wants, and relationships
- Do not dress up a dry summary with poetic language
- Do not make the prose so stoic, distant, or reverent that the reader loses track of who matters
- Do not rely on vague signs, silent realizations, or mysterious objects as the whole event
- Do not make every character wordless, solemn, or cryptic
- Do not cram the full cast into one chapter

### Preferred feel

- Prefer warmth and clarity over solemn, mystical prose
- Let characters tease, protest, reassure, confess, or misread each other a little
- If something magical or strange appears, make sure a character does something specific in response
- A reader should be able to answer: who was this about, what happened, and what changed for them

## 2. Save

Persist to disk:

1. Write the chapter to `$CHAPTER_FILE`. If the write fails, skip world.md updates and proceed directly to the handoff — the chapter is still in memory and must still be returned.

2. Update `.agents/moonjelly-reef/saga/world.md` when something changed in a lasting way:

- If a character has shifted in a meaningful, persistent way, update `## Active characters`
- Update `## Ongoing threads` to reflect what is still quietly in motion after this session

## 3. Handoff

Return exactly:

```
CHAPTER: $CHAPTER
```

If `$CHAPTER` is empty (chapter could not be produced), return:

```
CHAPTER: (lore writer could not produce a chapter this session)
```
