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

==========================================================================================================================
ROUND 2: items 7-11 (after the Director landed 1-6 as 658eb637), 11:15-12:35
Tree d25-hard-a (fast-forwarded to 658eb637), foreman rebuilt. Not committed: the Director lands.

THE DIRECTOR'S RULINGS ON ROUND 1, AS WRITTEN DOWN
- Item 4's bar stays "at least once" today. For the owner: "a share of uses instead?" (J19's rush passed at 1 landing in 13,
  and my hand measured 0 knockdowns in 11 rushes).
- The faceoff meteor (every v0.1.22 meteor scored) is a balance question for the owner and is left as it is.
- The JOB.md text is below (PROPOSED JOB.md TEXT), for the Director to add to the contract.

OUTCOME AGAINST EACH ITEM

7. A person-asked play rule can reach the cartridge's rules.json: MET.
   - Cause: S4's job, events 1082-1095. The cartridge's builder named the sidecar switches and marked them NOT BUILT:
     data/harbour.rules.json was outside its scope ["data/harbour.cartridge.json", "data/match.json"], and its contract
     said "no sidecar". The person's "Yes, add that file" granted nothing, because the question named no path, as
     questions to a person must not.
   - Fix (scopegrant.ts sidecarOf, through withGrants):
     - on a game on a core, in a person's change (a change since the last promotion), the package that owns the game's
       cartridge (the one with data/match.json) also owns data/<cut>.rules.json, unless another package lists it;
     - the scope listed in the builder prompt shows the file;
     - the merge note says "scope widened for this change: cartridge owns the game's cartridge, so it may write its
       rules sidecar ...";
     - a core builder rule (coreroute.ts) says the same: write the file, never mark a rule NOT BUILT for want of it.
   - Unit test D27 7, on S4's real plan and events 1071-1095:
     - the cartridge gets data/harbour.rules.json; base, harbour and skin do not;
     - nothing changes before a change, or when another package lists the file.
   - Live, on my J1 copy (at v0.1.22), sentence: "Nobody may skate the puck into the net any more: a puck I or anyone
     carries stops at the goal line, so every goal has to be a real shot."
     - The Planner named cartridge, and the diff found no cartridge key.
     - cartridge r15 wrote data/harbour.rules.json {"schema": "tl.rink.rules/1", "rules": {"net_carry_wall": true}} in
       its FIRST round (event 1177). It merged with the widening note (event 1187).
     - v0.1.23 PROMOTED 7.9 min after the sentence (event 1196), 0.72M tokens in.
   - S4's own switches (bot_ability_share, dive_shot_share) are arm A's core patch, not on main. On main, that rules file
     would still be refused by the Foreman's validation (unknown switch). The scope is fixed; the switch is S4's question.
   - Not filmed: net_carry_wall only shows when a skater carries the puck to the goal line, and no hand of mine does
     that. The Foreman's acceptance and smoke passed on the rule-patched core.

8. The exe no longer crashes on a refused rules file: MET, inside the base.
   - Reproduced with main's exe (dist/ThirdLife, build 6522394): "ThirdLife.exe --headless -- --dungeon=<the base with
     an unknown-switch rules file> --frames=600" gives "Segmentation fault", exit 139.
   - Cause: the kernel's ctx.cores.open returns null after "rules ... do not load" (correct), and the base's
     scripts/main.gd went on with rink.set_difficulty(...) on null. Through the editor's worker that is 24 script errors
     in 15 frames and a watchdog stop; in the release exe it crashes.
   - Fix (engine/templates/rink_game/scripts/main.gd, +24 lines): a null core makes the base stop playing and pushes
     one plain error line.
     - It shows a plated label mid-screen: "THIS GAME CANNOT START / The rink core refused this game's rules (data/<cut>,
       or its rules file data/<cut>.rules.json). / The reason is the error line just before this one in the log."
     - It uses its own view; ticks stop, and pack_state is {state: refused}.
   - Main's exe on the fixed pack: exit 1, the dungeon ends on its 600 frames ("why": "frames"), 2 engine errors, no
     crash.
   - Still: stills/i8_refused_rules_message.jpg (960 px, looked at). The rink hall, and the message in the middle on a
     dark plate, on three lines.
   - Named, outside the Director's list: engine/packs/hokej/scripts/main.gd got the same bytes. Selftest rink.template
     requires the template's scripts to equal hokej's byte for byte. The change is inert in hokej (no rules file), and
     rink.template plus rink.template_bots still PASS. Veto it if you want: the alternative is an exception in that
     selftest.
   - Existing packs keep their own copy of main.gd (a pack copies the base at its first build). S4's hand_a still
     crashes main's exe. New jobs, and any pack whose main.gd is updated, get the guard. The kernel was not touched.
   - Selftest 803-rink-refused.sh (block 800-809; 800-802 were taken):
     - rink.refused_smoke: 600 frames, exactly 2 errors, no watchdog;
     - rink.refused_dungeon: through boot.tscn, ends on its frames;
     - 2/2 PASS. Before the fix: watchdog at frame 15 in smoke, and the dungeon stopped at frame 16 with 22 script
       errors.

