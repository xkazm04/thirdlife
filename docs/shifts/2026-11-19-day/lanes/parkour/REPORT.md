# Lane parkour: report (day of 19 Nov, done at 10:05)

Route: Astra (codex gpt-6.2-astra, reasoning high) designed and built everything in two rounds in one session
(01a1f2bc-fc0c-7ad0-bfd1-9d7f5f86d10a). The Opus operator wrote no pack code and gave no design direction. Between the
rounds it passed back only measured failures against the brief. It then re-ran every gate itself.

| Round | Wall time | Tokens (Codex "tokens used") | What was passed in |
|---|---|---|---|
| 1 | 08:37:13-09:06:34 (29 min 21 s) | 217,780 | The brief, nearly verbatim, plus the operator rules (.tl/prompt-1.txt) |
| 2 (resume by id) | 09:11:21-09:48:24 (37 min 03 s) | 542,901 | Two unmet items: the swing demanded no timing (operator probe); a per-hand take-off lead table in the ladder bots (TLHand honesty). See .tl/prompt-2.txt |

## What the course is now
Timber Run has three stages and 12 checkpoints, inside the same 50 x 28 m plot. The HUD shows the stage, the next move, the
split and its session best, and the run time and its best. The finish board lists all three splits with their bests.
1. High line (unchanged): a 3.4 m run-jump, a 3.8 m gap into a landing slide under the 1.52 m beam (the run-jump-slide
   chain), the C retry, and the 65-degree chute slope slide.
2. Swing yard: two wooden stepping pads, yawed +-22 degrees and banked +-8 degrees, offset to the side so you must steer.
   Then a 1.05 m-wide narrow beam, crossed by a pendulum weight that swings +-56 degrees over a 156-frame period. The
   weight is moved by pack frame count, with no wall clock. Touching the weight counts as a hit and a fall, and sends you
   back to the beam entry.
3. Summit: a run-up concrete wall (a walking jump falls short), a 2.90 m jump to a crest 0.72 m above the lip, two
   0.78 m tower terraces, and the finish stripe between the flags.
No kernel change. No kit part was added. Astra checked these kit parts: ground_patch, kerb, scaffold, timber_frame, flag,
barrier_wall, watch_tower, lumber, pallet. It used the first five, plus the yard's existing parts. watch_tower was
rejected because it has one solid bounding box.

## Acceptance (operator-verified)
| Criterion | Verdict | Evidence |
|---|---|---|
| Stills of every new obstacle, the overview and the village road, with a contact sheet | met | stills/after/ (12 pack views + 5 road-tour shots), stills/before/, stills/contact-sheet.jpg (before/after overview and road, and each obstacle, including the blind swing hit). Astra's own sheets: stills/astra-1/, stills/astra-2/ |
| A windowed clip of 20 s or less | met | clip.mp4: 14.32 s, 1280x720, 60 fps, 859 frames, native speed (no speed-up). One full perfect-hand run (seed 1, orbit, HUD) from the start to the finish board. Strip: clip-strip.jpg. Run state: evidence/operator/clip-movie.json (806 race frames, 0 falls) |
| bot_course (perfect hand) finishes | met | 806 race frames (13.43 s), 0 falls, 0 swing hits, on seeds 1, 2 and 3. Splits 338 / 286 / 182 |
| A ladder per hand over 20 seeds | met | `tl ladder`, 20 seeds per cell: course newcomer 17/20 (85 %, 69..100), mean 2316 frames; course regular 20/20, 971; course sharp 20/20, 845; forced-C-retry newcomer 17/20, 2042; forced-C-retry regular 20/20, 1041. One input policy drives every hand; only the TLHand profile changes. The perfect proof bot keeps its 0.85 m high-line take-off. evidence/operator/ladder.txt |
| The impossibility test still fails, plus one case per obstacle | met | 8 one-value mutations x (bot_geometry, bot_course) = 16/16 exit 1, with only bot.ok red: chain gap 12 m, bar 0.55 m, pad spacing 13 m, beam entry 12 m, swing 0 degrees, swing period 12 frames, wall crest +2.4 m, tower step 1.85 m. evidence/operator/impossibility.txt. Astra also ran a first-pad lateral offset of 11 m, and a run with the contact callback removed |
| Swing demands timing (goal) | met, mildly | Round 1 failed: a blind runner (never waits) finished with 0 falls at all 12 start phases, faster than the timed one (evidence/operator/blind-swing-probe-r1.txt). Round 2, my own probe: the blind runner is hit at 6 of 12 phases (delays 0, 13, 65, 78, 91, 143) on seeds 1 and 2, and is clear at the other 6 (blind-swing-probe-r2.txt). Astra's registered bot_swing_phases: a hit costs 11-24 frames (0.2-0.4 s) against the timed runner, and blind is never faster |
| Gates | met | See below |

