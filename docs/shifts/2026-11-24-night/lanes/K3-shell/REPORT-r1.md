K3 SHELL, ROUND 1 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, branch hk-shell, uncommitted)

OUTCOME
A new thin house pack engine/packs/hokej (game.hokej 0.1.0): thirdjam's regular rink (90 x 45, corners 3.75, its markings
and 4 x 0.61 nets), ONE stand-in skater on the stand-in skating law, thirdjam's follow camera ported line by line from
CameraFollow.cpp, and thirdjam's key and mouse mapping ported from HokejGameMode. Runs from `tl play hokej` (launched,
no errors; nobody has played it by hand). The camera was checked frame by frame against thirdjam's OWN camera code,
compiled from its source: equal within 0.09 mm and 0.0003 degree over 1561 frames.

ACCEPTANCE (rounds 1-2)
1. Rink measures equal thirdjam's, a table with file:line: MET for every play-relevant measure (RINK.md). Visual
   differences named there: no glass, kit corner tessellation 7 not 12 segments, kick plate red/flush/0.29 m against
   yellow/2 cm proud/0.25 m, board cap 4 cm proud, no stanchions, netting as cords, a concrete apron, no arena.
2. Camera per frame within 1 cm and 0.1 degree of thirdjam's code path: MET against the direct evaluation.
   oracle/make_oracle.sh copies thirdjam's camera lines VERBATIM by line range (CameraFollow.h:11-330, 355-403;
   CameraFollow.cpp:80-134, 167-871, 934-958, 978-985; HUDFeed.cpp:8-12) and builds them with clang against
   oracle/ue_shim.h (FVector2D, FMath, FTransform...; no thirdjam logic). oracle/compare_trace.mjs feeds the skater path of
   bot_gym_hand to it and compares with the pack's camera: max |pos| 0.0090 cm (frame 950), |height| 0.0058 cm (812),
   |pitch| 0.00027 deg (480), |yaw| 0.00011 deg (622); the boards view changed height or pitch on 730 of the frames.
   Negative control: the oracle on a 120 x 60 rink differs from ours on 991 frames (first at 272).
   Per-frame numbers: r1_camera_vs_thirdjam.csv. Against thirdjam's FILM by eye: NOT YET (round 2).
3. Keys and aim as thirdjam's mapping, a headless test per rule: MET.
   bot_rule_w_away   PASS  300 frames, move = keys turned by the last sim frame's camera yaw, error 0 (HokejGameMode.cpp:937-958)
   bot_rule_s_lock   PASS  S held 200 frames: move stays on the yaw of the pull's first frame (error 0) while the camera turns 180 deg;
                           he ends facing the locked back direction (0.00 deg); a new pull relocks (cpp:940-952)
   bot_rule_aim      PASS  12/12: dead zone 0.7 entering, 0.5 leaving, size 0.5 + 0.5 clamp((d - 0.5) / 2.5) (cpp:756-767)
   bot_gym_hand      PASS  the scripted hand: start, sprint, hard turns both ways, the S pull-back, a lap along the boards
                           through the corners, a stop near the end boards (data/hand_gym.json; 'goto' legs steer as
                           jam.ScriptHumanCam does, cpp:864-872)
4. My eye's list of what differs from thirdjam's picture, with frames: MET for our side (ROUND-1.md, r1_sheet_gym_hand.jpg):
   sky and grass instead of an indoor arena (every frame); warm cream ice with a sun glare (f300, f1300, f1500) against cool
   even ice; grey/red boards against white/yellow with glass; the capsule; at the S pull-back (f500) the skater close to the
   lens, at the end boards (frame 480) at the frame's left edge: thirdjam's own code gives these poses, film check in round 2.
   Fixed on sight: a glass sheen stripe across the skater at the end boards (f1380) and nets that read as crates (f920).
5. Lint and smoke: MET (below).

GATES
tl check --tier fast: arch PASS [12/12], assets PASS [4/4], cards PASS [3/3], devx.test PASS [229/229];
  foreman.typecheck NOT RUN (foreman/node_modules missing in this worktree; no npm network here; foreman untouched).
hokej verbs (headless): lint PASS (1315 lines, bypasses [], kit_parts_added 1), smoke PASS (3600 frames, 0 errors),
  invariants PASS (determinism 903ced45e106fd47, frame p99 0.198 ms), bots 4/4 PASS. These are the units the full gate's
  `packs` step runs for this pack. --tier full not run: no kernel, kit, rig, style or seed file changed.