9. Create says plainly when a frozen measure undid a person's ask, and why: MET. Whether a person may unfreeze a measure
   is not decided here.
   - engine/ui/create: the notes moved to the new create_notes.gd, because create_model.gd hit its 600-line budget.
     - measure_note shows: "Not applied: a change to tests/support/pilot.gd was undone. The Foreman judges the game by
       it, so a change may not rewrite it."
     - It adds " Nothing in the game changed in this version." when the what-changed note says so.
     - The line comes before the balance lines.
   - Create test: a case inside create.iterate.model (count unchanged; CRLF kept).
   - Live, on a copy of S35's biplane job (v0.1.4) with S35's exact sentence:
     - core r24 restored the pilot, and the freeze undid it (event 751, "measure kept");
     - v0.1.5 was promoted byte-equal to v0.1.4 (only pack.json's version differs), 33.3 min, 0.43M in.
     - Create on the real job (Godot headless, .tl/d27/create_note.gd): main shows "" (nothing); this lane shows "Not
       applied: a change to tests/support/pilot.gd was undone. The Foreman judges the game by it, so a change may not
       rewrite it."

10. Only a real fairness ask counts as one: MET.
   - boundlift.ts FAIR_WORDS no longer matches any "balanc...". It matches:
     - "balance it/them/the teams/the game/...", "rebalance ...", "more balanced", "balanced game/teams";
     - "more even", "make it fairer", "too strong/weak", "overpowered", "nerf".
   - Unit test D27 10: S35's kart sentence ("the old balance check added ...") is a play change, and the biplane
     sentence is not "fair". Seven real fairness asks are still "fair".
   - Live, on a copy of S35's kart job (v0.1.7) with S35's FIRST wording, word for word:
     - core r19 built the clean-up and passed its first round with the balance note ("the share of test rounds where
       the lead changes hands: now 0.17, was 0.33. Say "make it fairer" to tune it.");
     - 0 tofu refusals, and no package other than core merged (no unasked teams change);
     - v0.1.8 PROMOTED in 51.9 min with 0.44M tokens in. S35's run took 125 min and 5.89M, with 3 refusals and teams
       changing the bots unasked. Most of the 51.9 min was verification and the 40 hand checks at CPU 100 %.

11. Every package's change reaches the card, and "nothing changed" when nothing did: MET.
   - fastchange.ts whatChangedNote:
     - "what you will see" takes up to two lines from every merged package (three when only one package merged, as
       before);
     - a package the Foreman's own checks sent back (its reopen was not the person's change) gets its own line: "not
       asked by you: teams changed it when the Foreman's checks sent it back (its dependency core was changed ...):
       `shoot.range_max` changed from 40 to 30 ...";
     - the files named are only those that really differ from the version before (changedFiles: a byte compare against
       the last promoted copy; foreman.ts passes it, +0 lines);
     - none, or nothing merged, reads "nothing changed in the game: the Foreman kept tests/support/pilot.gd as merged:
       it judges the game by it, so a change cannot rewrite it, and the change to it was undone".
   - Unit tests:
     - D27 11a, on S35's kart events 1294-1388: teams' and show's rounds get "not asked by you:" lines with their own
       words;
     - D27 11b, on S35's biplane events 741-786: "nothing changed in the game: ...", no 16-file list; changedFiles on
       temp directories.
   - Live:
     - the biplane card was written by a process that loaded the code from before the last tweak. It reads "nothing was
       merged: the change was NOT made".
     - The current code, run on the same live events with changedFiles of the two promoted copies, gives "...; nothing
       changed in the game: the Foreman kept tests/support/pilot.gd as merged: ...".
     - The kart run merged only core, so the "not asked by you" line had nothing to show live. It is proven on S35's
       real events (D27 11a).

GATES ON d25-hard-a (round 2, final source)
- foreman npm test: 476 tests, 469 pass, 0 fail, 7 skipped (main after round 1: 472/465/0/7; +4 tests: D27 7, 10, 11a,
  11b).
  - Run 5 had 2 failures:
    - H1f 5: fixed by keeping 3 lines when one package merged;
    - cli kill/resume: a timing test that passed alone (10/10) and in run 6.
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck).
  - An earlier run failed arch on create_model.gd's 600-line budget (614). That is now fixed by create_notes.gd
    (create_model.gd is 556 lines).
  - It then failed on create_notes.gd.uid missing; fixed by one class-cache import.
