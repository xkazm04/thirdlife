H1d (round 4 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 1969842
(H2 on top of H1c). Opus. From lane G1's Arsenal hockey round 2 (d25-arsenal PROOF-G1.md sections 6-11 and its
blocked-editor lines 20-27; the job read only). Rounds 1 to 3 are REPORT.md, REPORT-H1b.md and the H1c report.

1. A version that throws script errors in a window is not promoted: MET.
   - foreman/src/promogate.ts promotionErrors: after the promotion pictures, the ones whose report has a script_error
     (or smoke.no_script_errors failed) refuse the promotion, in words; the job ends `failed`, pack/ goes back to the last
     promotion, which stays the one to play. A picture that failed for another reason (driver, no file) is only left out,
     as before. foreman.ts: 3 lines (2002 of its 2005 lines).
   - The words, as the test reads them: "promotion refused: in a window, as a person plays it, the game throws script
     errors in 2 of 2 promotion picture(s): rink audio: no voice for commentary line 'faceoff.drop.04'
     (scripts/main.gd:2). The headless checks do not meet them, so they passed. A version that errors in front of the
     player is not promoted. Earlier version v0.1.0 stays the one to play. The change was NOT made."
   - Fake runner: the marker FAKE_WINDOW_ERROR errors only in the capture verb (as G1's commentary voice).
   - Test: H1d 1. Gap: a FIRST promotion takes no promotion pictures (only later ones do), so v0.1.0 would still pass;
     lane H2b fixes the base's missing voice itself.

2. Play words go to the cartridge's owner: MET.
   - coreowner.ts playOwner: on a core game, when the Planner names a package that is not the base and does not own the
     game's cartridge, words about play (CARTRIDGE_WORDS, or the toys: bubble, shield, ability, pickups, spots, tricks,
     boosts, zones, pads, cannon, hip check, cooldown, charges, comes back, win/matches) with no word about a picture
     (draw, look, glow, colour, flash, sound, icon, hint, HUD, camera, animation, ...) go to the cartridge's owner; the
     `reopened` reason says why. Skin words named on the skin stay there.
   - Test: H1d 2 with G1's plan and change 3, word for word: harbour -> cartridge; "make the bubble glow brighter and
     draw the arrows yellow" stays harbour; "rename the teams ..." on the skin stays the skin.
   - Moved test expectation (named, why): e3f_change_path.test.ts "E3f: on a core the base never takes a change ..."
     asserted `coreChangeOwner(plan, RINK_ROUTE, "skin", "make the goals bigger")` = { owner: "skin" } ("for a built
     owner nothing moves"). That is exactly what this item changes: it is now "cartridge", and "call it PIRATES" on the
     skin is asserted to stay the skin. The test name says so.

3. The "Yes, let it" chip sends the request: MET.
   - inbox.ts chipRequest (used by the inbox drain and by `foreman answer --change` in requests.ts): the other package's
     change request is the person's ORIGINAL request to the asking package, then "(<pkg> could not make it alone and
     asked: "<question>"; the person answered: "<answer>")". An answer to a question outside a change: the answer alone,
     as before (n3's test of it is unchanged and passes).
   - Test: H1d 3.

4. A package asks once per change: MET.
   - asktwice.ts: inside a change (a re-opened package), a builder that asks again after the person answered it is not
     asked a third time. On a core game where the request is play and another package owns the cartridge, the change goes
     back to routing (a change request to that package with the request, the question and the answer; the asking package
     keeps its merged files). Otherwise the person is told plainly: "<pkg> cannot make this change: It asked "...", you
     answered "...", and it asks again ("..."). It is not asked a third time: the change was NOT made, and the files <pkg>
     merged before stay. Say it again in other words, or name what matters most."
   - Questions are words: a JSON object in a question becomes "(the settings it names above)", backticks go
     (plainQuestion); the builder prompt asks for one question per change, in a player's words, with the choices plainly.
   - Test: H1d 4 (the fixture job off a core: not asked twice, the plain words, the job does not wait; and askedAgain on
     G1's plan and words: routed to cartridge with the request).
   - Not changed: Create's chips for other questions are Create's own (create_model.gd); I did not touch them.

5. Removals come from the game's own diff: MET.
   - The "removed: a shield" of v0.1.3 was the builder's DRILL file (data/drill_slush100.cartridge.json lost both shields
     and the slow puck), merged under the same key path. removal.ts removedSince now compares only the cartridge the game
     plays (data/match.json / skin.json), every cartridge when none is named.
   - Test: H1d 5 with G1's promoted v0.1.2 and v0.1.3 data (harbour, drill, match.json in foreman/fixtures/h1d/):
     exactly [a slow_puck (game.abilities)].

6. A figure the person names is set against the check: MET (on the cartridge diff path).
   - rinkjudge.ts askedFigureMiss: "N minutes" and "N goals a match" in the person's words (digits or words), against
     pro_minutes / pro_goals_a_match measured after the change; missed by more than a quarter -> "you asked for matches
     of about 3 minutes; they last 2.1 min at pro now (thirdjam's regular playtester, measured after the change): the
     change falls short of what you asked". A Foreman note ("not what you asked: ...") on the diff round, and its own line
     in the what-changed note.
   - Test: H1d 6 (G1's change 1 words and figures, through cartridgeChange with G1's cartridge and event 234's diff).
   - Not covered: a builder's round has no before/after figures, so it is not checked.

7. The `needs: "core"` card (the Director's choice b): MET, contract wording left to you.
   - v2.ts: an aspect may carry `needs: "core"` and `hours` (integer >= 1); `needs` without `hours` and `hours` without
     `needs` are refused. brief.schema.json (the Designer's schema) and the site's strict reader
     (engine/kernel/world/site/event_schema.gd) take them. designer.md: such a card says it in its line, and at least one
     alternative does the same with data only; never order engine code silently.
   - Create: a kept card that needs it shows "+6 h engine code"; under the cards, where the hint stands: "Snowball cannon
     needs new engine code: about 6 hours more. Tap it for a way with data only"; a tap (the alternative) takes both away
     and the hint comes back. create_model.gd core_cost_words, create_design.gd.
   - Selftest block 862 (create.corecost.schema, .pitch, .swap); still looked at: lanes/H1-critic/h1d_pitch_corecost.jpg
     (the tag sits under the card's line, above the dots, clear of the CRAZY badge; the words in amber in two lines
     beside Redesign / Build it).
   - JOB.md is not edited (Director-only): the brief_set aspect gains the two optional keys.

The Director's H1c decisions, done:
   - The base README (engine/templates/rink_game/README.md) no longer says "needs a core patch (lane K1)": engine code is
     "hours of work and a new build, and the person decides whether to pay that. Never order it: offer the nearest
     data-only way first ... and name the engine-code version as the costlier choice, with its hours."
   - A toy that costs the player (more than 5 points of wins) is a line on the card ("The slow-ice zones: costs you (8 of
     20 wins with, 13 without)"), not a check warning (toyLines).
   - Test: "H1d (the Director's H1c decisions)".

All 7 H1d node tests fail on main 1969842 (a scratch copy of HEAD with the new test file, fixtures, fake runner and the
new asktwice.ts beside it, one import shim): H1d 1 promoted ("done"), 2 owner harbour, 3 the answer as the request, 4
"not asked a second time" fails, 5 two removals, 6 no askedFigureMiss, decisions test fails. Block 862 cannot run on
main (no Core_ label, no core_cost_words).

GATES (each after room.sh)
- foreman npm test: 401 tests, 394 pass, 0 fail, 0 cancelled, 7 skipped (the same 7 as main). 401 = main's 394 + the 7 H1d
  tests. Log .tl/h1d/npm-test-2.log. The run before it had 1 fail: robust.test.ts "data/job-events.schema.json is the
  event vocabulary the reader enforces" (the aspect's new needs/hours were not yet in the generated file);
  foreman/data/job-events.schema.json regenerated with foreman/scripts/write-event-schema.mjs (+7 lines), then clean.
- node devx/bin/tl.mjs check --tier fast: PASS, exit 0: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
  foreman.typecheck clean. Log .tl/h1d/check-fast.log.
- bash engine/tools/selftest.sh create.  (630, 860, 861, 862 and H2's rebase cases): 23 passed, 0 failed.
- --tier full not run: no kernel, kit, rig, style or seed file changed (engine/kernel/world/site/event_schema.gd is the
  site's reader of job events, not the runtime kernel; say if you count it as kernel and want full).
- Godot: one class cache import (it wrote only create_corecost_case.gd.uid), the windowed pitch still.

CHANGED FILES (round 4)
- new: foreman/src/promogate.ts, foreman/src/asktwice.ts, foreman/src/test/h1d_hardening.test.ts (7 tests),
  foreman/fixtures/h1d/ (G1's v0.1.2 and v0.1.3 data), engine/ui/create/create_corecost_case.gd (+ .uid),
  engine/tools/selftest.d/862-create-corecost.sh
- foreman/src/foreman.ts (+5 lines: the promotion refusal, the one-question rule, plain questions), coreowner.ts
  (playOwner), inbox.ts (chipRequest), requests.ts (chipRequest), removal.ts (the played cartridge), rinkjudge.ts
  (askedFigureMiss, "costs you"), coregate.ts (FIGURE_MISSED note), fastchange.ts (its line), v2.ts (needs, hours),
  testing/fake-runner-core.ts (FAKE_WINDOW_ERROR)
- foreman/prompts/builder.md (one question, in words), designer.md (needs core), brief.schema.json (needs, hours)
- engine/kernel/world/site/event_schema.gd (needs, hours), engine/ui/create/create_model.gd (core_cost_words),
  create_design.gd (the tag and the words), engine/templates/rink_game/README.md (the core patch line)
- foreman/src/test/e3f_change_path.test.ts (one expectation moved, named above); foreman/data/job-events.schema.json
  (regenerated)
- lanes/H1-critic: STANDUP.md, REPORT.txt, h1d_pitch_corecost.jpg

BEHAVIOUR CHANGES
- A later promotion whose pictures show a script error ends the job failed and keeps the earlier version.
- Play words named on a built package that does not own the cartridge go to the cartridge's owner.
- A re-opened package gets one question per change.
- Changes that name minutes or goals get a "not what you asked" line when missed.
- Create's pitch can show an engine-code cost; a Designer brief may carry needs/hours.

QUESTIONS FOR THE DIRECTOR
- JOB.md: the aspect keys `needs: "core"` (only value) and `hours` (integer, required with needs) on brief_set; the
  Designer must give such a card a data-only alternative. And the `change_requested` text a chip writes now carries the
  request, the question and the answer: worth a line in JOB.md's answer --change section.
- Should a FIRST promotion also take one picture (about 40 s) so v0.1.0 is held to the same window check?
- Should the figure check also run on a builder's change round (a measured check before and after the merge)?

NEXT THREE
1. One promotion picture on the first promotion too (if you want it).
2. Before/after figures for a builder's data change, so item 6 covers it.
3. Let the cartridge builder run the measured check itself (G1 event 42).
