H3 gate: report (shift 2026-11-23-day, worktree .claude/worktrees/n23-method, branch n23-method at main c4b0b83)

What changed, in one paragraph
The Foreman now always stops after a job's first phase (the greybox) for a person, also on a job started with
--run-through. Run-through passes the phases after the first itself, as before. The rule is one function,
passesItself(s, phase) in foreman/src/design_state.ts (= run_through set AND the phase is not the plan's first),
used by every place that used to read `runThrough` for a phase decision: phaseStep and waitsForVerdict
(foreman/src/phases.ts), the waiting line and the playtest card of `foreman status` (status.ts), and the next step of
`foreman explain` (explain.ts). No flag, option or designer/planner answer reaches it: the only way past the greybox
is `foreman phase <job> pass`, which writes `phase_reviewed by: "player"`.

Acceptance, one by one
1. A run-through job pauses after phase 1 (job_state paused, reason "phase") and waits exactly as a job without
   run-through; later phases run through: MET. Test "person gate: a run_through job pauses after its first phase..."
   (events end phase_done:court_plays, job_state:paused:phase; no phase_reviewed; nothing of phase 2/3 started; run
   and resume exit 3 and write no event). Test "person gate: after the person's pass..." (phase events exactly:
   done court_plays, paused, pass by player, done rival, pass by auto, done magnet, pass by auto; job done, promoted).
2. The pause says why in the person's words: MET.
   status:  waiting  phase court_plays is the greybox and waits for your hand (run-through passes only the phases
            after it): try it ("..."), then: foreman phase <job> pass   or   foreman phase <job> hold --note "..."
            followed by the playtest card (first phase: with its 30 seconds) when the brief has the method lines.
   explain: next: foreman phase <job> pass   or   ... hold --note "<what to change>"   (phase court_plays is the
            greybox and waits for your hand even with run-through; try it: "...")
   help:    --run-through: the Foreman passes the phases after the first itself; the first phase (the greybox) always
            stops for a person's hand (foreman phase <job> pass|hold), with or without it.
   Create panel: the drawer line under "Build straight through" was "No stops: you try it at the end"; it is now
   "Stops once: you try the greybox first". The panel already shows its phase screen (Play / Pass / Hold) for any
   pause with reason "phase", run-through or not (engine/ui/job_v2.gd waits_on_phase does not read run_through), so
   no logic changed there.
3. No way around it by flag or designer answers; the fake adapter and tests reach the end by giving the pass
   explicitly: MET (passesItself is the only place; the tests pass with `foreman phase <job> pass`). Two residual
   paths, both older than this lane and outside "run-through", are in the questions below (plans without phases).
4. Tests: MET. New (4, foreman/src/test/phases.test.ts):
     - person gate: a run_through job pauses after its first phase (the greybox) exactly as a job without it, says
       why in the person's words, and resume does not move it
     - person gate: after the person's pass on the greybox the run_through job runs through phases 2 and 3 (passed
       by auto) to promotion
     - person gate: a hold on the greybox of a run_through job runs its change round and the greybox waits for the
       person again (no auto pass after the round)
     - person gate: passesItself and waitsForVerdict: run_through never passes the first phase; it passes a later
       one; without run_through nothing passes itself
   Updated (2), each because it asserted the old behaviour that run-through passes phase 1:
     - phases.test.ts "phases with run_through: the Foreman passes each phase itself (by auto) right after phase_done
       and never pauses": REPLACED by the first two gate tests above (it expected exit 0 from one `run` and three
       auto passes; now the run stops at phase 1 with exit 3 and phase 1 is passed by the player).
     - n2_method.test.ts "status: the paper check before approval, the playtest card at a phase pause (first phase
       with its 30 seconds), none with run-through": its last line expected NO playtest card for a run-through job
       waiting at its FIRST phase. Now the card is shown there (the greybox waits for a hand) and the greybox waiting
       line is asserted; the "none with run-through" case moved to a run-through job waiting at phase 2 (no card,
       "run-through passes it when the Foreman runs"), plus: without run-through phase 2 does get its card.
   Not changed: quality.test.ts "loop: still NOT ok after round 2 holds the job (also with run_through)" passes as
   is (its quality pause comes before any phase decision).
   npm test in foreman/: tests 325, pass 318, fail 0, cancelled 0, skipped 7 (main: 322 + 4 new - 1 replaced = 325).
   The 7 skips are environmental and name their reason: 5 "TL_GODOT is not set", 2 "site/... is not there".
5. Create panel reads right with the gate: MET. ui selftest 206 passed, 0 failed (see Gates); the create.page check
   presses RunThrough and rebuilds the drawer with the new line. No check names the line's text, none was added.
