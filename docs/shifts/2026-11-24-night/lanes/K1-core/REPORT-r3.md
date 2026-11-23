K1 core: report for landable round 3 (the Director's round-3 list, items 1-4)
Lane K1 "core", hockey campaign night 23-24 Nov 2026. Worktree .claude/worktrees/hk-core (branch hk-core, on hokej a565ca3). 18:30-20:12.
Round 2's report is REPORT-r2.md. Details of this round: ROUND-3.md.

HEADLINE
- Packs now reach the core through one kernel door, ctx.cores.open("rink", cartridge), and the runner's laws hold through it:
  two bot runs, a replay of the record, and a real window (replayed headless) all give the same hash.
- thirdjam's game-mode play rules (the two-role buttons by possession, held keys dying across a change of possession,
  saucer/brace holds, camera-relative move, stick aim, signals 1-4, restart) are ported into the core's C++ glue;
  GAMEMODE.md (published 19:17) splits all 25 rules, so the shell keeps only keys-to-raw-input and drawing.
- thirdjam's own automation tests run natively on HEAD: Jam.* 157 of 157 PASS (thirdjam's own gate is "full Jam N/N"); the
  Bar.* bars 22 PASS, 1 FAIL (it fails in thirdjam too); 39 tests not compiled (they need the Unreal pawn).
- A recorded raw human input stream has a reference trace (rink_rawtrace.gd), identical every run.

ITEM 1: kernel entry, API lines, state hash, determinism through the runner: MET
- engine/kernel/api/tl_cores.gd (class TLCores: open(id, cartridge = ""), state()), engine/kernel/api/tl_context.gd
  (+7 lines: `var cores: TLCores` with a lazy getter, after `var cameras`), engine/kernel/runner/manifest.gd
  KERNEL_API "1.16" -> "1.18" (line 7).
- engine/kernel/API.md: ONE appended section, "## 24. Game cores: `ctx.cores` (class `TLCores`, addition in 1.18)",
  lines 1194-1229 of my file (appended after the last line of section 23; nothing above it touched). For the merge, by hand:
  the version lines 1, 3, 5, 6 to 1.18, and the row
  `| ctx.cores: TLCores (1.18) | the engine's game cores, ctx.cores.open("rink"); no capability (section 24) |`
  in the table of section 2 after the `ctx.cameras` row. If K3's 1.17 added a section 24, renumber mine to 25 (TLCores'
  header comment and the section's own text cite "section 24").
