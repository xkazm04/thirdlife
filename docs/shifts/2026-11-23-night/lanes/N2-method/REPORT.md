N2 method: REPORT, night of 22-23 Nov 2026 (19:12 to the last STANDUP line, CEST)
Worktree n23-method. Route: Opus solo, with two read-only web-research subagents (craft and process; the two cases).
Nothing committed by me; the Director landed round 1 (a9b5447), round 2 (42b1097), round 3 (85d9953), round 4
(6be8539; JOB.md tell_min_f >= 20 in 2599ebe), round 5 (5910b8a) and round 6 (f4f71d2; JOB.md worded in b925a54).
All six rounds are on main; nothing of this lane is left unlanded but this report.

Nobody has played anything this lane made: it is a method, prompts and checks. No Foreman build job was started; the two
dry runs used the FAKE adapter (and, for the playtest card, the FAKE runner on a test fixture), so no model was called,
nothing was billed and nothing was built.

=====================================================================================================================
FOR THE OWNER'S VERDICT PAGE
=====================================================================================================================
The editor's stance, before and after. Before tonight the editor designed a game by filling a checklist and passed it
on bot figures: a design was "done" when every field was filled, a build when its tofu bot's metrics were in band and
it looked as good as our house game, which was "the bar". Tonight the test became "a person wants to play it again":
every design now starts from the player's fantasy and states the size of its world in the player's units, the
reference game's moment it copies, the first 30 seconds as a newcomer meets them, and what a person would see that
kills it (FANTASY, WORLD, TEARDOWN, 30 SECONDS, KILL IF, checked by the Foreman); the first phase is a greybox a
person plays with a playtest card; the critic can fail a game but never pass its fun; and our house hockey and duel,
which you called slop, are a working base for the engine and a floor, while the bar is the reference game's numbers
and the teardown's "do not copy" lines. Nobody has played anything built this way yet.

Asks:
1. The person gate: with run_through the Foreman passes its own phases. Should it still stop after the FIRST phase (the
   greybox) for your pass or hold? Recommended: yes; it is the one stage only a person can pass (METHOD.md 10).
2. JOB.md design keys versus labelled lines: the five method stages live tonight as labelled lines at the head of
   brief.rules (no contract change). Make them keys of brief.design (fantasy, world, teardown[], thirty_s, kill[]) so
   readers and the village site can show them, or keep the lines?
3. The house duel now fails tell 20: its chained lights wind up 12 frames, under a person's reliable reaction, and the
   editor now refuses that floor (checklist item 11, tofu row tell_min_f >= 20). Slowing its rival's tells (and, per the
   duel teardown, putting them in the body instead of words over the head) is the duel's next change, not tonight's.

