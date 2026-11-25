# E5b: the fixed path, real adapter (25 Nov 2026, hk-proof at hokej 67b1349)

Jobs root `.tl/proof-jobs-b/`. Every step went through `engine/ui/foreman_run.mjs` in `foreman_door.gd`'s order, with
`engine/ui/flags/real.json` (claude-cli, sonnet), answering as Create's new cards do:
- quality: `quality accept --note "the person plays it as it is"` + resume ("It's fine, go on");
- a builder's question: `answer <job> <pkg> "<words>"` + resume.

No code changed this round. The stills are in `e5b/`; I looked at all of them. Times are UTC from the job logs.
This is an interim write-up: jobs 1 and 2. Job 3 (patches and bumpers, after E1b) follows.

## Job 1: "3 against 3 hockey on a small pond rink" (against-3-hockey-20261125-1): DONE, v0.1.2, 140 min

**Concept: faithful, no drops needed.**
- The concept chose candidate 1 of 5, likelihood 0.85: "arcade pond hockey where six skaters on tiny pond ice make
  every pass count". The pitch was a cross-crease playmaker.
- The aspects (passes, saucer pass, rival roles, quick knockdowns, tiny pond, chase view) are all hockey.
- Design took 6.1 min (concept, designer x2 + a 3k-token repair, review x2). I approved it as it was.

**The cartridge** (50 keys against the base):
- rink 90 x 45 -> 46 x 24; 3 v 3, blue #2563EB against orange #F97316 (the team ids stay blue/orange);
- first to 5;
- goalie reach 0.9, reception 2.5, one-timer 24, saucer pass, knockdown 60, carry 0.92 / free 1.15;
- a "sharp-sticks" hook: a side two goals down aims better for 12 s;
- l1_day.

Skin: BLACK ICE THREE, Otters against Pike.

**Plan**: base, cartridge (phase 1), skin (phase 2), trials (phase 3: comparison cartridges plus policy bots).

**The goal flood is gone at the measured level.** At every look and pause, pro scored 7.6 goals a match against hokej's
4.2, which is inside the 0..21.8 band, so the measured check never fired. But:
- the match lasts 1.2 min (hokej 3.1);
- in my films bot_first_match ended 5:0 in 2242 frames (37 s) and the hand 5:1 in 65 s: a goal every 8 to 12 s.
- The check counts goals per match, not per minute, so a first-to-5 played in under a minute passes.
- "very short matches" is only a warning (0.6 to 0.9 min after the changes).

**The figures at each phase pause** (Create shows them now), the same at all three pauses (only the skin and trials
changed in between):
- rookie wins 10/10, pro 9/10, all_star 7/10;
- pro: 7.6 goals, 1.2 min, carry 0.6 s, shots 21.4, passes 0.3, speed 8.2 m/s, knockdowns 5.7;
- idle wins 3/16, skating alone wins 1/16.
- At the trials pause, each trial cartridge was measured too.

**Where the 140 min went** (this is the real problem of this job):

| span | min | what happened |
|---|---|---|
| build to the greybox look | 16 | base 4 (its first lint alone 3.1 min in a fresh workspace), cartridge builder 6.2 |
| greybox look + 2 revise rounds | 26 | the critic said NOT ok three times, on the core's own behaviour and the camera (bodies overlap, a check reads as merged bodies, the camera behind the carrier, roof beams in the top view). It named the base; E5's rule sent both rounds to the cartridge, which cannot touch any of it. Then a quality hold. |
| phase 2, skin | 5 | |
| phase 3, trials + tuned look + 2 revise rounds | 63 | each look takes 7-8 min of window captures (16 pictures, 40-50 s each at the late frames). The critic said NOT ok again; the rounds went to skin and trials. Quality hold again. |
| final + promotion | 2 | |

So about 89 min of 140 were critic loops that could not change what the critic saw.

**Change 1: "make it faster", 777 s (13.0 min). NOT the fast path.**
- Owner question 3.8 s -> cartridge. The diff call took 5.6 s:
  - values.skater_speed 13.5, turn 6, shot 22, accel 12 -> 16;
  - measured before/after: pro speed 8.2 -> 10.4 m/s, goals 7.6 -> 6.5, minutes 1.2 -> 0.9.
- The diff with its two checks took 41 s.
- Why it was not data-only: the round's merge listed `data/black_ice.cartridge.json`, `data/match.json` and
  `tests/bot_pond_drill.gd` (event 346). match.json and the drill test are byte-identical to v0.1.0 (cmp), but the
  merge names every file of the package's scope. A test in the list sends it down the whole path.
