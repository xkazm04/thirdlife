# P3: the look, second pass, with motion

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. Last night the kernel learned to hold many packs in one process, each in its own physics space and on its own
clock; a scheduler gives each pack ticks by tier (stage, sideline, backdrop, ledger); a drawing layer shows every pack
at its plot; a village landscape and a walking visitor exist; a real job built a hockey game from one sentence. The
owner now spends a day and a night on **perfecting the core before content spreads it**: every engine change gets more
expensive with each game built. You own one of four packages of round 1.

## Why this package exists
The owner's target for the look is the level of the concept image (`spike/lab/ref/B_toon_ink.png`), reached with no
generative model: shader, light, palette, geometry made in code, animation, camera. Last night's first pass moved the
Director's score from about 2 to 3 to 3.5 out of 5 (`docs/reports/N1-LOOK.md`): colour 4, lines 3.5, scale 3.5,
ground 3, light 3. The graphics card is not a limit: a village of six games costs 1.2 ms of GPU time a frame at
1080p. What is still weaker than the concept, in the Director's reading: line weight at middle distance; a plainly
low-poly sky, clouds and far cliffs; characters without faces, with plain proportions and no props; one lime tone of
grass. And nothing in motion has ever been judged: animation, camera easing, shake, effects exist and nobody has
watched them.

## Read first
1. Look before reading: the concept `spike/lab/ref/B_toon_ink.png`;
   `C:\Users\kazda\kiro\third-life\engine\look\sheet_before_after.png` (last night's sheet, in the main
   checkout only); `docs/reports/img/n7_village_vs_concept.jpg`, `n7_visitor_at_track.jpg`,
   `job3_hockey_after_change.jpg`, `n1_wall_after.jpg`, `n1_drive_after.jpg`.
2. `docs/reports/N1-LOOK.md` (the builder's "still weaker" list and the Director's), `engine/style/STYLE.md`,
   `engine/rigs/RIGS.md`, `engine/look/JOURNAL.md`, `engine/tools/look.sh`.
3. `spike/lab/b/REPORT-PASS4.md` lines 200 to 227: the art lane had a face with eyes, a smile and a blink on its
   avatar; find out what of that reached `engine/rigs/`.

## Scope
Yours: `engine/style/**`, `engine/rigs/**`, `engine/kits/**` except `tl_kit_terrain.gd` and the nature parts
(another builder shapes the land today), `engine/look/**`, `engine/tools/look.sh`, the three camera files
`engine/kernel/api/tl_cameras.gd`, `tl_chase_cam.gd`, `tl_orbit_cam.gd` (smoothing and framing only; the mouse code
stays as it is), camera data and camera lines in `engine/seeds/**`. Not yours: every other kernel file,
`engine/kernel/world/**` (the world's landscape, mesas and visitor belong to another builder), `engine/tools/tl.sh`.
The draw layer's three shader parameters (`tl_plot`, `tl_clip`, `tl_holes` in `toon.gdshader` and `tl_plot` in the
other style shaders) must keep working: `bash engine/tools/view.sh check ...` is your proof.

## The work, in this order
1. **A way to judge motion.** `look.sh clip <what> <out.mp4>`: a few seconds of a seed played by its bot, of the
   village tour, of the hockey pack, written with the engine's movie writer and turned into an mp4 and into a strip of
   frames (ffmpeg is installed) that you look at. Then watch, in this order: the biped walking and skating, the car,
   the chase and orbit cameras, shake, the effect presets, grass and smoke. Write down what is wrong before fixing.
2. **Characters.** Faces (eyes, a mouth, a blink), proportions closer to the concept's (larger head and hands, a
   readable silhouette at 100 pixels), team colours that read, one or two props a rig can hold (a hockey stick: the
   hockey game has none that reads). The rig's metrics and the timing of clips do not change: a seed's state hash
   must not move.
3. **Motion fixes** from item 1: foot slide, stiff turns, camera lag or jitter, effects that pop. Visual only.
4. **Lines at middle distance.** Outlines on objects 30 to 120 m away are still thinner than the concept's; thin
   members get one dark side instead of an even outline.
