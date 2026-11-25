H1c (round 3 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main f2753e3
(merge of H1b). Opus. From lane G1's real Arsenal job (d25-arsenal, .tl/jobs/three-against-three-hockey-20261125-1,
PROOF-G1.md, read only). Rounds 1 and 2 are REPORT.md and REPORT-H1b.md.

1. The measured check says what each toy is worth: MET.
   - check_cartridge.mjs --toys (the Foreman now passes it; rink.sh check-warm too). The toys a person sees, each played
     with and without, the same seeds paired:
       the F ability (the same cartridge, the hand without F, -remove=ability);
       the pickups (a copy without them, the spots they sit on and the abilities only a pickup grants);
       each other zone kind (a copy without those zones and the effects that fire on them).
     A copy thirdjam's validator refuses is named, not measured.
   - The hand: thirdjam's regular playtester with sprint, 20 seeds at pro. Not the planning hand the brief names: it never
     presses F, and K8's CHECK-CARTRIDGE-NOTE.md says its copies of the game are not valid with zones, pickups or effects.
     The playtester is the hand G1 measured with.
   - A toy that changes no match, or one within 5 points of wins and half a goal, is a warning ("toy: ..."). The Foreman
     turns it into a person's line (rinkjudge.ts toyLines) on the run (run.toys); the phase pause's report carries it;
     Create's measured card shows up to two (create_model.gd measured_view "toys", create_pause.gd Toy0/Toy1).
   - Real lab, G1's cartridge (foreman/fixtures/h1/harbour.g1.cartridge.json, copied from the job's pack):
       the F ability (shield, slow_puck): pro 8/20 with, 8/20 without, paired goal difference +0.2, F pressed 1.6 times a
         match: G1's own table to the figure (pro 8/20 both ways, +0.20, 1.6 presses) -> warning;
       the pickups (speed, precision): 8/20 and 8/20, +0.1 -> warning;
       the fast-ice zones (4): 8/20 with, 11/20 without (-15 points, -0.6 goals);
       the slow-ice zones (2): 8/20 with, 13/20 without (-25 points, -1.2): both change matches, and both cost the hand.
   - Time added, same machine, no cache, pool of 4: 7.2 s without toys, 19.5 s with (+12.4 s: five more cells of 20
     matches). Inside the cache (its key now holds the toy runs and their copies, v2) and inside the pool of 4.
   - Tests: H1c 1 (the Foreman's runRinkCheck through rink.sh on G1's cartridge with the stand-in lab: the toy lines, the
     toy cells inside the cache, the same again from the cache); selftest block 861 create.toys.model, create.toys.card.
   - Still, looked at: lanes/H1-critic/h1c_pause_toys.jpg. The pause's Measured card shows "The F ability: changes little
     (8 of 20 wins with, 8 without)" and "The pickups: changes little (...)" in amber under the goals and the match
     length, beside Try it / Pass / Hold. Nothing is cut.