- selftest create.: 29 passed, 0 failed (after the split).
- selftest rink.refused: 2/2. rink.template and rink.template_bots: 2/2.
- Full tier: NOT RUN. The kernel, kits, rigs, style and seeds are untouched. engine/templates and engine/packs/hokej
  changed (the base guard); the house hockey's play is unchanged (the guard only acts on a null core).

CHANGED FILES (round 2)
- foreman/src:
  - scopegrant.ts (sidecarOf; withGrants with the plan; widenedNote);
  - foreman.ts (spec passes the plan; the card gets changedFiles; 2004 lines);
  - coreroute.ts (sidecar rule);
  - boundlift.ts (FAIR_WORDS);
  - fastchange.ts (per-package words, "not asked by you:", "nothing changed in the game", measureKeptWords,
    changedFiles).
- Tests and fixtures: foreman/src/test/d27_editor.test.ts (+4 tests, +2 asserts); foreman/fixtures/d27/
  s4a-cartridge-r13-14.json, s35-kart-3A.json, s35-biplane-3A.json.
- engine/templates/rink_game/scripts/main.gd and engine/packs/hokej/scripts/main.gd (byte-equal); selftest.d/
  803-rink-refused.sh.
- engine/ui/create: create_model.gd (change_note), create_notes.gd (+ .uid, new), create_iterate_checks.gd.
- Lane folder: stills/i8_refused_rules_message.jpg.

BEHAVIOUR CHANGES (named)
- In a person's change on a core, the cartridge's owner may write its rules sidecar.
- Sentences that only name "the balance check" are play changes: balance figures become notes, not refusals.
- The card names every merged package. Packages sent back by the Foreman's checks get their own "not asked by you:"
  line. The files named are only those that changed. A byte-equal promotion says "nothing changed in the game".
- Create shows a "Not applied" line when the Foreman's measure freeze undid a change.
- The rink base stops with a readable card when its core does not open.

PROPOSED JOB.md TEXT (Director-only), rounds 1 and 2
- "[foreman] the rivals' part of change request N, for the bots your files drive (<files>): "<words>" ...": the person's
  sentences that tell the rivals what to do, sent to every other package whose files decide for a bot.
- "[foreman] new move lands in the Foreman's bot run: <id> landed L of S, ... (<tests>)" and "[foreman] new move judged
  at the end: ...":
  - a new attack's landing count;
  - a bot test reports it as bot.result.metrics.moves.<id> {started, landed};
  - a builder names a new move on a line "NEW MOVE: <id>".
- "part of your change was NOT made by X: the new move <id> never landed in the Foreman's bot run (...)".
- "[foreman] the rest of your change, which X did not make (...)": the NOT DONE lines of a builder, sent once (one hop) to
  the owner of the files they name. A "no key" claim carries the catalog's candidate keys.
- "[foreman] scope widened for this change: X owns the game's cartridge, so it may write its rules sidecar <file> ...".
- What-changed lines:
  - "not asked by you: X changed it when the Foreman's checks sent it back (<why>): <its words>";
  - "nothing changed in the game[: <why>]".

