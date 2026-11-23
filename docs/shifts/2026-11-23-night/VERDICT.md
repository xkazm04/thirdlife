# Night of 22-23 Nov 2026: verdict (research before any more game building)

**The owner, ~18:35, after playing the day's exe** (full text in PLAN.md): "Hockey is unplayable garbage ... Our hockey is
a proof we should not start any new minigame development as there is a lack of understanding how games should be done -
we need research to change mindset of what we are doing ... Both are slop nobody would touch for fun and we should prepare
processes and prompts to go much deeper in game design". He also found that Create could not start a new idea, and that
the World had objects blinking at the ground, aggressive blinking between distance levels, and incomplete far structures.

Four lanes ran 19:12 to 23:07. All landed on main; no minigame or game feature was built. Page: https://claude.ai/artifact/5og2f2Jykp6iMSUg8NqBJQ

## Read first (about 20 minutes)
1. `docs/research/hockey-teardown/TEARDOWN.md`, section 0 (ten lines) and section 3 (the ranked top 10).
2. `docs/research/duel-teardown/TEARDOWN.md`, section 0.
3. `docs/design/METHOD.md`, sections 1-3: the test, what our games missed, the stages before any build.
4. Then walk the World again in the exported exe (path under Gates): the valley, the village road east, the car course.

## N1 teardown (Opus, research only): landed, three rounds
- **Verdict:** landed 065f28e (hockey teardown), 17973df (`RULINGS.md`, scale probe), 11e8936 (duel teardown).
- **Hockey, in one line:** ours is not a smaller thirdjam but a much more crowded game. Our figures are 2.2x life size
  (radius 0.879 m) on 60 x 30 m: the rink is 34 body widths long against thirdjam's 112. That came from a drawing fix on
  16 Nov and was never a design decision. Teammates were made idle on purpose so a bot check would fail an idle hand. The
  camera follows the puck, so the cursor-stick moves when your hand doesn't. The puck barely slows and passes leave at a
  fixed speed. The game stops about 3.8 times a minute. Hit marks you ruled out in thirdjam came back.
- **The central finding:** by thirdjam's own first-five-minutes measures, ours scores *better*. Our instruments cannot
  see what you see. The lesson "his hand is the bar" was written down four times and lost each time a brief was written.
- **Scale probe** (copies of the pack, all-AI): life-size bodies cut knockdowns by a third; thirdjam's rink cuts 4-man
  piles 16 % -> 12 %; both halve knockdowns. Scale is necessary, not sufficient: the AI's pull to the puck is the other half.
- **Your rulings:** all 75 thirdjam rulings with your verbatim words in `RULINGS.md`, each marked any-game or hockey and
  whether ours follows it; section 10 is the ten the method cites.
- **Duel, in one line:** the rules are a faithful copy of For Honor / Souls / Sekiro; what fails is everything a person
  reads them through. Bodies don't tell (words over his head do); the tutorial hits for real (14/100 health after 19 s);
  rounds last ~20 s; threats wind up in 12 frames, below human reaction; the screen is a dashboard; three rivals are one
  fighter in three hats.
- **Evidence:** both teardowns cite file:line on our side and sources (thirdjam's repo and docs; public For Honor / Souls /
  Sekiro / frame-data sources) on the other; thirdjam ran here from a 15 Nov build (`C:/t/t5`, untouched) and was filmed.
- **Note:** the duel teardown was a Director extension: your message named both games; it is research only.

