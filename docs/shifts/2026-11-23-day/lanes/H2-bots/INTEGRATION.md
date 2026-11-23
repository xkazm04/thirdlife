# H2 integration: the bots on the combined hockey (H1's hand + H2's sheet)

Shift 2026-11-23-day, lane H2, integration round, in the integration tree `n23-int` (branch `d23-hockey`, `588103c` + this
round's changes, uncommitted). The owner plays this build this evening. Nobody has played it with a hand yet: every
figure below is a scripted hand (`TLHand` newcomer or regular driving the ladder bot) or bots alone.

## What changed this round

| what | where | before -> after | why |
|---|---|---|---|
| A5: the bots' hit thresholds in route A's scale (x 0.727) | `data/ai.json` `check_min_closing_red`, `check_min_closing_blue`, `cross_min_closing`; `data/levels/*.json` `check_min_closing_red`, `cross_min_closing` | 4 -> 2.9, 8 -> 5.8, 1.5 -> 1.09; levels checks 6 / 2 / 2 -> 4.36 / 1.45 / 1.45, cross-checks rookie 99 (never, kept) / 0.73 / 0.18 (from 1.0 / 0.25) | H1's route A scaled the hit law's speeds by 9.2 / 12.65 |
| **The stick's timing is the level** (new) | `scripts/ai/brain.gd` `_poke_ready` (called from `_contact`); new keys `poke_delay`, `poke_gap` in `data/ai.json` (the mates 6 / 30) and the levels | a bot poked the moment it could (H1's poke always takes in reach from the front or side) -> a poke only after the carrier has been in his reach `poke_delay` 20 / 6 / 0 frames in a row, and `poke_gap` 60 / 30 / 14 frames after his own last poke (rookie / pro / all-star; 14 is the game's own cooldown) | with a poke that always takes, the bots' timing decides how long a person keeps the puck; thirdjam's rookie pokes after 14 frames in reach, pro 2, all-star 0 (`DifficultyProfile.cpp`), and its rookie is "clumsy, never absent" (R-0067) |
| unchanged and still in force | `fresh_frames` 60 / 6 / 0 after a take; only D1 and the hunter (`hunt_m` 0 / 6 / 20 m) use the stick; no cross-check at rookie | | the ladder's other steps |
| README | the AI paragraph (poke timing, A5 numbers); a doubled "2.5 m cannot" in the poke paragraph the merge left | | |

No H1 file (poke.gd, carry.gd, tuning.json) was changed in this round.

## Measured: target / build 1 / combined / integration / thirdjam

Instrument: the round 1 probe with two more counters (every carry's length; the human's side losing the puck with his carry
last): this tree's `.tl/bots_probe_v2.gd` (copy in this folder, `bots_probe_v2.gd.txt`), in pack copies under `.tl/h2/`
(`A` = the combined tree with A5, before the stick ladder; `B` = this round's code), 20 seeds a cell, nine cells
(rookie / pro / all-star x all-AI, newcomer, regular). Build 1 = `d23-bots` `.tl/probe4` (probe v1: no carry lengths).
Tables by `.tl/h2/carry.mjs` and `.tl/h2/itable.mjs`. Per level: rookie / pro / all-star. thirdjam: round 1's figures and
H1's trace (median carry 0.57 s at pro with its playtester, folded blips; its bots took the carrier's puck ~30 times a
minute of carrying).

| figure | target | build 1 | combined (H1 + H2 + A5) | integration (stick ladder) | thirdjam |
|---|---|---|---|---|---|
| the human's carry, median s (newcomer hand) | rookie long enough to skate and choose, shorter by level | n/a (probe v1) | 1.3 / 0.87 / 0.67 | 1.7 / 1.2 / 0.72 | 0.57 (pro, its playtester, H1's trace) |
| the human's carry, median s (regular hand) | rookie long enough to skate and choose, shorter by level | n/a (probe v1) | 1.1 / 0.73 / 0.67 | 1.5 / 0.75 / 0.78 | 0.57 (pro, its playtester, H1's trace) |
| poked off him a minute of his carrying (newcomer) | rising by level | n/a | 17 / 40 / 39 | 6.9 / 32 / 35 | ~30 (pro; stick or touch) |
| poked off him a minute of his carrying (regular) | rising by level | n/a | 19 / 43 / 42 | 9.5 / 33 / 42 | ~30 (pro; stick or touch) |
| his side lost the puck after his carry, a minute of his carrying (newcomer; pokes, hits, his intercepted pass or saved shot) | report | n/a | 31 / 41 / 48 | 24 / 36 / 49 | n/a |
| his side lost the puck after his carry, a minute of his carrying (regular; pokes, hits, his intercepted pass or saved shot) | report | n/a | 31 / 48 / 56 | 27 / 39 / 49 | n/a |
| opponents' pokes that take the puck a minute of play (regular hand) | 0.7 / 1.8 / 2.7 | 1.4 / 1.5 / 1.0 | 2.9 / 3.1 / 1.9 | 1.4 / 1.2 / 2.3 | 0.7 / 1.8 / 2.7 (3 rendered matches a level) |
| opponents' pokes that take the puck a minute (all-AI) | a ladder | 0.21 / 0.58 / 0.62 | 0.82 / 2.2 / 2.2 | 0.03 / 0.52 / 2.4 | n/a |
| opponents' cross-checks landed a minute (regular hand; H1's cross-check also strips the puck) | 0 at rookie | 0.00 / 2.4 / 2.8 | 0.00 / 2.3 / 3.0 | 0.00 / 2.3 / 3.2 | 0 / 1.1 / 0.7 |
| opponents' checks + cross-checks tried a minute (regular) | report | 3.6 / 10 / 11 | 3.0 / 7.6 / 8.2 | 3.1 / 8.8 / 8.0 | 4.5 / 11 / 11 |
| hits landed on the human a minute (regular) | 1.5-2.5 | 1.0 / 2.4 / 2.3 | 0.86 / 1.1 / 1.6 | 1.3 / 1.7 / 2.0 | 1.5 / 2.4 / 2.0 |
| pass completion, both sides, 9 cells | 60-75 % | 83 %-91 % to 93 % | 85 %-93 % | 83 %-93 % | 48-60 % |
| mates' passes to the human a minute (regular) | 2-3, falling | 2.1 / 2.2 / 1.7 | 2.8 / 1.9 / 2.1 | 2.5 / 2.0 / 2.1 | 2.9 / 2.6 / 2.8 |
| mates' shots a minute (regular) | 0.8-1.1 | 0.91 / 0.78 / 0.64 | 0.82 / 0.47 / 0.62 | 1.0 / 0.41 / 0.36 | 0.8-1.1 |
| two of one side within 5 m of the puck, blue (9 cells) | ≤ 22 % | 15 %-21 % | 17 %-20 % | 16 %-21 % | 15-22 % |
| 4+ skaters within 5 m of the puck (9 cells) | ≤ 10 % | 5 %-8 % | 4 %-8 % | 4 %-9 % | 6-11 % |
| forecheck, two or more in blue's end (regular) | 65 / 77 / 84 % | 55 % / 73 % / 75 % | 58 % / 70 % / 80 % | 50 % / 80 % / 81 % | 65 / 77 / 84 % |
| still 2 s or more a minute per side (9 cells) | < 0.05 | 0.06-0.13 | 0.03-0.29 | 0.05-0.19 | 0.00-0.02 |
| puck loose (9 cells) | toward thirdjam | 38 %-51 % | 45 %-53 % | 43 %-53 % | 51-68 % |
| blue wins of 20 (ai) | reported, not tuned | 20 / 13 / 7 | 20 / 11 / 7 | 18 / 16 / 5 | n/a |
| blue wins of 20 (newcomer) | reported, not tuned | 16 / 8 / 4 | 16 / 7 / 1 | 19 / 7 / 3 | n/a |
| blue wins of 20 (regular) | reported, not tuned | 18 / 13 / 5 | 18 / 9 / 5 | 19 / 10 / 1 | n/a |

