H1j (round 10 of lane H1, the last of the day), 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 71a8c0a
(75bcf55 plus your JOB.md lines). Opus. Your answers to H1i, on G5's real bumper-kart job (d25-kart, read only, live):
events to 411 are in foreman/fixtures/h1i/ and events 412-481 are copied into foreman/fixtures/h1j/. Both tests fail
on main 75bcf55 and pass now.

1. Every Resume grants one more hand-check send-back: MET.
   - handcheck.ts sendBackHands: the send-back is spent once per promotion or change request, as before, and now
     also once per resume of a failed job (job_state running "resumed (was failed)").
   - Test: H1j 1, on G5's real events.
     - Up to 411, the send-back of event 352 is spent (false, as G5 met it at 461).
     - With the resume at 412 it is granted again, and core, which registers tests/bot_hand_perfect.gd, is re-opened.

2. A change request on a failed job, against the new Resume: CHECKED; the change wins.
   - What happened in G5 (events 461-481):
     - the job failed again at 461;
     - the person sent a change at 462 and `foreman change` resumed it at 463, without --retry-failed;
     - the Planner gave the change to core, and core's round 12 ran in the workspace where round 11's fix of the hand
       test still waited;
     - its merge (480) carried both: tests/bot_hand_perfect.gd and the bump.
   - The conflict is Resume (--retry-failed) with a person's change waiting. Resume would set core verifying at round
     11 while the change waits for core.
   - Decision: the person's change wins.
     - resumefix.ts sends nobody back while a change request is pending.
     - The change's round runs in the same workspace, so the waiting fix rides along (as G5's r12 shows).
     - After it, the final checks and the hand check run again, and a change request grants its own send-back.
   - Why: sending the package back first would hold the person's change behind a verification of the old fix. The
     change round costs a builder anyway, and it carries the fix.
   - Test: H1j 2:
     - at 462, with the change pending, Resume adds nothing;
     - at 461, with no change, Resume sets core verifying at round 11;
     - the real merge at 480 holds both the hand test and scripts/core/kart.gd.

3. DAY.md: WRITTEN (lanes/H1-critic/DAY.md, 32 lines). What H1 changed today, H1 to H1j, in a person's words, each with
   the real job that asked for it.

GATES (each after room.sh; logs in .tl/h1j/)
- foreman npm test: 435 tests, 428 pass, 0 fail, 0 cancelled, 7 skipped (the same 7). 435 = main's 433 + the 2 H1j tests.
- node devx/bin/tl.mjs check --tier fast: PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, typecheck clean.
- Not run: create. (no Create file changed), --tier full, world and k.sh (no kernel, kit, rig, style, seed or runner file).
- Before-run: both H1j tests FAIL on main 75bcf55 (a scratch copy with the test and the fixtures).

CHANGED FILES (round 10)
- foreman/src/handcheck.ts (one condition)
- foreman/src/resumefix.ts (the change wins)
- New:
  - foreman/src/test/h1j_hardening.test.ts (2 tests)
  - foreman/fixtures/h1j/g5-412-481.jsonl
  - lanes/H1-critic/DAY.md
- lanes/H1-critic: STANDUP.md, REPORT.txt
- No contract, kernel, Create or runner file changed. JOB.md's --retry-failed paragraph may want one clause: "a waiting
  change request goes first; then nothing is sent back".

QUESTIONS FOR THE DIRECTOR
- None new. Open from earlier rounds: dusk (the night rig, tomorrow), and the timer game's missing clock (G1).