FOR THE OWNER
- Item 4: should a new attack have to land a share of its uses, not just once?
- Whether a person may unfreeze a measure (item 9 only makes the refusal visible).
- Menu rows, if wanted:
  - .tl/d27/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.23: "Arsenal hockey:
    no skating it in (rules sidecar, editor d27)";
  - .tl/d27/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.8: "Bumper kart football:
    clean-up, first wording (editor d27)".

QUESTIONS FOR THE DIRECTOR
1. Keep the byte-equal copy of the base guard in engine/packs/hokej/scripts/main.gd? Selftest rink.template requires it.
2. S4's hand_a and editor_a packs still crash main's exe (they carry the old main.gd). Re-copy the base's main.gd into
   them, or leave them as spike evidence?

NEXT
1. A Create screen still for "Not applied" (headless text only so far) and for several balance lines.
2. Freeze the card's hand tests (T1's open ask 3), now that the card names measure kept.
3. Make the one-hop rule smarter: a handed-on round may still send a line to a package that has not merged in this
   change.

==========================================================================================================================
ROUND 3: items 12-15, plus the Director's findings (a) and (b), 12:40-13:55
Tree d25-hard-a (my files equal main bd7c07a5; the contract commit 2706f2e6 is not fast-forwarded here). Not committed:
the Director lands it.

OUTCOME AGAINST EACH ITEM

12. The land check measures honestly: MET. The bar stays "at least once".
   - landcheck.ts: a count is judged only when its bot kept using the move into the last third of its run.
     - The count reports moves.<id>.last_f, the frame of its last use. The runner's bot.frames is the run's length.
     - A count without last_f, or whose last use falls before 2/3 of the run, sends the round back: "the count must come
       from a bot that keeps using the move to the end of its run ... and never stops once it has landed".
     - A test's landings are held to its uses (J19 round 3: bot_crew counted 8 victims from 6 rushes, which summed to
       "9 of 8 (113 %)").
     - Every figure now carries the share: "rush landed 7 of 8 (88 %)".
   - builder.md "A new attack must land": the bot uses the move for the WHOLE run, never stops once it has landed, and
     reports last_f.
   - Tests:
     - D27 12: the round-1 bot_player pattern (stopped at its first landing) is refused, and so is a count without
       last_f; a bot that keeps charging passes;
     - D27 12c: the two real final reports of J19's round-3 promotion give 7 of 8;
     - D27 4, 4b, 4c expectations moved on purpose: their counts carry last_f now, and the figures carry the share.
   - Live: a fresh J19 copy at v0.1.4, J19's sentence 1 sent once.
     - core r14 set the rush's reach to 1.9 m. The pushbox rule the builder now reads did that; round 1's builder set
       1.25 m and the night's 1.15 m.
     - core r14 wrote a tests/bot_player.gd that presses the rush whenever lined up, for the whole run, and reports
       last_f.
     - v0.1.5 was promoted 33.6 min after the sentence (3.39M in).
     - The honest share it measured: bot_player rush 1 of 2 (last use at frame 4653 of 6000), bot_crew 6 started.
       Clamped, that gives 7 of 8 (88 %). The card note at event 659 was written before the clamp and reads "9 of 8".
     - My own measure, J19's hand (bot_juice_d27.gd) on the promoted v0.1.5, seeds 1-3, 3600 frames, 0 script errors:
       - 14 rush starts gave 4 / 3 / 2 rush knockdowns (9) and 4 rushes braced;
       - the slam floored 5 / 5 / 6;
       - bots rushed 1-2 a minute and slammed 3-4 a minute;
       - against that: round 1's v0.1.5 had 0 knockdowns from 11 rushes, and the night's had 0 of 15.
     - The bot_player sample is small (2 rushes in 6000 frames). The share is the owner's question, as ruled.
   - Two Foreman defects the live run showed, both fixed in this round:
     - core's note "Fighter: new `cd` dictionary and `ready(m)` method. The 8-frame buffer takes the new moves ..." made
       the gate judge moves cd and ready. Now explicit NEW MOVE lines win, and the loose form applies only to a line
       that starts with "New moves" (D27 12b, on the real note).
     - I stopped my own run at 12:05, after core's merge (crew r4's claude.exe was already gone). I cut its 4 events
       619-621 and kept them in .tl/d27/r3_j19-cut-events.jsonl, then fixed the parser and resumed.

