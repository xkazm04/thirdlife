# Verdict: day shift 27 Nov 2026 (Home sandbox: research + M6 "rules and runs")


Page: https://claude.ai/artifact/Y3yj7UtQ65PrTaCUJvp7hA
Owner away 24 h ("master the sandbox engine, deep research Minecraft/Roblox ... where can outshine those two ...
balanced level of freedom"). Every decision below marked **Director (owner away)** is yours to overturn.

## In one paragraph
The research (4 lines: Minecraft + Hytale, Roblox, smart builders + AI-first creation, our own engine) agreed on one
thing: a build that nobody needs gets about an hour. The thesis (docs/research/sandbox/THESIS.md) is **"Build it, say
what it does, play it"**, with freedom **free in the large, guided in the small**. Today built that: zones and rules
as a new layer of the same edit log (by hand with a Rules tool, by sentence with the LLM), runs with a clock, coins,
checkpoints, a finish card and a best-time ghost, three starter courses, day and night with lamps, a share code
(TL1-...) for any stamp, and assemblies (wall, tower, house, stair, bridge, platform) that the LLM now picks instead
of placing cells one by one. A newcomer playtest ranked 10 frictions: 7 are fixed (pad hop, where to build, hotbar clicks, presets on sloped
ground, refusals you can see, E prompts and hazard stripes, lamps), Tower climb was reshaped around the weak jump,
and 2 are open (the 2-high doorway and the jump itself; aiming from the walker's camera).

## What to play (10 minutes)
1. `dist/PLAY-LATEST.cmd` -> World. You arrive on the village road.
2. **B** opens building. The red line over the tabs points where land is free (the village keeps 350 m round it).
3. **Stamps** (tab), 1-3: Tower climb, Pad hop, Garden gate. Place one on the grass, **B** again to leave, walk onto
   the start. The run clock starts; coins, the finish flag, confetti, "New best!". Run it again: the ghost of your best
   runs ahead.
4. **Rules** tab: presets (start, checkpoint, finish, coin, door, jump pad, hazard, message). A card reads your rules
   back as sentences. Doors open on **E** (a key cap tells you), hazards show red stripes.
5. **N** steps the clock (day, dusk, night); **H** holds it. At night the street lamps and windows light.
6. **Ctrl+C** on a stamp copies a share code; **Ctrl+V** in another Home pastes it whole.
7. **Shapes** tab: the assemblies by hand (wall, tower, house, stair, bridge, platform).
8. With a model: the command bar, e.g. "a watchtower by the pond with a ladder" or "a bridge over the water". You get a
   ghost and a note first; **Enter** keeps it, **Ctrl+Z** takes it all back.

## Figures (real Opus calls, claude-opus-5-5)
| Ask | Before (cells) | After (assemble) |
|---|---|---|
| a tower | 106 s, 41.8k in / 11.6k out | 31.6 s, 11 ops |
| a watchtower | | 11.4 s, 2 ops, 17.2k / 0.8k |
| a house with windows | | 15.0 s |
| a bridge over the pond | | 32.2 s, clears the water |
| a garden maze with a gate on E and a coin (playtest) | | 76.5 s, 274 ops, played to the coin |

Landed: main cafb68de, pushed to origin at 19:01 (0 ahead, 0 behind). Exe: dist/ThirdLife built from cafb68de
(tag "cafb68d 2026-11-27 19:02"), `export.sh check` PASS, and the Rules tool opens in the exe (exe-rules.png).
Update 28 Nov 06:13: the juice session rebuilt dist/ThirdLife from main 6906574 (it contains M6), export.sh check PASS; `dist/PLAY-LATEST.cmd` starts that build.

Gate on the merged tree (23be5789, main merged in): `tl check --tier full` 11 of 13 PASS (arch, assets, cards,
devx.test 230/230, foreman typecheck + 503/503, kit 122/122, seeds 39/39, item 91/91, ui 219/219, world 9/9 = alone).
The two reds: kernel.selftest hit the gate's 1800 s cap (judged by the uncapped run: **809 of 812**), and packs 3/4
(hockey invariants.many_budget). The uncapped run's 3 reds and hockey are all red on main too: A/B at the same time,
the same load: hockey p50 1.329 ms on M6 vs 1.326 ms on main (budget 1.0), feel.pushbox_invariants fails on both,
base.lines x2 known red on main. k2.down_invariants failed once under the gate and passed in the uncapped run.

## What is NOT done (named so it is not a surprise)
- **A doorway two blocks high still stops the walker** (playtest #1) and a walking jump tops out at 0.87 m, so one
  block is not a sure hop (#5). Lane F1 found the cause and proved it on probe doors 24/24 but stalled before tests;
  its work is on branch `d27-f1` (c84f4f50), **not landed**. Until it lands, Tower climb uses 0.5 m plank steps and
  the LLM's 2-high doors need a 3-high hole to walk through. First thing for the next shift.
- Aiming from the walker's camera (a block hides 6 m behind it; labels pile up in a row) is unchanged: **F** (fly) is
  the way round it today. Blocks built on the spawn point still bury you on the next visit (B, then RMB, gets you out).
- No second playtest on the merged tree (disk ran out at 9 GB mid-afternoon, from another project; time went to the
  gate). The fixes were each checked by their lane in a window, not by a fresh newcomer pass.

## Decisions taken for you (Director, owner away)
- Rules are a fixed vocabulary (when / if / do), no code language. `if` holds at most 8 conditions.
- Start, finish and count triggers fire on the next frame; a taken coin fires nothing; stepping off the start and back
  within 1 s does not restart the run.
- Feet read a zone up to 0.3 m above the soles (so a door drawn on blocks over sunk ground still opens).
- The street lamp is now open from the start (it was "play any dungeon 3 times"): night needs lamps on day one.
- The LLM gets assemblies first in its prompt; it falls back to cells for anything else.

## Asks for you
1. Land F1 (2-high doorways, the sure 1-block hop)? Then Tower climb goes back to 1 m steps.
2. Keep the street lamp free, or gate it again once a newcomer has other lights?
3. `layers.ground_refused` in the ask's reply: keep, or drop (A lane's Q-A9)?
4. A door sunk into a slope opens its foundation cell with it (F2 Q2): accept, or keep the foundation?
5. Run names are shared across pasted courses (two pasted "Run 1" share one best time): rename on paste?
6. Still open from before: steppable pieces, "best 0" on the results card, a polygonal shore.
7. Another project's session (gtai) filled the disk twice today; it now deletes its AVIs once encoded.

## Route scoreboard
| Lane | Route | Held? |
|---|---|---|
| R research (4 lines) | Opus agents, web + repo | yes: THESIS.md |
| S6 seam | Opus | yes |
| T6 rules tool | Opus | yes |
| P6 play (runs, ghost, card) | Opus | yes |
| C6 LLM (zones, rules, fix) | Opus | yes |
| DN day and night | Opus | yes |
| LP look (shore, paths, growth) | Opus | stalled 3 h, resumed from RESUME.md, landed |
| A6 assemblies | Opus | yes |
| Q6 playtest | Fable | yes: 10 frictions |
| F1 walker | Opus | stalled 2 h: not landed |
| F2 build fixes | Opus | yes |
| F3 play fixes | Opus | yes |
