# K1 core: round 6 (24 Nov 21:35-22:00)

## 1. PassTargetHeld and PassTargetFacing (K5, deviation D5-1)
`rink_core.cpp` snapshot `Controls`, beside `PassTarget`, from thirdjam's own HUD query `UJamSim::HumanPassTarget` (JamSim.cpp; the
cone pick is `PickReceiverInCone`). K5's suggested lines were checked against the source and kept:
- `PassTargetHeld` (+ `PassTargetHeldAim`): `HumanPassTarget(Hi, BladePos - Pos, max(1, PassChargeFrames), Aim)`: the pass meter's call
  (HUDPassMeter.cpp:67). One difference, stated in SNAPSHOT.md: thirdjam draws it only while `PassChargeFrames > 0` (62-64); ours
  is always there (at 1 frame = the tap's target when nothing is held), the HUD decides when to show it. `max(1, ...)` also covers
  a dead press (`PassChargeFrames` -1 under charge_dies_on_loss).
- `PassTargetFacing` (+ `PassTargetFacingAim`): `HumanPassTarget(Hi, (cos Yaw, sin Yaw), game.pass.power_full_frames, Aim)`: the
  teach pulse's call (HUDTeach.cpp:67). Its 6-30 m and "ahead within 0.7" gate (68-72) is the HUD's, not ours.
- The cone is `game.pass.aim.cone_deg` (JamCartridge.cpp:1216), absent from hockey.regular = 25 degrees (K5's comment said 25: right).
`rink.controls` extended: on every frame both targets keep PickReceiverInCone's rule recomputed from the snapshot (a teammate,
1.5 m or more from the puck, the smaller of the angles from the puck to him and to the meeting point within the cone; nobody ->
the aim straight along the direction). Seed 1: held target on 4,743 frames, facing on 4,093, none on 7,463; seed 2: 6,635 /
5,948 / 10,268. Both PASS. Check that it bites: with the cone cut to 5 degrees it FAILS at once (a target 21.7 deg off).

## 2. The playtester's advice (K3)
Names: `set_advisor("playtester:<novice|regular|good>[:sprint]")` ("" = off) and `advise() -> Dictionary` (last_human_input's shape;
{} with no advisor, no human seat or a finished match). Not applied: the human's seat stays whatever `set_human_mode` says.
- A second `FJamPlaytester` (the advisor), seated exactly as the seat is (same setup, same seed), reset with the match. It thinks
  once a frame on the world the seat would see: on `advise()`, or inside `step()` when the frame was not asked (so its memory never
  skips a frame). Asked twice on a frame = once.
- What persists between calls (thirdjam AI/JamPlaytester.h, all inside the advisor, none in the snapshot): its clocks `Tick` and
  `PlayFrames`; the reaction ring `Ring[]` and `BrakeRing[]` (it acts on what it saw ReactionFrames ago); `MoveOut` (the stick ramp);
  `bHolding`, `HoldFrames`, `SaucerHold`; the cooldowns `LastPassFrame`, `LastCheckFrame`, `LastDekeFrame`, `LastCutFrame`,
  `CutUntil`, `CutDir`; `BraceTarget`; the stop-mark and dodge state; `Act`; and `Seed` (its noise is a hash of seed and frame
  window, Noise(): no random stream to keep).
- Test (selftest `rink.advice`, tools/rink_advice.gd): the playtester seated + an advisor of the same spec; the advice asked
  before each step equals what the seat sent, field for field: seed 1 regular+sprint 12,206 of 12,206 frames; seed 2 good 5,700 of
  5,700; seed 3 novice 10,630 of 10,630. The seated match still ends on thirdjam's playtester hash 973d6c043707b703 (round 4's
  proof value): the advisor disturbs nothing.
- Measured, and a limit K3 must know: a second core driven ONLY by its own advice through `set_human_input` plays a valid but
  different match (seed 1: its state hash parts at frame 160 and it ends 0:3, not 3:2; seed 2 at 476; seed 3 at 349). Cause: the
  advice's `Move` and `Stick` cross the Dictionary as `Vector2` (single precision); the first difference is 1e-6 m in the human's
  velocity at frame 147 and the match is chaotic. Through the real keys the rounding is coarser still. So the pack bot stays in the
  pack's own match and decides as thirdjam's playtester would on that state, but it is not the tournament's playtester to the
  hash (that is the seated mode, `playtester:...`).
- `restart()` now also restarts the seat's and the advisor's memory (RunPlaytestMatch makes one playtester a match). Before, a
  seated playtester carried its memory into a restarted match. No proof value moves (restart is not in any of them).

## 3. Builds
`rink.sh build all`: thirdjam debug + release, t5 debug, thirdlife debug + release (the patches are in the tree now).
Commit: bin/rink_core.windows.template_{debug,release}.x86_64.dll and bin/rink_core_thirdlife.windows.template_{debug,release}.x86_64.dll
(the binding changed in both: same source). Not: rinktest-*, rinkcli-thirdjam.exe, rinkcli-thirdlife.exe, *.exp/*.lib (ignored);
rink_core_t5 (ignored, proof only); rinkcli-thirdjam-t5.exe is tracked but its source did not change this round.
