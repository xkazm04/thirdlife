E4b: the pauses a person answers in Create, and a data-only change in under 3 minutes (night of 24-25 Nov 2026)
Tree .claude/worktrees/hk-create at hokej f85a082; nothing committed (the Director lands).

1. A builder's question: MET.
   Create's building screen shows a card "A builder asks you" (about "<package title>"): the question in its own words,
   its options as chips (create_model.gd question_options: list lines "- x" / "1. x" / "a) x"; else the two sides of
   "..., or ...?"; else Yes / No for a "May/Can/Should ...?" question), and an answer box. A chip fills the box; Answer
   sends `foreman answer <job> <package> "<words>"` then `resume` (foreman_door.gd answer: the path the Foreman already
   had; the builder's next round reads "Answer to your question:"). The page then says "Your answer is sent: the builders
   go on" until the log answers. Continue is no longer shown on a question (it could not answer it).
2. A quality hold: MET.
   A card "The critic is not happy yet": the critic's reasons in words (up to 3; the score row and slop tags left out),
   the still it judged (the held milestone's first capture on disk), and three choices:
     Fix it            `foreman quality <job> retry --note "the person asks for one more try"` + resume (one more revise
                       round; quality.ts sends it to the package it names, E5's rule: never the base)
     It's fine, go on  `foreman quality <job> accept --note "the person plays it as it is"` + resume
     Change it         a box for the person's words, then `quality accept --note "the person changes it instead: <words>"`
                       + `foreman change <job> "<words>"` (the request, then the run: E4's change path, cartridge diff first)
   foreman_door.gd quality() and quality_change(); refused while a Foreman holds the job. Continue is not shown on a hold.
3. A data-only change in minutes: MET on the fake adapter; real estimate about 2.8 min.
   Where E5's 14.5 min went (its job log, after "make it faster"): diff + two measured checks 50 s; then 13 bot runs
   (3 to 64 s each), 10 smokes (12 s), lints (1 s) and 4 promotion captures (40 s at the first frame, 110-120 s at the
   later one). The bots were: the round's acceptance (2), every pack test on the merge candidate (3), the dependants'
   re-verification, the whole final verification (every bot again on the same files) and the hand checks.
   foreman/src/fastchange.ts: a merge on a core game after its first promotion whose files are all data (cartridge,
   rules sidecar, skin: coreroute.ts CORE_DATA_RE) skips the pack tests, the dependants' re-verification and the
   milestone's re-look; a promotion whose merges since the last one were all data runs lint + smoke as its final
   verification, no hand checks, and ONE capture (the first camera, the first frame). A diff round's acceptance keeps lint
   and the player check's bot (the measured check has just played the changed cartridge at every level). Kept: the
   measured check (before and after), the merge gate (lint, smoke on exactly the pack that is promoted), one look. Every
   skip is a [foreman] note ("data-only change ..."). Anything touching a script, a test or the base goes the whole way.
   Measured (foreman/src/test/e4b_fast_change.test.ts, the E3 route driven as Create drives it, fake adapter + fake
   runner): runner calls from the request to the new promotion 19 -> 7 (lint 4 -> 3, smoke 3 -> 2, bot 8 -> 1, capture
   4 -> 1); 1.8 s on the fake runner; the new version plays the diff (skater.speed 14).
   Real-adapter estimate from E5's own per-verb times: 50 s (diff + measured checks) + 1 s lint + ~60 s player-check bot
   + 1 s + 12 s (merge gate) + 13 s (final lint + smoke) + ~40 s (one capture) = about 177 s, 2.9 min. Not yet run with
   the real adapter (no paid job in this round).
   Lines touched in foreman.ts: the import (one line after grow.js), the acceptance loop (roundAcceptance), the pack
   tests loop (fastMerge), the tail of mergeAndGate (a data-only re-merge: note, no reverify, no milestone), finish()
   (fastPromotion: the note, fastFinal, no hand checks, one capture), a new lastReopened() and captureSet's `one` flag.
   foreman.ts 1975 lines (ratchet 2005).

Proof
- Headless, real Foreman processes through the door in the exe's layout (781's way): selftest block 782-create-pauses.sh,
  create.pause.path 9/9: the quality card (reasons) -> Fix it -> the hold again -> It's fine -> phase pass -> the
  question card (its words, 2 options) -> tap the second -> Answer -> another hold -> Change it ("the rallies are too slow:
  make the court smaller") -> ... -> done, promoted, and the person's words are a change request in the log.
  ui/create/stage_pauses.gd (stage.gd --mode=pauses), the job from `node foreman/dist/testing/grow-steps.js <dir> --pauses`.
- Dry checks (ui.sh selftest and kernel selftest 630): create.pause.question (the card, options of three kinds, the exact
  answer + resume line), create.pause.quality (reasons without the score row, the still on disk shown, the three exact
  command lines).
- Stills (windowed run of the same mode, 1280x720, looked at): lanes/E4-iterate/stills-e4b/
    pz-01-question, pz-02-question-option (a chip in the answer box), pz-03-answer-sent, pz-04-quality-hold,
    pz-05-quality-change, pz-06-done. The fake runner's captures are 1x1 pixels, so the hold still in pz-04 is empty; the
    still itself is shown and checked in create.pause.quality with a real picture.

Gates: npm test 352 (345 pass, 7 environmental skips, 0 fail); tl check --tier fast PASS 5/5; ui.sh selftest
--repo=C:/Users/kazda/kiro/third-life 215 passed, 0 failed (212 + my 2 + 1 landed meanwhile); selftest.sh create. 11/11.

Not done / for the Director
- A question asking for a scope change (E5's "can those two files be added to this package's scope?") is answered in
  words only; `foreman answer --change <package>` (yes, that package may change) is not offered as a choice.
- The skips in (3) are a contract change of the final verification (JOB.md "Added after P10": a merge after a promotion
  goes through the whole final verification). Proposed wording: "On a game on a core, a change whose merges since the
  last promotion touched only the game's data (cartridge, rules sidecar, skin) is promoted after the round's acceptance
  (a cartridge diff round: lint and the player check), the merge gate, and lint + smoke on the pack; the pack tests,
  the dependants' re-verification, the milestone's re-look and the hand checks are skipped, each said in a [foreman]
  note, and the promotion takes one picture." Director-only.
