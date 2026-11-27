T-tofu: the tofu gate stops bending games (night of 27 Nov 2026, 03:02-04:15)
Tree d25-hard-a, branch n27-tofu (from main e66eb94e), not committed: the Director lands.

OUTCOME AGAINST THE BRIEF

1. A person-asked change that breaches a balance bound is built as asked and promoted, with a plain-words note: MET.
   - Real job (copy of shield-wall-3-v-20261125-1 in .tl/jobs/), change event 644, 03:47:
     "Make the Gulls' slam brutal and unfair on purpose: ... triple damage to my captain, floors him for three full
     seconds, ... slam again after two seconds instead of five ..."
   - core r15 (one round, no refusal) moved four bounds out: skill_variants 2 (>= 3), pressure_waves 1 (>= 2),
     lead_change_share 0 (>= 0.3), close_rounds 0 (>= 1). The gate did not refuse it.
     It wrote event 656: "[foreman] balance moved by your change: built as you asked; the gulls side now wins 3 of 3 of
     the Foreman's test rounds (was 2 of 3). Say "make it fairer" to tune it." plus a line with the figures.
   - v0.1.6 PROMOTED 04:08, 21 min after the sentence (event 693). The what-changed card carries the same line.
   - Create: Model.change_note on the real job (Godot headless, .tl/n27/create_note.gd) returns "Built as you asked;
     the gulls side now wins 3 of 3 of the Foreman's test rounds (was 2 of 3). Say "make it fairer" to tune it."
     The done screen shows it under the title (ChangeNote label).
   - The ability when played: stills/v016_slam_side_strip.jpg (side camera, frames 5800-5866). A Gull leaps about two
     metres, lands, a ring of gold stone slabs bursts out, and the blue fighter is thrown. In the tofu bot's v0.1.6 run
     the gulls win all 3 rounds (loser left 64 %, 59 %, 100 %).
   - How a touched bound is told from one the person did not touch (boundlift.ts, changeKind / rowCall):
     - The person's words are read clause by clause.
     - A PLAY change (an ability, a rule, a speed, any words the Foreman cannot place) moves the balance rows
       (skill_spread, skill_variants, lead_change_share, close_rounds, pressure_waves, possession_median_f). They are
       not judged, and the person gets the note.
     - A VIEW change (camera, HUD, plate, buttons, hints, with sky or colour clauses beside them) skips the balance
       rows.
     - A LOOK-only change, and a FAIR change ("make it fairer", "balance", "too strong"), keep the balance rows as a
       guard.
     - Every other row still guards: feedback_f, tells, idle rivals, verbs_used, contacts, spacing. The exception is
       when the person's words name what the row measures: launch, tumble or knockdown words for idle_max_f; fast,
       dash or charge words for tells; crowd or tackle words for spacing.
     - A guarding row that was already outside its bound before the change is not this change's regression. It is not
       judged, and a note says so.
     - A guarding row that regresses is still refused. The builder is told to keep what was asked and never add a
       hidden rule. Tests N27 2 and 3 cover this: feedback_f 9 on a hammer change is refused, and a look change that
       makes the rounds one-sided is refused.
     - Before the first version (the tofu stage) nothing changes.
   - The card's hand checks follow the same rule (handcheck.ts personAsked; tests N27 7):
     - in a play change, a win count outside the card's bound becomes the same note ("a newcomer player now wins 6 of
       20 (was 15 of 20) ...");
     - a view change skips it;
     - a look or fair change guards as before;
     - the idle hand (a player who does nothing must not win), an unfinished run and an unread `won` always guard.
   - The Director's live cases are covered by test or by reading the sentence:
     - J4 dunk, refused on skill_spread 1 and skill_variants 2: both are balance rows and the dunk is a play change,
       so it would now be a note (test N27 2 uses the dunk sentence).
     - J11 barrel roll, refused on skill_spread 0.0989: a play change, so a note.
     - J2 hammer and J5 aerials: both read as play.
     - On skill_spread above 0.95 (J4): the row's own definition calls 1.0 "a variant that never works: that is a
       different verb, not skill". It is not a guard worth keeping for a person-asked ability. It stays a balance row:
       a figure for the person, never a refusal in a change.