5. **Sky and far scenery.** Clouds with soft drawn forms instead of streaks; far cliffs and mesas with drawn strata
   and tree lines (the style and kit side: the material and the part; where they stand is the world builder's);
   a sky that is less magenta and closer to the concept's warm evening.
6. **Grass and ground tone.** More than one tone, soft patches, without the angular mottle seen from above.
7. If time remains: light. A warm bounce and a cool rim that make shapes turn, checked on the hero and the village.

## Acceptance (the Director will run these and look)
- No seed's state hash changes (smoke hashes begin `bc93a9a4` paddle, `b9adbb19` drive, `da4bdc3f` wall), and
  `bash engine/tools/view.sh check --packs=seed_drive,seed_paddle,seed_wall,ex_kit,ex_walker --at=0:0:0,110:0:0,-110:0:0,0:0:105,0:0:-100 --radius=64,40,38,40,30 --stage=1 --cam=court`
  passes.
- `engine/look/p3/`: before and after stills of the same shots as last night plus the village and the hockey
  arena; before and after clips of walking, skating, driving and one camera move; a sheet beside the concept.
  Everything looked at by you.
- A rubric table before and after: lines, colour, scale, ground, light, sky and far scenery, characters, motion,
  "shipped indie game". Be hard on yourself; the Director scores the same material.
- Frame cost before and after (`bash engine/tools/k.sh stats`, and GPU time if you can measure it honestly).
- `node devx/bin/tl.mjs check --tier full` green in your worktree.

## The repository's laws (verbatim from `CLAUDE.md`; they bind you)

## Laws that bite (details in the contracts)

- **Time is physics frames** (60 Hz). Tests, bots, captures, watchdogs count frames, never wall clock.
- **Determinism**: same pack + seed + frames = same `state_hash`. Randomness only from the kernel's seeded generator.
- **Unknown keys are errors** in every JSON schema. **Absent value = omit the key** (never `null`, never `0`).
- **Lists, not singletons** for anything a game may have more than one of.
- **Class names**: `TL*` belongs to the kernel except `TLKit`, `TLRig`, `TLStyle`, `TLMesh` (kit/rigs/style). Packs never declare `class_name`.
- **Packs use only the `TL*` API.** No hand-made materials, lights, environments (the runner counts them as bypasses). Look in `engine/kits/KIT.md` before making a mesh.
- **kit, rigs, style reference nothing outside themselves.**
- **Reuse before building**: kit part, seed pack, `engine/kernel/API.md` (generated index: `docs/generated/API-INDEX.md`).
- Windows 11 + Git Bash. Godot console exe via `TL_GODOT` or `.tl/local.json` (`tl doctor` says what it found). Other sessions load this machine: never kill a process you did not start; prefer `--headless`.

## How to work
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p3`** (branch `core-p3-look2`, cut from `main` this morning). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree).
- **No git command of any kind.** The Director stages and commits your files. The `tl` tool may call git for you;
  that is fine. Do not run git yourself, and make sure no test of yours runs git against anything but a temporary
  repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Three other builders and other sessions run Godot on this machine today: a failure that is only a
  time limit is re-run alone before you believe it, and you say which figures were taken under load.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`;
  an orphan window there slowed every later capture for 43 minutes last night). No network. No model calls. Never
  read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``engine/look/JOURNAL.md` under a "P3" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report, do not edit them.
- For anything outside your file scope, write the exact patch and its reason to ``engine/look/PATCHES-P3.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; do not guess and do not tune a fix that makes the measured result worse: withdraw it and say so.

## Final message (your report, as text; the Director saves it to a file)
Status; per item what you built and the command, figure or picture that proves it (full paths); the acceptance
checks one by one with their result; the list of files changed with a line each; proposed contract text; the contents
of your patches file; what changed for a pack author; what you did not verify; questions; minutes spent from real
timestamps (`date`).

## Time-box
Until the list is done or **110 minutes after your start** (run `date` first and often). The first items proven
are worth more than all of them half done. Leave the last fifteen minutes for the full gate and the report. A usage
limit can cut you off without warning: keep the journal current, and if you are resumed, re-read this brief and your
journal and continue.
