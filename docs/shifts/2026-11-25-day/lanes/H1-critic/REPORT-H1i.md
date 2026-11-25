H1i (round 9 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 86cf870.
Opus. G5's failed bumper-kart job, your answer to H1h (cards name the bounds a choice lifts), and your 20:00 sharpening of
item 1. Every item has a test that fails on main 86cf870 and passes now. G5's job was read in place, read only; the
events up to 411 (before its change request at 462) are copied into foreman/fixtures/h1i/.

1. A failed game can resume with the fix: MET (the Create card and the Foreman path).
   - Create:
     - A failed job's card (moved whole from create_build.gd into the new layer create_fail.gd, because create_build.gd
       is near its size budget) offers "Resume" ("keeps the work so far") beside "Try again" ("starts a new game from
       your sentence").
     - Resume runs foreman_door.gd's new resume_failed: `foreman resume <job> <run flags> --retry-failed`.
     - A job that failed while designing, with no plan to pick up, keeps only Try again.
   - The Foreman (your 20:00 note), in the new resumefix.ts, called from runOpen in place of the old --retry-failed loop:
     - Failed and dependency-blocked packages are queued again, as before.
     - When the job failed on a hand check, the package that registers the failing test goes back to work:
       a) if a builder round of it answered ok after its last merge and its workspace is still there (a waiting
          unmerged fix), that round is set verifying again. The Foreman checks the workspace as it is and does not run
          the builder. In G5 this is core r11, the fix of bot_hand_perfect.gd that the possession bound refused. Since
          H1h, the person's answer lifts that bound.
       b) otherwise the package is re-opened with the hand check's rows ("hand check failed (on resume) ...") for one
          new round.
     - Then the final checks and the hand check run again.
   - Tests:
     - H1i 1, on G5's real events to 411 and its hand-checks-s410.json:
       - the old path queued nothing (core is "promoted");
       - now core is set verifying at round 11 with the words of why;
       - the fold reads that as a built round left verifying, so the builder is not paid again;
       - with no workspace, core is re-opened with the hand check's rows.
     - Block 864 (create.failed.card, .words, .resume, .package; ui/create/create_failed_case.gd + .uid).
       - create.failed.resume: Resume sends `foreman resume <job> --adapter fake --retry-failed`.
       - main's card fails all four: no Resume, and the log's line shown as the reason.
   - Still: lanes/H1-critic/h1i_failed_card.jpg, G5's real reason on the card. It reads "This build stopped / Every
     part was built, but the last check plays your game with a bot hand, and it could not tell who won. Nothing was
     released." with Resume and Try again under it.

2. Cards name the bounds a choice lifts: MET.
   - v2.ts: AspectAlternative gets an optional `lifts`, a list of tofu metric ids, at least 1, unique, snake_case.
     Absent means omit the key, never []. The same is in prompts/brief.schema.json, the Designer's answer schema.
     foreman/data/job-events.schema.json is regenerated.
   - The Designer prompt (designer.md) lists the build's tofu check ids ({{tofu_ids}}, from the template's rows) and
     says when an alternative lifts them. designerProblems refuses an id that is not a tofu check of this build.
   - boundlift.ts: a chosen alternative with `lifts` lifts exactly those rows ("your card "<title>" (it lifts
     possession_median_f)"). An alternative without `lifts` falls back to the H1h word rule.
   - Test: H1i 2 (G5's brief with a neutral-titled alternative carrying lifts; the wire is valid and an empty list
     refused; the prompt names possession_median_f; an unknown id is a Designer problem; the word fallback still lifts
     G5's real card).

3. A failed job's reason in words: MET (on the same card; test create.failed.words).
   - create_fail.gd fail_words:
     - a failed part reads "The builders could not get "<title>" to work: its checks kept failing / it ran out of tries
       / ...";
     - the final-check reasons in words: the hand check ("... could not tell who won"), the final verification, a
       refused promotion (errors in a window), no builders, missing files, the limit;
     - otherwise "It stopped before it was done."
   - No ids, no report paths, no log lines.

LINES FOR contracts/JOB.md (yours to word; I did not edit the contract)
- Where JOB.md describes the v2 brief's aspects and their alternatives (next to `needs` and `hours`):
  "An alternative may carry `lifts`: a list (at least one, unique) of the ids of the plan's tofu checks that the choice
  makes meaningless (for example `possession_median_f` for a ball nobody holds). The Designer writes it. When the person
  picks that alternative (`aspect_reacted` with its id as `choice`), the Foreman does not judge those checks, at a
  round's acceptance or at the milestone look, and says so in a note that starts `[foreman] plan bound lifted`. Absent
  means the choice lifts nothing by name; never []. An id that is not a tofu check of the build is refused in the
  Designer's answer."
- Where JOB.md describes `foreman resume --retry-failed`:
  "On a job that failed on a hand check, --retry-failed also sends the package that registers the failing test back: a
  round of it whose builder answered ok after its last merge, with its workspace still there, is verified again as it
  is (`package_state verifying` at that round; its builder is not run); otherwise it is re-opened with the hand check's
  rows (`reopened` reason starting `hand check failed (on resume)`)."

GATES (each after room.sh; logs in .tl/h1i/)
- foreman npm test: 433 tests, 426 pass, 0 fail, 0 cancelled, 7 skipped (the same 7). 433 = main's 431 + the 2 H1i tests.
- node devx/bin/tl.mjs check --tier fast: PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, typecheck clean.
- bash engine/tools/selftest.sh create.: 29 passed, 0 failed (25 + block 864's four create.failed.* cases).
- Not run: --tier full, world and k.sh. No kernel, kit, rig, style, seed or runner file changed.
- Before-runs: both H1i npm tests FAIL on main 86cf870 (a scratch copy with the tests, the fixtures and a shim of main's
  retry behaviour), and block 864's create.failed.* FAIL with main's card.

CHANGED FILES (round 9)
- New:
  - foreman/src/resumefix.ts
  - foreman/src/test/h1i_hardening.test.ts (2 tests)
  - foreman/fixtures/h1i/ (G5's events to 411, hand-checks-s410.json)
  - engine/ui/create/create_fail.gd (+ .uid)
  - engine/ui/create/create_failed_case.gd (+ .uid)
  - lanes/H1-critic/h1i_failed_card.jpg
- Changed:
  - foreman/src/:
    - foreman.ts (runOpen's retry loop is now one line; 1999 lines)
    - v2.ts
    - designer.ts
    - boundlift.ts
  - foreman/prompts/designer.md and brief.schema.json
  - foreman/data/job-events.schema.json (regenerated)
  - engine/ui/create/create.gd (it extends create_fail.gd) and create_build.gd (the card moved out)
  - engine/ui/foreman_door.gd (resume_failed)
  - engine/tools/selftest.d/864-create-settle.sh (the create.failed.* cases)
- lanes/H1-critic: STANDUP.md, REPORT.txt

QUESTIONS FOR THE DIRECTOR
- After a resume that verifies a waiting fix, if the hand check fails again there is no further send-back: the one
  send-back for that failure was spent before the job failed. Should every resume grant one more send-back?
- G5 sent a change request (event 462) on that job after it failed. That path is not touched here; I can check it
  against the new resume next round if you want.

NEXT THREE
1. Dusk, once the night rig is exported (tomorrow).
2. One send-back per resume (if you want it).
3. The clock that a timer game does not show (G1 finding 20).