2. Builders cannot change the Foreman's measures: MET for the tofu bot. The hand tests are NOT frozen yet.
   - handcheck.ts keepMeasures/measureTests puts back the plan's tofu bot and every test script it loads
     (load_script, preload or load of tests/..., so J11's tests/support/pilot.gd is included) from pack/, right after
     the out-of-scope drop and before verification. It names them in a note: "[foreman] measure kept: <files> are
     measures the Foreman judges by ...".
   - It applies from the files' first merge on, so the builder still writes them in the tofu stage's first round.
   - Test N27 5 covers this: a bot_tofu.gd edit (G19 r5) and a pilot.gd edit (J11 r16, roll share 0.5 -> 0.6) are both
     undone.
   - Not frozen: the card's hand tests. The fake runner's fixtures (hands.test.ts 4 and 6) "fix the game" by rewriting
     the hand test, and freezing it failed both tests in my first full run (450/441/2). I took the hand tests back out
     rather than change those tests. Freezing them needs the fake runner to read its wins from a game file.
   - Packs on a core (Arsenal): the measured check is engine/cores/rink/lab/check_cartridge.mjs. It reads only the
     cartridge and rules file the Foreman passes it; its bands file and binary sit in the engine, and no builder
     workspace holds them. Nothing there for a builder to edit.
   - Not live-proven: no builder touched the tofu bot in tonight's real job, so there was no "measure kept" note.

3. No hidden rules to pass a bound: MET, both ways.
   - Forbidden: builder.md has a new rule. A person's change is built as asked; never add a hidden probability,
     multiplier, comeback or rubber band to move a measure; a rule the person did not ask for goes under DEVIATIONS on a
     "RULE:" line.
   - Surfaced: the what-changed card (fastchange.ts) lists every builder line since the last promotion that adds a rule
     nobody asked for, as "unasked rule (the builder's words; you did not ask for it): ...". It catches the RULE: lines
     and the 25 Nov wordings: probability, "2.0 times damage", comeback, "not in the contract", "nothing on screen
     announces". Test N27 6 runs on G19 r12's real note.
   - Live: both real changes' builders wrote RULE: lines. The cards of v0.1.5 (event 640, 3 unasked rules) and v0.1.6
     (event 691, 2) list them. Examples: "the slam floors only the slammer's rivals, never its own side"; "Gulls never
     slam during the round-1 lesson"; "triple damage needed a base. I set it at 6".

4. Camera-only and HUD-only changes skip the balance check: MET in tests, not live.
   - G19 core r11's real sentence (camera, score plate, key buttons, hint, noon sky) reads as "view". On r11's figures
     it passes with "[foreman] balance not judged: a change to the view or the screen only; ..." and no note to the
     person (test N27 4).
   - Hand checks are skipped the same way on a view change.

5. One real job: MET (two paid changes on one copied job; real claude-cli adapter, Sonnet builders).
   - Change 1, 03:24: a ground-pound slam for Bram and the Gulls (core r14, 5 min build). v0.1.5 was promoted at 03:44.
     The tofu figures stayed inside every bound, so no balance note was due; the card listed 3 unasked rules.
   - Change 2, 03:47: "brutal and unfair on purpose" (core r15). Promoted v0.1.6 at 04:08 with the balance note (see 1).
   - One aborted send, said plainly. My first send of change 2 (03:45) went to crew, which runs no tofu bot.
     - It also showed a bug: my regex read "unfair" as a fairness ask.
     - I stopped my own run after its Planner call (30 s, no builder started; no orphan claude.exe).
     - I cut its 6 events (644-649) from my copy of the log. They are kept in .tl/n27-cut-events-644-649.jsonl, and the
       full log before the cut is in .tl/n27-job-before-rollback.jsonl.
     - I fixed the regex ("unfair on purpose" is a play change; test N27 1) and resent with --package core.
   - Logs: .tl/n27-job.log and .tl/n27-job2.log. The job is .tl/jobs/shield-wall-3-v-20261125-1 (about 250 MB, in my tree
     only). d25-shield's job was only read.

GATES ON d25-hard-a (final source)
- foreman npm test: tests 450, pass 443, fail 0, skipped 7. Main e66eb94e on this tree before any change: 443 / 436 / 0
  / 7. The 7 new tests are tofu.test.ts; the counts match.
- node devx/bin/tl.mjs check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 230/230 and foreman.typecheck
  all PASS (5/5).
- selftest create.: 29 passed, 0 failed (same count as 25 Nov). create.model (12 checks) includes the new balance-note
  case.
- Run after the last foreman source edits (the regex and the pilot): tofu.test 7/7, then the full npm run 3 (450/443/0)
  and fast tier 2. The create. run came before those edits; the Create files did not change after it.
- NOT RUN: the full tier (no kernel, kit, rigs, style or seed change).

CHANGED FILES
- foreman/src/boundlift.ts: changeKind, askedChange, rowCall, splitByChange, rowsForChange, the note texts
  (BALANCE_MOVED, BALANCE_SKIPPED, already outside), winsLine (reads metrics.rounds or metrics.raw.rounds), handMovedNote.
- foreman/src/tofugate.ts: the split in a person's change (notes once a round); a refusal now tells the builder to keep
  what was asked.
- foreman/src/quality.ts: the milestone look judges the same rows (rowsForChange), so a look never refuses what the gate
  let through.
- foreman/src/handcheck.ts: personAsked (hand checks in a change), measureTests and keepMeasures.
- foreman/src/foreman.ts: +1 line, keepMeasures after dropOutOfScope (2000 lines, ratchet 2032).
- foreman/src/fastchange.ts: what-changed lines for the balance note and unasked rules (UNASKED_RULE, HIDDEN_RULE).
- foreman/prompts/builder.md: two rules, "a person's change is built as they asked / no hidden rules (RULE:)" and "the
  measure is the Foreman's".
- foreman/src/test/tofu.test.ts: new, 7 tests (N27 1-7).
- engine/ui/create/create_model.gd: balance_note, shown by change_note for a change that was made.
- engine/ui/create/create_iterate_checks.gd: a balance-note case inside the existing create.iterate.model check (count
  unchanged; CRLF kept).
- docs/shifts/2026-11-27-night/lanes/T-tofu/: STANDUP.md, REPORT.txt, stills/ (2 JPG strips).

CLAIM: two files I changed are not on night-2026-11-27-juice's list: foreman/src/tofugate.ts and foreman/src/foreman.ts
(asked in STANDUP at 03:06). Every other file is listed.

BEHAVIOUR CHANGES (named)
- In a change since the last promotion, the balance rows and hand checks no longer refuse a play change; they become a
  note to the person. A view change skips them. Look and fair changes guard as before.
- The tofu bot and the scripts it loads are put back if a builder edits them after their first merge. This holds during
  the tofu stage too (G19 r5's case).
- The what-changed card gains "balance moved ..." and "unasked rule ..." lines. Create's done screen can show an orange
  balance line for a made change.
- No existing test expectation moved.

PROPOSED CONTRACT TEXT (contracts/JOB.md, Director-only; notes section)
  Added 2026-11-27 (lane T): Foreman notes a person reads after a change.
  - "[foreman] balance moved by your change: <one line for Create>\nfigures (...)": a change since the last promotion
    moved a balance figure outside its bound. These are the tofu rows skill_spread, skill_variants, lead_change_share,
    close_rounds, pressure_waves and possession_median_f; the rows the person's words name; and a card hand check other
    than idle. The change was built as asked and is not refused for it. Create shows the first line on the done screen.
  - "[foreman] balance not judged: ...": a change to the view or the screen only; its balance figures were not judged.
  - "[foreman] already outside before your change, not judged as its regression: ...".
  - "[foreman] measure kept: <files> ...": a builder edited the plan's tofu bot (or a test script it loads) after its
    first merge; the edit was undone before verification.
  - what-changed lines "unasked rule (the builder's words; you did not ask for it): ...": a builder line adding a rule the
    person did not ask for (its RULE: line under DEVIATIONS, or hidden-rule words).

FOR THE OWNER TO LOOK AT
- stills/v016_slam_side_strip.jpg: the Gulls' slam (leap, landing, the ring of slabs, a fighter thrown).
- Play the copy: Create on this tree's .tl/jobs (or the pack .tl/jobs/shield-wall-3-v-20261125-1/promoted/
  game.shield_wall_3_v@0.1.6). Bram should feel like the monster that was asked for: the scripted bot wins 0 of 3.

QUESTIONS FOR THE DIRECTOR
1. Extend the claim to foreman/src/tofugate.ts and foreman/src/foreman.ts (used).
2. Land the JOB.md note text above?
3. Hand tests frozen too (needs a fake-runner change: wins from a game file), as T2 or later?

NEXT THREE (T2 onward)
1. J2's final-verification loop:
   - send a final failure to the package that registers the failing test (core), not to show;
   - a frame budget a person-asked longer match breaks becomes a note, or scales with the match length;
   - a builder's "nothing in my scope" answer stops the loop and tells the person.
2. The rink core route (Arsenal, J1): rinkjudge's goals-band gross defect on a person-asked play change becomes a note,
   as the tofu rows now are. The idle-win and never-ending-match defects stay guards.
3. Freeze the hand tests (fake runner reads its wins from a game file), and tie the balance note to the merged round. A
   later round that comes back inside its bounds should clear the note.

==========================================================================================================================
T2: J2's final-verification loop (04:13-05:05)
Tree d25-hard-a, branch n27-tofu, on top of 79cccfcf. Not committed: the Director lands.

OUTCOME AGAINST THE THREE NEEDS

1. A final-verification failure goes back to the package that owns the failing test: MET (test). Not exercised live,
   because need 2 made the test pass.
   - p10gate.ts blameFinal now skips a package that is cleared (rounds.ts clearedOf):
     - a control run cleared it (a "[foreman] pack test fails without this merge too" note for this test: J2 events 1006
       and 1034 said this about show twice, and the Foreman still blamed show);
     - or its builder answered, after a final send-back of this test, that nothing in its part can fix it (NOTHING_IN_SCOPE:
       "no change made", "nothing in my scope", ...).
   - When everyone who merged since the last pass is cleared, the package that registers the test takes it.
   - Test N27 T2 2 is J2's log in small: it goes to core, "show is cleared (a control run showed tests/bot_tofu.gd fails
     without its files too (event 1006))".