- docs/generated/*, docs/OWNERSHIP.md and context-map.json are NOT regenerated (restored to HEAD as you asked). In this
  tree that leaves 4 arch rules red: api-index-fresh, api-v1 (sources 1.18, file 1.16), context-map-cover (engine/cores/**
  in no context: hokej already has the `cores` context), reports-index-fresh. Proof the rest is green: with a temporary
  `cores` context and `tl arch --index`, `tl check --tier fast` was 5 of 5 PASS (arch 12/12, devx.test 229/229); then
  the five files were restored from HEAD.
- State hash: ctx.cores.state() = {"rink": {"hash", "frame", "score"}}; the probe pack engine/cores/rink/test_pack returns it
  from _pack_state, so the runner's state_hash covers the core.
- Determinism (selftest 800): rink.entry_twice (seed 3, bot hand: 11763bf0... twice), rink.entry_replay (the record
  replayed, no bot: the same), rink.window (the hand as raw key events in a real window; its own record replayed headless
  gives the window's core hashes at 5 of 5 checkpoints): PASS.
- FINDING (kernel runner, not the core): scripted --devices key events in a real-time window reach ctx.input late now and
  then: the window's record differs from the headless one at sample 3912 (frame 2235) and two window runs differ. Probable
  fix: Input.flush_buffered_events() after parse_input_event in kernel/runner/session.gd pre_sample (not applied: kernel).

ITEM 2: game-mode rules split and ported: MET (with one open proof)
- engine/cores/rink/GAMEMODE.md: 25 rules, each with thirdjam file:line and its owner. Core glue (14): the two-role
  buttons, "with the puck" incl. our pass in flight, held across a change of possession, saucer/brace hold frames (13),
  taps, bCrossHold only without the puck, camera-relative move + pull-back yaw hold, per-axis clamp, stick aim (pad /
  cursor with hysteresis + A191 anchor / hidden-cursor delta), sprint/brake levels, single-role edges, team signals 1-4
  into the brain's world, restart. Hit-stop and the shown carrier: K2's pawn (they gate no input and no sim frame:
  "presentation only: the sim steps on", HokejGameMode.cpp:1753-1775). Pause and step pacing: the shell.
- engine/cores/rink/native/glue/rink_gamemode.{h,cpp} (C++ beside the shim; thirdjam's files untouched).
- RinkCore v1.1, additions only (no v1 name changed): set_human_mode("raw") + set_raw_input({Down, Pressed, Axis,
  CameraYaw, StickAxis, CursorOnIce, CursorPx, CursorHitM, MouseDeltaPx}), set_bot_mode("brain"|"parked"), restart(),
  last_human_input(), the snapshot's "Controls".
- SNAPSHOT.md v1.1 (K2's three asks): every enum's values with source lines (ContactOutcome 0 none 1 bump 2 stumble 3 down,
  JamSim.h:717-720; Phase; StickHitResult; PokeResult; DrawResult; DekeSide; SweepSide; SpinDir; Role; Stamina; event names
  and kinds; IntentKind), InBox (and IsSpinning) in the Skaters shape line, the gym (set_bot_mode("parked")).
- Open: the glue is not yet checked against thirdjam's own Jam.Controls tests (JamGame/Private/ControlsTests.cpp: they
  drive UJamPlayerInput / FKey). Next round.
- Open: in the gym the opposing centre moves about 40 m from frame 108 with no input (wingers and backs: 0.000 m). Not
  explained yet; said in SNAPSHOT.md.

ITEM 3: thirdjam's own Jam.Core.* / Jam.Bot.* tests natively on HEAD: MET for 180 of 219 (the HEAD proof)
- 219 tests registered in HEAD's JamCore (216 in 41 test files + 3 in JamPlaytester.cpp). Compiled unchanged: 180.
  Not compiled (39): JamContactTests.cpp (36), JamStickTests.cpp (2), VisualSwapTests.cpp (1): they include JamPawns.h,
  the Unreal actor code (AJamSkater::HitStopPick / HitStopFramesFor / StumbleFramesFor / SmoothAimDeg / CallFigure,
  UClass loading). The contact law's own tests are therefore not run yet: the biggest gap of this proof.
- Runner: engine/cores/rink/native/tests/rinktest.cpp (scons tests=yes -> bin/rinktest-thirdjam.exe, not committed:
  bin/.gitignore): `rinktest-thirdjam.exe <content dir> [names] [--shard=i/n] [--list]`.
- Results (sheet: thirdjam-tests-head.txt, one line per test):
  Jam.* (Jam.Core, Jam.Bot, Jam.Rules, Jam.Effects, Jam.Playtest...): 157 of 157 PASS.
  Bar.* (thirdjam's quality bars, which its own gate does not require): 22 PASS, 1 FAIL.
    FAIL Bar.Playtest.GoodNeverIdlesAtAllStar ("all_star good seed 2: 1 spell of 15 s without a touch, longest 1267
    frames"): thirdjam's own records say the same of HEAD's game: "Bar.Playtest.GoodNeverIdlesAtAllStar still fails (1-3
    spells per seed); it stays a Bar" (thirdjam docs/experiments/PLAYTEST.md, BALANCING.md, status/A34.md). Same outcome.
    Bar.Bot.Hockey5.Stops passed last (the longest test: it was killed once with its shard and rerun whole).
  The run: 8 shards, then the crashed shard's rest and two slow shards' rests on the fixed runner; every one of the 180
  verdicts above is from a build that has both shim fixes below or (for tests that ran before the fixes) does not touch
  the fixed functions.
- Shim bugs the tests found, fixed this round: FString::ReplaceInline returned 0, not the count (6 tests failed on it;
  the simulation never calls it); TestEqual on TArrays recursed (Jam.Core.Seams overflowed the stack). Unreal-like big
  stack for the runner (16 MB). Neither touched the simulation's numbers: selftest 800 (trace_t5 = the Unreal build's
  lines; trace_head = round 2's HEAD baseline) still PASS on the rebuilt binaries.

ITEM 4: a recorded hand through the person's input path: MET for determinism; Unreal comparison NOT done
- tools/rink_rawhand.gd (selftest rink.rawhand): one scripted raw stream twice: the same FJamInput every frame (digest
  190a8498...) and the same hash (231ba574...); every verb reaches the sim (shoot held 20, lift 19, cross-hold 323, pass
  held 64, check 18, sprint 1440, poke 24, spin 4, ability 3; 7 team signals).
- tools/rink_rawtrace.gd: the reference trace of a RECORDED raw stream (K3's ask): --write-sample records a stream;
  --stream=<json> --out=<txt> replays it, one line per frame (frame, hash, score, carrier, the human's FJamInput). The
  3,600-frame recording replays to the live run's hash; two replays identical. proof/rawhand.seed5.600.stream.json and its
  trace are committed; selftest rink.rawtrace checks them (600 of 600 lines).
  K3: record your own stream as a JSON list of the dictionaries you pass to set_raw_input (Vector2 as [x, y]), then
  `godot --headless --path engine --script res://cores/rink/tools/rink_rawtrace.gd -- --stream=<file> --out=<file> --seed=N`.
  (rink.sh untouched this round, as you asked: K4 owns its end.)
- Not done: Unreal frame-by-frame for a raw stream. thirdjam has no replay of a recorded device stream (jam.ScriptHuman
  makes its input from the sim inside a rendered PIE game; the headless commandlet has no human input path). Question 3.
- Not done: thirdjam's playtester as a RinkCore seat whose decisions a shell bot presses. RunPlaytestMatch sets it up with
  about 20 switches and per-frame extras; a seat that is not bit-equal to it would be a new hand. Its own round.

GATES
- tl check --tier fast in this tree: arch FAIL only on api-index-fresh, api-v1, context-map-cover, reports-index-fresh
  (the files you regenerate); assets PASS 4/4, cards PASS 3/3, devx.test FAIL 224/229 (the same arch rules seen through
  arch.test.mjs), foreman.typecheck PASS. With those files regenerated (then restored): 5 of 5 PASS.
- selftest rink.: 8 of 8 PASS (smoke, trace_head 51/51, trace_t5 21/21 = Unreal, entry_twice, entry_replay, window 5/5,
  rawhand, rawtrace 600/600), on the rebuilt binaries.
- tl check --tier full --only kernel.selftest (the kernel changed): FAIL as a STOPPED RUN: 216 of 217 units completed,
  0 failed, killed at the step's 1800 s timeout (my 8 test shards loaded the machine for part of the run; the step's recent
  history on main: 1628 s and one earlier kill at 1800 s). Not a pass; please rerun on a quiet machine after the merge.
- Not run this round: the rest of the full tier (world, packs, seeds, perf). Round 2's packs failure (hockey invariants
  frame budget) was shown to be the same without the extension.
- Binaries rebuilt by `bash engine/tools/rink.sh build all` (debug + release DLL now include the glue; t5 CLI).

CHANGED FILES
- kernel: engine/kernel/api/tl_cores.gd (new), engine/kernel/api/tl_context.gd, engine/kernel/runner/manifest.gd,
  engine/kernel/API.md (appended section).
- core: engine/cores/rink/GAMEMODE.md (new), SNAPSHOT.md (v1.1), native/glue/ (new), native/src/rink_core.cpp,
  native/SConstruct (glue; tests=yes target), native/shim/* (test support: AutomationTest.h, HAL/FileManager.h,
  Misc/DateTime.h, ProfilingDebugging/, UObject/Interface.h, 3 generated stubs; CoreMinimal.h, ShimString.h, ShimMath.h,
  ShimObject.h, shim.cpp additions; the ReplaceInline fix), native/tests/rinktest.cpp (new), native/thirdjam/ (+ HEAD's
  41 test files, JamBrain.h/.cpp, JamBaseline.h, JamCarryDrill.h, JamContactDrill.h, JamSkaterVisual.h: verbatim),
  native/content/Designer/ (verbatim), test_pack/ (new), tools/rink_hand.gd, rink_rawhand.gd, rink_rawtrace.gd (new),
  proof/rawhand.seed5.600.* (new), bin/ (rebuilt DLLs + t5 CLI; .gitignore += rinktest-*.exe).
- engine/tools/selftest.d/800-rink-core.sh (+5 cases).
- docs/shifts/.../K1-core/: STANDUP.md, ROUND-3.md, REPORT.txt.

DEVIATIONS
1. set_bot_mode("parked") is a test stand (K2's gym), not thirdjam.
2. The glue compiles in the shipped jam.ctrl.* values (OurPuckShoots 1, HeldAcrossChange 1, SaucerHoldFrames 13,
   BraceHoldFrames 13, AimAnchor 1, AimAnchorSpeed 0.3); no console variables; default bindings only (no rebinding).
3. Signals: keys only; the teammate's acknowledgement bark and the bus event (presentation) are not sent.
4. rinktest runs thirdjam's tests with a 16 MB stack (Unreal's thread stacks are larger than Windows' 1 MB default).

QUESTIONS FOR THE DIRECTOR
1. The merge of API.md / manifest.gd with K3's 1.17 (lines above).
2. Kernel runner: apply the one-line flush in session.gd pre_sample for scripted window runs (kernel owner's call)?
3. An Unreal-side raw-stream replay (a small JamGame commandlet feeding a recorded FJamInput / key stream through
   ApplyButtons) would give K3 a frame-by-frame reference against thirdjam itself. Worth a slot (Unreal build work)?
4. The 39 tests behind JamPawns.h (36 are the contact law's): compile the pawn's static helpers through a minimal actor
   shim, or wait for K2's port of the pawn and test against that?

NEXT THREE
1. Contact tests: get JamContactTests.cpp (36) and JamStickTests.cpp compiled (the pawn helpers), and Jam.Controls tests
   against the glue.
2. The gym's drifting centre: find why, so K2's gym is one skater on still ice.
3. A playtester seat in RinkCore bit-equal to RunPlaytestMatch, its per-frame decision exposed for K3's shell bot.
