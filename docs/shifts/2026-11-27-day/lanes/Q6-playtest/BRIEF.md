# Lane Q: a newcomer plays the Home sandbox (M6 merged), read-only

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-play` (detached at the integration tip a8a98d50 of branch d27-m6). Fable (eye and design judgement). Time box ~2.5 h. **No code edits**: this lane plays, looks and reports. Captures and notes go in `docs/shifts/2026-11-27-day/lanes/Q6-playtest/` in your worktree (JPG < 400 KB, clips ≤ 30 s); raw frames under `.tl/`.

## Why
The owner (away 24 h) asked to "master the sandbox engine ... where can outshine [Minecraft, Roblox] ... balanced level of freedom ... our graphics and LLM builder". The thesis (`docs/research/sandbox/THESIS.md`): **build it, say what it does, play it**. Five lanes built M6 today (rules and runs, the Rules tool, the LLM rules with a space check, play with a HUD and a ghost, courses as share codes, starter courses, day and night, the look polish). Each lane proved its own part. Nobody has played the whole as a person meets it. Memory rules this repo lives by: "his hand is the bar" (reproduce as a person meets it before calling anything fixed); "behaviour is the core" (judge what a hand and the world give back); "mimic proven design" (compare with what made Minecraft/Roblox/Fortnite Creative/Tiny Glade loved: `docs/research/sandbox/R1-R3`).

## Play (in a window: the editor binary on `res://boot/boot.tscn`, as lanes did; `node devx/bin/tl.mjs doctor` names Godot; drive input with the test hooks the lanes used if you cannot type, but say so)
1. Enter the World, find the Home, press B. Try every tool once without reading BUILD.md first (then read it): what is obvious, what is hidden?
2. Place the three starter courses (stamp tool, Starters page) and play each run: start, coins, doors (E), pads, checkpoints, hazards, finish card, a second run with the ghost.
3. Make your own small course with the Rules tool presets around a few blocks.
4. One real LLM ask (the command bar, Enter): "a garden maze with a gate that opens when I press E and a coin in the middle" — report duration and what it built; play it. (One call only.)
5. Copy a course's share code (Ctrl+C in the stamp tool), paste it (Ctrl+V), place it.
6. Night: N in build mode to night, look at lamps, stars, the moon; play a run at night.

## Report (REPORT.txt + a final message)
- A storyboard: 10-16 stills in the order a person meets them, each with one line (works / friction / bug).
- The ten biggest frictions or bugs, ranked by how much a newcomer would mind, each with the exact repro.
- A plain verdict per thesis claim: does building look good without effort? does a build do something without code? does the LLM build what was asked? is playing it fun for a minute? does night make you want to build lamps?
- Against the research: three things Minecraft/Roblox/Fortnite Creative do that a newcomer here will miss first.
- Gates: none required (read-only). Standups in `STANDUP.md` stamped from `date +%H:%M`, at least every 45 min; no tool call over 20 min.