**The stick ladder.** With H1's poke (always takes in reach from the front or side), the combined tree had no stick ladder:
the human was poked off 17-19 times a minute of his carrying at rookie, 40-43 at pro, 39-42 at all-star, and rookie's bots
took the puck 2.9 times a minute of play (more than pro's). With the timing keys: **7-9.5 / 32-33 / 35-42 a minute of his
carrying**, and his median carry **1.5-1.7 s at rookie, 0.75-1.2 s at pro, 0.72-0.78 s at all-star** (thirdjam about 0.57 s
at pro). In the all-AI cells the bots' takes a minute go 0.03 / 0.52 / 2.4 (combined 0.82 / 2.2 / 2.2): rookie's bots
barely poke bots, because a bot carrier passes inside rookie's 60-frame grace.

**What I judge playable, and why.** At rookie a person keeps the puck about 1.5 s by median, 9-22 % of his carries last 3 s
or more, and a poke comes about once every 6-9 s of carrying, after he has stood 20 frames (a third of a second) inside a
stick: long enough to see the rink, skate a few metres and choose, and the poke is visible coming (the bot stands at his
stick before it strikes). At pro the carry is about thirdjam's (0.75-1.2 s against 0.57 s) and the poke rate thirdjam's (32-33
against ~30 a minute of carrying): a person must pass or shoot within a second, as in thirdjam. All-star is faster still on
the stick (35-42) but the regular hand's median carry does not drop below pro's (0.78 against 0.75 s): the ladder's top step is
in the forecheck, the hunt and the shooting, not the carry. These are scripted hands that read the puck's true position; a
person turns slower. If the owner finds rookie too sticky, `poke_delay` 20 -> 30 at rookie is the one number to move.

**Not reached, said plainly.**
- Opponents' takes a minute of play (regular hand) 1.4 / 1.2 / 2.3 against thirdjam's 0.7 / 1.8 / 2.7: rookie is still twice
  thirdjam's per minute of play (the human carries more here), pro is under. Per minute of his carrying the ladder holds.
- Pass completion 83-93 % against 60-75 % (unchanged by H1's pickup and poke rules: the pass magnet now bends only a pass
  that heads at its receiver, and completion did not move).
- The human's mates shoot less at pro and all-star on the combined tree (0.41 / 0.36 a minute against build 1's 0.78 /
  0.64; the combined tree before this round 0.47 / 0.62): H1's slower carrier and a poke that always takes shorten a mate's
  carry before he shoots. Not chased in this round.