2. The measured check judges the game's cartridge, not a drill file: MET.
   - The decision: the check judges the cartridge the game plays, the one data/match.json or data/skin.json names
     (`cartridge`). Every changed cartridge is still validated. A drill or test cartridge beside it is named in a note and
     never refuses a round:
       "not the game's cartridge: data/drill_slush100.cartridge.json (validated, not measured): the measured check judges
        the cartridge the game plays, data/harbour.cartridge.json, named by data/match.json".
     A refusal says which file it judged and which it did not. With no cartridge named, every changed one is judged as
     before. coreroute.ts playedCartridges; gameCartridges (the look, the phase pause, the cartridge diff) prefers them too.
   - Test: H1c 2 with G1's two real files (harbour, drill_slush100): the drill alone gives no refusal, no measurement and
     the note; both changed with the game's failing gives a refusal that names data/harbour.cartridge.json and the drill.
   - Not changed: the builder still cannot run check-cartridge itself (G1 event 42); and the game's 6.8 goals in 1.5 min
     at pro passed the gross-defect band (lane E3d's band, not this item).

3. The critic no longer pushes drawings against the simulation: MET.
   - quality.ts coreMotionAsk: on a game on a core, when the critic's worst reason (its first note) asks the bodies for a
     reaction (bounce, recoil, knock-back, thrown back, stagger, stumble, pushed away), the look is
     held for the person at once, like a base-owned reason; no revise round. The card says: "the critic asks the bodies
     for a reaction the rink core does not do (recoil); a package could only draw a body away from where the core has it,
     and the player would then be hit by a body he does not see, so no revise round was spent. Play it and keep it, or ask
     for the reaction in words (it is a change of the core)". A retry the person asks for still runs a round.
   - Every other revise round on a core carries the line DRAW_TRUE: "draw them where the core has them, never away from it
     (no drawn bounce, recoil or stand-off the core does not do). A reaction the core does not do is the person's call ...".
   - Test: H1c 3, with G1's real first critic note of look 1 (critic-greybox-s88: "no flare, hold, recoil or fall").
   - Not a hit-stop: a pause of the picture a package can draw true; E3f 3 keeps "no hit-stop" a revise round (a first
     version of this rule caught it and failed E3f 3; the rule was narrowed, not the test).
   - Why one revise round was thrown away (events 126 to 165): both looks filmed the same frames (follow and top f920,
     f2760, bot_harbour f108/f137, strips f98/f127), so the comparison was like with like. Round 4 lost because its own
     drawing changes (hit_stop_f 5, throw_m 1.8, a new contact test) no longer showed a reaction at the filmed contact; the
     critic saw "the rival overlap the beads with no visible bounce" (critic_compare-a1-s164: keep previous). The round was
     spent chasing, by drawing, a body reaction the core does not do. With item 3 neither revise round runs on this reason
     (about 22 of the 46 minutes, by G1's count).

4. A sentence clause that orders a core patch gets a question card: NOT DONE (a contract question, below).
   - Where the order comes from: the base README in the Designer's reference says a game "that needs another body or
     another ball needs a core patch (lane K1)"; the design review asked for it ("Deliver the dropped field: order the core
     patch", event 8); the Designer then wrote "Ordered core patch" into one card's detail (event 10).
   - Why not done: a question before a plan exists has no package to hang on (JOB.md's `question` needs one), and the
     brief has no field that marks an aspect as needing engine code. Both are contract changes.

All three H1c node tests fail on main f2753e3 (a scratch copy of HEAD with the new test file and fixtures and an import
shim): H1c 1 no toy lines, H1c 2 "a drill alone is not the game: no refusal", H1c 3 "no revise round".
Block 861 cannot run on main (no toys in measured_view, no Toy0 label): not run there.

GATES (each after room.sh)
- foreman npm test: 390 tests, 383 pass, 0 fail, 0 cancelled, 7 skipped (the same 7 as main). 390 = main's 387 + the 3
  H1c tests. Log .tl/h1c/npm-test-2.log. Honest note: the run before it ended "1 fail": foreman.test.js's after-hook
  could not delete a kill test's temp dir (EPERM on Windows, every test in the file passed, the CPU was at 81 %). Run
  alone it failed the same way once, then passed 15/15 twice; main's copy passed it once. I read it as a Windows file
  lock in cleanup, not a test of this change, and the full rerun above is clean.
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean. (The first run failed arch: coreroute.ts 620 of its 600 lines; playedCartridges moved to a new
  foreman/src/played.ts, 600 now. Log .tl/h1c/check-fast.log.)
- bash engine/tools/selftest.sh create.  (630, 860, 861): 16 passed, 0 failed.
- --tier full not run: no kernel, kit, rig, style or seed file changed.
- Godot: one class cache import (it wrote only create_toys_case.gd.uid), the windowed pause still.
- Real lab: G1's cartridge with and without --toys (no cache), 7.2 s and 19.5 s.

CHANGED FILES (round 3)
- engine/cores/rink/lab/check_cartridge.mjs (--toys, --toy-seeds; cache key v2), engine/tools/rink.sh (check-warm --toys)
- foreman/src/rinkjudge.ts (ToyFigure, toyLines), foreman/src/coreroute.ts (--toys, run.toys, gameCartridges),
  foreman/src/played.ts new (playedCartridges), foreman/src/coregate.ts (the played cartridge, NOT_THE_GAME, the refusal's words),
  foreman/src/quality.ts (coreMotionAsk, CORE_MOTION, DRAW_TRUE)
- engine/ui/create/create_model.gd (measured_view toys), engine/ui/create/create_pause.gd (Toy0, Toy1)
- new: engine/ui/create/create_toys_case.gd (+ .uid), engine/tools/selftest.d/861-create-toys.sh,
  foreman/src/test/h1c_hardening.test.ts (3 tests), foreman/fixtures/h1/harbour.g1.cartridge.json,
  foreman/fixtures/h1/drill_slush100.g1.cartridge.json
- foreman/fixtures/h1/fake-rinklab.mjs: the F ability changes nothing there (as G1's shield), press counts, the idle and
  skating-only hands lose
- lanes/H1-critic: STANDUP.md, REPORT.txt, h1c_pause_toys.jpg

BEHAVIOUR CHANGES
- Every measured check of a cartridge with toys is about 12 s longer cold (G1's: 7 s to 19.5 s); cached, nothing. The cache
  key changed (v2), so the first check of each cartridge after landing measures again: run `rink.sh check-warm` once.
- A drill or test cartridge no longer refuses a round; the note names it.
- A worst critic reason that asks the core's bodies for a reaction holds the job for the person instead of a revise round.
- No existing test expectation was moved.

QUESTIONS FOR THE DIRECTOR
- Item 4 needs one of two contract changes (JOB.md): (a) a design-time question (a `question` with no package, shown on
  the pitch: "This needs new engine code, about N hours more. Or I can do it with data only: <alternative>"), or (b) an
  optional aspect key (for example `needs: "core"` with `hours`) that Create shows on the card and in the estimate line,
  with the Designer told to give such an aspect a data-only alternative. Which do you want? (b) is smaller.
- Should the base README's line "needs a core patch (lane K1)" stay in the Designer's reference? It reads as an
  instruction to order one.
- The two zone kinds of G1's game COST the hand 15 and 25 points of wins. Should "a toy that costs the player" be a
  warning too, or is that the game's design?

NEXT THREE
1. Item 4, once the contract shape is chosen.
2. Let the builder run the measured check on its own cartridge (G1 event 42: not among the job's allowed commands).
3. A toy that costs the player as a warning, if you want it.