=====================================================================================================================
OUTCOME AGAINST THE ACCEPTANCE
=====================================================================================================================
1. docs/design/METHOD.md and docs/design/CASES.md, with sources. MET.
   - METHOD.md (14 sections, 35 sources, every [n] listed: a test checks it):
     1 the test and the evidence ladder ([H] a person's hand passes fun; [C] film and [B] bot figures can only fail it;
       [P] paper passes the paper stages); the owner's ten standing rulings from thirdjam (N1's RULINGS.md section 10);
     2 what our games missed (19-22 Nov evidence and N1's two teardowns: "our measures cannot see what he sees", a world
       size nobody chose, rules made to pass a metric, ports move numbers not experience, juice instead of a core,
       breadth hides the core, the rules right but the bodies/timing/tutorial/pace wrong, a rubric set below the human
       limit, a copied idea without its conditions, loops that only add);
     3 the eight stages, what each writes, who checks, what passes it; the method lines;
     4-11 fantasy (MDA's aesthetics), pillars, core loop (Griesemer, Meier, Cook; flow and difficulty: Chen, Hunicke),
       the 30-second test (Miyamoto, Hayashida, Apple), the feel spec (Swink, West's 3/60 target, readability: Riot,
       TF2, Zhang, Vossen; juice: Jonasson & Purho, Nijman, Sakurai; the size of the world first, in the player's
       units), the reference teardown (read the last game and the owner's rulings first; port the reasons and the frame
       of reference, numbers last), the greybox (Splatoon's tofu, Gabler's 7-day rules, Fullerton; kill freely:
       Supercell, Valve), kill criteria;
     12 the playtest loop (Valve's Ambinder and Birdwell, Halo 3, Nielsen's five users; watch, don't ask; a ranked list
       of what a first-time player feels, worst first; one change between two plays);
     13 the one-page design of a small arcade game (Librande, Tim Ryan);
     14 rules by role: Concept, Designer, Reviewer, Planner, Builder, Critic, Director, Person.
   - CASES.md: hockey (NHL '94 from its manual and its developers, NHL Hitz, Blades of Steel, and N1's thirdjam
     teardown as stage 6b) and the duel (For Honor's own patch notes and debriefs, Souls' attack anatomy, Sekiro,
     FOOTSIES, fighting-game frame data, and N1's duel teardown as stage 6b), each through all eight stages with
     rules, numbers and moments, "what our build did instead", and the method lines a brief would carry. The two
     calls with no source (a waiting tutorial opponent; a 45-90 s round) are marked as our design calls to test by hand.
     Both method-line blocks pass the editor's own checks (a test).
2. The prompt rewrite. MET. Before/after excerpts:
   - concept.md, before:
       "# The game must be one we could sell
        A game that runs but that nobody plays twice is a failure. ... **Copy the proven core; be new only in the hook.**"
     after:
       "# The test: a person wants to play it again
        Not "the mechanics exist" and not "the bot figures are green": a person, offered "stop or play again", plays
        again. ... 1. **The fantasy first.** ... 2. **Copy the proven core; be new only in the hook.** ...
        3. **Tear the reference down; never remember it.** ... "the fast feel of NHL 94" is a mood, and a mood is not a
        reference."
     and the five candidates are five FANTASIES; `why` names the fantasy and the moment of the first 30 seconds.
   - designer.md, before: "# Your goal: a game a stranger plays twice" followed by an 11-item fun checklist.
     after: "# Your goal: a game a person wants to play again" ("Every bot figure of our hockey was in band when he
     called it unplayable ... a filled field is not a decision"), then "# Work in the method's order": 1 Fantasy,
     2 Pillars, 3 Core loop, 4 the 30-second test, 5 the feel spec ("first, in `rules`, the size of the world in the
     player's units ... No rule exists only to pass a bot figure"), 6 the reference teardown, 7 the greybox, 8 kill
     criteria; then the method lines format; the old checklist stays under "What each part of the design must hold".
   - design-review.md, before: "You are judging a DESIGN, on paper; the game does not exist yet."
     after: "... the first person to play this game, on paper ... you play it in your head, second by second, as a
     newcomer would"; "First walk the 30 SECONDS line as the newcomer, beat by beat ... Then check every KILL IF line:
     is it something a person playing the first phase can see". Score keys unchanged.
   - critic.md, added at the top: "Watch as a newcomer meets the game ... You can fail a game on what the frames show;
     you can never pass its fun, because no frame shows whether a person wants to play again." The first note adds
     "the worst thing a first-time player would feel in them".
   - critic-compare.md: the design's method lines; "A version in which one of the design's kill lines is plainly seen
     loses to one in which it is not."
   - planner.md: the first phase is judged by "a PERSON [who] plays it for 5 minutes and passes or holds it ... The
     bots are the floor; the person is the gate"; every feel number in `data/tuning.json`.
   - builder.md and the builder's Feel section: "a person plays this, so it must feel good in the hand ... the bots
     are the floor under that, never the bar"; the method lines named; feel numbers in `data/tuning.json`.
   Steps (foreman/src): a room design writes the method lines (FANTASY, WORLD, 1-3 TEARDOWN, 30 SECONDS, 2-4 KILL IF) at the
   head of brief.rules and is sent back without them (method.ts methodProblems, designer.ts); the review, the Planner,
   the builders, the critic and the compare read them; the critic scores a new rubric item `kill_criteria` when the
   brief has KILL IF lines (a kill line plainly seen fails the look); `foreman status` prints a "paper" check before
   approval and a "playtest" card at a phase pause (not with run-through).
3. npm test all green with the count. MET.
   - Baseline in this tree before any edit: 310 tests, 303 pass, 0 fail, 7 skip.
   - Round 1: 316 / 309 / 0 / 7. Round 2: 319 / 312 / 0 / 7 (the Director's re-run saw 311 + 1 fail: the busy-machine
     spawn-timeout test "grandchild kept running", wall clock; it passes alone). Round 3: see GATES.
   - New tests: foreman/src/test/n2_method.test.ts (9 tests: METHOD sections, roles and sources; the method lines;
     the room's prompts and send-back; Planner and builder text; the critic's kill_criteria item; status paper and
     playtest lines; CASES' method lines and stages; the world-size rule; the compare prompt).
   - Test expectations moved, with why: the fixture brief v2Brief() carries method lines (a room design needs them);
     fake critic answers on such briefs score kill_criteria (the rubric now has it); the builder Feel header regex
     reads "(docs/GAME-QUALITY.md, docs/design/METHOD.md)". No test was loosened.
   - Fast tier: 5/5 PASS on every round's tree.
4. docs/GAME-QUALITY.md points at METHOD.md. MET. A "read METHOD.md first" paragraph at the top ("Every check in this
   file can fail a game; none of them can pass its fun"); section 1's pillars, loops, first minute and one-page design
   dropped (METHOD 5, 6, 7, 13; the designer prompt no longer pastes section 1); section 9's "how professionals test
   fun" points at METHOD 10-12; section 12's "And a person" names the playtest card.
5. No Foreman build job. MET. Dry runs: lanes/N2-method/dry-run-r1.txt (design room on the FAKE adapter: the method in
   the concept, design and review prompts; the paper check in status) and dry-run-r3.txt (the fixture job-phases with
   method lines on the FAKE adapter and runner, run to its first phase pause: the playtest card).

   Round 4 (the Director's go after round 3 landed):
   - WORLD, a fifth required method line: the size of the world in the player's units (body size, the arena in body
     widths or lengths, speeds in body lengths a second, the camera's distance in body heights), at most 45 words. A
     design without it, or with one that names no body unit (/body widths|lengths|heights/), is sent back (method.ts
     WORLD_UNITS). It reaches the review, the Planner, the critic and the paper check ("the world in the player's
     units"). N1's top finding (a rink of 34 body widths that nobody chose) is now enforced, not only prompted.
   - The tell floor raised from 12 to 20 frames: the tofu row tell_min_f (foreman/src/tofu.ts, min 20), checklist item 11
     and the tofu table of GAME-QUALITY.md, builder rule 18 (a chained follow-up too), and the designer prompt. Why: 12
     sat below the human limit it protects (about 15 frames average reaction, 20 reliable [CASES B25]; For Honor's
     lights 24-30), N1's duel teardown lesson 3. Consequence named: the house duel's own figure is 12 (its chained
     lights), so it now fails item 11, and a build that copies it fails its tofu row; the duel is out of tonight's
     scope (no game work), so that is the next duel change, not tonight's.

   Round 5 (the Director's go after round 4 landed): a house game is a working base, not the quality bar.
   - Before (templates.ts houseExcerpt, pasted to the design step, the Planner and every builder):
       "# The house game: engine/packs/<pack> (<game>), the reference implementation of this template
        It is a tracked game of this engine that plays the template on the kernel, tuned there. Copy its rules, its
        numbers and its structure; where its numbers differ from the research, the house game's win (they are
        measured on this kernel)."
     After:
       "# The house game: engine/packs/<pack> (<game>), a working base on this engine, NOT the quality bar
        It is a tracked game that runs this template on the kernel: read it for how the engine is driven (its files,
        calls, data layout, the frame table the Foreman checks). The owner played it and called it slop (22 Nov), and
        no person has accepted it since: its feel, timing, scale, camera and screen are a floor, not the bar. The bar
        is the reference below ("The bar"): where the reference's numbers and the house game's differ, the
        reference's win unless the design says why."
     followed by "# The bar: the reference games, not the house game": 8 reference numbers per template (CASES.md) and
     the teardown's top ten as "Do NOT copy these from the house game" lines (templates.ts `bar`, barLines).
   - The arcade_sport bar takes the scale and the puck from thirdjam: contact radius 0.4 m, rink 90 x 45 m = 112 body
     widths, cruise about 7 body heights a second, carrier x0.92, bots sprint, puck drag 0.5/s + friction 0.147 m/s^2,
     a pass solved to arrive at 8 m/s, a snap shot cone of 8 degrees, the camera bound to you with an aim anchor,
     mates who shoot, bots deciding every frame, one run to three goals, presentation-only hit-stop, nothing drawn at
     a hit. Its camera keep changed from "a broadcast camera ... following the puck" to "the play camera bound to YOUR
     skater and raised (behind and above, with an aim anchor), or a raised broadcast view that keeps you in one place;
     never low behind the skater, never one that follows the puck and loses you". The house numbers `skater` and
     `follow` are labelled as the house game's, with their faults named (body_scale 2.2; a camera on the puck).
   - The duel bar: lights 24-30 frames, heavies 48-60, every dangerous tell >= 20, parry rewards 36/54, a shrinking
     12-frame parry, i-frames about 28, hit-stop 6-8 / 12-16, an attack every 2-3 s, rounds 45-90 s and a waiting first
     rival (both our calls, to test by hand), two bars.
   - The floor stays: the frame check, the house compare and the house strip still run. Their words change: the
     compare's "SHORT ... copy how engine/packs/<pack> does it" became "reach at least its figure (how ... does it shows
     the engine calls); it is a floor, not the bar: the bar is the reference game (docs/design/CASES.md)"; the critic's
     context "is the bar" became "is a floor, not the bar: a working base the owner called slop and no person has
     accepted"; the strip label "(the bar, not this build)" became "(a floor, not the bar, not this build)"; the
     house_game rubric item says "a FLOOR and not the bar ... Reaching the house game is not reaching the bar"; the
     critic's context gains the template's "do not copy" lines (quality.ts barContext); the revise pair asks for "at
     least like the house one" and not to copy what its teardown names.
   - GAME-QUALITY.md section 11 ("Where the two differ, the house game wins") rewritten: "A house game is a working
     base, not the quality bar"; the house numbers still win only on how the kernel is driven (pushbox, camera API, clip
     clocks). planner.md and METHOD.md section 9 say the same.
   - The frame-check question this round raised was decided by the Director and built in round 6 (below).

   Round 6 (the Director's ruling after round 5 landed): a copied move may wind up slower than the house game's, up to
   the template's bar, never faster.
   - templates.ts: Bar.maxAnticipation (the duel: light 30, heavy 60, For Honor's 400-500 ms and 800-1000 ms);
     designTemplateProblems accepts anticipation_f from the house game's figure to that maximum; active and recovery
     frames, and every move without a bar maximum, are still copied exactly. The refusal names the range:
     "anticipation_f 31 (the table: 18 to 30: at least the house game's, at most the bar's)".
   - Before (the refusal): "changes its frames: anticipation_f 6 (the table: 18)"; after: "anticipation_f 6 (the
     table: 18 to 30: at least the house game's, at most the bar's)".
   - The concept menu, the template excerpt, the designer prompt and GAME-QUALITY.md (rule 5, section 11) say a wind-up
     may be slower, up to the bar, never faster. JOB.md's 2026-11-22 paragraph is the Director's to word.
   - Tests both ways (n2_method round 6): a duel light at 18 and 26 accepted, 31 and 16 refused; a heavy at 60
     accepted, 61 refused; a slower block (no bar maximum) still refused. Two n4 expectations name the range now.

=====================================================================================================================
GATES (round 6 tree)
=====================================================================================================================
- npm test (foreman), round 6: 322 tests, 315 pass, 0 fail, 7 skip (22:26; +1 round-6 test). Fast tier 5/5 PASS.
- npm test (foreman), round 5: 321 tests, 314 pass, 0 fail, 7 skip (22:10; +1 round-5 test). Fast tier 5/5 PASS.
- npm test (foreman), round 4: 320 tests, 313 pass, 0 fail, 7 skip (21:46). Fast tier 5/5 PASS.
- npm test (foreman), round 3: 319 tests, 312 pass, 0 fail, 7 skip (21:30). One earlier full run of the same tree had 2
  environment failures (robust.test "the child never appeared in the ledger"; wp3c.test cleanup "EPERM, Permission
  denied" on a temp dir); both files pass alone (25/25), and the full rerun above is clean. Counted as a busy machine,
  not that change (round 3 changed only docs).
- Test expectations moved in round 4, with why: the passing tofu fixtures' tell_min_f 14/18 -> 22/24 (the floor is 20),
  including the shared fixture bot foreman/fixtures/job-paddle/fake-builder.json (18 -> 24; without it the cli test
  "new -> approve -> plan -> run" held at its tofu look, which showed the floor working);
- Test expectations moved in round 5, with why (the stance changed, so the words did): d3_hockey's camera keep message
  and the house numbers' label; n4_house's excerpt head, menu line, compare line, critic context and strip label. The
  checks themselves (hockey -2's low chase camera fails; the house compare's SHORT rows) are unchanged.
  the failing fixture's message "wants >= 12" -> ">= 20"; the crazy colosseum proof's real figures (tell 12) now fail
  the tofu row, asserted as such, and pass with 20; n2 tests count five method lines. No test was loosened.
- Fast tier: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
- Full tier: not run; no kernel, kit, rigs, style or seeds file changed (the lane rule asks for it only then).

=====================================================================================================================
CHANGED FILES (all rounds)
=====================================================================================================================
new:     docs/design/METHOD.md, docs/design/CASES.md, foreman/src/method.ts, foreman/src/test/n2_method.test.ts,
         lanes/N2-method/{STANDUP.md, REPORT.txt, dry-run-r1.txt, dry-run-r3.txt}
changed: docs/GAME-QUALITY.md; foreman/fixtures/job-paddle/fake-builder.json; foreman/prompts/{concept,designer,design-review,critic,critic-compare,planner,builder}.md;
         foreman/src/{designer,quality,room,roomtext,status,tofu,templates,house,revisepair}.ts;
         foreman/src/test/{helpers,n4.test,n4_house.test,n4_moments.test,filmcheck.test,quality.test,d3_hockey.test}.ts
Prompt size: the designer prompt grows about 8 KB net (method 7990 chars in, GAME-QUALITY section 1's 3015 out).
designer.ts is at 597 lines of its 600-line budget.

=====================================================================================================================
BEHAVIOUR CHANGES
=====================================================================================================================
- A design-room answer without the five method lines (a WORLD line in body units included), or over their word limits,
  is sent back (it costs a retry on a
  model that ignores them; the prompt shows the exact format and a worked example).
- A look of a job whose brief has KILL IF lines has one more rubric item (kill_criteria); the critic must score it, and
  a kill line plainly seen fails the look like any rubric item under the threshold.
- The keep-the-better compare reads the method lines; a version showing a kill line loses.
- The tofu row tell_min_f needs 20 frames (was 12).
- `foreman status` prints "paper" lines before approval and "playtest" lines at a phase pause. A brief without method
  lines (every job made before tonight) prints and judges exactly as before.

=====================================================================================================================
FOR THE OWNER (how to look)
=====================================================================================================================
- Read docs/design/METHOD.md sections 1 to 3 (5 minutes): the test, the evidence, the stages.
- Read docs/design/CASES.md: each case's "Stage 4: the 30-second test" and "Stage 8: kill criteria" are what you would
  check with your hands; "What our build did instead" says where we went wrong.
- The next editor job (when you allow one) shows you, before you approve, the FANTASY, WORLD, TEARDOWN, 30 SECONDS and KILL IF
  lines ("foreman status": paper lines), and at the first phase pause the playtest card.

=====================================================================================================================
QUESTIONS AND PROPOSALS FOR THE DIRECTOR (contracts are Director-only)
=====================================================================================================================
1. ASK FOR THE OWNER (verdict page, ask 1): the person gate after the first phase with run_through.
2. ASK FOR THE OWNER (ask 2): JOB.md design keys versus the labelled rules lines; the readers (job-events schema,
   job_model.gd, event_schema.gd) would follow a key change.
3. DONE (rounds 4 and 6, JOB.md worded by the Director in 2599ebe and b925a54): tell_min_f >= 20; a copied move's
   wind-up may be slower than the house game's up to the bar. The house duel now fails item 11 (ask 3).
4. CARDS.md proposal: recipe cards could carry a card's own FANTASY and KILL IF lines, so a card-built game starts from
   a tested fantasy (engine/cards is in my scope, the card schema is a contract).

=====================================================================================================================
NEXT THREE THINGS THIS LANE WOULD DO
=====================================================================================================================
1. A playtest record: `foreman phase <job> hold|pass --note` notes parsed into who played, minutes, the ranked worst
   three and the kill lines seen, so the next round's builders read a structured playtest, not free text.
2. Done in round 4 (the WORLD line). Next: read the WORLD line's numbers into the Planner's root contract and check
   them against the build's own layout (the rink's length over the body's width), so a build cannot drift from it.
3. Run the method on paper with the owner for one sentence (no build): the room's concept and design, read aloud,
   paper lines judged by him; that is the first [H] evidence the method itself works.
