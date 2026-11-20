# cel-astra, round 1 brief (20 Nov 2026, day shift; for GPT 6.2 Astra)

You are the designer and builder of arm **cel-astra** (team cel, "crisp cel"). An Opus operator runs you, measures your
work, re-runs every gate and looks at every still. Your claims are checked; measured figures beat adjectives.

Worktree (work only here): `C:/Users/kazda/kiro/third-life/.claude/worktrees/d20-cel-astra`, branch `d20-cel-astra`.
Read-only git is fine; **do not commit**, do not run any git that writes. Never kill a process you did not start
(four arms and a Director share this machine and run Godot and Codex).

## Read first, in full
1. `docs/shifts/2026-11-20-day/COMMON.md`: the owner's words, the hard rules, sharpness, the shot set, the gates.
2. `docs/shifts/2026-11-20-day/TEAMS.md`: your scope is "Astra arm: the frame and the figure" and, under
   "Team cel", the cel-astra list.
3. The board you work toward: `docs/shifts/2026-11-20-night/target/2-crisp-cel.jpg` (look at it), and its rules in
   `docs/shifts/2026-11-20-night/target/NOTES.md` section 2.
4. For orientation in this code (last night's Astra arms on the diorama look; same code base, behind style keys):
   `docs/shifts/2026-11-20-night/lanes/frame-astra/ASTRA-NOTES.md` and `REPORT.txt`,
   `docs/shifts/2026-11-20-night/lanes/character-astra/ASTRA-NOTES.md` and `REPORT.txt`.

## The owner's words, verbatim (20 Nov, 10:20)
"hard to decide. Diorama looks better on first sight, but graphics seems blurry and quality/fidelity far below the art
concept. The original game does not look very good now, but there is clear the potential is there to evolve to create
beuatiful and sustainable world. Lets use this day still to work in parallel. 2 builders on Evolving crisp cell, 2
builders on diorama to see if we can improve the graphics quality further. Again 1 Astra + 1 Fable in team. No need to
focus on full game, the focus should be the world (surface, sky, nature) and the character. I would like to see from
both glimpses of full potential which would help me decide. Lets use 10 hours of time, and loop to perfect both
variants to use the time fully"
Also (10:10): "for Character the Opus + Astra looked better" than Fable's.

## Your look and its switch
- Style file `engine/style/style_crisp.json` (at the start an exact copy of today's `style.json`); run with
  `TL_STYLE=crisp`. `TL_STYLE=classic` must keep rendering exactly as today (within 1/255).
- Every diorama feature of last night is behind keys of `style_diorama.json` (seamless sky, contact shade, clay figure,
  lens, ...). You may switch any of them on for crisp when it serves crisp cel, adapt them, or build your own.
- Your partner arm **cel-fable** (Fable, separate worktree) owns surfaces and nature: `toon.gdshader`, water, the
  palette/mat/detail/water/toon/terrain/nature sections, the `material()` part of `tl_style.gd`, terrain, trees, kit.
  Do not edit those. Note: the band thresholds of today's light (`band_hi`, `band_lo`, `band_soft`, `wrap`) and the
  shade colour live in the `toon` section and are applied in `toon.gdshader`, both your partner's, while the board's
  two-to-three band light with a crisp boundary is on your list. Get it through what you own (sun, env, lights, ink,
  grade, new post/outline/shader files, new keys in your sections), or, when a change in the partner's files is truly
  needed, write the exact patch (file, keys, values, why) into
  `docs/shifts/2026-11-20-day/lanes/cel-astra/PATCHES.md`; the Director passes it on at integration.
- `tl_style.gd` is held to 600 lines by `tl arch` (595 today): put new code in your own new file
  (e.g. `engine/style/cel/*.gd`) and call it from the `install()` part.
- Your selftest block is **600-609**: new cases go in `engine/tools/selftest.d/60N-<name>.sh`.

## Shots and measurements
- The lane's shot script (my copy of the COMMON.md set):
  `bash docs/shifts/2026-11-20-day/lanes/cel-astra/shotset.sh crisp <abs out dir under .tl/>`
  (`ONLY="headless"` for parkour f520, hockey f1500 and the figure back/front close-ups without a window;
  `ONLY="tour"`, `"flight"`, `"road"` for the windowed parts; `51_road_visitor` is the frame that stands beside the
  board). Windowed runs wait for one machine-wide window lock shared by five sessions: iterate headless
  (`engine/tools/tl.sh capture`, `engine/tools/look.sh clip rig:...`) and take windowed shots sparingly.
- Round-0 stills (today's look, from a pristine copy of the base) are landing in `.tl/r0/classic/` while you read;
  crisp equals classic at the start. My measurements of them follow in the next round.
- The owner's first complaint about the other look was "blurry": keep the picture crisp at 1920x1080 (render scale 1.0,
  clean edges, unsmeared textures, no lens blur needed for cel). I measure sharpness as the variance of a Laplacian over
  fixed crops of the same shots, before and after.

## The round
Round 1 runs about 90 minutes: please be done by **12:05** with a working tree. Pick the biggest gaps between the
current crisp stills and the board on your list (bands and the warm/plum light, contours, sky and clouds, the figure,
sharpness), build, take your own shots, compare with the board, iterate.

When you finish the round, write `docs/shifts/2026-11-20-day/lanes/cel-astra/ASTRA-NOTES.md`: what you built and why
it moves toward the board, every new key and its file, your own measurements, the selftests you ran with their lines,
and what you would do next. Keep `PATCHES.md` for anything your partner's scope needs. Then stop; I verify and resume
you with measurements.

Gates I will run on your tree (you may run them too; they take long, so run the fast ones):
`node devx/bin/tl.mjs check --tier fast`; `node devx/bin/tl.mjs check --tier full --only world,packs,kit.selftest`;
`bash engine/tools/selftest.sh style.`; `bash engine/tools/selftest.sh rig.`; your 60N cases. Figure rails (TEAMS.md):
`TLBiped.create` unchanged, clip and bone names kept, `metrics()` height 2.0 radius 0.3, at most 12k tris and 30 bones,
hockey skaters / parkour runner / village walker / summoned wings still work, `rig.`, `moves.`, `flight.`, `wings`,
`character.` selftests pass.
