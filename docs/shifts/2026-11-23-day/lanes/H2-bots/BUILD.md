# H2 build 1: the behaviour sheet built into the house hockey

Shift 2026-11-23-day, lane H2, build round. Worktree `d23-bots` (from main `f1659f1`). The sheet is
`docs/research/hockey-teardown/BEHAVIOUR-BOTS.md` section 4; this file says what was built, what it measured before and
after with the same instruments, which tests moved and why, and what is left for H1. It stays on a branch until the owner
says so. **Nobody has played it with a hand**; every figure is a scripted hand or bots alone.

**Scope kept:** `engine/packs/hockey/scripts/ai/*` (brain, carrier, roles), `data/ai.json`, `data/levels/*.json`, two
tests (`tests/bot_own_net.gd`, `tests/bot_modes.gd`), the README's AI paragraphs. Nothing in skate, carry, poke, hits, fun or `tuning.json`.

## What was built (sheet line → where)

| line | built | where |
|---|---|---|
| 1 | Spacing: mates keep `sep_m` 8 m apart, weight `sep_weight` 2.5 (was 4 m x 1.2); the man contesting a loose puck keeps it too (weight 0.6; he was exempt); thirdjam's clump split: two mates within `clump_m` 2.5 m for `clump_frames` 45 frames steer to `split_m` 5 m apart (the higher id gives way, anybody gives way to the human); the lane-blocker (D2) stays 5 m off the carrier (he was the pile's second body) | `brain.gd` `_execute`, `roles.gd` `block`; keys in `ai.json` |
| 2 | Support ring 9-18 m from the carrier, ideal 12-15 (was 6-14, ideal 6-9), 2 m grid, a spot within 5 m of a mate marked crowded (was 4 m, penalty doubled); the high man 12 m behind the puck (was 8) | `roles.gd` `support`, `safety` (consts `RING_MIN`, `RING_MAX`, `CROWD_M`, `HIGH_M`) |
| 3 | The human's mates' shooting ban deleted (`assisted()`, `assist_frames`) | `carrier.gd` choose, `brain.gd` `_execute`, `ai.json` |
| 4 | The mate's 8 m hold and his turn-away at their net deleted | `carrier.gd`, `brain.gd` |
| 5 | Feeding the human by level: when he is open ahead (his pass lane passed the threshold and he is up ice of the carrier), a mate passes to him in `feed_share` of his carries (rookie 0.6, pro 0.4, all-star 0.2; Classic 0.4), rolled once a carry; `feed_bonus` deleted | `carrier.gd`, `brain.gd` `level_value`, levels |
| 6 | Rookie at full pace: `red_skill` 1.0 / 1.0 / 1.05 (was 0.55 / 0.795 / 0.83) | levels |
| 7 | Clumsy, not slow: reaction 10 / 7 / 5 frames (was 18 / 12 / 7); aim 8 / 4 / 2 deg (was 6 / 4 / 2.5); `shoot_min_xg` 0.25 / 0.15 / 0.05 (was 0.15 for all); a new `shoot_weight` 1.6 / 1.9 / 3.0 (was 1.6 for all) | levels, `carrier.gd` |
| 8 | Settle before a re-pass: no pass or dump within `settle_frames` 10 of a take (a shot, and so a one-timer, is exempt) | `brain.gd` `_execute` |
| 9 | Passes: `pass_min_lane` 0.25 (was 0.55), `pass_weight` 1.8 (was 2.6), the up-ice gain 0.45 (was 0.3) | `ai.json`, `carrier.gd` |
| 10 | The back-pass and corner-carom own-goal guard deleted; the guard on a pass across our own mouth kept | `carrier.gd` `_near_own_net` |
| 11 | Stick timing by level: `fresh_frames` 60 / 6 / 0 (was 60 for all); the mates 6 | levels, `ai.json` |
| 12 | Rookie never cross-checks: `cross_min_closing` 99 | `levels/rookie.json` |
| 13 | The hunt: the nearest non-D1 defender within `hunt_m` 0 / 6 / 20 m of the opposing field carrier goes at him and may poke and cross-check (only D1 could); the mates 6 | `brain.gd` `_pick_hunter`, `_choose`, `_contact` |
| 14 | The forecheck by level: while their carrier is in his own end only `forecheck_men` 1 / 2 / 2 of us go in, the second in `forecheck_share` 1.0 / 0.6 / 1.0 of his carries; the others hold at the blue line | `brain.gd` `_forecheck` |
| 15 | Checks from `check_min_closing_red` 6 / 2 / 2 m/s (was 9.5 / 3.0 / 2.6) | levels |
| 16 | Bots sprint: a contester or presser sprints in `sprint_share` 0.2 / 0.35 / 1.0 of his chases (the mates 0.35), through the existing `skate.pace` | `brain.gd` `think` |
| 17 | No standing: the support spot re-chosen every 10 frames (was 30); a skater brakes onto his spot only above `brake_above` 3 m/s (was 0.3) and keeps his feet moving on it (a slow glide across the puck's line); the D3 post follows the puck's z by 0.5 (was 0.3) | `roles.gd`, `brain.gd` |
| 18 | `yield_frames` 30 (was 45) | `ai.json` |

The sheet's share rolls (lines 5, 14, 16) do not draw from `ctx.rng`: they hash the run's seed with what is decided
(`brain.gd` `roll`), so the shared stream that aims, adds noise and resolves pokes runs as before. Still deterministic:
same seed, same hash.

Three rounds of measuring were needed: iteration 1 (the sheet's values) left the spread, the passes and the all-star's
shots short; iteration 2 widened the ring and the high man, raised the up-ice gain to 0.6 and the shot weight by level;
iteration 3 (the build) took the roll off `ctx.rng`, set the up-ice gain to 0.45 (0.6 made the bots stop shooting:
`bot_hockey_ai` saw no AI shot), rookie's stick delay to 60 frames and all-star's shot weight to 3.0. Iteration tables are
in this tree's `.tl/probe2` (1), `.tl/probe3` (2), `.tl/probe4` (3, the build).

## Before / after (the probe, 20 seeds a cell, nine cells)

Instrument: `docs/research/hockey-teardown/probes/bots_probe.gd.txt` as `tests/bots_probe.gd` in a copy of the pack under
`.tl/` (before: main's pack, the round 1 run, `.tl/probe/out`; after: this build, `.tl/probe4/out`), summed by
`probes/bots_sum.mjs`; this table by `.tl/build_table.mjs`. Ranges are over the nine cells unless the row names cells or
levels (rookie / pro / all-star). thirdjam's column is round 1's measured figures (its own instruments; summaries kept).
**[m]**: a length on today's rink and bodies. "n/a": not measured on that side.

| line | figure | sheet target | before | after | thirdjam |
|---|---|---|---|---|---|
| 1 | two of one side within 5 m of the puck, blue / red (9 cells) | ≤ 22 % | 30 %-38 % / 24 %-30 % | 15 %-21 % / 14 %-28 % | 15-22 % |
| 1 | 4+ skaters within 5 m of the puck | ≤ 10 % | 15 %-18 % | 5 %-8 % | 6-11 % |
| 2 | side spread round its centre, m | ≥ 9 [m] | 6.2-7.6 | 7.1-8.8 | 13 m (8.7 at our rink's scale) |
| 2 | blue mates' distance to their carrier, m | ≥ 13 [m] | 8.6-10 | 10.0-12 | 18-24 m (12-16 at rink scale) |
| 3 | the human's mates' shots a minute (newcomer / regular, by level) | 0.8-1.1 | 0.3 / 0.1 / 0.1; 0.2 / 0.2 / 0.0 | 1.1 / 0.8 / 0.7; 0.9 / 0.8 / 0.6 | 0.8-1.1 |
| 4 | puck in blue's end / red's end, pro regular | ≤ 20 % / ≥ 35 % | 33 % / 18 % | 25 % / 24 % | 17 % / 40 % |
| 5 | mates' passes to the human a minute, regular hand, by level | 2-3, falling | 3.4 / 2.5 / 2.0 | 2.1 / 2.2 / 1.7 | 2.9 / 2.6 / 2.8 |
| 7 | opponents' shots a minute, regular hand, by level | 2.5 / 3.8 / 6-7 | 2.3 / 4.0 / 4.4 | 2.3 / 3.0 / 4.4 | 2.5 / 3.8 / 7.0 |
| 7 | opponents' shot distance median, regular hand, m | longer with the level | 9.6 / 9.7 / 10 | 9.1 / 10 / 13 | most from 20 m+ at pro and all-star |
| 8 | blue's passes re-passed the frame they arrive (rookie all-AI) | ≤ 5 % | 62 % (6 seeds) | 0 % | 0-11 % within 15 frames |
| 8 | blue's passes a minute, rookie all-AI | 10-20 | 45 | 21 | n/a |
| 9 | pass completion (both sides, 9 cells) | 60-75 % | 79 %-95 % | 83 %-93 % | 48-60 % (its own definition) |
| 9 | passes completed over 6 m / completed pass median, m | 30-40 % / ≥ 7 [m] | 14 %-24 % / 3.3-5.2 | 45 %-55 % / 6.5-7.9 | 29-42 % / n/a |
| 10 | goals whose last carrier was the defending side | ≤ 5 % | 15 of 509 (3 %) | 25 of 472 (5 %) | n/a |
| 11 | opponents' pokes that take the puck a minute, regular hand | 0.7 / 1.8 / 2.7 | 2.0 / 1.7 / 1.6 | 1.4 / 1.5 / 1.0 | 0.7 / 1.8 / 2.7 (3 matches a level) |
| 11 | opponents' pokes tried a minute, all-AI | ≥ 2 | 0.4 / 0.5 / 0.4 | 0.9 / 2.9 / 2.7 | 2.1 / 3.3 / 4.4 (rendered, its hand) |
| 12 | rookie cross-checks landed a minute (newcomer / regular) | 0 | 1.3 / 0.8 | 0.0 / 0.0 | 0 |
| 13 | an opponent within 2.3 m inside 1 s of the human's take, regular hand | 63-78 %, rising | 73 % / 70 % / 78 % | 76 % / 72 % / 78 % | 66 / 72 / 69 % |
| 13 | the human's carries never reached, regular hand | 12-23 % | 20 % / 18 % / 12 % | 13 % / 15 % / 13 % | 34 / 27 / 30 % |
| 14 | two or more forecheckers in blue's end, regular hand | 65 / 77 / 84 % | 91 % / 95 % / 98 % | 55 % / 73 % / 75 % | 65 / 77 / 84 % |
| 14 | forecheckers, mean of 3, regular hand | 1.2 / 1.4 / 1.6 | 2.0 / 2.1 / 2.2 | 1.5 / 1.7 / 1.7 | 2.0 / 2.3 / 2.7 of 5 |
| 15 | opponents' checks + cross-checks tried a minute, regular hand (the hit rate) | report, not tuned | 3.8 / 9.4 / 10 | 3.6 / 10 / 11 | 4.5 / 11 / 11 |
| 15 | opponents' body checks / cross-checks landed a minute, regular hand | report | 1.6+0.8 / 3.5+2.1 / 3.9+2.4 | 2.2+0.0 / 2.8+2.4 / 3.0+2.8 | 3.6 / 4.2 / 5.1 (3 matches) |
| 15 | knockdowns by red a minute, regular hand | report | 1.6 / 2.8 / 3.2 | 2.0 / 2.5 / 2.2 | n/a |
| 17 | still 2 s or more a minute per side (9 cells) | < 0.05 | 0.1-1.1 | 0.0-0.1 | 0.00-0.02 |
| 18 | opponents' hits landed on the human a minute, regular hand | 1.5-2.5 | 1.6 / 2.9 / 2.9 | 1.0 / 2.4 / 2.3 | 1.5 / 2.4 / 2.0 |
| - | puck loose (9 cells) | toward thirdjam | 29 %-39 % | 38 %-51 % | 51-68 % |

## Tests that moved, each with its sheet line

| test | what moved | sheet line | change |
|---|---|---|---|
| `tests/bot_own_net.gd` | row `own_corner` failed: red's carrier made a pass toward his own end, which the test counted as unsafe | 10 (the back-pass guard deleted) | a pass toward the own end is now counted (`back_passes`, in the row's detail) and no longer fails the row; the row still fails on a pass that is not a release of the frame before, on any goal in the drill, and on a carrier who does not act. Nothing else in the test changed |
| `tests/bot_modes.gd` | `base` mode, bots on both sides, went 0:0 into overtime past the 9,000-frame cap | 1-14 together (fewer goals in the all-AI base match) | `CAP` 9,000 → 18,600 frames: the rules' own end (`tuning.json` `time_limit_seconds` 300 s of play, two 2 s intermissions, 1 s); the test still fails a mode that does not end by its rules. On the build: base ended 1:0 at 12,599 frames |

Two tests failed in iteration 2 and were fixed in the game, not in the test: `bot_hockey_ai` (no AI shot in its match:
the up-ice pass gain of 0.6 made carriers pass instead of shoot; 0.45 in the build) and `bot_reach` (the scripted poke of
its row "an opponent pokes it" whiffed because the sheet's new rolls had shifted `ctx.rng`; the rolls now hash the seed).
No test was loosened for any other reason. Ladder tests assert that the match is played to its end and the hand acted
(not a win share), except `bot_ladder_rookie_perfect`, which must win: it passes.

## The ladder (wins of 20, read through `TLHand`; the same probe cells)

| blue wins of 20 (the hand) | before | after |
|---|---|---|
| all-AI (blue = Classic mates) (rookie / pro / all-star) | 18/20 / 16/20 / 8/20 | 20/20 / 13/20 / 7/20 |
| newcomer (rookie / pro / all-star) | 16/20 / 6/20 / 0/20 | 16/20 / 8/20 / 4/20 |
| regular (rookie / pro / all-star) | 19/20 / 11/20 / 6/20 | 18/20 / 13/20 / 5/20 |

The figures are reported, not tuned back (the owner: bot metrics are not the bar). The human side gains at pro and
all-star: his mates now shoot, carry and feed him, and red's ladder is pressure instead of slowness. No ladder test's bound
is a win share, so no bound changes; the README's ladder table (16 Nov bands) is history, and the next ladder should be
read through a person's hand.

## The hit rate (the Director: keep hits possible, re-measure, report, do not tune back)

Opponents' checks and cross-checks tried a minute with the regular hand: 3.8 / 9.4 / 10 before, **3.6 / 10 / 11 after**
(thirdjam 4.5 / 11 / 11). Landed body checks + cross-checks a minute: 1.6+0.8 / 3.5+2.1 / 3.9+2.4 before, **2.2+0.0 / 2.8+2.4 /
3.0+2.8 after**. Knockdowns by red: 1.6 / 2.8 / 3.2 before, **2.0 / 2.5 / 2.2 after**. Hits landed on the human: 1.6 / 2.9 / 2.9
before, **1.0 / 2.4 / 2.3 after**. The pile is gone and the hits stayed: tries are as many as before and as thirdjam's,
all-star's knockdowns fell by a third. In the all-AI cells red tries more than before (the hunt). Rookie lands no
cross-check at all (line 12).

## For H1 (outside this lane's scope)

- **Line 15, check speeds.** H1 scales hit speed thresholds by 0.727 (route A). `check_min_closing_red` 6 / 2 / 2 m/s and
  `cross_min_closing` 99 / 1.0 / 0.25 in `data/levels/*.json` (and `check_min_closing_blue` 8, `cross_min_closing` 1.5 in
  `ai.json`) are closing speeds the bots test against `hits.closing`; if H1's thresholds scale, scale these by the same
  0.727 (rookie 4.4, pro and all-star 1.5) or hand me the numbers.
- **Line 16, sprint.** The bots now call `skate.pace(slot, held, move)` (`scripts/skate.gd:136`) like the human: stamina,
  the sprint bonus and the turn penalty are skate's. If H1 changes the sprint's numbers, bots follow them.
- **Line 11, pokes by level.** The all-star's pokes that take the puck stay short of thirdjam's ladder (see the table): its
  presser now pokes at once, but the odds are `scripts/poke.gd`'s (front 65 %, side 45.5 %, behind 26 %, 24-frame lock on a
  new owner). A per-level odds factor would be H1's.
- **The puck loose / pass completion.** Completion stays high because a pass to an open mate is caught (`carry.gd` pickup
  windows, the 3.3 m pass magnet); thirdjam's passes die short. That is the puck's law, H1's.
- **Lengths in metres** (lines 1, 2, 13: `sep_m`, `clump_m`, `split_m`, the 5 m block, the 9-18 m ring, the 12 m high man,
  `hunt_m`): they assume today's rink and bodies (route A keeps them).

## Not reached, said plainly

| line | figure | target | after | why, and what would move it |
|---|---|---|---|---|
| 2 | side spread / mates' distance to their carrier | ≥ 9 m / ≥ 13 m | 7.1-8.8 m / 10-12 m | three skaters on a 30 m wide rink with 1.76 m bodies; 8.7 m is thirdjam's spread at our rink's scale, so the spread is there by the rink, not by body widths (H1's route A keeps the bodies) |
| 4 | the puck in blue's end / red's end (pro, regular hand) | ≤ 20 % / ≥ 35 % | 25 % / 24 % | moved the right way (33 / 18 before); the human's side still spends more time defending than thirdjam's |
| 5 | mates' passes to the human, falling with the level | 2-3 | 2.1 / 2.2 / 1.7 | the feed rule fires only when he is open ahead and his lane passes 0.25; with the mates now shooting themselves the total fell. Raise `feed_share` if the owner finds he is starved |
| 7 | all-star opponents' shots a minute | 6-7 | 4.4 (median 13 m, was 10) | the shot weight 3.0 and `shoot_min_xg` 0.05 moved distance more than count; the carrier still prefers a pass. Not tuned further today |
| 9 | pass completion | 60-75 % | 83-93 % | the lane threshold is not what keeps passes safe: open mates (lines 1-2) and the pass magnet (`carry.gd`, H1) catch them. Longer passes reached (45-55 % over 6 m, median 6.5-7.9 m) |
| 11 | opponents' pokes that take the puck, by level | 0.7 / 1.8 / 2.7 | 1.4 / 1.5 / 1.0 | rookie still pokes too well and all-star too little; the hunt and stick timing raised tries (all-AI 0.4 → 0.9-2.9 a minute) but success is `poke.gd`'s odds (H1) |
| 14 | all-star forecheck (two or more in the carrier's end) | 84 % | 75 % | 55 / 73 / 75 % against 65 / 77 / 84: a ladder now, the top step short |
| 17 | still 2 s or more a minute | < 0.05 | 0.0-0.1 | down from 0.1-1.1; which skater the last ones are was not traced |
| 6, 16 | red's speed at rookie; bots sprinting | the mates' pace; sprint shares | not measured | the probe has no speed counter (round 1 said so); `red_skill` 1.0 makes rookie's skating wish the mates', and bots call `skate.pace` now, but neither is measured here |

## Proof as a person meets it

`bots_after_pro_regular_s1.mp4` (this folder, 22 s, pro, the regular hand, seed 1, a window at 60 fps) and
`bots_before_after_pro.jpg` (one frame every 4 s, before above, after below; the before clip is main's pack, same seed
and hand). After: the knot round the puck has loosened (two to three bodies at the puck instead of four to six), a
mate stands wide for the pass, a one-timer. It is still a 60 m rink with 1.76 m bodies. Nobody played it with his own
hands.

## Gates

- `node devx/bin/tl.mjs check --tier fast` (11:50): **PASS** arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck.
- `node devx/bin/tl.mjs check --tier full --only packs` (11:36-12:05): **FAIL**, "completed 2 of 3 units found; verb runs
  128 of 129; FAILED hockey: invariants: invariants.many_budget: frame p50 1.419 ms (budget 1.0 ms)". Every hockey bot
  (56), lint, smoke, and the duel and parkour packs passed; only the clock budget failed. **It is the machine, not the
  sheet:** run alone at 12:06 the build's invariants gave p50 1.386 ms and main's pack (this tree's `.tl/probe/hockey`,
  the code before the sheet) gave 1.376 ms in the same minute, both failing; CPU load was 94 % (other sessions). The
  verdict on the frame budget needs a quiet machine. Retried at 12:10 (CPU 100 %): the build 1.426 ms, main's pack 1.384 ms
  (the sheet costs about 3 %: the support ring is re-chosen every 10 frames instead of 30). **This check was already failing
  before the sheet**: the night's integration tree `n23-int` (01:01) failed it at 1.265 ms, `n23-world` (21:30) at 1.445,
  `d22-home` at 1.117; the last pass in the worktrees' logs is `n22-int` (07:49 on 22 Nov, 0.979 ms). I did not loosen it.
- The full test list was also run outside the gate (4 at a time, 11:31-11:33): all passed after the two test
  changes above (55 in the list run; `bot_modes` passed alone after its cap change).