CHANGED FILES (all new)
engine/packs/hokej/pack.json, README.md
engine/packs/hokej/scripts/main.gd        the gym: order of a frame as AHokejGameMode (input through last frame's camera, sim, camera)
engine/packs/hokej/scripts/cam.gd         StepThirdPerson and helpers, line by line with cpp:N references
engine/packs/hokej/scripts/controls.gd    keys' axis, camera-relative move with the S lock, cursor aim
engine/packs/hokej/scripts/skate_standin.gd  STAND-IN: hand_tj_skate.mjs law + UJamSim::CollideSkaterStatic (boards, nets), K1-shaped surface
engine/packs/hokej/gen/tj_rink.gd         rink (kit part placed onto RinkActor's outline) + markings + nets + the stand-in capsule and stick
engine/packs/hokej/data/hockey.regular.cartridge.json (thirdjam's, verbatim), gym.json, standin_law.json, hand_gym.json
engine/packs/hokej/tests/bot_gym_hand.gd, bot_rule_w_away.gd, bot_rule_s_lock.gd, bot_rule_aim.gd
docs/shifts/2026-11-24-night/lanes/K3-shell/: STANDUP.md, ROUND-1.md, RINK.md, REPORT.txt, r1_sheet_gym_hand.jpg,
  r1_top_rink.jpg, r1_camera_vs_thirdjam.csv, oracle/{ue_shim.h, oracle_main.cpp, make_oracle.sh, compare_trace.mjs}
No rule-table edits (lint and tl arch accept engine/packs/hokej as it is). No selftest case added (block 820-829 unused).
Behaviour changes elsewhere: none. engine/packs/hockey untouched.

DEVIATIONS (from thirdjam, each with its reason)
1. No glass over the boards (RinkActor.h:61, 0.9 m): the kit's glass draws white sheen stripes, and with the boards view's
   camera 0.4 m inside the end boards a stripe crossed the skater (f1380). Back when the kit or style has a quiet glass.
2. The boards view's KeepAspect is fixed at 16:9 (thirdjam reads the viewport, cpp:1226-1230): a pack cannot read the window
   size. The drawn lens is thirdjam's horizontal 70 degrees at any aspect (Camera3D KEEP_WIDTH). Equal at 16:9.
3. The move's camera yaw is the camera's last sim-frame yaw (FJamCameraFilter::LastYawOutDeg, as jam.ScriptHumanCam reads
   it, cpp:860-861); thirdjam's ReadHumanInput reads PlayerCameraManager's rotation, the last RENDERED (render-alpha
   interpolated) pose (cpp:943-946). The same at alpha 1; otherwise at most one sim frame of camera turn. Ours is deterministic.
4. The netting is cords 1.8 cm every 0.25 m; thirdjam's is a see-through net-mesh material (RA:864-867) a pack cannot make.
5. Line widths: RinkActor's own (30 cm centre and blue, 6 cm goal); the shipped look paints those four lines with device B's
   MI_Ice_Night (binary asset, widths unread).
6. The aim anchor (lane A191, jam.ctrl.AimAnchor 1, InputMapping.cpp:1108-1132) is not ported: it needs the cursor's PIXEL
   (still or not), and the engine hands a pack only the resolved point (TLInput aim). Engine gap: a "pointer moved this
   frame" flag on the aim. Also the aim is projected through the physics-frame camera pose (the kernel's rule), thirdjam's
   through the rendered one.
7. Camera stages not ported because thirdjam's shipped settings never run them: KeepHumanInFrame (zeroed by the boards view
   itself, cpp:269-275), the A186 bound (jam.camera.Bound 0), KeepYaw (0), the yaw budget (RigYaw 1). cam.gd refuses
   settings that would need them. Punch and kick (cpp:1257-1287) belong to step 3; box follow (cpp:1231-1249) to penalties.
8. Kit rink visuals: corner arcs 7 segments (thirdjam 12), kick plate red, flush, 0.29 m (thirdjam yellow, 2 cm proud,
   0.25 m), board cap 4 cm proud each side, no stanchions, a 3.5 m concrete apron; no arena (benches, boxes, table, lights,
   caps, stands): stair step 5.
9. STAND-IN simulation (to be swapped for K1's core): hand_tj_skate.mjs's free-skater law (C:/t/t5 StepSkater port) plus
   HEAD's CollideSkaterStatic (boards with bounce 0.3, nets as boxes with the slide), no board events, no puck, no bots;
   Vector2 single precision (as K1's snapshot plans).
10. STAND-IN figure (K2's to come): a 1.64 m capsule with a chest mark; the stick a bar drawn along FJamInput::Stick
    (0.5..1 x reach 1.2 m from the body's edge), not the sim's BladePos.
11. Keys: Shift and Ctrl of either side (Godot's KEY_SHIFT / KEY_CTRL); thirdjam binds the left ones only. No gamepad and no
    mouse-delta aim (the engine has no gamepad; thirdjam's match always shows the cursor, so its delta path is idle).
12. The skater's rest yaw and spawn: (-7.5, 0) facing +x (cartridge spawn, JamSim.cpp:159); there is no faceoff in the gym.

WHAT THE OWNER OR DIRECTOR SHOULD LOOK AT
- docs/shifts/2026-11-24-night/lanes/K3-shell/r1_sheet_gym_hand.jpg beside docs/research/hockey-teardown/media/sheet_thirdjam_pro_regular.jpg
  (12 frames of the scripted hand under the ported camera; the scale and the camera now match thirdjam's: a life-size
  figure 6 m ahead, the skater low in the middle of the frame).
- docs/shifts/2026-11-24-night/lanes/K3-shell/r1_top_rink.jpg (the rink from above: lines, circles, dots, creases, nets).
- `tl play hokej` with the keys in the pack's README.

QUESTIONS FOR THE DIRECTOR
1. Home of the camera: it lives in the pack for now (scripts/cam.gd). The brief allows engine/cores/rink/view/**; a pack
   may not load from there until the kernel entry K1 names exists (lint's load fence). Move it when that entry lands?
2. Engine gaps for a full port: the aim's pointer-moved flag (DEVIATION 6) and a quiet glass in the kit or style (1).
3. The arena (step 5) is what my eye rejects first in every frame; it is frozen by the stair. Confirm it stays frozen.

NEXT THREE
1. Round 2: thirdjam's rendered build (tj-run, -Multiprocess, one Unreal process) with jam.camera.Log 1 and stills; its
   JAMCAM lines (skater px, py, hyaw and the camera fcx, fcy, fh, fpitch, fyaw) fed to our camera: per-frame numbers and
   same-frame sheets side by side. thirdjam has no fixed-input-list facility I could find (only jam.ScriptHuman scripts and
   drills), so the side by side follows the brief's fallback: its recorded path into our camera.
2. Swap K1's core in for skate_standin.gd (same set_human_input / step / snapshot surface) and rerun the oracle compare.
3. Swap K2's figure in for the capsule; then the visual tests of direction 7.