- So the dependants were re-verified: the trials package's bot then FAILED on the faster cartridge (event 355). That
  reopened trials for a 2.3 min builder round, then the full final verification and 4 captures.

**Change 2: "the orange team is too strong", 395 s (6.6 min).**
- No question was asked back, rightly: this game has an orange team (Pike, `teams[1].id` "orange").
- Diff `values.ai_red_skill -> 0.6` ("The orange Pike will play less sharply against your blue Otters").
- Measured: pro wins 10 -> 10 (already 10/10), goals 6.5 -> 6.0. So the player's side already won every pro match
  and nothing said so; skating alone now wins 8/16 with the planning hand "NOT VALID" (not judged).
- Again the full path (the same 3-file merge), but no builder round.
- In my film, the first 20 s of v0.1.2 are frame for frame those of v0.1.1. A person sees no change.

**Look** (`b_j1_phase1_strip.jpg`, `b_j1_v011_strip.jpg`, `b_j1_v012_strip.jpg`, `b_compare_hokej_j1v010.jpg`:
hokej on the left):
- It is hokej's match on a 46 m rink.
- Blue against orange, nets on the ice at the goal lines (E5's base fix shows), first to 5.
- The skin's words are in: "Otters beat the keeper!", "Pike FLATTENED! Grab it and pass!", "In it goes! Otters!".
- Seen problems:
  - the follow camera dives into the bodies in a pile at the boards (v0.1.1 tile 3: the inside of two figures);
  - at the boards it is pressed against the glass;
  - two goals in the first 20 s.

**As a player**:
- It plays like hokej; the pond and the names are right.
- "Faster" shows in the speed (10.4 m/s).
- "Orange too strong" changed nothing I could see, and I was already winning every match.
- Too short and too many goals: first to 5 over in about a minute.

Cost: 10.5M tokens in (8.48M cache reads), 294k out, weighted 3.17M. There were 6 critic calls and 9 builder runs
(cartridge 3, skin 3, trials 4, minus the change round).

## Job 2: "pirate hockey, the Sharks against the Gulls in teal and gold, first goal wins" (pirate-hockey-sharks-against-20261125-1): DONE, but the change destroyed the game; 53 min

**Concept: faithful.** Candidate 1 of 5, likelihood 0.85: "one goal settles the pirate grudge between teal Sharks and
gold Gulls". No pickups or cannons. Design took 8 min (designer x4, review x2). Approved as it was.

**The cartridge** (45 keys):
- 70 x 35, goal 3.5 m;
- teams `sharks` #12A39A against `gulls` #E3A71C;
- score_to_win 1;
- momentum contact, lunge, check wind-up 0, bot wind-ups 12;
- reception 3, pass lead 20;
- l2_night, gold trim.

Skin: "Sharks vs Gulls: Golden Goal", pirate banks ("Plundered!").

**The gross-defect check acted, for real**:
- Cartridge r1 (1.9 min) was refused before any verb: "skating alone (no shot, pass or check) wins 6 of 16 at pro:
  the game is won without its verbs" (event 36), with hokej's figures beside it.
- r2 (1.5 min) raised carry_speed_mult to 0.82, body_check to 0.8 and removed hold_radius. The re-measure passed.

**Phase 1 pause** at 19 min (before any critic):
- rookie 8/10, pro 5/10, all_star 3/10;
- pro: 1 goal a match, **0.2 min** (12 s), shots 1.8;
- skating alone 1/16, idle 1/16;
- warnings: "very short matches" at every level.

In my run, bot_first_match ended 0:1 in 938 frames (15 s); the hand's match took 68 s. I LOOKED
(`b_j2_phase1_strip.jpg`): teal against gold, "FIRST TO 1", hokej's play. PASS.

**Phase 2** (the skin): the greybox look said NOT ok. Its reasons:
- after a knockdown the follow camera stares at empty ice;
- the top view is a thin strip under black roof beams.

What followed:
- Revise round 1 went to the cartridge, which asked: "Which package should get the critic's camera, goal-response,
  crew-shout and top-view fixes, or should `scripts/cam.gd` and the related HUD and view files be added to this
  package's scope?"
- Create shows this as a question card. I answered as a person: "No. Leave the camera and the HUD as they are; change
  only the game's data."
- Round 2's cartridge edit was refused by the gross check again (skating alone), so the files before it stayed.
- Then a quality hold at 43 min: "It's fine, go on".
- I looked at phase 2 (`b_j2_phase2_strip.jpg`): the pirate words are on screen ("Plundered!", "Skate, pass, shoot!
  WASD, right click, left click"). PASS.
- v0.1.0 promoted at 45 min.

**Change: "make the goals bigger", 378 s (6.3 min). WRONG OWNER, AND IT TURNED THE GAME BACK INTO HOKEJ.**
- The owner question (4.4 s) named **base**: "Goal size is part of the play space, which the root rink_game base builds
  (including gen/tj_rink.gd)..." (event 198). goal_width_m is a cartridge key.
- The cartridge diff route never ran (the owner was not the cartridge's).
- The base's change round re-copied the base:
  - its note says "38 file(s) copied, ... kept as pack/ holds them: data/match.json, data/skin.json" (event 201);
  - but the merge (event 208) lists 40 files **including data/match.json and data/skin.json**.
- v0.1.1's data/match.json now plays `hockey.regular.cartridge.json` at pro, and its skin.json is HOKEJ's ("HOCKEY
  WITH THE WHISTLE TAKEN OUT", Blue/Orange).
- The pirate cartridge is still in data/ but nothing points at it.
- `b_j2_v010_vs_v011.jpg`: v0.1.0 teal/gold FIRST TO 1 on the left; v0.1.1 blue/orange FIRST TO 3, 90 m rink, on the
  right.
- The goals are not bigger: the cartridge is byte-identical (cmp).
- A person would say: "I asked for bigger goals and got someone else's game." The earlier version is kept beside it
  (promoted/...@0.1.0 is the folder without a suffix).

Cost: 7.42M tokens in (5.58M cache reads), 204k out, weighted 2.60M, 53 min.

## Defects for the Director (not fixed: this round was proof only)

1. **(blocks a change outright) A change can be routed to the base, and the base's change round overwrites the game's
   data with the base's** (job 2: events 198, 201, 208).
   - The owner question should never answer the base on a core game; a cartridge key belongs to the cartridge's owner.
   - The base re-copy must not overwrite files a later package owns. Its note says they are kept, but the merge lists
     them.
2. **The cartridge diff round's merge lists the package's whole scope** (job 1, event 346: match.json and
   tests/bot_pond_drill.gd unchanged). That defeats `fastchange.ts`: every change on job 1 took the full path, 13.0 and
   6.6 min instead of about 3.
   - It also made a dependant's bot fail and cost a builder round.
   - The merge should list only the changed files, or the fast-path test should look at the bytes.
3. **The critic loop on a core game cannot be satisfied by any data package.**
   - Its reasons are the core's behaviour and the base's camera; it names the base, then its rounds go to the
     cartridge, skin or trials.
   - Job 1 spent about 89 of 140 min there, with two quality holds; job 2 about 15 min, one hold, plus a scope question
     the person can only refuse.
   - Each tuned look takes 7-8 min of captures.
   - Suggestion: on a core game, when the critic names the base, go straight to the person (the quality card) instead
     of two revise rounds.
4. **The measured check misses the goal rate.**
   - Goals a match within 0..21.8 passes, but a first-to-5 over in 0.9-1.2 min (job 1), or a first-goal-wins over in
     12 s (job 2), is still "ok" with a warning.
   - Goals a minute, or the match length against hokej's, would catch both.
5. **A change against a side that already wins everything goes through** ("the orange team is too strong" when the
   player's side wins 10/10 at pro). The orange-team question rightly did not fire (orange exists); the "before"
   figures could have answered "your side already wins every match".
6. **Small-rink camera**: the follow camera goes inside bodies in a pile and presses against the glass at the boards
   (job 1 strips). The base's or the core's camera.
7. **The first lint of a fresh job workspace takes about 3 min** (jobs 1 and 2: base r1 lint 3.1 and 2.7 min; later
   lints 1-20 s), probably a class-cache import. That is time every job pays before anything happens.
8. **The `l2_night` look tier does not show**: job 2 asked for a night harbour; the barn looks the same as day.

## Where a person would be stuck in Create (this round)
- Nowhere hard. The quality card (twice in job 1, once in job 2) and the question card (job 2) both had a way out.
- But a person would wait through long silent critic loops (25-60 min) with the strip saying "building".
- After job 2's change, they would get a different game with "version 2" on it, and nothing in Create says what
  changed.