- Mates' feeds 2.5 / 2.0 / 2.1 a minute: inside 2-3, not falling with the level.
- Idle 0.05-0.19 a minute against < 0.05; forecheck 50 % at rookie against 65 %.
- Wins (reported, not tuned; scripted hands): regular 19 / 10 / 1, newcomer 19 / 7 / 3. All-star is harder than in build 1
  (5 and 4 of 20 there).

## Tests

No test expectation moved in this round. The full list of the pack's 56 bot tests, run 4 at a time on this round's code
(13:05-13:09, `.tl/h2/tests/`), all passed (lint, smoke and invariants are in the gate below).

## Gates

- `node devx/bin/tl.mjs check --tier fast` (13:21): **PASS** arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck.
- `node devx/bin/tl.mjs check --tier full --only packs` (13:11-13:33): **FAIL**, "completed 2 of 3 units found; verb runs 128
  of 129; FAILED hockey: invariants: invariants.many_budget: frame p50 1.308 ms (budget 1.0 ms)". Every other unit passed:
  hockey lint, smoke and its 56 bots, duel, parkour.
- `many_budget`, back to back on this machine (one run each, `tl.sh invariants`, frame p50):

| time | this round (`engine/packs/hockey`) | the combined tree before this round (`.tl/h2/A`) | main's pack (`c4b0b83`, d23-bots `.tl/probe/hockey`) | CPU load |
|---|---|---|---|---|
| 13:33-13:35 | 1.237, 1.207 ms | | 1.093, 1.044 ms | about 18 % after |
| 13:36-13:38 | 1.153 ms | 1.154 ms | 1.073 ms | 99 % after |

  This round's code costs nothing measurable (1.153 against 1.154 ms); the combined tree is 7-16 % over main's pack (build 1
  measured +3 % on its own; the rest is the combined hand build). **Main's own pack is over the 1.0 ms budget too**
  (1.04-1.09 ms) on this machine today. Not loosened; the Director's call.

## Proof as a person meets it

`bots_integration_rookie_newcomer_s1.mp4` (22 s, rookie, the newcomer hand, seed 1, a window at 60 fps) and
`bots_integration_rookie_newcomer.jpg` (one frame every 2 s). At rookie the human's carries run for a while, a red skater
comes to his stick and stays before he pokes, his mates go to the net and shoot (a save at 6 s, his goal at 12 s). Still the
60 m rink and the 1.76 m bodies (route A).

## For the Director

- The one number to move after the owner's evening: `poke_delay` at rookie (20 frames; 30 if he finds rookie still too
  sticky, 12 if too easy). `poke_gap` and `fresh_frames` are the next two.
- The human's mates shoot less at pro and all-star on the combined tree (0.4 a minute): a mate's carry is now short (H1's
  slower carrier, a poke that always takes); worth a look in the next bots round (`settle_frames` or the mate's
  `shoot_weight`).
- Pass completion stays 83-93 %: the puck's catch, not the bots' choice of lane, keeps passes safe.