13. Create screen stills in a window: MET, and the window showed a layout bug, now fixed.
   - .tl/d27/create_still.gd mounts Create (create.tscn), opens the real job's done screen, and saves the window at
     1280x720 under the window lock. Stills at 960 px, looked at:
     - stills/i9_create_not_applied.jpg: the S35 biplane copy. "Your game is ready / Biplane duel · version 6", then in
       orange "Not applied: a change to tests/support/pilot.gd was undone. The Foreman judges the game by it, so a change
       may not rewrite it."
     - stills/i6_create_balance_lines.jpg: T2's robot job, with four lines (a measure kept, and three balance lines).
       The first window showed the lines running UNDER the Play and Add to menu buttons, so you could not read them.
   - Fix (create_build.gd _done): a longer note takes smaller letters (17 px, or 15 above 6 lines) and pushes Play,
     Add to menu and the change box down. One line keeps the old places, so the other screens are unchanged. The
     re-filmed still reads cleanly.
   - create.iterate.change now also checks that a 2-line note ends above Play (count unchanged; CRLF kept). It fails
     on the old layout (note at 380 plus 2 lines of 20 px, against Play at 414).

14. The one-hop rule, refined: MET.
   - halfmade.ts: a round that was itself handed the rest of a change may still send a line to a package that has not
     merged in this change (it has not made its part yet). It never sends back to one that has.
   - D27 2d extended: with the cartridge's merge it sends nothing; without it, the line goes to cartridge.