## N2 method (Opus, web research): landed, six rounds
- **Verdict:** landed a9b5447, 42b1097, 85d9953, 6be8539, 5910b8a, f4f71d2; JOB.md worded in 2599ebe, b925a54.
- **What exists now:** `docs/design/METHOD.md` (35 sources): the test is "a person wants to play it again"; only a person's
  hand can pass fun or feel; film and bot figures can only fail it. Eight stages before any build: fantasy, pillars, core
  loop, the 30-second test, the feel spec, the reference teardown, a greybox a person plays, kill criteria. Your ten standing
  rulings are cited. `docs/design/CASES.md` walks hockey (NHL '94 / Hitz / Blades of Steel + thirdjam) and the duel
  (For Honor / Souls / Sekiro + frame data) through the stages with numbers.
- **The editor rewritten to it:** every design must write FANTASY, WORLD (the size in the player's units), TEARDOWN,
  30 SECONDS and KILL IF lines, checked by the Foreman; the first phase is a greybox with a playtest card asking the worst
  three things you felt; the critic can fail but never pass fun; the house hockey and duel are a working base and a floor,
  not the bar; each template carries the reference game's numbers and the teardown's top ten as "do not copy"; the tell
  floor is 20 frames (12 was below human reaction); a copied move may wind up slower than the house game's, up to the bar.
- **Evidence:** npm test 322 (315 pass, 0 fail, 7 skip), re-run by the Director each round; two dry runs on the FAKE
  adapter; no Foreman build job was started.
- **Consequence named:** the house duel now fails the 20-frame tell floor (its chained lights wind up in 12).

## N3 world (Opus-directed Astra): landed, five rounds
- **Verdict:** landed 484f58e, eaa6742, 2c8394c, 4b54397, ea65073, and bf75b0d (round 6, after the verdict's suite found 4 tests red).
- **Six causes found and fixed**, each with before/after from the same spots (lane `final/` and `round-*/`):
  1. far peaks, hills and woods cut at 2 km and sliding in and out (the camera's far plane; now 9300 m with the Home);
  2. venue floors grass near / dark slab far: the blend design (19 Nov) keeps village grass near; round 2 drew the asphalt
     everywhere (a big dark square) and broke the classic-look pins; round 6 keeps the blend and makes the far pictures
     match it: grass near and far, style shaders back to their pinned bytes;
  3. the village's 1385 grass tufts appearing and vanishing all at once (one range for all; now 38 cells of 32 m);
  4. objects sinking and floating at the mid/far switch (the far picture snapped a venue's ground to 6 m: up to 2.07 m);
  5. road rails popping whole per 31 m piece (now fade over 92-116 m, so no rail is drawn thinner than the test allows);
  6. cars turning into static boxes at 38 m (the village plays venues in full to 60 m; +0.65 ms p50 busy).
- **Evidence:** selftests n3.sight / n3.tufts / n3.far_ground (each red on the old code); world 8/8 unchanged every round,
  under crisp and classic; tours headless PASS; Astra 177 k tokens (one read-only survey), fixes built by hand.
- **Left:** moving bodies beyond 70 m are still boxes by design.
- **The verdict caught one:** its uncapped suite found round 2 had moved four pinned tests (two classic-look shader pins,
  the blend test, the rails test). Round 6 fixed it the blend's way; `blend.car_origin`'s expectation moved from "distant
  asphalt" (it pinned the near/far mismatch you reported) to "distant grass", named in its header.

## N4 create (Opus): landed, two rounds
- **Verdict:** landed 88ae2cd (fix) and fc59f3a (export check).
- **Cause:** in an exe the game files sit in the .pck, so the editor looked for its Foreman from nowhere and every GO showed
  "The builders cannot start: Foreman not found". It now looks from the exe's folder.
- **Evidence:** in a fresh export, Create > GO reaches the Designer's pitch (fake adapter); `export.sh check` now presses
  GO itself and passes only at the pitch; ui.selftest 206/206.
- **Warning:** GO in today's exe starts a REAL Foreman job (real adapter). By your rule, don't press Build it until the
  method gate is agreed.

## Gates on main (final list, n23-int)
- **Final list at fa086cb** (n23-int, 23:08-01:08): arch 12/12, assets 4/4, cards 3/3, devx 229/229, foreman.typecheck,
  foreman.test 322 (316 pass, 0 fail, 6 skip), kit 120/120, seeds 39/39, item 91/91, ui 206/206, world 8/8 = alone
  (crisp and classic). Its uncapped kernel suite found 4 tests red from N3's round 2 and 4 (494/4): fixed in round 6.
- **Re-check at bf75b0d** (after round 6, 02:22-03:16): world 8/8 under crisp and under classic; **uncapped kernel
  selftest 498 passed, 0 failed**; tours headless and in a window PASS; **perf 6/6** (tour6 p50 2.65 ms, walk30 2.41 ms,
  load6 519 ms); export built and `export.sh check` PASS, including Create up to the pitch.
- **Not read quietly:** hockey many_budget failed in both packs runs (1.27 ms against 1.0) while other sessions ran 8
  Godot processes; nothing tonight touched a pack, so it is machine load, not a regression (the last quiet read was
  0.979 ms on 22 Nov).
- **The exe:** `.claude/worktrees/n23-int/dist/PLAY-LATEST.cmd` (build bf75b0d).

## Your answers
1. **Hockey (from the teardown's 10 recommendations; none built):** first agree a one-page "world in the player's units"
   for hockey, then re-scale before re-tuning? (recommended), or set hockey aside?
2. **The person gate:** should the editor always stop after its first (greybox) phase for your pass or hold, even with
   run-through? (recommended: yes)
3. **Method lines as contract keys:** keep FANTASY / WORLD / TEARDOWN / 30 SECONDS / KILL IF as labelled lines in the brief,
   or make them keys of the job contract so the village site can show them?
4. **Next step for the method:** walk it on paper with you for one sentence, no build, as its first test by a person?

## Route scoreboard
| Route | Lanes | Result |
|---|---|---|
| Opus solo, research | N1 | held: two teardowns and your rulings in 4 hours, evidence both sides |
| Opus solo, writing + code | N2, N4 | held: six and two landable rounds, tests re-run by the Director |
| Opus-directed Astra | N3 | Astra used once, read-only, to survey causes (177 k); every fix by hand. A read-only Astra survey is a cheap, useful lever |

## Cost
Astra 177 k tokens. Claude: 4 lane agents (about 0.3-0.7 M subagent tokens each). No Foreman jobs.

## Next shift (no building until you answer)
1. You read the teardowns and the method, walk the World, and answer the five asks.
2. The method on paper with you for one idea; then, if you accept it, a hockey "world in the player's units" page.
3. The World's remaining stand-ins (bodies beyond 70 m), and a window selftest that counts distance pops along the road.
