N2 method: REPORT, night of 22-23 Nov 2026 (19:12 to the last STANDUP line, CEST)
Worktree n23-method. Route: Opus solo, with two read-only web-research subagents (craft and process; the two cases).
Nothing committed by me; the Director landed round 1 (a9b5447) and round 2 (42b1097). Round 3 is in this tree.

Nobody has played anything this lane made: it is a method, prompts and checks. No Foreman build job was started; the two
dry runs used the FAKE adapter (and, for the playtest card, the FAKE runner on a test fixture), so no model was called,
nothing was billed and nothing was built.

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
   Steps (foreman/src): a room design writes the method lines (FANTASY, 1-3 TEARDOWN, 30 SECONDS, 2-4 KILL IF) at the
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

=====================================================================================================================
GATES (round 3 tree)
=====================================================================================================================
- npm test (foreman): 319 tests, 312 pass, 0 fail, 7 skip (21:30). One earlier full run of the same tree had 2
  environment failures (robust.test "the child never appeared in the ledger"; wp3c.test cleanup "EPERM, Permission
  denied" on a temp dir); both files pass alone (25/25), and the full rerun above is clean. Counted as a busy machine,
  not this change (round 3 changed only docs).
- Fast tier: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
- Full tier: not run; no kernel, kit, rigs, style or seeds file changed (the lane rule asks for it only then).

=====================================================================================================================
CHANGED FILES (all rounds)
=====================================================================================================================
new:     docs/design/METHOD.md, docs/design/CASES.md, foreman/src/method.ts, foreman/src/test/n2_method.test.ts,
         lanes/N2-method/{STANDUP.md, REPORT.txt, dry-run-r1.txt, dry-run-r3.txt}
changed: docs/GAME-QUALITY.md; foreman/prompts/{concept,designer,design-review,critic,critic-compare,planner,builder}.md;
         foreman/src/{designer,quality,room,roomtext,status}.ts; foreman/src/test/{helpers,n4.test,quality.test}.ts
Prompt size: the designer prompt grows about 8 KB net (method 7990 chars in, GAME-QUALITY section 1's 3015 out).
designer.ts is at 597 lines of its 600-line budget.

=====================================================================================================================
BEHAVIOUR CHANGES
=====================================================================================================================
- A design-room answer without the four method lines, or over their word limits, is sent back (it costs a retry on a
  model that ignores them; the prompt shows the exact format and a worked example).
- A look of a job whose brief has KILL IF lines has one more rubric item (kill_criteria); the critic must score it, and
  a kill line plainly seen fails the look like any rubric item under the threshold.
- The keep-the-better compare reads the method lines; a version showing a kill line loses.
- `foreman status` prints "paper" lines before approval and "playtest" lines at a phase pause. A brief without method
  lines (every job made before tonight) prints and judges exactly as before.

=====================================================================================================================
FOR THE OWNER (how to look)
=====================================================================================================================
- Read docs/design/METHOD.md sections 1 to 3 (5 minutes): the test, the evidence, the stages.
- Read docs/design/CASES.md: each case's "Stage 4: the 30-second test" and "Stage 8: kill criteria" are what you would
  check with your hands; "What our build did instead" says where we went wrong.
- The next editor job (when you allow one) shows you, before you approve, the FANTASY, TEARDOWN, 30 SECONDS and KILL IF
  lines ("foreman status": paper lines), and at the first phase pause the playtest card.

=====================================================================================================================
QUESTIONS AND PROPOSALS FOR THE DIRECTOR (contracts are Director-only)
=====================================================================================================================
1. ASK FOR THE OWNER: the person gate. With run_through the Foreman passes its own phases (JOB.md 2026-11-20). Should it
   still pause after the FIRST (greybox) phase for a person's pass or hold (METHOD.md section 10)? Recommended: yes.
2. JOB.md proposal: brief_set.brief.design could carry the method stages as keys (fantasy, teardown[], thirty_s, kill[])
   instead of labelled lines in brief.rules; the readers (job-events schema, job_model.gd, event_schema.gd) would follow.
   Held by the Director for the verdict; tonight's labelled lines need no contract change.
3. JOB.md / GAME-QUALITY.md proposal: the tofu row tell_min_f >= 12 (checklist item 11) sits below the human limit it
   protects (about 15 frames average reaction, 20 reliable; For Honor's lights 24-30). Raise it to 20 (N1's duel
   teardown lesson 3). Not changed: it is a contract number and the house duel's chains would fail it.
4. CARDS.md proposal: recipe cards could carry a card's own FANTASY and KILL IF lines, so a card-built game starts from
   a tested fantasy (engine/cards is in my scope, the card schema is a contract).

=====================================================================================================================
NEXT THREE THINGS THIS LANE WOULD DO
=====================================================================================================================
1. A playtest record: `foreman phase <job> hold|pass --note` notes parsed into who played, minutes, the ranked worst
   three and the kill lines seen, so the next round's builders read a structured playtest, not free text.
2. A "world in the player's units" check in the design step: the brief's rules must state body size, arena in body
   lengths and speed in body lengths a second (today it is prompt text only).
3. Run the method on paper with the owner for one sentence (no build): the room's concept and design, read aloud,
   paper lines judged by him; that is the first [H] evidence the method itself works.
