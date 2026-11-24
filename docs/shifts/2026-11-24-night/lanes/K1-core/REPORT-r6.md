K1 core: report for landable round 6
Lane K1 "core". Worktree .claude/worktrees/hk-core at 277acce (your fast-forward), nothing committed by me. 21:35-21:58.
Details: ROUND-6.md beside this file.

DONE
1. K5 (D5-1): Controls gains PassTargetHeld / PassTargetHeldAim and PassTargetFacing / PassTargetFacingAim from thirdjam's
   UJamSim::HumanPassTarget. K5's lines checked against the source and kept: held = along the stick at max(1, PassChargeFrames)
   (HUDPassMeter.cpp:67; thirdjam shows it only while PassChargeFrames > 0: the HUD's choice), facing = along Yaw at
   game.pass.power_full_frames (HUDTeach.cpp:67; the 6-30 m / ahead gate is the HUD's). The cone is game.pass.aim.cone_deg,
   25 by default (not in hockey.regular).
   rink.controls extended: both targets keep PickReceiverInCone's rule on every frame (recomputed from the snapshot), seeds 1 and 2
   PASS (held target on 4,743 / 6,635 frames, facing on 4,093 / 5,948, none on 7,463 / 10,268). With the cone cut to 5 degrees
   the check fails at once (it bites).
2. K3: the playtester's advice. set_advisor("playtester:<novice|regular|good>[:sprint]") and advise() -> the FJamInput it would
   press now (last_human_input's shape), not applied. A second playtester seated like the seat; it thinks once a frame (advise(),
   or step() when not asked), so its memory never skips a frame.
   Test rink.advice: with the playtester seated and an advisor of the same spec, the advice = what the seat sent on every frame of
   whole matches: 12,206/12,206 (seed 1 regular+sprint), 5,700/5,700 (seed 2 good), 10,630/10,630 (seed 3 novice); asked twice =
   once; the seated match still ends on thirdjam's playtester hash 973d6c043707b703.
   What persists between calls (all inside the core, none in the snapshot): its clocks (Tick, PlayFrames), the reaction ring
   (Ring, BrakeRing: it acts on what it saw ReactionFrames ago), the stick ramp (MoveOut), the held shot / saucer (bHolding,
   HoldFrames, SaucerHold), its cooldowns (LastPass/Check/Deke/CutFrame, CutUntil, CutDir), BraceTarget, stop-mark and dodge
   state, Act; its noise is a hash of seed and frame (no random stream). Set the advisor before reset; set mid-match it starts
   with an empty memory.
   LIMIT, measured: a core driven only by its own advice through set_human_input plays a different (valid) match: the advice's
   Move and Stick cross the Dictionary as single-precision Vector2; seed 1 parts at frame 160 (ends 0:3, not 3:2), seed 2 at 476,
   seed 3 at 349. Through real keys the rounding is coarser. The pack bot decides as thirdjam's playtester would on the pack's
   own match; the tournament's playtester to the hash stays the seated mode.
   Also: restart() now restarts the seat's and the advisor's memory (one playtester a match, as RunPlaytestMatch); no proof value
   moves.
3. SNAPSHOT.md v1.3 (both items, the persisted state, the limit). rink.sh build all: thirdjam debug + release, t5, thirdlife debug +
   release: all PASS.

COMMIT (binaries): bin/rink_core.windows.template_debug.x86_64.dll, bin/rink_core.windows.template_release.x86_64.dll,
bin/rink_core_thirdlife.windows.template_debug.x86_64.dll, bin/rink_core_thirdlife.windows.template_release.x86_64.dll (the
binding changed in both cores). Also engine/cores/rink/rink_core_thirdlife.gdextension.uid (untracked in 6a2c125; rink_core's
.uid is tracked, so the variant's should be too). Not: rinktest-*, rinkcli-*.exe except the tracked t5 one (unchanged), *.exp, *.lib.

GATES
- tl check --tier fast: 5 of 5 PASS (arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck).
- selftest rink.: 18 passed, 1 failed. All 13 of mine PASS (smoke e9e795069734352c, trace_head 51/51, trace_t5 21/21, entry_twice,
  entry_replay, window, rawhand, rawtrace 600/600, playtester_seat, controls, variant now in its FULL case, advice).
  FAIL rink.view.hits (K2's hitread.core1800, got af496e74ecbfdcba want 3ba801e4fee31b2b): the same failure as round 5, shown
  then to be there with the f9d2db9 DLL; not mine.
- Not run: tier full, export, 801/802 (untouched).

FILES (uncommitted): native/src/rink_core.cpp, engine/cores/rink/tools/rink_controls.gd, new tools/rink_advice.gd (+ .uid),
engine/tools/selftest.d/800-rink-core.sh (rink.advice), engine/cores/rink/SNAPSHOT.md, the four DLLs, the .gdextension.uid,
lane ROUND-6.md, this REPORT.txt, a STANDUP line.

KERNEL LINES: none (no kernel file touched; the new methods are the core's, in SNAPSHOT.md).

DEVIATIONS
1. PassTargetHeld is given on every frame (thirdjam's meter draws it only while a pass is held).
2. restart() now resets a seated playtester's memory (before: carried over).
3. The advisor is not thirdjam's (thirdjam's playtester only ever drives a seat); it is the same class with the same setup.