## Gates (operator runs)
- lint: PASS (schema, layout, fence, capabilities, size; 0 bypasses, 0 kit parts added).
- Every pack test on seeds 1, 2 and 3: 36/36 pass (12 registered bots). evidence/operator/bots-seeds-1-3.txt
- `tl check --tier full --only packs,world`: PASS packs [2/2], verb runs 42 of 42; PASS world [8/8], world = alone
  (parkour is included). It passed on the first try: hockey's frame-time check did not trip this time.
  evidence/operator/full-packs-world.txt
- `tl check --tier fast`: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 226/226, foreman.typecheck clean.
- Full tier beyond packs and world: not run. Only the pack changed; no kernel, kit, rigs, style or seeds.

## Changed files (all in scope)
engine/packs/parkour: README.md, pack.json (0.2.0, kernelApi 1.7 -> 1.8, 12 tests, 10 cameras), data/yard.json,
data/return.json (new), scripts/main.gd, scripts/course.gd, scripts/return_lane.gd (new), tests/bot_course.gd,
tests/bot_geometry.gd, tests/bot_ladder_retry_regular.gd. New tests: bot_ladder_course_{newcomer,regular,sharp},
bot_splits, bot_wall, bot_swing_phases, bot_return_controls, support/run_hand.gd.
Also docs/shifts/2026-11-19-day/lanes/parkour/** (stills, clip, evidence, Astra's reports astra-report-1.md and
astra-report-2.md).

## Behaviour changes (moved expectations, named)
1. The race no longer ends at the bottom of the chute (frame 338). That point now closes stage 1, and the race ends on the
   summit at 806 frames. bot_course now has to reach the summit with 0 falls and 0 swing hits. In round 1 the test
   required the bot to have waited at the swing; round 2 removed that requirement (Astra named it), because the game
   itself now punishes a mistimed crossing.
2. New HUD: per-stage split and best, run best, and a "Weight hit · Back on beam" notice.
3. A pendulum hit counts as a fall, and the clock keeps running. R resets the attempt and the swing phase. The C retry and
   the hunt2 A15/C7 fixes are kept.
4. The ladder bots share one input policy (the round-1 per-hand lead table is gone), so the round-1 ladder figures
   (newcomer 20/20) are not comparable with round 2's (17/20).

## For the owner (how to look)
`node devx/bin/tl.mjs play parkour`, or walk to the plot from the village road. Watch clip.mp4 and
stills/contact-sheet.jpg. Every difficulty figure here comes from scripted hands, not from a person. Nobody has played
the new stages yet. Things a person should judge:
- A hit costs only 0.2-0.4 s, because you go back to the beam entry, about 5 m away.
- The "final tower" is a 3.2 m concrete run-up bank plus a crest and two 0.78 m terraces on scaffold.
- The pads and the narrow beam are easy for a straight-line bot. With the orbit camera they may feel different.

## Questions for the Director
1. Should the walker get a ledge grab or a mantle for vertical faces? The run-up wall works with the stock running jump.
2. Should a swinging bar you can hang from and release exist? That needs a new walker attach/release move. Today the
   swing is crossed on foot.
3. Contracts: none touched.

## Next three things this lane would do
1. A person plays all three stages in a window. Then judge the hit cost, the pad camera and the tower height against his
   hand.
2. Find out why the newcomer hand loses 3 of 20: which obstacle and seed. The ladder output has the seeds.
3. If the Director answers yes to question 1 or 2, a stage built around the new move (kernel lane first).
