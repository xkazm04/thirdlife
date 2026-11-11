# P6: what a far game shows, and the land at a distance

You are a builder on **Third Life**: a single-player sandbox on Godot 4.7.2 (Jolt physics, 60 Hz fixed tick) in which
an LLM builds small games ("packs") over a law kernel, and the games all keep running in one world a visitor walks
through. The owner spends this day and night on **perfecting the core before content spreads it**: every engine change
gets more expensive with each game built. Round 1 landed today: limits that count processor time and a performance
ledger (`docs/PERF.md`, `docs/reports/P1-MEASURE.md`); one contact pass per pack instead of a script per body
(`docs/reports/P2-HOTPATH.md`); a second pass on the look with characters, sky and motion (`docs/reports/P3-LOOK2.md`);
land with relief, plots as terraces and a visitor with a body (`docs/reports/P4-RELIEF.md`). You own one of five
packages of round 2. The night ends with a Windows executable built from the merged result, so leave your part green.

## Why this package exists
The owner's ruling this morning: "we don't need to display full game from distance. We need to learn what to abstract
and hide from distance without destroying the view." Today a game has two pictures: all of it, or one merged still
mesh with every moving part, light and small object dropped (`engine/kernel/world/draw/DRAW.md`). Nobody decided what
a far game should say about itself. And from a height the village is still far from the concept
(`docs/reports/img/p4_vs_concept.jpg`): pads read as discs, the far half washes out in haze, mesas float on a plain,
the picture is sparse where the concept (`spike/lab/ref/B_toon_ink.png`) is dense. This package is a study with
pictures first and code second.

## Read first
1. Look first: the concept; `docs/reports/img/p4_vs_concept.jpg`, `p4_bridge.jpg`, `p3_sheet_concept.jpg`,
   `n7_village_overview.jpg`, `world_12_packs.jpg`.
2. `engine/kernel/world/WORLD.md` (the owner's rulings at its head), `draw/DRAW.md` (sections on the stand-in and on
   what does not move with a pack), `docs/reports/N5B-DRAW.md`, `docs/reports/P4-RELIEF.md` ("still wrong"),
   `engine/look/PATCHES-P3.md` (entry 4), `docs/reports/P3-LOOK2.md`.
3. `engine/kernel/world/draw/draw.gd`, `landscape.gd`, `terrain/**`, `tiers.json`, `engine/tools/view.sh`,
   `engine/tools/world.sh`.

## Scope
Yours: `engine/kernel/world/draw/draw.gd`, `draw/DRAW.md`, new files under `engine/kernel/world/draw/`,
`engine/kernel/world/landscape.gd`, `terrain/**`, `visitor.gd` (camera only), `engine/kits/**` (lower-detail variants
of parts; no change to a part's full form), `engine/style/**` (distance rules only: how lines, haze and tone behave
with distance; the draw layer's `tl_plot`, `tl_clip`, `tl_holes` parameters keep working),
`engine/kernel/world/captures/p6/**`. Not yours: `engine/kernel/world/world.gd`, `pack.gd`, `tiers.gd`, `draw/view.gd`
(the loading builder: if you need a hook there, write the patch), `engine/kernel/api/**`, `engine/rigs/**`.
Simulation is never touched: `bash engine/tools/view.sh check ...` and `bash engine/tools/world.sh tour tour --headless`
pass after your work.

## The work, in this order
1. **The study.** For three games (the track, the paddle court with its stand, the hockey arena) take paired pictures
   from the visitor's eye and from a rise at 50, 150, 300 and 600 m: full game against today's stand-in. For each
   distance write down, as a table in `draw/FAR.md`: what a viewer can still read (the kind of place, that something
   is happening there, who is winning), what is noise (wire, small props, texture detail, thin lines that shimmer),
   and what is missed when it is dropped (moving actors, the scoreboard, lights, smoke, flags). The table is the
   deliverable the owner asked for; make it concrete.
2. **Three pictures of a game instead of two.** From the table: (a) near: all of it; (b) middle: the venue's large
   forms in lower detail, clutter gone, plus signs of life drawn cheaply (actors as simple moving marks updated on the
   pack's own ticks, a scoreboard that still shows the score, a few lights, smoke); (c) far: a silhouette that still
   says what kind of place it is. Thresholds with margins in `tiers.json` are the loading builder's file: propose the
   numbers, and read them through whatever exists. A far game is still alive (it ticks slower, never off): its
   picture should move a little.
3. **Lines, haze and tone with distance.** No shimmer of thin lines on far things; a venue 300 m away still reads
   through the haze; far things simplify toward flat shapes with one outline, as a drawn background would.
4. **The land at a distance.** The pads read as places, not discs (irregular outline, a wall or rock edge on one
   side, a road arriving); tree lines on ridges and along mesa rims; the far plain and the mesas joined to the
   village's land instead of floating; the world's own ground patches soft instead of angular; density where the
   eye goes (between venues along the road) and calm elsewhere. The village may become more compact if plots allow.
5. **Cost.** Draw calls, primitives and GPU time per tier for 6, 12 and 30 games, before and after, through the
   ledger where a scenario exists.
6. **The pictures**, under `engine/kernel/world/captures/p6/`, each looked at: the paired distance sheets of item 1
   again with the new middle and far pictures; the overview beside the concept; one eye-level frame with a near, a
   middle and a far game in view.

## Acceptance (the Director and the owner will look)
- `draw/FAR.md` with the table of item 1 and the rules you derived from it, in plain words.
- The paired sheets before and after; the overview beside the concept; your honest list of what is still wrong.
- The drawing check and the tour proof pass; seed and hockey hashes unchanged.
- The cost table of item 5; a middle game costs clearly less to draw than a near one, a far one less again.
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
- **You work only in your own git worktree: `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p6`** (branch `core-p6-far`, cut from the merged round 1). Every path in
  this brief is relative to it unless it is written in full. Never edit anything under the main checkout
  `C:\Users\kazda\kiro\third-life` outside your worktree; you may read there (`site/` holds the real jobs' packs
  and is not in your worktree: the hockey game is at
  `C:\Users\kazda\kiro\third-life\site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1`).
- **No git command of any kind**, not even a read-only one. The Director stages and commits your files. The `tl` tool
  may call git for you. No test of yours runs git against anything but a temporary repository with `GIT_DIR` unset.
- Godot: `export TL_GODOT="C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe"`. Your
  worktree has no `.godot` cache yet: the first engine run builds it. `foreman/node_modules` is linked.
- Gates: `node devx/bin/tl.mjs check --tier fast --changed` while you work; `node devx/bin/tl.mjs check --tier full`
  once at the end. Four other builders run the engine on this machine tonight. Limits now count processor time, so a
  busy machine should no longer fail healthy code: if it still does, that is a finding for your report. Timing figures
  go through `node devx/bin/tl.mjs perf run` where a scenario exists, and you say whether the run was marked quiet.
- Kill every process you start; never kill others; never leave a window behind (windows go to `--position 0,1440`).
  No network. No model calls. Never read, use or print any `ANTHROPIC_KEY_*` variable.
- Small verified steps. Journal each in ``engine/kernel/world/draw/JOURNAL.md` under a "P6" heading`.
- Contracts (`contracts/**`) are the Director's: write proposed contract text into your report.
- For anything outside your file scope, write the exact patch and its reason to ``engine/kernel/world/draw/PATCHES-P6.md`` instead of editing.
- **Your measurement outranks this brief.** Where a premise here is wrong, say so with the evidence and build the
  right thing; a fix that makes the measured result worse is withdrawn and documented, not tuned.

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
