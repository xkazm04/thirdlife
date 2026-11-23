K3 SHELL, ROUND 2 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, branch hk-shell, uncommitted)

OUTCOME
Our camera equals thirdjam's RENDERED game's camera. thirdjam's build ran once (t5 tree, regular cut, pro, its own measured
hand, jam.camera.Log 1, 1280x720; one Unreal process, ended by its timeout): 9,465 logged camera steps. Its skater's path,
fed to our camera (new test bot_tj_replay, in the gate): 9,329 of 9,465 steps within 0.54 cm, 0.22 cm of height, 0.097
degree of pitch, 0.004 of yaw (1,672 of them with the boards view acting); the other 136 are inside thirdjam's contact
kicks (its JAMKICK lines, stair step 3), counted apart. The two poses my eye questioned stand: thirdjam's film shows them
(r2_sbs_film.jpg). The look is now a dark hall, white boards with a yellow kick plate, cool even ice. Kernel API 1.17:
the aim's cursor pixel (the aim anchor is ported as thirdjam has it) and the window's aspect (the camera uses the real one).

THE DIRECTOR'S POINTS
1. Side by side with thirdjam's FILM and per-frame log: DONE through the fallback (thirdjam cannot be fed a fixed input
   list in its rendered game). film/run_tj.sh (the run), film/jamcam_to_trace.py (log -> data/tj_trace_regular_pro.json),
   tests/bot_tj_replay.gd (the comparison, numbers above), r2_sbs_film.jpg (eight film frames, thirdjam left, ours right,
   same frame, same path). The oracle (thirdjam's code compiled) on the same path matches the log too: over 1 cm only on 11
   rows, the two stumble kicks without a hit-stop (frames 4507, 8791). So the build runs the camera settings ported.
2. The S pull-back pose (gym frame 500, the skater huge at the bottom): STANDS. thirdjam frame 5970: his #7 fills the
   lower middle, the camera's foot 1.6 m from him.
   The back-to-the-boards pose (gym 480 / 840, skater at the frame's edge): STANDS. thirdjam frames 1800 and 6420: the
   skater at the right edge against the boards, the camera down and tilted (pitch -41 and -35 degrees).
3. The goal: thirdjam DRAWS the sim's 4 x 0.61 m opening. RinkActor loads the arena mesh SM_Arena_Goal_W400H061
   (t5 RinkActor.cpp:99-103, 1110-1121), made by tools/blender/arena/arena.py goal_build (lines 559-633): posts' inner faces at
   +-2.0 m, crossbar underside at 0.61 m, 16 cm posts and crossbar, 11 cm low bars and braces, 1.5 m deep, back frame
   0.366 m, 3 cm cords in 25 cm cells. Ours is now built from those numbers. The film shows the same low wide cage
   (frames 6480, 8670).
4. The look, no art: a plain dark hall (walls, ceiling, floor; data/gym.json `hall`), white boards with the yellow kick
   plate (RinkActor's own outline with 12 segments a corner, 1.2 m boards, 0.25 m plate 2 cm proud, drawn by us now; the
   kit gives only the ice sheet), ice without glare and without warm cream. NOT MET: thirdjam's ice colour. The film's ice
   is a mauve grey (median sRGB 158, 140, 150); ours is light blue (129, 169, 209): the style's cel shade colours the
   ice under the ceiling, a pack may not make a light, and a light of our own (tried in a scratch copy, a downward
   directional light) turns the toon ice white at any energy. No overhead lights: the style owns lighting (question 1).
   Glass: still none; listed.
5. Kernel API additions (1.17; engine/kernel/API.md updated, docs/generated regenerated with `tl arch --index`):
   - TLInput: aim_pixel(action) -> Vector2, NO_PIXEL, set_aim(action, point, pixel = NO_PIXEL). The cursor's pixel latched
     with the aim, recorded as "<aim>@p" 1 / "@px" / "@py" (zeros left out), in the state hash from the first frame a pixel
     was latched (a run without one hashes as before: every existing aim test passed in the selftest).
     controls.gd anchor_step = FJamAimAnchor::Step (InputMapping.cpp:1113-1127, AimAnchor 1, speed 0.3); test
     bot_rule_aim_anchor PASS (5 phases: a still pixel keeps the offset through a moved point; a moved pixel, a skating
     skater, no pixel re-project).
   - TLCameras: aspect() -> float (the window's; 16:9 headless). main.gd hands it to the camera each frame (KeepAspect),
     as StepSimFrame reads its viewport (CameraFollow.cpp:1226-1230). DEVIATION 2 of round 1 is gone.
   - The move's camera yaw of the last DRAWN frame: NOT given. The drawn pose depends on render timing; a sim reading it
     would depend on the frame rate and a record (keys) would no longer replay. The last sim frame's yaw stays (thirdjam's
     own ScriptHumanCam reads that one); the one-frame deviation stays listed.

GATES
hokej verbs: lint PASS (1574 lines, bypasses [], data 587 KB), smoke PASS, invariants PASS (determinism a13d437236a6c623,
  p99 0.176 ms), bots 7/7 PASS: w_away, s_lock, aim (12/12), aim_anchor (5 phases), gym_hand, tj_replay (above),
  and the oracle compare of the gym hand still PASS (0.009 cm, 0.0003 deg).
tl check --tier fast (after the last edit): arch PASS [12/12] (api-v1 1.17: 44 classes, 692 members), assets [4/4],
  cards [3/3], devx.test [229/229] PASS; foreman.typecheck NOT RUN (no foreman/node_modules in this worktree).
tl check --tier full (kernel changed): exit 1.
  PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, kit.selftest 120/120, seeds 39/39, world 8/8.
  FAIL kernel.selftest [124/125]: 124 passed, 0 failed, then the step's 1,800 s timeout killed it (the machine was loaded;
       the gate's own perf probe read 68 % use). A STOPPED RUN, NOT A PASS. The input cases that touch my change (p7 record
       and replay, k1 pointer, k4 hand aim) are among the 124 passed. The tail run alone afterwards: e6.* 3/3 PASS, n3.* 3/3
       PASS, home.* 9/9 PASS; create.go.* could not run here (needs foreman/dist, not built in this worktree). Which case was
       the 125th is not identified: please rerun kernel.selftest on main or on a quiet machine.
  FAIL packs [3/4 packs; 137 of 138 units]: duel, hokej (8/8 units) and parkour complete; hockey's invariants fail
       invariants.many_budget, frame p50 1.052 ms against 1.0. NOT MINE: A/B back to back, HEAD's kernel 1.132 / 1.164 ms,
       1.17's 1.147 / 1.113 ms: both over; the machine was busy (engine/packs/hockey untouched).
  NOT RUN perf (machine busy), foreman.typecheck, foreman.test (no node_modules), item.selftest, ui.selftest (main only).

CHANGED FILES
engine/kernel/api/tl_input.gd, engine/kernel/api/tl_cameras.gd, engine/kernel/runner/manifest.gd (KERNEL_API 1.17),
engine/kernel/API.md; docs/generated/API-INDEX.md, API-V1.json, REPORTS.md (tl arch --index; regenerate on main as usual).
engine/packs/hokej: pack.json (kernelApi 1.17, two tests), README.md, scripts/main.gd (replay mode for the proof, the anchor,
  the live aspect), scripts/controls.gd (FJamAimAnchor), scripts/cam.gd (comment), gen/tj_rink.gd (RinkActor's outline,
  boards and kick plate, arena.py's goal, the hall; the kit part gives only the ice), data/gym.json (hall),
  data/tj_trace_regular_pro.json (thirdjam's log, 579 KB), tests/bot_rule_aim_anchor.gd, tests/bot_tj_replay.gd.
docs/shifts/2026-11-24-night/lanes/K3-shell: ROUND-2.md, RINK.md (rewritten), STANDUP.md, REPORT.txt, r2_sbs_film.jpg,
  r2_sheet_gym_hand.jpg, film/run_tj.sh, film/jamcam_to_trace.py.
Behaviour changes elsewhere: set_aim gained an optional parameter; packs that never give a pixel hash and record as before.
Raw captures: thirdjam's 317 stills deleted after the sheet (the eight used are in .tl/sbs/tj_used); its log in .tl/tj.

DEVIATIONS (from thirdjam; round 1's list with its changes)
1. No glass, rail, stanchions or emissive trim on the boards (RinkActor.h:61, 68; RinkActor.cpp:506-552): the kit's glass
   glared across the skater (round 1). Until a quiet glass exists.
2. NEW: the ice colour: light blue in the style's shade (129, 169, 209) against the film's mauve grey (158, 140, 150); no
   overhead lights (packs may not make lights). Round 1's aspect deviation is gone (ctx.cameras.aspect).
3. The move's camera yaw is the last sim frame's, not the last drawn frame's (see point 5).
4. The netting and frame are square bars; arena.py's clay bars are rounded and thumbed.
5. Line widths: RinkActor's own; the shipped look paints four lines with device B's MI_Ice_Night (binary, unread).
6. The aim anchor resets whenever the aim is invalid; thirdjam resets only when the cursor's ray misses the ice, not when
   the cursor leaves the window (our aim does not say which).
7. Camera stages thirdjam's shipped settings never run are not ported (KeepHumanInFrame, the bound, KeepYaw, the yaw
   budget); punch and kick (contact) and box follow are later steps. bot_tj_replay counts the kick rows apart.
8. No arena (stands, roof, lights, benches, boxes): a plain dark hall; stair step 5.
9. STAND-IN simulation (K1 has not published SNAPSHOT.md): hand_tj_skate.mjs's law + CollideSkaterStatic.
10. STAND-IN figure: the 1.64 m capsule; thirdjam's #7 skates crouched and reads a little smaller.
11. Keys: Shift and Ctrl of either side; no gamepad, no mouse-delta aim.
12. The gym has no faceoff; the skater starts at (-7.5, 0) facing +x.

WHAT TO LOOK AT
- docs/shifts/2026-11-24-night/lanes/K3-shell/r2_sbs_film.jpg: thirdjam's film beside ours, same frames, same path
  (f5970 and f1800/f6420 are the two poses in question).
- docs/shifts/2026-11-24-night/lanes/K3-shell/r2_sheet_gym_hand.jpg: the scripted hand in the new look.
- `tl play hokej`.

QUESTIONS FOR THE DIRECTOR
1. Light: matching thirdjam's ice (mauve grey, lit from above) needs the style to offer an indoor light (no sun, an even
   overhead light) a pack can ask for; a pack may not make lights and a kit light did not work under the cel shader. Who?
2. Contracts: tl.input/1 records may now hold "<aim>@p", "<aim>@px", "<aim>@py" entries (PACK.md names only @x and @z),
   and PACK.md's input section could name aim_pixel. Wording for you.
3. KERNEL_API 1.17 is taken here; if K1's kernel entry also bumps it, one of us becomes 1.18 at landing.

NEXT THREE
1. K1's core in for the stand-in law (same surface), then the gym hand and the replay test again.
2. K2's figure in for the capsule; the visual tests of direction 7.
3. The tempo rows of the gym against thirdjam's (direction 2), through the same scripted hand in both games.