2. A frame budget that a person-asked longer match breaks scales, with a note: MET, live.
   - In a person's PLAY change (the same rule as the balance note), a bot run that failed ONLY on frames runs once more:
     - "only on frames" means bot.completed false; bot.ok is accepted too, because a cut run cannot be ok;
     - it runs with 3x the frames, at most 108,000 (tofugate.ts longerMatch, called from foreman.ts verifyLogged);
     - if it passes, it counts, and the person gets "[foreman] balance moved by your change: built as you asked; matches now
       run longer (...). Say "make matches shorter" to tune it.";
     - a run still not done with 3x the frames (a match that never ends) stays a failure, and so does a run with any other
       failed check.
   - Live, on a copy of J2's job with J2's exact hammer sentence (sent 04:18):
     - show r7's pack run of tests/bot_tofu.gd ran out of 36,000 frames and passed with 108,000, using 43,666 frames
       (events 1202, 1203 note);
     - the FINAL verification failed the same way (event 1214: "not done within 36000 frames", 2 matches) and passed on
       the longer run (event 1215: done, 43,666 frames);
     - there was no send-back to show at all;
     - v0.1.6 was PROMOTED at 05:01 (event 1267) with the hammer.
   - The card's newcomer hand check fell to 11 of 20 (bound 13 or more). By T1's rule that became a note, not a refusal
     (event 1260): "built as you asked; a newcomer player now wins 11 of 20 (was 17 of 20). Say "make it fairer" to tune
     it."
   - Create on the real job (headless): change_note = "Built as you asked; a newcomer player now wins 11 of 20 (was 17 of
     20). Say "make it fairer" to tune it."
   - stills/t2_robot_v016_hammer_strip.jpg: robots carry sledgehammers, one raised (tile 1), and robots are flattened and
     tumbling in dust (tiles 7-9).
   - Timing: the builder rounds finished by 04:32. Promotion came at 05:01, 43 min after the send, because the card's 40
     hand-check runs took about 13 min. The last 30 min were verification only, with no builder spending tokens.

