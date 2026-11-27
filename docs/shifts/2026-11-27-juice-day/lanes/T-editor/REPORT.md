T-editor: the editor's queue from the juice night (day of 27 Nov 2026, 08:15-11:15)
Tree d25-hard-a, branch d27-tofu (from main 8be26d61). Nothing is committed: the Director lands it.

HOW THE LIVE PROOFS WERE MADE
- I copied the three night jobs (d25-shield, d25-arsenal, d25-court) into .tl/d27/src. I read the source jobs and did not
  change them.
- I rolled each copy back to the version before the night's sentence (.tl/d27/rollback.mjs):
  - job.jsonl was cut after that version's promotion;
  - pack/ was restored from that promoted copy;
  - ws/, state.json and later promotions were dropped.
- The three copies:
  - J19 shield wall at v0.1.4, with J19's sentence 1;
  - J1 Arsenal hockey at v0.1.21, with J1's meteor sentence;
  - J4 half court at v0.1.4, with J4's A3 "on fire" sentence.
- Each sentence was sent once, word for word as the night sent it. Adapter claude-cli, Sonnet builders, the change
  flags of engine/ui/flags/real.json.
- All three jobs ran at the same time on a machine at CPU 100 % (another session was running too). Every round logged
  starved_stalls notes. The wall times below are slow because of that and cannot be compared with the night's.
- The job log times are UTC. My 10:0x standup line said "15 min" for J19. That was wrong: it took 74.9 min. The
  standup has a correction line.

OUTCOME AGAINST EACH ITEM

