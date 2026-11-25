H1e (round 5 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main d6260bb.
Opus. Games from scratch judged as hockey (lanes G2 robot football, G4 half-court basketball; their texts copied read only
into foreman/fixtures/h1e/), plus the Director's two additions: the first promotion's picture, and G1's 20-vs-80 seeds.

0. A first promotion takes one picture (the window check): MET.
   - foreman.ts: the promotion pictures run for every promotion; the first takes ONE (the first camera at the first
     frame, as a data-only change's promotion does). A script error in it refuses the promotion: "promotion refused: in a
     window, as a person plays it, the game throws script errors in 1 of 1 promotion picture(s): rink audio: no voice for
     commentary line 'faceoff.drop.04' (scripts/main.gd:2) ... Nothing was promoted." The picture is part of the final
     checks (no `after` tag); the what-changed note and the pictures note stay for later promotions.
   - Test: H1e 0 (a dirty v0.1.0 refused; a clean one takes exactly one picture and is promoted).
   - Moved expectations (named in the tests): explain.test.ts status "events 57" (was 56), wp3b.test.ts the final checks
     end with "capture" (was "bot"): both are the one new picture.

1. Judged by the game's own design, not the house game's: MET.
   - foreman/src/gamewords.ts: the game's own words are its design (verb ids and the template moves they copy, clip ids,
     aspect ids). A house contact row or a verb/moment kind is the game's when every word of it that names a game is the
     game's; rows of generic body/contact/juice words (stability, stumble, hold, shake, slow, ...) transfer and are still
     judged. A brief without a design is not filtered.
   - revisepair.ts contactDiff: the house rows the game does not have are "not judged, not missing", said once:
     "N house contact row(s) belong to engine/packs/hockey's own play (check, whiff, lunge, cross, board, ...), which this
     game's design does not have". On G4's real pack and brief: 70 missing before; now the check/board/cross/goal/save
     rows are out and the shared ones (hits.stumble_ratio, ...) are still asked.
   - revisepair.ts: a house strip kind the game does not have (the hockey one_timer for the basketball) is no longer
     "make the house game's kind happen": "The house game's contact here is a one_timer, which this game's design does
     not have: do not add it. Set only how the bodies take contact beside it ...".
   - quality.ts: the house strip films the house moments the game has first (a poke before a one-timer for G4); the
     house_game rubric item says "This game's design does not have the house game's one_timer, check, board, ...: never
     call them missing and never ask for them; set beside it only what the two games share (the bodies, how they take
     contact, the team's play)" (houseForeign).
   - G2's robot football really designed a one-timer (an aspect card "Cross And Blast", NHL '94 in its TEARDOWN), so by
     its own design it keeps it; G4's basketball has none.
   - Tests: H1e 1 (contactDiff on G4's real tuning and brief), H1e 1b (houseForeign/houseItem with G4's brief and the
     house hockey's tuning). Not covered by a test: revisePair's new sentence (it needs strips on disk; the words are
     built from gameHasVerb, which H1e 1 covers).

2. The plan's tofu bounds enforced by the Foreman: MET.
   - foreman/src/tofugate.ts: when the plan's tofu bot runs in a round's acceptance and answers ok, the Foreman judges its
     metrics against the plan's rows (tofu.ts); out of bounds fails the round, nothing is merged, and a failed check of its
     own (reports/<pkg>-r<n>-tofu-bounds-s<seq>.json, a verify event) carries the rows into the next round's feedback:
     "tests/bot_tofu.gd answered ok, but the Foreman judges its metrics against the plan's tofu bounds and 2 are outside
     them: pressure_waves 0 (the plan's bound: >= 2); scrum_share 0.453 (the plan's bound: <= 0.3) ...".
   - At most two such rounds (the look's revise budget); after them the round merges and the milestone look judges the
     same bounds and holds the job for the person, as before, so an impossible bound reaches the person, not the cap.
   - Tests: H1e 2 (G4's real plan and bot report s82); n4.test.ts "tofu: a core whose bot misses the metrics ..." with
     its expectation moved (named in the test: round 1 is now not merged and round 2 gets the rows; it said "the root was
     merged and sent back by the look" with two tofu reports). That moved test fails on main and is the wiring proof.
   - Not changed: the bounds themselves (scrum_share's "within 5 m of the puck", possession's "HOCKEY-ARCADE 5.5" wording)
     are the arcade_sport template's; whether 0.3 is right for six players on a 15 x 11 court is a design question.

3. The card says what transfers from hockey: MET.
   - engine/cards/team_possession.json 0.4.0 -> 0.5.0, existing keys only: a `dont` line ("Do not carry hockey into a
     ball game. ... takes the bodies, possession by reach, the pass and the team AI; NOT the stick, the puck, the
     one-timer, the boards and board bonus, the body check or the cross-check ...") and a variant "basketball or another
     ball game on a court". tl cards check PASS.
   - Test: H1e 3 (the card's words, and the builder's recipe section carries them).

4. No confident toy word from noise (the Director's addition, G1 round 3): MET.
   - check_cartridge.mjs and rinkjudge.ts toyClear: each toy now carries the paired counts (won only with it / only
     without it). A worth is said only when they show it: "nothing" (no match plays differently), "helps"/"costs" (a
     two-sided sign test over those counts, p < 0.1), "little" (within 10 points even at the far end of a 95 % margin);
     otherwise "not clear yet (won only with it a, only without it b, of n)". Only "nothing" and "little" are check
     warnings; a cost is words on the card (the Director's H1c decision); a toy that helps gets no line.
   - Test: H1e 4 with G1's figures as a fixture (foreman/fixtures/h1e/g1-toys-20-vs-80.json, from PROOF-G1.md section 14):
     every pairing consistent with the 20-seed totals of the pickups, pads and pools is "not clear yet" (never "costs
     you"); G1's 80-seed pairs: the returning bubble 22/11 "helps", at all_star 11/3 "helps", v0.1.0's 5/8 and v0.1.1's
     7/3 "not clear".
   - Moved expectations (named): h1c_hardening.test.ts H1c 1 (the stand-in lab's pickups were "changes little" at 4/4
     paired, now "not clear yet", and the zones get their not-clear lines; the warning text carries the counts) and
     h1d_hardening.test.ts's "costs you" line (now with counts that show it).
   - Not done: measuring more seeds when unclear (the other option); 20 stays the default (--toy-seeds raises it).

Every new H1e test fails on main d6260bb (scratch copy of HEAD with the new tests, fixtures and the new helper modules
gamewords.ts and tofugate.ts beside it, one import shim), except H1e 2, whose unit is the copied module itself; its
wiring is proven by the moved n4 test, which fails on main. H1e 1b and 4 fail on main because the functions are new.

GATES (each after room.sh)
- foreman npm test: 407 tests, 400 pass, 0 fail, 0 cancelled, 7 skipped (the same 7 as main). 407 = main's 401 + the 6 H1e
  tests. Log .tl/h1e/npm-test-2.log. (A run before the last moves had 2 fails: explain.test.ts's event count and
  wp3b.test.ts's final-check list, both the new first-promotion picture; their expectations are moved and named.)
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean. Log .tl/h1e/check-fast.log.
- bash engine/tools/selftest.sh create.: 23 passed, 0 failed. node devx/bin/tl.mjs cards check: PASS (3 steps).
- --tier full not run: no kernel, kit, rig, style or seed file changed (a card and the rink lab's check script).
- No Godot run this round (no engine UI change).

CHANGED FILES (round 5)
- new: foreman/src/gamewords.ts, foreman/src/tofugate.ts, foreman/src/test/h1e_hardening.test.ts (6 tests),
  foreman/fixtures/h1e/ (G4's brief, plan, tuning, bot report s82; G2's brief; G1's 20-vs-80 table)
- foreman/src/foreman.ts (first promotion picture, the tofu gate; 2003 of its 2005 lines), revisepair.ts, quality.ts,
  rinkjudge.ts (toyClear, toyLines), engine/cores/rink/lab/check_cartridge.mjs (paired counts, clear),
  engine/cards/team_possession.json
- tests moved (named in each): explain.test.ts, wp3b.test.ts, n4.test.ts, h1c_hardening.test.ts, h1d_hardening.test.ts
- lanes/H1-critic: STANDUP.md, REPORT.txt

QUESTIONS FOR THE DIRECTOR
- The arcade_sport template's tofu rows are hockey-worded and hockey-sized (scrum within 5 m of the puck at most 0.3,
  possession "HOCKEY-ARCADE 5.5"). Should a ball game on a small court get its own bounds (a card field, a contract
  question), or do they stand?
- Toys: when the paired counts are not clear at 20 seeds, measure more (for example up to 80, about 4 x the toy time,
  inside the cache) or keep "not clear yet"?

NEXT THREE
1. Per-game tofu bounds for team ball games (after your answer).
2. Adaptive toy seeds when not clear (after your answer).
3. A test of revisePair's foreign-kind sentence with strips on disk.
