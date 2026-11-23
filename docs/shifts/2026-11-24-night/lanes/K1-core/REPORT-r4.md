K1 core: report for landable round 4 (the Director's round-4 list items 1-4 and item 5)
Lane K1 "core", hockey campaign night 23-24 Nov 2026. Worktree .claude/worktrees/hk-core (on hokej 38862d9). 20:18-22:40.
Details: ROUND-4.md. Earlier rounds: REPORT-r2.md, REPORT-r3.md.

HEADLINE
- A player quitting the exe with a dungeon open no longer crashes (it did 4 of 4; now 0 of 9, and closing the window 3 of 3).
- Scripted key presses in a real window now land on their frames even when another window takes the focus (142 frames
  were lost before).
- K3's recorded raw stream now replays to the pack's own match on all 9,071 frames: the camera yaw crossed a JSON parser
  one double ulp away; raw devices are now single precision by rule.
- thirdjam's contact law passes its own 36 tests natively (and the 2 stick tests): Jam.* 195 of 195 overall.
- thirdjam's playtester is seated in the core and plays thirdjam's own matches to the hash; pressed through real keys it
  parts at frame 162 / 196, for reasons a person's hands also meet.

ITEM 1: the window and the quit: MET
- session.gd: the flush was already there; the cause was focus loss (the OS releases held keys). The session presses again
  what its script holds before each sample. Selftest 801 window.scripted_focus PASS (focus stolen: 5,179 of 5,179 samples
  equal headless; a second window run equal too). Headless records unchanged byte for byte.
- dungeon.gd: `_exit_tree` tears the pack down and stops the watchdog thread and the script logger when close() never ran
  (an engine quit). Exit 139 4 of 4 before; 0 of 9 after (parkour, duel, hockey x 3); window close 3 of 3 exit 0.
  Selftest 802 dungeon.quit_after PASS. Not ours, noted: a bare Godot 4.7.2 project crashes on windowed quit 5 of 10 on
  Vulkan, 0 of 10 on D3D12 (our project uses D3D12).
- Uncapped engine selftest suite (bash engine/tools/selftest.sh, no gate timeout), stopped at 22:38 on the Director's word
  (the suite runs at the verdict on the integrated branch): 477 PASS, 2 FAIL when stopped (my 8xx blocks not reached in that run;
  they passed on their own: rink. 9/9, 801, 802).
    FAIL dungeon.trips (menu -> world -> menu -> dungeon x 3: the dungeon hashes bd182092f284, alone c7d3e7f438e5): NOT from
    this round: the same bd182092f284 with my dungeon.gd change removed and with my session.gd change removed (A/B, 3 runs
    each). It is on the hokej base 38862d9 already; the other dungeon cases (hash_alone: hockey, parkour, paddle) PASS.
    FAIL feel.pushbox_invariants (wall-clock frame budget p50 1.086 ms > 1.0, measured while my A/B runs loaded the
    machine): PASS when rerun alone.

ITEM 2: thirdjam's tests through a pawn shim: MET for the 39 pawn-dependent tests but one; Jam.Controls NOT done
- The pawn's five pure helpers (HitStopFrames, HitStopFramesFor, HitStopPick, StumbleFramesFor, BrakeDecelFor, SmoothAimDeg)
  are extracted verbatim from thirdjam's JamPawns.cpp at build time (tools/extract_pawn_helpers.py; JamPawns.cpp/.h copied
  verbatim, not compiled) behind shim/pawn/JamPawns.h; CallFigure dispatches by name for the one probe class (PATCHES.md
  deviation 12). Result: 36 of 36 Jam.Core.Contact* and 2 of 2 stick tests PASS. VisualSwapTests (1) loads Unreal classes:
  not compiled.
- Totals (sheet thirdjam-tests-head.txt): 218 of 219 compiled; Jam.* 195 of 195 PASS; Bar.* 22 of 23 (the failing
  Bar.Playtest.GoodNeverIdlesAtAllStar fails in thirdjam too, round 3).
- Jam.Controls.* (24): NOT run. ControlsTests.cpp includes Slate, the menus, the settings widget and the game mode; about 10
  of its tests exercise the button rules. A UI shim that size, or extracting single tests (a re-typing), was not worth the
  round. Evidence today: K3's compiled thirdjam resolver agrees with the glue on 5,198 of 5,198 frames.

ITEM 3: the gym: MET
- The "drifting centre" was the human pushing him by body contact (he stands at the dot in the human's path).
- set_bot_mode("off"): the other nine kept in thirdjam's penalty box every frame ("no input, no contact",
  JamSim.cpp:1349-1357): human 43.9 m, others 0.000 m (selftest rink.rawhand). SNAPSHOT.md says how K2 uses it.

ITEM 4: the playtester as a hand that presses the real keys: seat MET; through the keys it parts (reported)
- set_human_mode("playtester:<novice|regular|good>[:sprint]") (glue/rink_playtester.cpp): seeds 1, 2 end on thirdjam's
  tournament playtester hashes (973d6c043707b703 after 12,206 frames; 1bbdb50b63cdaac3 after 16,903). Selftest
  rink.playtester_seat PASS. last_human_input() is its decision each frame, for a shell bot to press.
