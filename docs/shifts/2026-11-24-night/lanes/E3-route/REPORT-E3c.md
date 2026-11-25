
==================================================================================================================
E3c (25 Nov, on hokej 6c49444): the design room takes a plain sentence at its word; the critic respects the drops
==================================================================================================================
1. The concept choice (prompts/concept.md step 2-3, checked in room.ts conceptStep via concepts.ts faithfulProblems).
   Candidate 1 (index 0) is always the faithful reading: the game the words name, no twist they did not ask for, the
   highest likelihood. A STANDARD job whose sentence names a known game (templateForSentence: duel, rink_sport,
   arcade_sport) and has no twist words (concepts.ts TWIST_WORDS: twist, crazy, but, except, instead, where the/you/
   every..., power-ups, lava, gravity, ...) must answer "chosen": 0; any other answer is sent back with the reason
   ("choose the faithful reading, chosen 0, not candidate 4 (...)"). The other four candidates stay in the concept as
   offered alternatives. CRAZY jobs, sentences that ask for a twist, and own genres choose freely as before.
   Test (fake adapter): the real proof's shape (candidate 4 "each goal drafts you to the team you beat", 0.08) is
   refused on attempt 1, attempt 2's prompt carries the reason, the result is chosen 0 with the twist still offered.
2. The critic (phases.ts criticRubric, the rubric quality.ts judge() already uses; quality.ts untouched): the person's
   decisions (aspect_reacted) ride on the fun_promise item's text, so every look's critic prompt carries them:
   DROPPED "<title>" (<line>) (the person's note), KEPT "<title>" (note), CHOSE "<alternative>" instead of "<title>",
   with: they win over the pitch, clip moments, method and kill lines written before them; a dropped aspect is not
   looked for, never scores an item down and never makes the look NOT ok; a pitch, clip or kill line about it is void.
   No new rubric id (a scripted critic answers the same scores). Test: the text, the rubric ids, and the prompt the
   critic is sent.
3. Not mine, fixed to make the gate honest: hokej's K8 round 3a (cca4737) changed the shipped
   hockey.thirdlife.cartridge.json after E2's C++ verdicts were recorded, so "cartridge: the same verdict as the core's
   C++" failed on 6c49444. Re-recorded with the test's own command (cartridge_corpus.js --write, then
   rink_validate.gd on the built core): only the two sha1 lines of foreman/src/test/fixtures/cartridge-cpp-verdicts.json
   changed; every verdict is the same; the test passes.
Files: foreman/prompts/concept.md, foreman/src/{concepts,room,phases}.ts, foreman/src/test/e3c_room.test.ts (new, 2
tests), test fixtures (helpers' rink concept, core_route's concepts and n4's duel concept now chosen 0).
Gates: npm test 350 tests, 343 pass, 0 fail, 7 skipped (was 348); tl check --tier fast PASS 5/5.
Open: the critic_compare call (quality.ts compareLooks) builds its own prompt; it was left alone (quality.ts is E5's this
round). TWIST_WORDS is a word list: a sentence that asks for a twist in other words still gets the faithful reading.