1. A sentence about the rivals reaches every package that drives a bot: MET.
   - Unit tests: D27 1 (J19's real plan, merged files and sentence) and D27 1b (end to end through the Foreman on the
     paddle fixture: the rival paddle's package is reopened and merges after core).
   - How it works (rivals.ts rivalSplit, called in applyChangeRequests):
     - it picks the person's sentences where a rivals word (rivals, bots, opponents, defenders, mates, keepers...) is
       followed within five words by a verb of doing;
     - those sentences go, as the Foreman's change request, to every other package whose files decide for a bot
       (brain, mind, ai...), never to a base;
     - nothing is sent when no sentence names the rivals. A sentence about what happens to them, or about their look,
       is not sent.
   - Live, J19 copy:
     - event 596 sent "The rivals charge an open line, raise shields when charged, slam a crowd and run out of the
       ring." to crew (scripts/crew/mind.gd) in the same second the Planner named core;
     - crew r4 merged scripts/crew/mind.gd (event 640) after core;
     - v0.1.5 was promoted from ONE sentence (74.9 min, 3.23M tokens in). The night needed two sentences and two
       versions to get there.
   - Hand measure, the same hand J19 used (tests/bot_juice_d27.gd, which counts the new contact types), seeds 1-3,
     3600 frames, 0 script errors:
     - bots' slams 4 / 2 / 4 a minute, by Pip, Finn, Sable, Oda and Bram (night v0.1.5: 0-1, all of it Bram);
     - bots' rush starts 1 / 2 / 0 a minute;
     - slam knockdowns 11 / 6 / 8.
   - Live, J4 copy: event 1114 sent "Defenders double-team whoever is on fire." to crews_stakes (scripts/crews/brain.gd).
     crews_stakes r12 built the trap double team, merged at event 1161.
     - Limit: that job ran on the first build of rivalSentences, before the five-word window. It also quoted the first
       sentence ("until the other side scores ... their jumps go higher"). The window is fixed and tested (D27 1).
   - Film: clips/j19_d27_v015_rivals_slam.mp4 (14 s, seed 1, frames 1100-1960, 0 script errors).
     - Stills I looked at: stills/j19_pip_slam_f1136-1208.jpg and j19_finn_slam_f1856-1928.jpg.
     - Pip leaps with the red landing ring under him. The hint reads "Pip: Leaping slam: get out of the red ring before
       he lands", and the captain's health drops.
     - Finn's slam leaves a fighter in blue floored in a ring of gold slabs.
     - As a person: the rival crew now slams too, and you see the ring coming.

2. A play request that a drawing package hands off is carried to the cartridge's owner and made: MET, on the second run.
   - Cause: halfmade's NOT_DONE did not read "RULE: not done." (lower case, no "here"). Its ownerOf also took the first
     plan package whose glob held the path, so the base's data/** would have taken data/harbour.cartridge.json.
   - Fixed:
     - NOT_DONE now reads "not done/made/built" at the start of a line, and "needs <path>, which is outside my scope";
     - ownerOf prefers a package that lists the path itself and never picks a base;
     - every round since the reopening counts;
     - lines go to their owners one by one (lists, not singletons).
   - Unit tests:
     - D27 2: J1's real event 1012 now goes to cartridge. On main, the same input makes no request (checked on main's
       compiled code: [] ).
     - D27 2b: the what-changed card no longer shows a "RULE: not done" line as an unasked rule or as what you will see.
   - Live run 1 (kept in .tl/d27/runs/j1-run1-three-against-three-hockey):
     - harbour r15 wrote NOT DONE lines with the exact keys. Events 1036/1038 carried them to cartridge and skin.
     - cartridge r12 MADE the meteor: shotgun mode, magnitude 2, cooldown 720, charge 40/12, spin_stability 0.5, merged at
       event 1056.
     - Then the final verification failed on harbour's own test of the old bubble. The data-only path had skipped
       harbour's re-verification, and the blame went to skin, then to the cartridge.
     - The cartridge builder put the bubble back against the person's words and asked a question (events 1105-1108).
   - Fixed (D27 2c): a data-only round that REMOVED something re-verifies its dependants (fastchange.ts removedInRound;
     foreman.ts +0 lines).
   - Live run 2 (fresh copy, the same sentence, sent once):
     - the cartridge made it at event 1049;
     - harbour was reopened as a dependant (event 1055) and adapted its test to the meteor (merge 1096);
     - v0.1.22 was PROMOTED at event 1166 (54.9 min, 3.88M in).
   - The promoted cartridge: one shotgun mode ability, magnitude 2, cooldown 720 (12 s), charge_frames_max 75,
     charge_speed_bonus 6, spin_stability 0.4, puck max_speed 50. The night needed a second sentence for this.
   - A cost run 2 still paid: skin, handed only the tagline, said "the meteor itself needs the cartridge". That sent it
     back to cartridge (r13, r14) and harbour (r17), and none of them changed anything.
     - Fixed after (D27 2d): one hop. A round that was itself handed the rest of a change tells the person and sends
       nothing on.
     - Run 2's process had loaded the code from before that fix.
   - Film: clips/j1_d27_v0122_meteor.mp4 (5 s, seed 1, frames 2160-2460, the night's tests/bot_meteor_blind.gd).
     - Still I looked at: stills/j1_meteor_f2256-2352.jpg.
     - The hint reads "F: METEOR Light your stick on fire" and the plate "F: METEOR READY". A fire ring flares at the
       stick, the plate turns to "METEOR BACK IN 12", the fireball flies 27 m with sparks, and GOAL comes up.
     - The night's editor v0.1.23 said "CANNON LOADED" and "F: SHOTGUN".
     - The film run printed 1 SCRIPT ERROR at exit, in the kernel runner's watchdog: "Cannot call method 'lock' on a
       null value" at kernel/runner/worker.gd:387 _wd_run. It is not the pack's, and I did not touch it (kernel).
       The headless runs had 0 errors.
   - Headless, seed 1, 3600 frames, 0 script errors: 4 meteors in the minute (frames 92, 1191, 2284, 3234). Each one
     flattens 2 skaters, and all 4 are goals.
     - For the owner: a meteor is a sure goal, and the first one comes off the faceoff drop at frame 92. The night's
       by-hand pack had to hold F back after a drop.

3. The builder reads the cartridge's keys before saying "the cartridge has no key": MET.
   - Prompt: coreroute.ts coreExcerpt (builder part) has a new rule, "Read the catalog before you say a key is
     missing". The builder must search ref/cores/<core>/CARTRIDGE.md and name the key it found. When nothing matches, it
     writes "NOT DONE: no key in CARTRIDGE.md for <what> (searched: <words>)". A key in a file it does not own goes as
     "NOT DONE: ... needs <file>, which is outside my scope: <key and value>".
   - The Foreman checks the claim too (keyfind.ts). It finds the catalog rows that meet a "no key" line, and they travel
     with the carried request: "harbour said the cartridge has no key ..., but the catalog has keys that may be exactly
     that: ...".
   - Unit test D27 3: on J1's real line it finds shot.charge_frames_max/charge_speed_bonus and
     game.contact.spin_stability.
   - Live, both runs: harbour r15 named game.shot.charge_frames_max, game.shot.charge_speed_bonus and
     game.contact.spin_stability itself ("Per the catalog this stability cost applies with a full shot wind-up").
     - It wrote "CARTRIDGE.md has no key for either (searched: ability, shotgun, block, dive, bot trick, ai)" only for
       the bots' meteor and dive. That is true (CARTRIDGE.md: "Bots never hold one").
     - The night's false "no key" did not recur.

4. A new attack the person asked for lands at least once in the Foreman's bot run, or the round goes back: MET, with a
   weakness I name.
   - landcheck.ts landGate runs after a round's acceptance passes, in a person's play change that asks for an attack:
     - every move the builder names ("NEW MOVE: <id>", or "New moves `x`") must be counted by a bot test of the package
       (metrics.moves.<id> {started, landed});
     - not counted, never used, or 0 landed is a failed check of its own, and the builder gets the figures and the
       likely cause (reach against how close bodies can come);
     - after the revise budget (2 rounds) the round merges, and the person gets "part of your change was NOT made ...".
   - D27 run 1 taught two more rules (D27 4b, 4c):
     - a round that hands part of the change on is not sent back for its move; the final bot run judges it at
       promotion (finalLandNotes) and the card says so;
     - the newest NEW MOVE line of a package is its word on its moves (run 2 named "shotgun", then "meteor").
   - builder.md has new rules: "A new attack must land" and "What is not yours goes on" (the NOT DONE form).
   - Unit tests: D27 4 (J19's real builder note, 0 of 15 is refused), 4b, 4c.
   - Live, J19: core r14 named NEW MOVE rush and slam and added metrics.moves to tests/bot_player.gd. The gate passed
     with "rush landed 1 of 13, slam landed 2 of 2" (event 611).
     - The rush's reach went from 1.15 to 1.25 m, still under the 1.4 m pushbox gap.
     - My hand measured the rush at 0 knockdowns in 11 rushes over seeds 1-3. The slam floors people every few seconds.
     - Weakness: "at least once" is met by 1 of 13. bot_player even stops pressing rush once it has landed. As a person,
       the charge still almost never bowls anyone over.
     - On the night's v0.1.5 the gate would have refused 0 of 15 (test D27 4). Whether the bar should be a share
       (Q1 below) is the Director's call.
   - Live, J1 run 2:
     - the gate let harbour's round through to the final run ("new move judged at the end", event 1085);
     - harbour counted "meteor: 3 started, 2 landed" in bot_harbour;
     - the card note at event 1163 then wrongly said "shotgun was not seen to land". Fixed after (D27 4c); that job ran
       on the code from before the fix.

5. Banners and impact words go mid-screen, not into the score line: MET for the new word, where builders get it.
   - builder.md has a new rule, "Words on the screen": a TLHudLayer text or a center label, an outline instead of a box,
     never in the score or clock line, never padded with blank lines into a slab.
   - Every card's fun.juice says the same (6 cards; duel's banner line is extended).
   - The duel template's role lines say it (templates.ts).
   - Unit test D27 5.
   - Live, J4 copy, the night's A3 sentence (which does not say where the words go):
     - court_exchange r11 drew "<NAME> IS ON FIRE!" on a new HUD painter layer at the screen centre: 64 pt, black face,
       outline, fading;
     - its note: "The existing DUNK!/REJECTED! banners still sit in the score line as before; I didn't move them in this
       round" (not asked);
     - v0.1.5 was PROMOTED at event 1259 (105 min, 2.80M in).
   - Film: clips/j4_d27_onfire_mid_screen.mp4 (6.2 s, seed 1, frames 1850-2220, the night's film_v014.gd hand, 0 script
     errors).
     - Still I looked at: stills/j4_onfire_f1904-2048.jpg. Big orange "YOU IS ON FIRE!" in the upper middle of the
       court, with no slab, and the clock "00:32 SHOT 12" clear.
     - Compare the night: J4-court/stills/a3_editor_v015_fire.jpg, where ON FIRE ran into the clock.
     - Flaws a person sees:
       - "YOU IS" is wrong grammar for the player's own id;
       - the old "*** DUNK! ***" still prefixes the score line. It was not asked; a sentence fixes it now that the rule
         is in every builder's prompt.

6. Create shows every "balance moved" note of a change, not only the newest: MET.
   - boundlift.ts balanceLines keeps the newest line of each thing moved (the words before " now "), in first-told
     order. The what-changed card (fastchange.ts) and Create (create_model.gd balance_note) both use it.
   - Unit tests: D27 6, plus the create.iterate.model case extended with two older notes. That expectation changed on
     purpose: two lines where there was one.
   - Real job (Godot headless, .tl/d27/create_note.gd, main's create_model.gd beside mine), T2's robot job with 3 notes:
     - main shows 1 line: "newcomer wins 11 of 20";
     - this lane shows 3: "close test rounds: now 0, was 0", "matches now run longer", "newcomer 11 of 20".
     - The first of the three is T2's stale note from before its fix. New jobs no longer write it, but old jobs show it
       now.

GATES ON d25-hard-a
- foreman npm test:
  - run 3 (after every source change but the D27 4c fix): 471 tests, 464 pass, 0 fail, 7 skipped;
  - run 4 (final source): 472 tests, 465 pass, 0 fail, 7 skipped;
  - main: 460 / 453 / 0 / 7. The new tests are d27_editor.test.ts (12).
  - Run 1 (468/461) had its dist rebuilt mid-run and is not counted.
- node devx/bin/tl.mjs check --tier fast, second run: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test
  230/230, foreman.typecheck).
  - The first run FAILED devx.test 229/230 on arch's "real tree under 5 s" timing, at CPU 100 % with three jobs
    running. It is a clock under load, not code; it passed when rerun.
- selftest create.: 29 passed, 0 failed. Run after the Create changes; Create was not touched after it.
- Full tier: NOT RUN. No kernel, kits, rigs, style or seeds changed (cards and ui only).
- foreman.ts is 2004 lines (ratchet 2032).

CHANGED FILES
- foreman/src/rivals.ts (new), landcheck.ts (new), keyfind.ts (new);
- foreman/src/halfmade.ts: NOT_DONE, ownerOf, per-owner groups, coreHintOf, one hop;
- foreman/src/fastchange.ts: balanceLines on the card, removedInRound;
- foreman/src/boundlift.ts: balanceLines;
- foreman/src/coreroute.ts: the builder's catalog rule;
- foreman/src/templates.ts: banner words;
- foreman/src/foreman.ts: 4 call sites, +2 lines;
- foreman/prompts/builder.md: three rules;
- foreman/src/test/d27_editor.test.ts (12 tests); foreman/fixtures/d27/ (4 small JSON excerpts of the night's and
  today's real events);
- engine/cards/*.json: one juice line each;
- engine/ui/create/create_model.gd, create_iterate_checks.gd (CRLF kept);
- docs/shifts/2026-11-27-juice-day/lanes/T-editor/: STANDUP.md, REPORT.txt, clips/ (3 mp4), stills/ (4 JPG).

BEHAVIOUR CHANGES (named)
- A person's change can now re-open more than one package:
  - the rivals' words go to every bot package;
  - a builder's NOT DONE line goes to the owner of its file, once (one hop).
- In a person's attack change, a round whose new move never lands, or is not counted, goes back to its builder (at most
  2 rounds; then a NOT MADE note). A move handed on is judged at promotion and only noted.
- A data-only cartridge round that removed something re-verifies its dependants (no longer the full fast path).
- Create's done screen and the what-changed card can show several balance lines.

FOR THE OWNER (menu rows, if wanted)
- .tl/d27/jobs/shield-wall-3-v-20261125-1/promoted/game.shield_wall_3_v@0.1.5: "Shield wall: big moves, one sentence
  (editor d27)".
- .tl/d27/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.22: "Arsenal hockey:
  meteor, one sentence (editor d27)".
- .tl/d27/jobs/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.5: "Half-court 3 v 3: on fire mid-screen
  (editor d27)".

QUESTIONS FOR THE DIRECTOR
1. Item 4's bar: "at least once" let J19's rush through at 1 of 13 (my hand measures 0 of 11). Should it be a share of
   uses, for example a quarter? That means more send-backs and more tokens.
2. Proposed JOB.md note text (Director-only):
   - "[foreman] new move lands in the Foreman's bot run: ...";
   - "[foreman] new move judged at the end: ...";
   - "part of your change was NOT made by X: the new move ...";
   - change requests "[foreman] the rivals' part of change request N, ...";
   - a bot test's metrics.moves.<id> {started, landed} as the Foreman's convention.
3. J1 copy finding, not in my six: every meteor in the editor's v0.1.22 is a goal, and one comes off the faceoff drop.
   That is a balance figure for the person, not a defect of the editor.

NEXT (queued by the Director, after this lands)
7. A person-asked play rule can reach rules.json when the cartridge owns it (S4 events 1082-1095).
8. The exe segfaults after a refused rules file. I fix it only if the fix is in engine/templates/rink_game, cores/rink
   or ui; otherwise I write it up.
9. Create says plainly when a frozen measure undid a person's ask (S35 biplane).
10. Only a real fairness ask counts as one; "balance" alone does not (S35 karts).
11. Every package's change reaches the what-changed card; a promotion that changed nothing says "nothing changed".