3. A builder's "nothing in my scope can fix it" answer stops the loop and tells the person in Create: MET (test, plus
   Create check). Not live: tonight's job never reached it.
   - sendBackFinal: when the blame is left with nobody (every candidate cleared, the owner included) after at least one
     send-back, the loop stops.
     - It appends "[foreman] change not finished: the game's check <test> still fails (...), and no part of the game is
       left that can fix it: <package: why, in the builder's words>. The earlier version stays the one to play. ...".
     - It returns "spent": the job ends done on the earlier version, as today's "the change was NOT made".
     - Test N27 T2 3 uses J2's "No change made ... nothing in my scope can fix the cause".
   - Create (create_model.gd change_note):
     - a change whose job ended "the change was NOT made" without a promotion now reads "Your last change could not be
       made: "<words>"", followed by the not-finished reason on a second line;
     - before this, such a change kept the outcome "in flight", and no note said it was not made;
     - create.iterate.model checks it (job e4-unfinished).

LIVE FINDINGS FIXED IN THIS ROUND (from the same job)
- Measure kept, live (event 1140). Core r16's workspace still held J2's earlier edit of tests/bot_tofu.gd: the edit
  counted the hammer's wind-up as a tell. The Foreman undid it, and the note names it.
- Core r16 and r17 were refused on tells 2 < 3. The frozen bot does not count the new hammer wind-up among its tells.
  - The builder kept the hammer and said why (event 1150); the gate yielded at r18 as designed.
  - Fixed after: a new attack move with its own wind-up (swing, raise, slam, smash, hammer, leap, dunk, ...) moves the
    tells rows (test N27 T2 5). A look change still guards them.
  - This job ran on the code from before the fix.