6. contracts/JOB.md: not edited. Proposed wording below.
7. docs/design/METHOD.md: one line added at "The gate" bullet of section 10 (stage 7, the greybox): "Enforced since
   23 Nov (the owner's decision): the Foreman always pauses after the first phase for a person, also on a job started
   with `--run-through`, which passes only the phases after it (`foreman/src/design_state.ts`, `passesItself`)."
8. node devx/bin/tl.mjs check --tier fast: PASS (see Gates).

Gates
- npm test (foreman/), on the final LF files: tests 325, pass 318, fail 0, cancelled 0, skipped 7, exit 0.
- node devx/bin/tl.mjs check --tier fast: exit 0. PASS arch [12/12], PASS assets [4/4], PASS cards [3/3],
  PASS devx.test [229/229], PASS foreman.typecheck (tsc --noEmit clean).
- bash engine/tools/ui.sh selftest --repo=C:/Users/kazda/kiro/third-life: "[selftest] 206 passed, 0 failed", exit 0
  (engine = this worktree's, with the new drawer line; --repo points at the main checkout only for the gitignored
  real marble job site/marble-run-three-marbles-20261110-2, which a worktree does not have, and for foreman/dist,
  whose Foreman is main's: the Create checks drive it dry). Without --repo, in the worktree, it could not run: the
  marble checks fail for the missing job and the script then stops (a SCRIPT ERROR at selftest.gd:68), the known
  worktree case named in devx/lib/gate/steps/selftests.mjs. My first try of that was stopped by my own 600 s
  timeout under another lane's bot load; I stopped only the two Godot processes of my own selftest (their command
  line named this worktree's engine and res://ui/selftest.gd). I did not compare 206 with main's count; this lane
  added and removed no ui check.
- Not run: tl check --tier full (no kernel, kits, rigs, style or seeds changed; the lane rules ask full only then).
- No Foreman build job was started; every job ran on the fake adapter and fake runner in temp dirs.

Changed files
  foreman/src/design_state.ts   isGreybox, passesItself (the rule)
  foreman/src/joblog.ts         re-exports them
  foreman/src/phases.ts         phaseStep and waitsForVerdict use passesItself; header comment
  foreman/src/status.ts         greybox waiting line; playtest card unless the Foreman passes the phase itself
  foreman/src/explain.ts        next step names the phase command at the greybox, also with run-through
  foreman/src/cli_design.ts     --run-through help text
  foreman/src/test/phases.test.ts, foreman/src/test/n2_method.test.ts
  engine/ui/create/create_design.gd           drawer line text (+ comment)
  engine/ui/fixtures/make_create_fixtures.mjs comment only: c12-run-through is a log written before the gate
  docs/design/METHOD.md                       the one line in section 10
  docs/shifts/2026-11-23-day/lanes/H3-gate/   STANDUP.md, REPORT.txt
Not mine: the worktree shows docs/shifts/2026-11-23-night/lanes/N2-method/BRIEF.md as deleted; it was already so when
I started (git status at 09:29) and I did not touch it.

Behaviour changes
- `foreman new --run-through` jobs now stop once, after phase 1 (exit 3, status "paused (phase)"), and need
  `foreman phase <job> pass|hold`. A hold on phase 1 runs its change round and stops at phase 1 again (no auto pass).
- Old logs whose phase 1 was passed `by: "auto"` still replay as they are (the reader does not reject them; the
  Create fixture c12-run-through is such a log and its check still reads "3 auto passes").
- The Create drawer text with run-through on: "Stops once: you try the greybox first".

What the owner should look at, and how
- Start a job from the Create panel with "Build straight through" down (or `foreman new "<sentence>" --run-through`,
  approve, plan, run): it must stop after the greybox with the phase screen / `foreman status` waiting line, and only
  his Pass moves it on; after that it runs to the end without stopping again (unless the critic holds quality).

Proposed contracts/JOB.md wording (Director-only; no new event or reason: the pause stays reason "phase")
- Line 275, replace with:
  - `job_created.run_through` (optional): `true`. Absent = the Foreman stops after every phase and waits for the
    player. With it the Foreman passes every phase after the first itself; the first phase (the greybox) always waits
    for the player (the person gate, 2026-11-23).
- Lines 296-297, replace the last sentence with:
  Unless `run_through` is set, the job then waits: `job_state {state: "paused", reason: "phase"}`. After the first
  phase it always waits, also with `run_through`.
- Lines 301-302, replace the last sentence with:
  With `run_through` the Foreman writes `phase_reviewed {verdict: "pass", by: "auto"}` itself, right after
  `phase_done`, on every phase but the first; the first phase is passed only `by: "player"`. A log written before
  2026-11-23 may carry an auto pass on its first phase; it reads as written.
- Line 313, replace with:
  - The pause written after `phase_done` without `run_through`, and after the first phase's `phase_done` with it, is
    `job_state {state: "paused", reason: "phase"}`.

Questions for the Director
1. Plans without phases have no greybox pause at all, with or without run-through (unchanged by this lane): a
   hand-written `foreman plan --from` may omit `phases`, and a re-plan that leaves fewer than two phases
   (replanPhases in phases.ts) drops them mid-job, after which the job runs to promotion with no person stop. The
   v2 Planner always writes phases (requirePhases). Should a phaseless job stop once before promotion for a person,
   or should a re-plan during an unpassed greybox keep the greybox as its own phase? Both are JOB.md decisions.
2. The Create fixture c12-run-through (engine/ui/fixtures) still shows a pre-gate run-through log (three auto
   passes). Regenerate it to the new shape (phase 1 by player) and move its check, or keep it as the "old log reads
   as written" case? I kept it (scope: UI text only).

Next three things this lane would do
1. Land the JOB.md wording above (Director) and, if wanted, a reader warning on an auto pass of the first phase in a
   log written after 2026-11-23.
2. Close question 1: a person stop for phaseless plans, or keep the greybox through a re-plan.
3. Regenerate c12-run-through with a player pass on phase 1 and add a Create check that a run-through job at its
   greybox shows the phase screen (Play / Pass / Hold).
