D3 editor: REPORT, day shift of 22 Nov 2026 (12:41 to about 14:15 CEST)
Worktree d22-editor. Route: Opus solo. Nothing committed by me; the Director landed rounds 1-3. Round 4 is this
report's round and is landable.

Nobody has played any of this by hand. The hockey job was judged by the critic and by me from its strips, not in a
window by a person.

=====================================================================================================================
OUTCOME AGAINST THE BRIEF
=====================================================================================================================
1. The critic checks a bot's claims against the film. MET.
   - foreman/src/filmcheck.ts measures motion from the strips the look already takes:
     - a small PNG reader;
     - each tile reduced to 8 px block means;
     - a block counts as changed above 12 levels, and a tile step counts as moved at 6 or more changed blocks.
     It is deterministic and takes about 55 ms a strip, with no model.
   - Two findings:
     - idle: a strip still for 50+ frames against an idle_max_f claim under that;
     - contact: a 12x2 contact strip around a reported moment in which nothing moves at all.
   - The check is one-sided: stillness proves, motion does not. An unreadable strip is "unmeasured", never still.
   - A contradicted claim fails:
     - its tofu row (row.contradicted);
     - the tofu check (new row moments_on_film for contacts);
     - the house compare (SHORT).
   - The critic is told "MEASURED FROM THE FILM ... CLAIM CONTRADICTED: <claim>; <what the frames show>".
   - Every look writes reports/film-<m>-s<seq>.json. `foreman filmcheck <job>` runs it read-only over a job's history.
   - Unit tests: a contradicted fixture fails the tofu and house checks; honest fixtures pass.
     Test file: foreman/src/test/filmcheck.test.ts.
   - On real reports (read-only):
     - fight-colosseum-20261122-3: 4 contradictions in 2 looks. idle_max_f 42 (look s56) and 37 (look s91) against
       the side and duel strips f4772 and f9550, which change in 0 of 11 tile steps (at least 55 frames). These are the
       strips the night's critic called "frozen 55+ frames". JPG: proof3-contradicted-idle37-side-f9550.jpg.
     - -1, -2, -4, -5, -6: 0 contradictions over 36, 36, 37, 61 and 13 strips; -5's 5 contact strips all moved.
     - House hockey ladder (pro_regular, seed 1, run in .tl/filmcheck), idle_max_f 70: the one_timer 761 and poked 523
       contact strips and a 12x5 strip at 1970 were all moving, so no contradiction. The chase camera always moves, so
       this is weak evidence there.
2. One hockey job through the editor to its tofu look. MET; the job is HELD, which is a result.
   Details below.
