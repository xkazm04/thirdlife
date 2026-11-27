S1-bots REPORT (juice day, 27 Nov 2026): should a new move tell the bots to use it and answer it by default?

The full spike: SPIKE.md in this folder (the question, both arms, the test, results A vs B, risks, how to play, and
the lane's pick kept apart at the end). Sentences and the bar: SENTENCES.md. Timeline: STANDUP.md.

OUTCOME AGAINST THE BRIEF
- Both arms on all three games, with clips: MET.
  - karts and shield wall: promoted versions on both arms;
  - half-court: arm A's change was refused twice by the Foreman's newcomer hand check (not promoted), and its built
    pack is kept and measured; arm B promoted v0.1.9 after 3 sentences.
  - 7 clips of 20-23 s and 12 stills, all looked at.
- "arm-ready S1-bots A" sent: MET. The Director committed it as 381de1cb on d27-sp-bots.
- The off switch tried once ("Only I can do it.", karts): MET. The bots fired the glove 0 times over seeds 1-3; the
  card said so.
- Headless, per measured version: 3600 frames x seeds 1-3, seed 1 twice with the same hash, 0 script errors: MET for
  every version counted (karts 5, shield 6, court 6).
- Cost per arm (wall time, tokens, lines, risk): MET, in SPIKE.md section 4 and 5.

THE RESULT IN ONE TABLE (sentences to reach "bots use it"; final bots' uses / answers per live minute)
- karts:  A 1 sentence (124.9 min, 4.43M tokens in), 18.7 fires (5 of 5 bots) / 11.1 answers
          B 3 sentences (226.8 min, 7.13M in), 8.8 hits (4 of 5) / answers publish no event (my glove landed 1 of 27)
- shield: A 3 sentences (153.8 min, 8.35M in), 2.0 throws (4 of 5) / 0.7 by events (4.0 by the pack's own counter)
          B 3 sentences (122.2 min, 3.37M in), 5.7 throws (4 of 5) / 1.3
- court:  A 1 sentence gave 4.3 shoves (4 of 5) / 12.3 answers, but the hand check refused it twice (328 min, 4.74M in)
          B 3 sentences (389.8 min, 5.74M in), 13.0 shoves (5 of 5) / 12.3 dodges; newcomer hand 6 of 20 kept as a note
- Off switch (A, karts): 0 bot uses; 112.9 min, 4.28M in.

GATES (arm A's tree, d25-court, on the code as committed)
- foreman npm test: 463 tests, 456 pass, 0 fail, 7 skipped (main: 460 / 453 / 0 / 7; +3 are s1_bots_default).
- node devx/bin/tl.mjs check --tier fast: 5/5 PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230,
  foreman.typecheck).
  - The first run failed arch: foreman.ts was 2007 lines against its 2005 ratchet. Two lines were merged, then it
    passed.
- Full tier: not run. Only foreman/ changed; no kernel, kit, rig, style or seed file.

CHANGED FILES (arm A, commit 381de1cb; +262 / -11)
- foreman/src/botsdefault.ts (new). The owner question's move/bots fields; the "bots by default" brief section; wire
  requests to every other bot package; the card line.
- foreman/src/grow.ts: the owner prompt gets the move/bots section, and the schema gets optional keys.
- foreman/src/foreman.ts: 4 lines (ask once, apply, the brief section).
- foreman/src/fastchange.ts: the card line.
- foreman/src/test/s1_bots_default.test.ts (new, 3 cases).
- Arm B: no code.
- Lane docs, this folder: SPIKE.md, SENTENCES.md, STANDUP.md, REPORT.txt, clips/ (7 mp4), stills/ (12 jpg).
- Raw work under each tree's .tl/s1/ (job copies, counting hands, reports).

BEHAVIOUR CHANGES
- Arm A: a change that adds a move, with no word about the bots, now also changes every bot package. Its balance moves
  without the person asking. Karts: lead changes 0.33 -> 0.17, perfect hand 18 -> 16 of 20. Court: newcomer 12 -> 7 of
  20, then refused.
- No test was loosened. The builders' own test edits are in their notes; for example, crews_stakes' bot_crews now
  requires at least one bot shove and one answer.

FINDINGS FOR THE DIRECTOR (and lane T)
1. lane T's changeKind (main, foreman/src/boundlift.ts FAIR_WORDS) reads "stand off balance" as a FAIRNESS ask. The
   card's hand bound then guards and refuses the change ("change not finished"). That refused arm A's half-court
   twice. B's later "the rivals use the shove too" read as play, so the same kind of drop (16 -> 9 of 20) became a
   "built as you asked" note.
2. Arm A's routing fires only when a change ADDS a move. A follow-up sentence about an existing move ("the others still
   almost never throw the shield") went to core only on both arms. Lane T's routing fix is needed either way.
3. Builders often add a move's bot answers without an event (B's kart hops and swerves, A's shield sidesteps). A
   counting hand then sees nothing. Lane T's "a new attack must land in the bot run" rule could also ask for an answer
   event.
4. Machine noise: CPU 96-100 % all day. Runner timeouts at 600 s and builder timeouts cost rounds:
   - A karts: 2 rounds + 1 builder timeout;
   - A off switch: 1 round;
   - B karts: 1 round;
   - B court: 2 rounds;
   - shield wall: 0 on both arms.
   Wall times include it.
5. Shield wall's low camera behind the captain hides most bot throws on both arms. A person sees their own throws, not
   the bots'.

QUESTIONS FOR THE DIRECTOR
- Contracts: none edited. If A is chosen, contracts/JOB.md would need the new optional owner-answer keys (move, bots,
  bot_packages, use, answer) and the "[foreman] bots by default" note. That is the Director's call.
- Menu rows: SPIKE.md section 6 lists pack paths and titles for every arm-version the owner should play.

NEXT THREE THINGS THIS LANE WOULD DO
1. Treat a bots-by-default note as part of the person's play change in the balance and hand gates (note, not refusal).
   Re-run A's half-court sentence 1 to show it promotes.
2. Give the default "use" line a rate a person sees ("about once every 10-20 s a bot, when it pays"). Re-run shield
   wall sentence 1 on A.
3. Make the default ask the builder for an answer event (dodge/block/swat), so the counting hand and the card can see
   answers. Then re-measure karts B and shield A.

ROUND 2 (15:00-16:35): arm A after fixes. A got two fixes B did not need, and now also carries lane T's fixes.
- A2, commit 091f956f, in botsdefault.ts and its test. The default "use" line promises a rate a person sees (each bot
  about once every 10-20 s of play). It asks for an event per bot use and per bot answer, and for a bot test bar of
  2 uses and 1 answer a live minute.
  - Gates on the A tree before the merge: fast 5/5 PASS; foreman npm 463 tests, 456 pass, 0 fail, 7 skipped.
  - On the merged tree (Director): fast 5/5; npm 484 tests, 477 pass, 0 fail, 7 skipped.
- Main merged into d27-sp-bots (474d9e91): lane T items 1-16. Item 10 makes "off balance" read as a play change; the
  rebuilt foreman returns "play" on the court sentence.
- Re-run: arm A's FIRST sentence only, on fresh copies (d25-court/.tl/s1/jobs-a2/), measured the same way. The counting
  hands now also read the pack's notes list, where the new events are published.
  - shield wall: v0.1.8 in 27.4 min, 4.35M in / 42k out (core r17 + crew r6, 0 noise rounds). 4 of 5 bots throw
    4.0 a minute and answer 4.7 a minute (3.7 from throw_answer events). The bar after ONE sentence; the first run took
    3, B took 3.
  - half-court: v0.1.7 PROMOTED in 72.9 min, 3.97M in / 35k out (court_exchange r13 + r14, crews_stakes r13). All 5
    bots shove 10.3 a minute and answer 17.0 a minute. The newcomer hand stayed at 12 of 20 (as v0.1.6), and is now a
    "built as you asked" note, not a refusal. Perfect hand 20 of 20. The first run was refused twice; B took 3
    sentences.
  - Every run: same hash twice on seed 1, 0 script errors.
  - clips/a2_shield_v018_throw.mp4, clips/a2_court_shove.mp4; stills a2_shield_sheet.jpg, a2_shield_flying.jpg,
    a2_court_sheet.jpg, a2_court_wham.jpg (all looked at).
- New findings:
  - the card lists A's default bot rules as an "unasked rule (you did not ask for it)", beside the "bots by default"
    line;
  - the shield crew builder kept its rate under "every 10-20 s" (core's ai.json gaps of 10-18 s).
- Menu rows for both A2 versions are in SPIKE.md section 6. The A after fixes section is in SPIKE.md section 4. The
  pick has a dated round-2 addendum; the first-round text is kept.
