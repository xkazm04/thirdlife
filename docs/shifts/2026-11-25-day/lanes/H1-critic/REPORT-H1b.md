H1b (round 2 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 8a592cb. Opus.
Round 1 (H1) landed as fab4ba5 / 98b1f52; its report was the lane's first final message.
==========================================================================================================================
ROUND 2 (H1b), on top of main 8a592cb (merge of H1)

1. Clock failures under load no longer cost builder rounds: MET.
   - Why they still did: machine.ts restsOnAClock knew one wall-clock check, invariants.frame_budget (the p99 stage budget).
     invariants.many_budget (the budget of one pack in a world of many, on the frame MEDIAN, 1.0 ms) was not known as a
     clock, so its failure was a plain verdict: ONE run, no second run, no machine measure, straight to the builder.
     Read in the real jobs: d25-court half-court-3-v-20261125-1 events 31-32 (court_core r1 invariants s31: only
     many_budget failed, p50 1.048 ms; next event "running" round 2) and d25-robot robot-soccer-3-v-20261125-1 event 33
     (core r1 invariants s33: only many_budget, p50 1.334 ms, p99 2.754; round 2 followed).
   - Fix: CLOCK_CHECKS = frame_budget and many_budget (restsOnAClock, clockDetail). A clock-only failure is now run twice;
     if both fail, the machine is measured: FIRST room.sh's own measure (Win32_Processor LoadPercentage, mean of 3 samples;
     machine.ts cpuLoad, about 7 s): above 70 % the machine is busy whatever the reference pack says; else the reference
     pack as before. Busy -> a note, a pause, and each try again now also WAITS for the load to come down to 70 % (polling
     every 15 s, at most 10 minutes: waitForQuiet) before running; still busy after the tries -> package blocked
     machine_busy, job paused, `resume` verifies the same files. Nothing reaches the builder. A quiet machine (load and
     reference calm) still sends a real slow pack to the builder with the figures.
   - Options: machineLoad (seam; on the fake runner none), busyCpuPct (70), quietWaitMs (600000).
   - Tests: H1b 1 (G4's case: a second run passes, no round 2), H1b 1b (G2's case with the load at 93 %: tries, then
     machine_busy pause, no round 2; resume on a quiet machine promotes without the builder), H1b 1c (the try waits for
     the load: pause 20 s, one poll, then 40 % and the run), H1b 1d (slow code on a quiet machine still goes to the
     builder; restsOnAClock units). Fake runner: FAKE_RUNNER_MANY_SLOW=<n> and marker FAKE_MANY_SLOW (p50 1.048 ms).
   - Real measure checked once on this machine: cpuLoad() = 87 % in 7.5 s.

