K4 reference: report (rounds 1-3 in one pass, 18:40-21:00, 23 Nov 2026)

WHAT THIS LANE PRODUCED
- docs/research/hockey-teardown/PLAY.md: a measured description of thirdjam's play, from the running native core.
  1 tempo map (gym probes + matches), 2 mechanic matrix (every verb from the source with file:line; 114 ablation cells,
  32 skate-plus-verb cells, 9 signal cells, 200 seeds each), 3 skill ladder (4 hands x 3 levels x 200 seeds),
  4 weak list (12 entries, ranked), 5 the harness. Data: docs/research/hockey-teardown/media/play_{ladder,ablate,only,signal}.json,
  play_gym.jsonl.
- engine/cores/rink/lab/: the measurement runner rinklab.exe (thirdjam's JamCore compiled unchanged + an input filter on the
  human's slot as a subclass of FJamSimAdapter, read-only counters, gym probes), cells.mjs (runs and tabulates cells),
  tables.mjs (PLAY.md's tables), balance.mjs + balance.baseline.json (the harness).
- engine/tools/rink.sh: lab-build, lab, balance (a 19-line block; nothing else in the file changed).

HEADLINE FINDINGS (all 200-seed cells, thirdjam's playtester hands, hockey.regular)
- You can score without shooting: a carry over the goal line is a goal. With every shot removed the regular hand still scores
  1.84 goals a match at pro (2.02 with shots); a quarter of the hand's goals in the full game are walked in.
- Passing gives the puck away: 38 % of the regular hand's passes reach a mate at pro; removing the pass wins +9 points.
- Pro is flat at the top (regular 75.5 %, good 76.0 %); rookie is won without the player (idle hand 60.5 %).
- The puck changes teams every 2.2 s at pro; a carry lasts 0.8 s; the puck is loose a third of the time.
- What carries the game: the stick's aim (-27 points when removed, regular pro), the stop (-13 / -19), the sprint (-12 / -14),
  the shot (-8 to -14), the charge. Dead in play: brake button, ability, one-timer, tap, saucer, deke, spin, brace, poke.
  No verb wins alone (best single verb: half of the full hand). The good hand's far-side carry (+11 when removed) and its
  quick draw press (+14 when removed) cost it.
- Levels are harder by speed: opponents average 8.3 / 9.6 / 11.0 m/s (rookie / pro / all_star), the human 9.5 at all.

ACCEPTANCE
- Every figure names its instrument, seeds and hand; every "what beats it" cites thirdjam's source line: MET (PLAY.md "How it
  was measured", tables headed with cells and seeds; matrix 2a cites JamSim.cpp / JamSim.h / JamCartridge.h /
  JamPlaytester.cpp / DifficultyProfile.cpp / JamAICore lines of HEAD 8dc713c6, which our native copy equals byte for byte).
- The ablation covers every verb FJamInput has: MET. Move (the base: the skate-only hand, 2c), bShoot (tap), bShootHeld
  (charge; both = shoot), bPass and bPassHeld (pass; saucer), bCheck, bBrake, Stick (stick; shield = aim while carrying),
  bPoke, bLift, bDeke, bSprint, bSpin, bAbility, bCrossHold (brace); plus the stop made with Move, the one-timer window and
  the draw. The team signal is not in FJamInput (a HUD verb into the brain's world): measured by holding it (2d).
  bAbility: the cartridge has no abilities, so its removal is identical in all 1,200 matches (stated).
- The weak list has at least eight entries with a figure or a traced match and frame: MET (12; item 1 has a replayable
  trace: rookie, seed 2, frames 498-548, `rink.sh lab match -seeds=2-2 -difficulty=rookie -player=regular -playersprint
  -remove=shoot -trace=1`).
- The harness runs from a clean build by one command and reproduces its baseline exactly: MET. With .tl/rink-lab-obj and
  rinklab.exe deleted: `bash engine/tools/rink.sh balance` built and ran in 2 min 22 s:
  "PASS  balance: 12 cells (600 of 600 matches) and 43 gym probes equal the baseline, hash for hash (132 s)". Final re-run:
  see the last line of STANDUP.md.
- Nothing under engine/cores/rink/native/ changes: MET (git status: no change under native/).
- `node devx/bin/tl.mjs check --tier fast` passes: MET ON THE CAMPAIGN BRANCH'S RULE FILES, NOT IN THIS TREE AS IT STANDS.
  This tree (cut at aa609ce) fails arch context-map-cover on K1's engine/cores/rink/SNAPSHOT.md (engine/cores has no
  context here; hokej 503861d added the "cores" context and the OWNERSHIP row). With hokej's context-map.json and
  docs/OWNERSHIP.md copied in for the run and restored after: PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test 229 of 229, PASS foreman.typecheck (after `npm ci` in foreman/, gitignored). As it stands here:
  FAIL arch (that rule only), FAIL devx.test 226/229 (the same rule's real-tree tests). My files fall under engine/cores/**.

GATES
- tl check --tier fast (with hokej's two arch files): 5 of 5 PASS, devx.test 229/229.
- tl check --tier fast (this tree as it stands): FAIL arch context-map-cover (engine/cores, pre-existing, fixed on hokej).
- Sameness of the lab runner: 60 of 60 playtest lines equal rinkcli HEAD (K1's build), re-checked 20 of 20 after each rebuild.
- Determinism: ladder run twice, 2,400 of 2,400 match hashes equal; four cells a third time, 800 of 800.
- Full tier not run: no kernel, kit, rig, style or seed file changed.

CHANGED FILES
- M engine/tools/rink.sh (block placed just before the `*)` arm; after `esac` it would never run).
- A engine/cores/rink/lab/{SConstruct, lab_filter.h, lab_filter.cpp, lab_gym.h, lab_gym.cpp, rinklab.cpp, cells.mjs,
  tables.mjs, balance.mjs, balance.baseline.json, bin/.gitignore}
- A docs/research/hockey-teardown/PLAY.md, media/play_ladder.json, play_ablate.json (268 KB), play_only.json,
  play_signal.json, play_gym.jsonl
- A docs/shifts/2026-11-24-night/lanes/K4-reference/{STANDUP.md, ROUND-1.md, REPORT.txt}
- Not committed: engine/cores/rink/lab/bin/rinklab.exe (gitignored; built on demand by rink.sh in seconds with MSVC).

BEHAVIOUR CHANGES
- None to the game or the shipped core. The lab only reads and filters inputs in its own runner.

DEVIATIONS (measurement only)
1. An ablated verb is a key the game never hears; the hand does not re-plan. charge -> tap and saucer -> tap pass are
   conversions on the release frame.
2. The stop ablation carves a reversed stick to 115 degrees (the playtester's own carve).
3. Every ablation but "draw" leaves the faceoff unfiltered (the draw press is a poke).
4. -only keeps skating, the stick's aim and the draw; run at pro and all_star only (rookie: both full hands win 100 %).
5. The signal arm holds one intent all match aimed at every mate.
6. The gym cuts the roster to 2 v 2 and runs no brain.
7. The lab builds with its own SConstruct (plain MSVC /O2 /MT /std:c++20 /fp:precise), not godot-cpp's environment;
   sameness shown by equal playtest lines.
8. rink.sh block position (above).

LOOK (rule 3)
- This lane draws nothing; there are no frames to compare. Evidence is figures and replayable traces.

FOR THE OWNER
- Read PLAY.md section 4 (twelve weak points, ranked) and section 3 (the ladder). Section 1's table is the speed of the
  game in his units. Replay the walk-in goal: `bash engine/tools/rink.sh lab match -seeds=2-2 -difficulty=rookie
  -player=regular -playersprint -remove=shoot -trace=1` (frames 498-548).

QUESTIONS FOR THE DIRECTOR
1. Should `rink.sh balance` become a gate step (devx/lib/gate/steps/, one file)? It needs MSVC and about 2.5 minutes with
   6 processes; I left it as a command (scope).
2. Binary policy: rinklab.exe is not committed (built on demand); fine, or commit it like the rink_core DLLs?
3. Two open measurements: why the good hand wins 14 points more by never taking the draw (it wins every draw at pro either
   way), and why the held "pass" signal lowers passes received. Worth a trace lane before "surpass" leans on either.

NEXT THREE (if sent on)
1. A person-like hand that re-plans without a verb (the honest second arm of the ablation; would settle the dead verbs).
2. Trace the draw effect and the pass losses frame by frame (and against the Unreal film of the same seed).
3. Run the harness on lane K3's integrated pack once it plays through RinkCore, so the shell's game is held to these figures.
