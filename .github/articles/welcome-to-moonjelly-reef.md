# Welcome to Moonjelly Reef 🪼

**By Luca Ban** | Apr 28, 2026

## What Is Moonjelly Reef?

Moonjelly Reef is a minimal orchestration system for LLMs. You scope a ticket, run `/reef-pulse` before you go to bed, and wake up to polished PRs waiting for your approval.

That's it. That's the pitch.

## How I Got Here

I had been running Claude Code seriously for a while (multiple tabs, parallel sessions, watching diffs scroll by). It was great. Then I started wanting more: run it overnight, across multiple issues, with QA loops baked in.

So I looked around.

The orchestration systems I found were powerful, but they all asked me to adopt a new operating model: new CLIs, new state stores, new worker taxonomies, new workflow concepts. Some used databases, some used custom runners, some came with dozens of skills or a whole methodology.

I wanted to try something simpler and smaller.

What if the orchestrator was just... a skill?

## What You Wake Up To

Before I explain how it works, let me show you what it feels like when it does.

You run `/reef-pulse` and go to sleep. In the morning, you open your terminal and see something like this:

```
┌─────────────────────────────────────────────────────────────┐
│  🪼 SESSION COMPLETE                                        │
│                                                             │
│  Duration    ~2h15m                                         │
│  Pulses      9                                              │
│  Agents      24  dispatches                                 │
│  To Land     #91  #48  #42                                  │
└─────────────────────────────────────────────────────────────┘
```

For three scoped tasks, 24 agents moved overnight. Work got broken down, worked, verified and QA'd, reworked, leading up to two PRs to land. The more you scope, the longer the reef will stay busy. All to make them pearls (PRs).

You didn't write a single orchestration script. You didn't configure a cluster. You ran one command and went to bed.

That summary is the whole promise of the Reef.

## The Insight That Made It Work

Here's the thing I didn't believe until I tried it.

Every other orchestration framework assumes you need deterministic code to coordinate agents reliably. Something has to track state, sequence steps, recover from failures. So they build that thing: a database, a CLI, a Go binary with a scheduler. It becomes an engineering project in itself.

I thought the same way at first. Then I asked: what if I just didn't?

The whole Reef is a single Claude session. Stateless. It reads labels from your issues, dispatches subagents with markdown instruction files, and exits. That's the orchestrator. No database. No persistent process. No infrastructure to run.

Each subagent starts fresh, reads its phase instructions, does exactly one job, and updates the labels when it's done. The labels _are_ the state machine. GitHub holds everything.

The getting-it-to-work story is messier than the design story.

The POC came together fast. Subagents dispatching, labels moving, issues closing. It all worked in principle embarrassingly early. Then I tried to actually rely on it.

Subagents went sideways. They'd get stuck halfway, interpret instructions charitably in the wrong direction, or quietly do something I never asked for. The main session would hit compaction and not understand what to do next. An agent would introduce a bug, the inspector would miss it, and the rework agent would fix a different thing entirely. The orchestration held; the creatures inside it didn't. The reef got messy fast.

Cleaning up the reef, having the creatures behave: that came through a lot of retooling, not through any cleverness. What I found was **the closer the phase instructions are to shell commands, the better.** Ambiguous prose gives a model room to interpret. Explicit, ordered steps (here is the command, here is what you do with the output) give it nowhere to go but forward. Git operations moved into bash scripts. Instructions tightened. Acceptance criteria got precise. One by one, the places where subagents could improvise got smaller.

After enough of that, the reef stopped getting confused. When something goes wrong now, the fix is always the same: read the phase file, find where it leaves room for interpretation, close the gap.

That's the deal. Not a clever system. A simple and clear one.

## The Three Commands

Moonjelly Reef adds just three skills. That's all you need.

`/reef-scope` is where you sit down with the LLM and work out what you're actually trying to build. It asks questions, one at a time. You answer them, until you and the LLM are completely aligned. By the end, there's a plan with user stories and acceptance criteria that you both understand, and the issue is labeled and handed off to the reef.

`/reef-pulse` is the one you run before bed. It scans your open issues, dispatches a subagent for each one that's ready to move, and recurses until nothing automated is left to do. You don't stay to watch. That's the point.

`/reef-land` is where you come back. The PR is waiting. You read the report, look at the diff, decide if it's right. If it is, you land it. If it isn't, the reef goes back in.

Scope the work. Let it run. Land what you trust.

## A Peek at What Happens in the Reef

Take a dive while the reef is running and you'll see it: creatures orchestrating, bumping into each other, occasionally getting into it. It's a beautiful dance.

You'll see narwhals slicing tasks up 𐃆🐋 into bite sized meals for the octopi. The octopi are the busiest 🐙. Each one in a worktree with all eight arms going at once, looking like master chefs who've been given too much counter space and are absolutely thriving.

Then the barreleye 🧿 shows up and finds the thing the octopus was hoping wasn't there. There is always a thing. The crab 🦀 gets the report, sheds its shell, grows a new one, goes back in. Sometimes they go a couple of rounds.

Somewhere quieter, a coral polyp 🪸 has been sitting on a blocked dependency and is completely unbothered by it.

You rise back up next morning and it's all there, a beautiful pearl (PR).

## What the Reef Deliberately Isn't

**Not a code-based orchestrator.** No CLI to install. No binary to build. No runtime to manage. You install the Reef (add 3 skills) and it runs inside Claude Code, Codex, OpenCode etc. Wherever you can run a skill, you can run the Reef. The infrastructure is: your repo and your issues (local markdown files work too, GitHub isn't required).

**Not a framework of dozens of skills.** One skill. The whole thing is one skill with a handful of phase instruction files. You can read every file in an afternoon and understand the entire system. That's a feature, not a limitation.

**Not a platform with a roadmap.** The Reef does what it does, and that's intentional. The moment I start adding federation, plugin systems, and swarm topologies, it stops being the Reef. Every framework I looked at started simple and grew into something you need a map to navigate. The Reef stays small on purpose. If you need more than the Reef offers, you might want Gas Town, and that's fine.

## Get Started

```sh
npx skills add mesqueeb/moonjelly-reef
```

Run `/reef-scope` first: it walks you through setup, then asks if you want to scope some work. That's really all you need. `/reef-scope` to scope some work, `/reef-pulse` before going to bed. Try to scope at least a couple of tasks, so you can feel the true might of the reef.

The reef is magnificent, the water is warm. Come dive. 🤿