2. Create's pitch shows the estimate: MET.
   - create_model.gd estimate_words: brief_set's {packages, wallMinutes, tokens} as "About 8 hours and 6.5 M tokens to
     build (9 parts)" (hours to the half hour, under an hour in minutes; tokens in M or k). create_design.gd _pitch puts it
     (label "Estimate") under the cards, left of Redesign / Build it, above "Tap a card to change it"; no estimate, no line.
   - Selftest block 860 (engine/tools/selftest.d/860-create-estimate.sh, ui/create/create_estimate_case.gd):
     `bash engine/tools/selftest.sh create.estimate` -> PASS create.estimate.words, .pitch, .none (3 passed, 0 failed).
     The words are checked for G2's real estimate (9, 480, 6.5 M -> "About 8 hours and 6.5 M tokens to build (9 parts)")
     and G4's (10, 480, 8 M).
   - Still, looked at: lanes/H1-critic/h1b_pitch_estimate.jpg (the fixture c2-pitch, Penguin Push, 1280x720, a window):
     "About 1 hour and 1.8 M tokens to build (5 parts)" in bold cream under the six cards, beside Redesign and Build it,
     readable, nothing overlapped.
   - Not run on main: on main create_model.gd has no estimate_words, so the case script cannot load and block 860 would
     print no PASS line (a FAIL by the block's own rule); I did not build a second Godot project to show it.

3. Compact list changes in the what-changed line: MET.
   - removal.ts compactChange: a list change reads "game.rink.zones: + lane-middle, - spot-nw, - spot-ne"; a list without
     ids "game.rink.obstacles: 4 bumpers changed, size 5 -> 7, x, z"; an object "game.rules: first_to changed"; a short
     value as before ("game.rink.goal_width_m: 4 -> 4.4"). The cartridge diff note is written with it, so the
     what-changed line now ends with its files (E5e-shaped change: 279 characters instead of a cut at 1000). The diff report
     keeps the full values.
   - Test: H1b 3 (E5e's change end to end, the exact first line; scalar, object and absent cases).

4. The check cache is warmed after a lab build: MET.
   - `bash engine/tools/rink.sh check-warm`: the measured check as the Foreman runs it (--defects, with the rules file when
     there is one) of packs/hokej's thirdlife cartridge and every templates/*/data/*.cartridge.json; prints
     "PASS rink check-warm: 2 cartridge(s) in the cache (k measured now, m already there)". lab-build and
     lab-build-thirdlife run it when the exe they built differs from the one before (sha1), TL_RINK_WARM=0 skips it.
     check-cartridge no longer tries to build the real lab when TL_RINKLAB_EXE names a stand-in.
   - Test: H1b 4 (stand-in lab: 2 measured, then 0 measured and 2 there; the Foreman's house check then reads the cache
     with no lab process).
   - Not run against the real lab on main's cache: the Director can run `bash engine/tools/rink.sh check-warm` on main
     once after landing (about 90 s at 4 lab processes) so the next job starts warm.

All six H1b node tests fail on main 8a592cb (a scratch copy of HEAD with the new test files, the new fake runner and an
import shim): H1b 1 "no round 2", 1b failed verify_failed, 1c the pauses, 1d no measure note, 3 the long line, 4 no
check-warm.

GATES (each after room.sh)
- foreman npm test: 387 tests, 380 pass, 0 fail, 0 cancelled, 7 skipped (the same 7 as main: 5 need TL_GODOT, 2 need site/
  job dirs). 387 = main's 381 + the 6 new H1b tests. Log .tl/h1b/npm-test.log.
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean. Log .tl/h1b/check-fast.log.
- bash engine/tools/selftest.sh create.  (blocks 630 and 860 together): 14 passed, 0 failed, including create.page and
  create.iterate/pause paths after the pitch change and the three create.estimate cases.
- --tier full not run: no kernel, kit, rig, style or seed file changed (engine/ui, engine/tools/rink.sh, selftest.d).
- Godot: the class cache import once (it wrote only create_estimate_case.gd.uid), the windowed pitch still.

CHANGED FILES (round 2)
- foreman/src/machine.ts (CLOCK_CHECKS with many_budget, cpuLoad, waitForQuiet), foreman/src/foreman.ts (+5 lines: the
  load first in measureMachine, the quiet wait before each try, loadNow; 1998 lines, under the 2005 baseline),
  foreman/src/options.ts (machineLoad, busyCpuPct, quietWaitMs), foreman/src/testing/fake-runner-core.ts
  (FAKE_RUNNER_MANY_SLOW, FAKE_MANY_SLOW)
- foreman/src/removal.ts (compactChange), foreman/src/coregate.ts (the diff note uses it)
- engine/ui/create/create_model.gd (estimate_words), engine/ui/create/create_design.gd (the Estimate label),
  engine/ui/create/create_estimate_case.gd (+ .uid) new, engine/tools/selftest.d/860-create-estimate.sh new
- engine/tools/rink.sh (check-warm; lab-build* warm on a new exe; no build when TL_RINKLAB_EXE is set)
- foreman/src/test/h1b_hardening.test.ts new (4 tests), foreman/src/test/h1_hardening.test.ts (+2 tests: H1b 3, H1b 4)
- lanes/H1-critic: STANDUP.md, REPORT.txt, h1b_pitch_estimate.jpg

BEHAVIOUR CHANGES
- A many_budget failure is run twice; under load the job now pauses (machine_busy) where it used to spend a builder round.
  On a loaded machine a clock retry can now wait up to 10 minutes per try for the load to come down (3 tries by default).
- Create's pitch has one more line. The cartridge diff note and the what-changed line show list changes compactly (the
  full values stay in reports/<id>-r<round>-diff-s<n>.json).
- A lab build whose exe changed now spends about 90 s warming the cache (4 lab processes).
- No existing test expectation was moved.

FOR THE OWNER TO LOOK AT
- lanes/H1-critic/h1b_pitch_estimate.jpg: the pitch with "About 1 hour and 1.8 M tokens to build (5 parts)".

QUESTIONS FOR THE DIRECTOR
- After landing, run `bash engine/tools/rink.sh check-warm` once on main (about 90 s): the game lanes' next jobs then
  start with the house and base checks cached.
- Busy is "over 70 %", the day's ceiling. On a machine that other sessions keep at 85-100 % all day a real slow pack would
  wait (paused) instead of being sent back; is pausing the job the right answer then, or should the reference pack's
  verdict win over the CPU figure after the last try?
- The estimate says "parts" for packages; is that the person's word you want?

NEXT THREE
1. Show the estimate against the job's real time and tokens on the building screen (how far along, in the same words).
2. Measure the reference pack's many_budget p50 at the same moment as a second gauge (a calm pack_min p50 vs now).
3. Ask before a builder's round removes list entries (round 1's open item).