- "close test rounds: now 0, was 0" was told to the person as their change's doing (event 1146). Fixed: a row already
  outside its bound before the change gets no balance note (test N27 T2 4). This job ran on the code from before the fix.
- rounds.test 6 ("p10gate.ts classifies no round by a prefix of its own") failed on my first clearedOf. It now lives in
  rounds.ts, beside finalSentSince.

GATES ON d25-hard-a (final source)
- foreman npm test: 455 tests, 448 pass, 0 fail, 7 skipped. That is T1's 450/443 plus the 5 T2 tests.
- node devx/bin/tl.mjs check --tier fast: 5/5 PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck).
- selftest create.: 29 passed, 0 failed (run after the Create changes).
- tofu.test.ts: 12/12. rounds.test passes.

CHANGED FILES (T2)
- foreman/src/tofugate.ts: longerMatch, onlyOutOfFrames, longerNote, DEFAULT_BOT_FRAMES, LONGER_MAX_FRAMES.
- foreman/src/foreman.ts: +2 lines in verifyLogged (2002 lines, ratchet 2032).
- foreman/src/p10gate.ts: blameFinal skips cleared packages; sendBackFinal stops with the person's note.
- foreman/src/rounds.ts: clearedOf, NOTHING_IN_SCOPE, CHANGE_NOT_FINISHED.
- foreman/src/boundlift.ts: a row out before gets no note; the tells touch words.
- foreman/src/test/tofu.test.ts: +5 tests (N27 T2 1-5).
- engine/ui/create/create_model.gd: change_note for a change not finished; not_finished.
- engine/ui/create/create_iterate_checks.gd: the e4-unfinished case inside create.iterate.model (count unchanged; CRLF).
- Claim: foreman/src/p10gate.ts is not on night-2026-11-27-juice's list. rounds.ts is listed.

BEHAVIOUR CHANGES (named)
- A bot run that fails only on frames, in a person's play change, gets one rerun with 3x frames, at most 108,000. This adds
  up to about 3 min of headless play per such run. Outside a person's play change, nothing changes.
- A final failure is no longer sent to a package that a control run or its own builder cleared.
- A final loop with nobody left to fix it ends with a note to the person instead of spending the remaining rounds.
- The what-changed card still shows only the newest "balance moved" line. On this job that is the hand-check line; the
  "matches now run longer" line is in the log, not on the card.

PROPOSED JOB.md TEXT (Director-only)
  - "[foreman] change not finished: ...": a final check still fails and every package it could go back to is cleared (a
    control run showed it fails without that package's files, or its builder answered that nothing in its part can fix
    it). The job ends done on the earlier version; Create shows the reason under "Your last change could not be made".
  - "[foreman] balance moved by your change: built as you asked; matches now run longer ...": a bot run in a person's play
    change ran out of its frames and passed when run once more with three times as many (at most 108,000).

NEXT
1. T3 (queued): raise the change box's cap (create_build.gd:380, max_length 240). JOB.md and the Foreman set no length
   limit on change_requested.text (events.ts: nonEmpty only). The door already flattens line breaks.
2. The what-changed card and Create: show every distinct "balance moved" line of the change, not only the newest.
3. Hand-test freezing (ask 3 from T1).
