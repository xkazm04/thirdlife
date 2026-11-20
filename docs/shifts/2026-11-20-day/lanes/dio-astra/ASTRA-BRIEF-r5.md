# dio-astra, round 5 (about 16:40 to 18:15): brief for Astra (a fresh session)

You are the designer and builder of the **dio-astra** arm (the frame and the figure of the toy diorama). I am your
operator (Opus): I run you, measure, verify and pass back measurements. The design is yours.

## Read first
- `docs/shifts/2026-11-20-day/COMMON.md`, `docs/shifts/2026-11-20-day/TEAMS.md` (your scope: "Astra arm" and
  "Team dio" -> dio-astra; selftest block 620-629, 624-629 free).
- The board `docs/shifts/2026-11-20-night/target/4-toy-diorama.jpg`, `target/NOTES.md` section 4.
- This lane's history (all yours): `ASTRA-NOTES.md` (rounds 1-4: far-only lens, `env.exe_aa`, 16x anisotropy per
  viewport, the walking `horizon_resolve`, the low warm key, cream clouds, local-contrast grade, the clay figure's
  finish), `PATCHES.md`, `ASTRA-BRIEF-r3.md`, `ASTRA-BRIEF-r4.md`, `ASTRA-FEEDBACK-i1.md`. Your measurement tools are
  under `.tl/astra-r3/` and `.tl/astra-r4/` (exe walk runner `exe.mjs`, `motion.py`, seeded classic harness
  `.tl/astra-r1/seeded-view.gd`).

## What changed since round 4
Integration 2 (Director, 16:35): this worktree is now `d20-dio` 8968ffe = your r3-r4 (008ee0c) + dio-fable r3-r5
(74208f6: olive flock, tufts, grit, felt dowels, felt-ball bushes, brushed edges, resin mirror) + a `road_rails` port
that stays off until dio-fable names `detail.road_rails` in its section. The class cache is rebuilt.

## The Director's list for this round (16:35), in order
1. **The river bank in `13_lot_river_road` is dark when backlit.** My measurement on your r4 tree (`.tl/v4/dio/13`,
   1920x1080): lower half mean RGB (79,71,14), luma p5/p50/p95 46/60/104; the board's lower half is 59/133/181. The
   sky band in the same frame has luma p50 157.
2. **Cost:** "horizon_resolve and the new light must not push the diorama past 2x classic GPU. I will measure it on a
   quiet machine at the verdict, so keep a switch-off key ready for each pass." So every costly pass (the horizon
   resolve, the local-contrast grade, 16x anisotropy, the sky bake settings, the soft-shadow settings) needs its own
   style key that turns it off, and your notes list them with what each costs as best you can measure.
   GPU figures so far are unreliable on this machine: my windowed tour p50 2.339 ms (joined, i1) and 3.041 ms (your r4
   tree); your tour6 2.778 ms (r3) and 8.315 ms (r4), classic 2.193-2.701 ms in the same sessions.
3. **The figure under the new light.** The Director judges the ginger-orange hair from the close-up after the shots.
   "Bring the clay reading (fingerprint normals, chipped paint at cuffs and boots) closer to the board." Measured: the
   review close-up hair crop (x 730-1000, y 110-330 of `41_figure_closeup`) is mean RGB (161,107,71) on r3 and
   (194,120,70) on r4.

## Machine etiquette (new, from the Director)
**Do not hold the window lock across a whole shot set** (your `group.mjs` wrapper held it for more than 15 minutes
in round 4; my style selftest timed out behind it after 900 s). Take the lock per capture, as `world.sh` and the
selftests do, so other arms' captures can interleave.

## Times
- This round ends at about **18:15** with a clean, working tree, gates green, classic exact (seeded harness, a fresh
  `TL_CACHE_DIR` per side), and a "Round 5" section appended to `ASTRA-NOTES.md`. One more short round may follow.
- Final integration 19:45; I must be ready by 19:30.
- Keep the lane folder light (no mp4 over 10 MB, `clip.mp4` about 8 MB, at most 30 s). Do not write `REPORT.txt`.

## Rules (unchanged; hard)
Work only in this worktree. Read-only git is fine; **do not commit**. Your scope only; in `style_diorama.json` only
your sections (sun, env, fog, sky, clouds, ink, grade, lights, miniature_lens, figure). No `engine/packs/**`,
`engine/seeds/**`, `contracts/**` changes; classic exact; no state hash moves. Do not start an unfiltered
`tl check --tier full`. Never kill a process you did not start. Raw captures under `.tl/astra-r5/`.
Gates I re-run: `node devx/bin/tl.mjs check --tier fast`; `... --tier full --only world,packs,kit.selftest`;
`bash engine/tools/selftest.sh style.` (and `rig.`, `moves.`, `flight.`, `wings`, `character.`).
