# K1 round 3: the kernel entry, the game mode's play rules, thirdjam's own tests, a recorded hand (18:30-19:40)

## 1. The kernel entry and determinism through the runner

- `ctx.cores.open(id, cartridge = "")` and `ctx.cores.state()`: `engine/kernel/api/tl_cores.gd` (class TLCores) and one lazy
  member on TLContext (`var cores: TLCores`, made on first use). Kernel API **1.18** (the Director's numbering; K3 holds 1.17):
  `KERNEL_API` in `engine/kernel/runner/manifest.gd`, and API.md gets one appended section (24). docs/generated and
  context-map.json are NOT regenerated (the Director regenerates after the merge).
- A pack never names the extension's class; an unbuilt core is an error naming `bash engine/tools/rink.sh build`.
- Probe pack `engine/cores/rink/test_pack` (id core.rink_probe): the regular match through ctx.cores, the human's skater on
  `ctx.input`, `_pack_state() = ctx.cores.state()`.
- Selftest 800, new cases, all PASS: `rink.entry_twice` (bot hand, seed 3: state hash 11763bf0... twice),
  `rink.entry_replay` (the bot run's input record replayed, no bot: the same hash), `rink.window` (the same hand as raw key
  events in a real window; the window's own record replayed headless prints the same core hashes at all 5 checkpoints).
- **Finding (kernel, not the core):** in a real-time window, scripted `--devices` key events reach `ctx.input` late or not
  at all now and then: the window's input record differs from the headless one at sample 3912 (frame 2235), and two window
  runs differ from each other. The core is not the cause (the window's record replayed headless gives the window's core
  hashes exactly). Probably Godot's buffered input events (parsed during a physics tick, flushed with the next rendered
  frame). `Input.flush_buffered_events()` after `parse_input_event` in `kernel/runner/session.gd` pre_sample is the likely
  one-line fix; not applied (kernel runner, not this lane's scope).

## 2. thirdjam's game mode: play versus presentation (GAMEMODE.md, published 19:17)

25 rules split with their thirdjam file:line. Play rules ported into the core's glue (`native/glue/rink_gamemode.{h,cpp}`,
C++ beside the shim, thirdjam's files untouched): the two-role buttons resolved by possession, "with the puck" including
our pass in flight, a key held across a change of possession going dead, the 13-frame saucer and brace holds, taps
released before the step, `bCrossHold` only without the puck, camera-relative move with the pull-back held in the camera
frame of its start, the per-axis clamp, the stick aim (pad, cursor with hysteresis and the A191 anchor, hidden-cursor
delta), sprint and brake levels, the single-role edges, team signals 1-4 into the brain, restart. Hit-stop and the shown
carrier are presentation only (they gate no input and no sim frame): K2's pawn. Pause and the step pacing: the shell
(call `step()` once a physics frame, not while paused).

RinkCore v1.1 (additions only; the v1 per-skater dictionary is unchanged): human mode `raw` + `set_raw_input` (Unreal key
names, axes, camera yaw, cursor), `set_bot_mode("parked")` (K2's gym), `restart()`, `last_human_input()`, the snapshot's
`Controls` (hold steps, team signal). SNAPSHOT.md v1.1: every enum's values with source lines, `InBox` in the shape line,
how to run the gym.

Not proved yet: the glue against thirdjam's own Jam.Controls tests (JamGame/Private/ControlsTests.cpp); they drive
UJamPlayerInput and FKey. Next round.

## 3. thirdjam's own automation tests on HEAD, natively

219 tests are registered in HEAD's JamCore (216 in the 41 test files, 3 in JamPlaytester.cpp). Compiled unchanged against
the shim (+ a minimal FAutomationTestBase, IFileManager, FOutputDevice/GLog, TUniquePtr, KeySort...): **180**. Not
compiled: JamContactTests.cpp (36), JamStickTests.cpp (2), VisualSwapTests.cpp (1): they include JamPawns.h (Unreal actors:
the hit-stop and figure helpers AJamSkater::HitStopPick / HitStopFramesFor / StumbleFramesFor / SmoothAimDeg / CallFigure).
Results: see the table in REPORT.txt (filled from the final run).

Shim bugs the tests found (fixed): `FString::ReplaceInline` returned 0 instead of the count (5 ModeKeys tests and
DifficultyProfilesResolve failed on it; the simulation never calls it). Runner: thirdjam's tests need a big stack (Unreal's
threads have one); rinktest links with 16 MB.

## 4. A recorded hand through the person's input path

- `tools/rink_rawhand.gd` (selftest `rink.rawhand`): one scripted raw device stream, fed twice: the same FJamInput every
  frame (digest 190a8498...) and the same hash (231ba574...); every verb reaches the sim (shoot held 20 frames, lift 19,
  cross-hold 323, pass held 64, check 18, sprint 1440, poke 24, spin 4, ability 3; 7 team signals).
- `tools/rink_rawtrace.gd`: the reference trace of a recorded stream for K3 (`--write-sample` records the scripted hand
  as a JSON stream; `--stream` replays a stream and writes one line per frame: frame, hash, score, carrier, the human's
  FJamInput). The recorded 3,600-frame stream replays to the live run's hash; two replays are identical. A 600-frame sample
  and its trace are committed in `proof/` (selftest `rink.rawtrace`).
- Not done: comparing a raw stream with Unreal frame by frame. thirdjam's game mode has no replay of a recorded device
  stream (jam.ScriptHuman generates its input from the sim, in a rendered PIE game); the headless commandlet path has no
  human input path at all. A faithful Unreal side would need a small commandlet that feeds a recorded FJamInput stream
  through ApplyButtons; that is Unreal work (a build of JamGame), so it is a question for the Director.
- Not done: thirdjam's playtester as a seat in RinkCore whose decisions a shell bot could press. RunPlaytestMatch sets the
  playtester up with about 20 environment- and config-dependent switches and per-frame extras (ability rule, contest and
  stop marks, hit notes); a seat that is not bit-equal to it would be a new hand, so it waits for a round of its own.

## The gym (for K2)

`set_bot_mode("parked")`: the nine others get no input. Measured over 600 frames: the human skated 33.8 m, parked wingers
and backs moved 0.000 m, but **the opposing centre moved 39.8 m** (from frame 108, about 3 m/s, with no input). Not
explained yet (the faceoff's draw logic inside UJamSim is the first suspect). Said in SNAPSHOT.md.

## What my eye rejects

Nothing to look at in this lane (no picture).

## Deviations

1. `set_bot_mode("parked")` is a test stand, not thirdjam.
2. The glue compiles in the shipped values of jam.ctrl.* (OurPuckShoots 1, HeldAcrossChange 1, SaucerHoldFrames 13,
   BraceHoldFrames 13, AimAnchor 1, AimAnchorSpeed 0.3); no console variables.
3. Bindings are thirdjam's defaults only (no rebinding table yet).
4. Signals are given by the keys only; the bark (teammate acknowledgement) and the bus event are presentation and not sent.