(a) = item 16, JB-back's duplicate crew rounds: same cause family, folded in: MET.
   - Cause (d25-shield .tl/jobs/shield-wall-3-v-20261125-1-jb, events 869-960):
     - crew was queued for the rivals' part, waiting for core (its dependency);
     - core's merge handed crew its NOT DONE lines (888);
     - crew r8 built the rivals' part (merge 915), and only then did the hand-off re-open crew for r9, which found "All
       three were already in place".
   - Fix (halfmade.ts foldable, through changeReady): a Foreman request (a hand-off, the rivals' part) for a package
     that is queued and has not built its round yet is applied at once. The package's builder reads every change of
     the package in one prompt (the prompt lists p.changes).
   - Test D27 14b, through the Foreman on the paddle fixture:
     - the rival paddle gets both the rivals' part and core's hand-off and builds ONE round;
     - with foldable switched off in the built code, the same test fails (2 builder runs).
   - Live:
     - the J4 round-3 copy ran on the process from before the fold. It showed the duplicate: crews_stakes r12 built the
       double team, and the hand-off then re-opened it for r13.
     - The resumed J19 run folded at its start: crew built both in one round, r5.

15. Skin words in a person's grammar: MET, where builders get the words.
   - builder.md has a new rule, "Words read as a person says them": the player is YOU, with "are" and "your"; everyone
     else goes by the name the game shows; never an internal id inside a sentence (no "YOU IS"); one template per case.
   - Every card's mid-screen juice line adds "a word about the player says YOU ARE (never YOU IS)".
   - Test D27 15.
   - Live: a fresh J4 copy at v0.1.4, the A3 sentence sent once.
     - court_exchange r11 wrote "YOU ARE ON FIRE!" if a.id == &"you" else "%s IS ON FIRE!" % the name (fire.gd:28).
     - v0.1.5 PROMOTED at event 1252, 65.6 min after the sentence, 3.06M in. The filmed pack equals the promoted one
       (pack.json and my test aside).
     - Film: clips/j4_r3_you_are_on_fire.mp4 (960 px, crf 30, seed 1, frames 1860-2160). Still:
       stills/j4_r3_you_are_on_fire.jpg (looked at). "YOU ARE ON FIRE!" in big outlined orange letters mid-court, an
       ON FIRE tag over the player, and the clock clear.
     - The night's v0.1.5 said "YOU IS ON FIRE!".
     - Still there, not asked: the old "DUNK!" in the score line. The film run printed the kernel worker's exit-time
       "lock on null" script error at worker.gd:387, as in round 1. It is not the pack's; the headless run had 0
       errors.

(b) J2nd's kart copy, core r31 "REFUSED on the pack's tofu bot": a degenerate tofu run, NOT a T1 hole. Round-4 candidate.
   - What happened (d25-kart .tl/jobs/j2nd/bumper-kart-football-3-20261125-1, events 1503-1514):
     - core r31's own acceptance passed, the tofu bot included;
     - then the merge gate's PACK TEST of tests/bot_tofu.gd failed on the bot's OWN ok: "2 matches; {...}", because it
       wants 3 matches in its 36,000 frames (it ended at frame 35,401, completed). Shells and golden goals make matches
       longer;
     - skill_spread 0 is a figure in that summary, not the reason;
     - the tofu bounds gate (T1's balance-as-notes) never ran on it.
   - Why T2's longerMatch did not catch it: longerMatch reruns only a run that did not complete (bot.completed false).
     This one completed, by its own done at its budget, with ok false.
   - Round-4 candidate: in a person's play change, a run of the plan's tofu bot that completed with its own ok false,
     and no script or engine error, runs once more with 3x frames (at most 108,000), as longerMatch does. If it passes,
     the person gets "matches now run longer".
   - Then core r32 edited the tofu bot to accept 2 matches, the freeze undid that ("measure kept", event 1526), and the
     job paused on a question.

GATES ON d25-hard-a (round 3, final source)
- foreman npm test: 481 tests, 474 pass, 0 fail, 7 skipped (main 476/469/0/7; +5: D27 12, 12b, 12c, 14b, 15).
- node devx/bin/tl.mjs check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck).
- selftest create.: 29 passed, 0 failed (after the layout fix and its check).
- Full tier: NOT RUN. The kernel, kits, rigs, style and seeds are untouched.

CHANGED FILES (round 3)
- foreman/src/landcheck.ts: last_f, the share, landings held to uses, the newMovesOf fix.
- foreman/src/halfmade.ts: hop to a package that has not merged; foldable.
- foreman/src/foreman.ts: changeReady folds (+1 line, 2005).
- foreman/prompts/builder.md: the whole-run count, and "Words read as a person says them".
- foreman/src/test/d27_editor.test.ts: +5 tests; expectations moved in D27 2d, 4, 4b, 4c, as named above.
- foreman/fixtures/d27/j19-d27r3-core-r14-note.json.
- engine/cards/*.json: "YOU ARE (never YOU IS)".
- engine/ui/create: create_build.gd (the note pushes the buttons down) and create_iterate_checks.gd (the note-clear
  check).
- Lane folder: clips/j4_r3_you_are_on_fire.mp4; stills/i9_create_not_applied.jpg, i6_create_balance_lines.jpg,
  j4_r3_you_are_on_fire.jpg.

BEHAVIOUR CHANGES (named)
- A new attack's count must come from a bot that keeps using it into the last third of its run (last_f), or the round
  goes back.
- A Foreman request for a queued package that has not built yet joins that round, instead of re-opening it afterwards.
- A handed-on round may still hand a line to a package that has not merged in this change.
- Create's done screen moves its buttons down for a note of more than one line.

QUESTIONS FOR THE DIRECTOR
1. Item 12 measured 7 of 8 (88 %) through the Foreman's runs, but only 2 player rushes in 6000 frames. Should the count
   need a minimum number of uses (for example 5) before it is believed? That is part of the owner's share question.

ROUND 4 (queued, from the Director's messages)
- (b): rerun the plan's tofu bot with 3x frames when its own ok fails in a person's play change.
- 17: a hand-off can reach the wrong owner (Arsenal's faceoff lock went to the cartridge; the drawing package's own
  main.gd could do it).
- 18: a NOT DONE with no owner goes back to its builder, or to the person as "not made".
- 19: the rivals' copy dropped a sentence (event 869: "... before he lands. : a rival ...").
- 20: "merge crew 7 files" when nothing changed: the merge must count real changes.
- 21: a builder that edits its own acceptance test to pass is listed on the card ("a test was changed to pass: <why>"),
  with no freeze.
- 16: done in round 3 (fold).
