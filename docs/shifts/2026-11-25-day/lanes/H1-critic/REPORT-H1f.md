H1f (round 6 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 2c2a16f.
Opus. The H1f round's four items plus the optional fifth, from lanes G2 (robot football) and G4 (half-court basketball).
The jobs were read in place, read only; the texts the tests need are copied into foreman/fixtures/h1e/.

1. A person's yes widens the scope: MET.
   - New foreman/src/scopegrant.ts. A person's yes to a builder's scope question ("may it change / outside / scope /
     can those files / be added to") gives that package the paths the answer names, for the change it was asked in
     (since the package's last reopen). A folder is "<dir>/**". The Foreman's spec(id) carries the grant, so
     dropOutOfScope keeps those files and the acceptance merges them. A "no", or an answer to a question that is not
     about scope, grants nothing.
   - The merge says what was widened, as a note: "[foreman] scope widened for this change, on the person's answer:
     <id> may change <globs>; merged outside its plan scope: <files>".
   - G4's words ("you may change scripts/main.gd, scripts/core and scripts/bodies") parse to scripts/main.gd,
     scripts/core/**, scripts/bodies/**.
   - Test: H1f 1.

2a. Team ball games get their own tofu bounds, scaled to the court (your answer): MET.
   - tofu.ts: courtOf(brief) reads the court ("<L> x <W> m") and the sides ("three against three", "3 v 3", "five a
     side") from the brief. tofuMetricsFor and tofuPlannerText take the court.
   - The scrum row is rescaled from the house hockey's "4 of 6 within 5 m on 1800 m²":
     radius = 5 m x sqrt(area / 1800); count = 4 x players / 6, at least 2. The 0.3 bound stays.
   - G4 (15 x 11 m, three against three): "4 or more field players (not keepers) stand within 1.5 m of the ball or
     puck (scaled to this court, 165 m² and 6 players, ...)". G2's 64 x 40 m pitch gives 6 m.
   - The hockey's own court keeps the row word for word, and a game with no court found is not scaled.
   - Every caller passes the court: the planner's rows (designer.ts), the acceptance gate (tofugate.ts), and the
     milestone's tofu judgement and house compare (quality.ts).
   - Test: H1f 2a, with G4's and G2's real briefs.
   - Not changed: the other arcade_sport rows (possession_median_f, overlap_share). They are not distances or head
     counts, so the court does not move them.

2b. Toys unclear at 20 seeds are measured up to 80, inside the cache and the pool (your answer): MET.
   - check_cartridge.mjs: the pool-and-cache code is now one function, playRuns. A toy that is "not_clear" at
     --toy-seeds is played again on seeds 21-80 (new flag --toy-seeds-max, default 80). The extra seeds go in groups
     of 20 through the same pool of 4, and the base cell is played on the same seeds, paired. This second stage is
     cached under its own key.
   - "not clear yet" is said only if a toy is still unclear at 80. A toy that is already clear at 20 (for example
     "changes nothing") is not played again.
   - Real lab, G1's harbour cartridge (.tl/h1f/real-lab-g1-toys80.txt): the whole check, all four toys taken to 80,
     ran in 34.9 s. The F ability gave 44 wins with it and 47 without, won only with it 5 and only without it 8. That
     is G1's v0.1.0 row at 80 seeds exactly (PROOF-G1 section 14). It is still unclear at 80, so it says "not clear
     yet (... of 80)".
   - Test: H1f 2b (stand-in lab: three noisy toys reach 80 and stay unclear; the F ability stays at 20; a second check
     reads both stages from the cache).
   - Moved expectation (named in the test): h1c_hardening.test.ts H1c 1. Its three "not clear yet" lines now read
     "of 80" (they were "of 20"), and the cache holds two files (the first stage and the second).

3. "The look changed, the play did not": MET.
   - New foreman/src/playsame.ts. After a critic revise round whose reasons were about play (clump, pile, contact,
     hit-stop, bots, tackle, overlap, scrum, pass, ... matched in the critic's notes), the Foreman compares every bot
     test that ran both before the round (up to the snapshot's seq) and after it.
   - The measure is what each bot counted: its result without the summary words (moments by frame, won, goals,
     touches, the tofu metrics), keyed by test and seed. Nothing is played again for it. If every bot counted the same
     on both sides, the person gets a note and the milestone summary carries it: "[foreman] the look changed, the play
     did not: the critic's reasons were about play ("contact"), and after revise round 1 tests/bot_rally.gd plays
     frame for frame as before (the same moments at the same frames, the same counted figures). The round changed how
     the game looks, not how it plays".
   - Why not state_hash: in G2's real reports the hash moved with the look while the newcomer's result stayed
     identical (for example newcomer s54 against s101: the hash differs, the result is the same). The hash cannot tell
     a look change from a play change.
   - Replayed on the real jobs (read only): G2's art_pass revise round 2 says it (reasons "tackle"; all six bots the
     same after the round). G2's other rounds and G4's rounds do not: some bot's counts moved (bot_tofu's figures, or
     bot_mash's). So the rule is strict and fires only when every bot counted the same.
   - Test: H1f 3 (the note in the log and in the milestone; a bot whose moment moves by a frame gives no note; reasons
     about the picture give no note).

4. A person's note on a kept card is checked: MET.
   - phases.ts personDecisionsText: when the person reacted to a card with keep or an alternative and wrote a note,
     the critic's rubric says: "A NOTE on a KEPT or CHOSEN aspect is the person's REQUIREMENT, as binding as a drop:
     check each against the frames ("<card>": "<note>"); for each one the frames do not keep, write a note that starts
     "person's note not kept:" ... and score this item 0.4 or lower".
   - quality.ts notesKept: a critic note that starts "person's note not kept:" makes the look NOT ok whatever its
     scores, and is moved to the front. The milestone summary and the revise round then say it first.
   - Test: H1f 4. It uses G4's real reaction on event 14 ("keep the camera steady behind me like a TV game, no
     swinging") for the rubric words. In the loop, a critic that said "ok" while naming the note as not kept gets a
     revise round whose feedback leads with that note.
   - Limit: this relies on the critic seeing the swing in its frames. A camera that turns with the player shows in
     strips, but no figure measures it.

5. What changed leads with the person's words: MET.
   - fastchange.ts whatChangedNote: after `asked "<the person's words>"`, the line now says "what you will see, in the
     builder's words: <the first three lines of the merged package's own note> (and N more in its note)", and only
     then the cartridge keys and the files. The note limit rose from 1000 to 1500 characters.
   - Test: H1f 5, with G2's v0.1.1 events as a fixture (foreman/fixtures/h1e/g2-change-events.jsonl). "Any slide at 6
     m/s or faster ... floors it / The slider that floors a non-carrier ... / The captain's slide (robot 0) now also
     hits and floors his own mates. ... (and 12 more in its note); files: data/tuning.json, ...".

Every H1f test fails on main 2c2a16f (6 of 6). The run used a scratch copy of 2c2a16f with the new test, the new
modules scopegrant.ts and playsame.ts, and two shims (courtOf returning undefined, notesKept as identity), so only the
behaviour is missing:
- H1f 1: "not dropped";
- 2a: no court;
- 2b: the pickups stay at 20 matches;
- 3: no note;
- 4: no requirement in the rubric;
- 5: no builder's words.

GATES (each after room.sh)
- foreman npm test: 413 tests, 406 pass, 0 fail, 0 cancelled, 7 skipped (the same 7 as main). 413 = main's 407 + the
  6 H1f tests. Log: .tl/h1f/npm-test.log.
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0. arch [12/12], assets [4/4], cards [3/3], devx.test
  [229/229], foreman.typecheck clean. Log: .tl/h1f/check-fast.log.
- Not run:
  - --tier full: no kernel, kit, rig, style or seed file changed.
  - selftest create: no Create UI change this round.
  - Godot: not run.
- The real rink lab ran once (34.9 s, room under 70 %).

CHANGED FILES (round 6)
- new: foreman/src/scopegrant.ts, foreman/src/playsame.ts, foreman/src/test/h1f_hardening.test.ts (6 tests),
  foreman/fixtures/h1e/g2-change-events.jsonl
- foreman/src/foreman.ts (spec carries the grant; the widened note at the merge; 2004 of 2005 lines), tofu.ts,
  tofugate.ts, designer.ts, quality.ts (court, notesKept, the look-not-play note), phases.ts (kept-card notes),
  fastchange.ts (the builder's words), engine/cores/rink/lab/check_cartridge.mjs (playRuns, second stage)
- moved test (named in it): foreman/src/test/h1c_hardening.test.ts
- lanes/H1-critic: STANDUP.md, REPORT.txt
- The scope_* and widened words are note text; no event schema changed.

QUESTIONS FOR THE DIRECTOR
- Scope grants read the person's answer with a regex: a yes, plus the paths it names. A yes that names no path
  ("yes, go ahead") grants nothing, and the drop stays as before. Should a bare yes grant the paths the builder's
  question named? That is easy to add, but it trusts the builder's words.
- Item 3's rule is strict: every bot run on both sides must count the same. Should it instead name the bots that did
  not change ("the newcomer's match did not change") when some did?
- Item 4 has no figure for "the camera turns with the player". A camera yaw figure (degrees a second, from the runner)
  would let the Foreman check "steady" itself. That is a runner or kernel change, for the Director to place.

NEXT THREE
1. A camera-steadiness figure in the runner's capture report, so a "steady camera" note is measured, not only seen.
2. Item 3 per bot (which play changed and which did not), if you want it.
3. The scaled row in the house compare names both radii, so the house figure and the game's figure are read as
   comparable shares.