3. The revise pair (N4's next-three item 2). MET.
   - foreman/src/revisepair.ts: a send-back copies the build's contact strip and the house strip at the same contact
     kind into ref/look/<m>-r<round>/.
   - The round's feedback starts with "THE PAIR ..." and the build's contact numbers against the house game's
     (duel: data/contacts.json; hockey: data/tuning.json hits and fun).
   - On -5 and -6 the contact numbers match the duel's on every row, yet house_game stayed at 0.45-0.55. The gap is in
     how the numbers are played, not in the numbers.
4. Director's extra: the stale house cache. MET.
   - The house baseline carries a key: the house pack files, the bot and its strip moment kinds, and HOUSE_MEASURE.
     A cached baseline with another key, or none, is measured and filmed again.
   - The house strip first films a kind the build's own bots reported, and keeps its kind.
   - Shown on a copy of proof -5: the stale KO-fallback strip f4523 (no kind) became the Wall's parry at f2269.
     JPGs: housecache-proof5-stale-KOfallback-side-f4523.jpg and housecache-proof5-fresh-parried-side-f2259.jpg.
5. Round 4 (from the hockey job's findings). Built, landable.
   - A band row (possession_median_f 240-600) is judged by its distance to the house figure (margin 25 %). A house
     figure outside the template's bound is said.
   - A strip still for 50+ frames with no claim of its own bot is named to the critic with its bot.

=====================================================================================================================
THE HOCKEY JOB
=====================================================================================================================
Pattern: .tl/hockey/proof.sh and planrun.sh, copied from main's .tl/proof and pointed at this tree. Run detached;
Opus builders; no --run-through (stops after its first phase); its site/ is this tree's. Sentence: "ice hockey on a
frozen pond, three against three".

ice-hockey-frozen-pond-20261122-1: FAILED in design (12:45-12:54, 9 min)
  "design verb "poke" names move "cross_check", which is not in the arcade_sport move table (poke)", three times.
  - The move line read "poke 5/7/12 (`cross_check`)". The concept wrote "Poke 5/7/12 as move cross_check", and the
    design step followed it on every retry.
  - Fixed in round 1: the line now says move "poke" 5/7/12 (its clip `cross_check`, not a move id). The error names the
    clip and the move id to write.
  - Tokens: in 236,381, out 59,316, cache-read 56,695, weighted 244,672.

ice-hockey-frozen-pond-20261122-2: HELD on quality at blockout (12:59 to 14:03; 64 min wall, 56 min run)
  - Dist: it ran on the 13:07 dist, which has round 1 (the film check) but not rounds 2-4 (pair, cache key, bands).
    It was not restarted.
  - Concept: "arcade 3v3 pond hockey where every big check cracks the ice; holes swallow skaters" (candidate 2 of 5,
    likelihood 0.15). Design review ok: hook 0.85, gif 0.85.
  - Verbs: poke (move "poke" 5/7/12), body_check, shoot, pass, brace.
  - Plan: card.team_possession; 6 packages in 4 phases. The tofu phase is core alone, milestone blockout. The TOFU CHECK
    line names all 11 metrics.
  - Core: round 1 failed invariants; round 2 passed and merged.
  - Look 0 (critic-blockout-s68):
    - Critic NOT ok: silhouette 0.6, readability 0.4, style 0.45, shows_play 0.65, fun_promise 0.35, feel 0.25,
      slop 0, house_game 0.35.
    - Tofu stage PASSED (tofu 1): feedback_f 0, skill_spread 0.305, skill_variants 3, idle_max_f 15, tell_min_f 16,
      tells 127, pressure_waves 6, lead_change_share 1, close_rounds 3, verbs_used 5, possession_median_f 377,
      moments_on_film 0.
    - Film check: 8 strips measured, 0 contradicted.
    - The critic, in its own words:
      - "Red and blue skaters bunch into scrums along the boards ... The puck is almost never visible."
      - "the contact strips (f387, f2982) show no wind-up and no tiles held for a hit-stop. Nobody reacts away from a
        blow."
      - fighters_overlap: "four or five blue and red bodies merge into one blob at the left goal".
      - camera_hides_exchange: "the reported contact happens at the right edge of the frame".
      - "no marker on the controlled player (the house game uses a green ring)".
      - "green summer meadow" where the brief asks for a winter pond.
      - "possession_median_f is 377 vs 164 ... matches the static scrums filmed".
  - Revise round 1:
    - New version: feel 0.15, house_game 0.3; "a faceted 12-segment pale disc covers the ice"; hit_without_reaction.
    - The compare KEPT PREVIOUS: "All 12 tiles of image 10 show the same frozen frame".
  - Revise round 2:
    - New version: tofu NOT ok (skill_spread 0.217, skill_variants 2), feel 0.15, house_game 0.25.
    - KEPT PREVIOUS (it passes the tofu stage).
  - Held: "milestone blockout is still NOT ok after revise round 2". The kept version is the round-0 core. The owner
    decides (foreman quality <job> accept|retry); I did neither.
  - Tokens (tl ledger): in 10,777,008, out 160,256, cache-read 9,865,838, weighted 2,058,010. 6 packages planned,
    10 rounds, 5 edit runs, 2 critic looks. Billing is the claude.ai subscription, so the ledger carries no money
    figure.
  - Strips (lane folder):
    - hockey2-PAIR-build-check_stumble-f387-over-house-one_timer-f761.jpg: the build's contact strip over the house
      strip. The build's chase camera sits low behind a red skater who fills the frame, with the scrum far off and a
      meadow behind. The house's camera looks down on the play, its controlled skater has a green ring, and the bodies
      are apart.
    - hockey2-PAIR-r2new-build-f2011-over-house-one_timer-f761.jpg: the round-2 version (rejected) over the house strip.
    - hockey2-r0-blockout-{chase,overview}-bot_tofu-strip-f377.jpg, hockey2-r0-blockout-chase-bot_player-strip-f6248.jpg.
    - hockey2-r2new-overview-bot_tofu-strip-f2001.jpg: the pale fan "disc" over the ice and the snow plane.
    - hockey2-house-strip-chase-one_timer-f751.jpg: the job's house strip, a real one-timer at 761. Before round 1's
      reader fix it would have been the bot's last minute (moments now live at metrics.raw.moments).

What the editor got wrong on hockey, against the owner's three hockey words (puck stickiness, player speed, AI decisions)
  - It cannot show the puck. Every critic line says the puck is unfindable, so "stickiness" cannot be judged from the
    film at all. The house game draws it bigger with a rim (tuning.json look.puck_scale 2.5, puck_rim). That row did
    not reach the builder as a number to copy: the arcade_sport builder numbers are skater, skate, carry and shoot, not
    `look`.
  - It copied the scrum, not the spacing. The bots pile 3-6 bodies into one blob and possession lasts 377 frames against
    the house's 164. The house compare said "not short" on it (the band-row fault, fixed in round 4).
  - The chase camera from the design ("Low Chase Camera: ride right behind your skater") is the wrong camera for the
    exchange. The house game uses a high follow camera and a ring under the controlled skater. The duel template has a
    "keep the house camera" rule; arcade_sport has none.
  - A round-1 critic line pinned a still strip of bot_player (f9537, 55 frames) on the tofu bot's idle_max_f claim. The
    film check measured the same strip as still and correctly did not count it against the tofu bot. Round 4 now names
    such strips with their bot for the critic.
  - The template bound itself: the house hockey's possession_median_f is 164, under arcade_sport's own 240-600 band
    (HOCKEY-ARCADE 5.5). Either the band or the house game is wrong; that is the Director's call.

=====================================================================================================================
GATES
=====================================================================================================================
- npm test (foreman), with plain copies of site/marble-run-three-marbles-20261110-1, -2 and site/_engine_snapshot3 in
  this tree (without them, 2 more skip):
  - round 1: 299 tests, 294 pass, 0 fail, 5 skip
  - round 2: 303 tests, 298 pass, 0 fail, 5 skip
  - round 3: 305 tests, 300 pass, 0 fail, 5 skip
  - round 4: 307 tests, 302 pass, 0 fail, 5 skip
  Main before the shift: 290 tests, 284 pass, 0 fail, 6 skip. The 5 skips left are "TL_GODOT is not set".
- tl check --tier fast, every round: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck).
- npm run -s build: clean.
- The full tier is not mine: no kernel, kit, rig, style or seed change.

=====================================================================================================================
CHANGED FILES (all rounds)
=====================================================================================================================
foreman/src:
- filmcheck.ts (new)
- cli_filmcheck.ts (new)
- revisepair.ts (new)
- cli.ts (+5 lines)
- quality.ts
- tofu.ts
- house.ts
- shots.ts
- templates.ts

foreman/src/test:
- filmcheck.test.ts (new, 9 tests)
- revisepair.test.ts (new, 8 tests)
- n4.test.ts: one expectation, the move-line wording, with why

docs/GAME-QUALITY.md: section 13, five bullets.

Lane folder: STANDUP.md, this REPORT.txt, JPGs.

Behaviour changes, with the tests they moved:
- The move line wording (n4.test.ts:98).
- house_game: arcade_sport now compares idle_max_f, because N3 made it an opponent-idle figure.
- A two-bound row is now short when far from the house figure.
No test was loosened.

=====================================================================================================================
CONTRACT PROPOSALS (Director-only)
=====================================================================================================================
- Rounds 1-3 were placed in JOB.md by the Director (9f7f077/191687d, 9975f9f, 5be9c61).
- Round 4, JOB.md, the house-baseline paragraph: "A row with both bounds is compared by its distance to the house
  figure (the 25 % margin); the line says when the house figure is outside the template's bound."
- Question: arcade_sport's possession_median_f band is 240-600, and the house hockey plays 164 (pro regular, seed 1).
  Which is the bar?

=====================================================================================================================
FOR THE OWNER
=====================================================================================================================
- The hockey job's held core is not promoted. The kept pack is site/ice-hockey-frozen-pond-20261122-2/pack (the
  round-0 core) in the d22-editor tree. I did not open it in a window.
- The strips to look at first:
  1. hockey2-PAIR-build-check_stumble-f387-over-house-one_timer-f761.jpg (build over house);
  2. proof3-contradicted-idle37-side-f9550.jpg (a claim the film contradicts).

=====================================================================================================================
NEXT THREE THINGS
=====================================================================================================================
1. arcade_sport keeps: the house camera (high follow, a ring under the controlled skater) and the puck look
   (puck_scale, rim) as builder numbers read live from data/tuning.json, as the duel template keeps its camera. Today's
   job lost both, and the critic could not judge stickiness.
2. Run hockey job -3 on today's dist (pair, kind-matched house strip, band rows). See whether revise rounds move
   house_game past 0.35 when the builder has the poke pair and the possession SHORT in hand.
3. A spacing figure for arcade sports (bodies inside one blob, which the house hockey measures as overlap_frames and
   crowd4) as a tofu row, so a scrum fails the tofu stage, not only the critic.