- tools/rink_keyshand.gd presses each decision through the person's path (bindings, skate axis, pad stick, camera yaw 0) into a
  second core: seed 1 parts at frame 162 (inputs equal at single precision; the playtester's move/stick are doubles, a
  device axis is a float), seed 2 at frame 196 (a lift pressed while LMB is still held for a cross-check: a person must let
  go one frame first). The keys path cannot carry the analog decision to the bit while the raw shape is single precision.

ITEM 5: K3's raw replay parting at frame 1,294: FIXED
- Cause: the glue used CameraYaw as a double; the replay's yaw went through Godot's JSON number parser one double ulp off
  (0.93477410078048706 vs ...717); positions differed ~1e-12 from frame 1,288, under the hash and the float snapshot.
- Fix: raw values are single precision (CameraYaw rounded to float on entry; optional CameraYawDeg, thirdjam's form);
  rink_rawtrace.gd writes one line per stream entry. On a copy of K3's pack: rawtrace_compare.py PASS 9,071 of 9,071;
  raw_replay_exact.gd: no input, no hash difference. The raw-hand proof was regenerated (600-frame hash unchanged
  3f805d57...; rink.rawhand's 3,600-frame hash moved 231ba574 -> aed35f01: its yaw is now single precision).
- No pixel: omit CursorPx or give a negative coordinate: no anchor (decided; SNAPSHOT.md v1.2).

K5's asks (snapshot, additions only, SNAPSHOT.md v1.2 with thirdjam lines)
- DONE this round (built and in the snapshot, SNAPSHOT.md v1.2 with thirdjam lines): Controls.ButtonsWithPuck /
  ButtonsCarrying / ButtonsInReach (thirdjam's HasPuckForButtons / ButtonContext, InputMapping.cpp:432-442, 474-486),
  PassTarget, PassTargetAim, SaucerTarget (JamSim.h:903 BestPass), TakeOwner (JamSim.h:885-887), CarrierInTakeGrace
  (JamSim.h:879-884). Not yet exercised by a selftest of their own: the first item of round 5.

GATES
- tl check --tier fast: PASS 5 of 5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- selftest rink.: 9 of 9 PASS (+ playtester_seat); window.scripted_focus PASS; dungeon.quit_after PASS.
- (the uncapped suite: see item 1)
- Binaries rebuilt by `bash engine/tools/rink.sh build all` (debug + release DLL with the glue and the seat; t5 CLI).

KERNEL LINES (for the Director; no version line or docs/generated touched)
- engine/kernel/runner/session.gd: new vars _held_keys, _held_buttons; pre_sample starts with _reassert_held(); the "key" and
  "button" device branches record held / released; new func _reassert_held(). No API change.
- engine/kernel/dungeon/dungeon.gd: new func _exit_tree() (teardown + _free_pack when close() never ran). No API change.

CHANGED FILES
- kernel: engine/kernel/runner/session.gd (held keys pressed again), engine/kernel/dungeon/dungeon.gd (_exit_tree).
- core: native/src/rink_core.cpp (raw precision, CameraYawDeg, no pixel, bot mode off, playtester mode, Controls fields),
  native/glue/rink_gamemode.{h,cpp} (no-pixel anchor; exported HasPuckForButtons / ButtonContext), native/glue/rink_playtester.{h,cpp}
  (new), native/shim/pawn/ (new), native/shim/HAL/IConsoleManager.h, native/tools/extract_pawn_helpers.py (new),
  native/thirdjam/{Private,Public}/JamPawns.* (verbatim), native/SConstruct (pawn shim in the test build), native/PATCHES.md,
  SNAPSHOT.md (v1.2), GAMEMODE.md, tools/rink_rawtrace.gd, rink_rawhand.gd, rink_keyshand.gd (new), proof/rawhand.* (regenerated),
  bin/ (rebuilt).
- engine/tools/selftest.d/800-rink-core.sh (+ playtester_seat), 801-scripted-window.sh (new), 802-dungeon-quit.sh (new).
- docs/shifts/.../K1-core/: STANDUP.md, ROUND-4.md, REPORT.txt, thirdjam-tests-head.txt.

DEVIATIONS (new this round)
1. set_bot_mode("off") holds the other nine in the penalty box (a test stand; writes PenaltyFrames through the glue).
2. Raw devices are single precision by rule (CameraYaw rounded on entry); CameraYawDeg in float degrees.
3. CallFigure by name without reflection, for the probe class only (tests).
4. The playtester seat takes over RunPlaytestMatch's setup with no measurement environment; its statistics are not kept.

QUESTIONS FOR THE DIRECTOR
1. Jam.Controls: a UI shim for ControlsTests.cpp (large), or the ~10 button-rule tests extracted (a re-typing of test code)?
2. The keys hand: should the raw shape gain a double-precision axis/stick for bots (so a bot can press the playtester's
   analog decision to the bit), or is "next to thirdjam's hand" the right bar for a pack bot?
3. Vulkan quit crash in bare Godot 4.7.2: worth an upstream report / a guard that keeps exports on D3D12?

NEXT THREE
1. Jam.Controls per your answer to question 1.
2. A pack-side playtester bot for K3 that presses the seat's decisions with the lift release rule, measured frame by frame.
3. Rebinding: let the shell hand the core a bindings table (the glue reads the defaults only).
