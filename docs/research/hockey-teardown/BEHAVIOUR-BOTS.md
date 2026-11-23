# Hockey behaviour teardown: the bots, and the sandbox

Lane H2 of the day shift of 23 Nov 2026. Research only: nothing in `engine/`, `foreman/`, `contracts/` or `devx/` changed.
Round 1 (this draft): section 0 and sections 1-2, the bots. Round 2: section 3 (the sandbox), sections 4-5.

**The owner, 23 Nov, after the first teardown (verbatim):** "Hockey - the points you identify plays minority role. You are
focused on visual perspective where as the core of gameplay design is in behavior, which is almost untouched by your
analysis. Please do repeat it - it is about sensitivity of movement (speed, accelaration, deaccelaration),
tackles/croschecks and their reactivity, bot aggressivity and ability to play hockey, openness to sandbox the game (bring
weapons, special equipment and boosts), stick control with puck and ability for puck to stick to players"

This file answers "bot aggressivity and ability to play hockey" (round 1) and "openness to sandbox the game" (round 2).
Lane H1 answers the body, the hits and the puck.

## 0. The verdict in ten lines

1. **Our bots are not less aggressive than thirdjam's. They press as often and hit as often.** With the same definitions,
   an opponent reaches our human carrier within 1 s of his take in 63-78 % of his carries (thirdjam 62-72 %). About one
   opponent stands within 5 m of him in both games, and opponents try about 4 / 10 / 10 checks and cross-checks a
   minute at rookie / pro / all-star in both (table 1.1, 1.3). Measured against the rink instead of the metre, ours is looser (0.5-0.8 within
   3.3 m); measured in body widths (ours 1.76 m, thirdjam 0.8 m), ours is far tighter.
2. **What differs is what the press looks like: ours is a pile.** Four or more skaters stand within 5 m of the puck in
   15-18 % of play, against 6-11 % in thirdjam. Two of one side chase the same puck in 32-38 % of play, against 15-22 %.
   A side spreads 6.5 m round its centre, against 13 m (table 2.2, sheet `media/bots_aggr.jpg`).
3. **Our level ladder is not an aggression ladder.** Our rookie already forechecks with two of three in blue's end 91 %
   of the time, and all-star 98 %: it starts near the top and has nowhere to go. Our rookie's pokes take the puck as often
   as all-star's (2.0 against 1.6 a minute). thirdjam climbs: forecheck 65 → 77 → 84 %, pokes that take the puck
   0.7 → 1.8 → 2.7 a minute, cross-checks 0 at rookie (its rookie never uses the stick on a man).
4. **Our rookie is easy by absence, which the owner ruled out for thirdjam** ("a level is easy by clumsiness, never by
   absence", R-0067). Our rookie's skating wish is scaled to 0.55 of a mate's (`scripts/ai/brain.gd:137`,
   `data/levels/rookie.json`; measured mean speed 4.9 m/s against his mates' 6.0, N1 probe) and he reads the play 18
   frames late. thirdjam's rookie skates at full pace (`OppPace9 1.0`) and misses by aim, a slow poke and a short shot.
5. **Our passes are short and safe; thirdjam's are long and contested.** Ours complete 86-94 %, with a median of 2.5-5 m;
   thirdjam's complete 48-60 % (its own instrument). In our all-AI match at rookie, blue makes 45 passes a minute, and in
   a 6-seed check 62 % of them were re-passed the frame they arrived: one-touch ping-pong in a crowd.
6. **Our puck is always somebody's.** It is loose 29-39 % of play in ours and 51-68 % in thirdjam (its own
   instrument 51-57 %, our inference of its trace 57-68 %). thirdjam's game is a race for loose pucks into open ice; ours
   is keep-away inside a scrum.
7. **The human's mates never shoot**: 0.0-0.3 shots a minute against thirdjam's 0.8-1.1. A rule makes them shoot only
   within 4 s of the human's own pass or shot (`scripts/ai/carrier.gd:25`, `data/ai.json` `assist_frames`). The rule
   exists to stop an idle hand from winning the ladder.
8. **The opponents' shooting grows with the level in thirdjam (2.5 → 3.8 → 7.0 shots a minute; at pro and all-star three
   in four from 20 m or more) and less in ours (2.3 → 4.0 → 4.4, median 10 m)**. thirdjam's all-star shoots from anywhere, which is what pressure on the
   goal feels like.
9. **Our bots stand still for 2 s or more 0.3-1.1 times a minute per side; thirdjam's practically never** (0.00-0.02).
10. **Most of our differences come from rules written to move a bot metric or to stop an idle hand from winning**: the
    first-second grace for a fresh carrier, the mates who never shoot, the dozen own-goal guards, the single D1 who may
    poke. Section 1.5 and 2.5 list each one with file and line. What this cannot see: a person's hand on either game.

## Definitions (the same on both sides)

Every figure counts **live frames** only (play running, not frozen for a goal, a period's end or a hit-stop); a minute is
3,600 live frames, pooled over the seeds of a cell (the sum of the counts over the sum of the minutes). "Field skater" =
not a goalie. Positions are the skaters' centres on the ice, in metres of each game's own world.

| word | means |
|---|---|
| **carry** | one skater holding the puck from the frame he takes it to the frame anybody else has it or it is loose |
| **time to pressure** | frames from the take to the first frame an opponent field skater's centre is within **stick reach** of the carrier's centre. Stick reach = the game's own poke reach (ours 2.3 m; thirdjam: see 1.1). A carry that ends first counts as **never reached** |
| **near the carrier** | opponent field skaters within 5 m and 10 m of the carrier, averaged over carried frames. Our rink is 60 m long, thirdjam's 90 m: the same share of the rink is 3.33 m / 6.67 m on ours, given too |
| **poke / check / cross-check** | *tried* = the game started the action (our `possession.poke_tries`, `hits.tries`); *landed* = a poke that knocked the puck loose (`possession.pokes`), a check or cross-check that made contact (`hits.last`, class bump, stumble or knockdown) |
| **forecheck** | while a side carries in its own end (behind its own blue line), how many opponents are in that end with it; and the share of those frames with two or more |
| **pass** | a release the game counts as a pass. *Complete* = the next field skater to take it is of the passer's side. *Length* = from where the passer stood to where it was taken. *Re-gathered* = the passer has it again on the next sampled frame |
| **touches per possession** | takes by one side (passes received included) from its first take until the other side takes the puck |
| **shot** | a release the game counts as a shot; distance from the puck to the goal centre; *on net* = goals + saves by the other goalie, over shots |
| **entry** | the side in possession takes the puck over the other side's blue line; *kept* = it stays in that zone 2 s or a shot comes from it (our `tests/metrics.gd`) |
| **spread** | mean distance of a side's field skaters from their own centroid |
| **chasers** | a side's field skaters within 5 m of the puck; *2+ share* = frames with two or more of one side there |
| **net front / slot covered** | the attacking side has a field skater within 6 m of the net it attacks / the defending side one within 8 m of its own net |
| **idle** | a field skater (not the human) under 0.5 m/s, not carrying and not down, for 2 s in a row: one count per stretch |
| **circling** | a carrier who has held it 3 s and is still within 4 m of where he took it |

## How it was measured

**Ours.** A copy of the pack in this tree's `.tl/probe/hockey` (not `engine/`), main `c4b0b83`, with one extra test,
`tests/bots_probe.gd` (copy: `probes/bots_probe.gd.txt`), extending the ladder bot `tests/bot_hockey.gd`. It reads the
pack state every frame and counts by the definitions above. 20 seeds a cell, headless, nine cells: rookie / pro /
all-star, each with **all-AI** (the autopilot on b0 too, the pack's own `bot_metrics_ai` set-up), and with the human b0
played through `TLHand` **newcomer** and **regular** (the ladder's hands). 179 of 180 runs completed on the first pass;
pro / newcomer seed 20 died in a Git Bash fork failure (a segmentation fault of the shell, not Godot) and was re-run.
Runner `probes/bots_run.sh`, sum `probes/bots_sum.mjs`.

**thirdjam.** The 15 Nov build in `n23-teardown/.tl/tj-run` (JamCore linked 15 Nov 11:39 UTC, between commits `81e3d1a9` and
`cf828cad`, so about H40; not the submitted H47), copied to this tree's `.tl/tj-run` and run from there. It was measured
with three of its own instruments:
- **`-run=JamTournament -trace=1`** (its headless commandlet; `probes/bots_tj_cell.sh`), 20 seeds a cell, same nine
  cells: `-mode=brain` (bots on all ten, the human's skater too) and `-player=novice` / `-player=regular` (its person-like
  playtester on the human's skater). Its trace prints every skater's position every frame, but **not who carries the
  puck**: `probes/bots_tj_trace.mjs` infers the carrier (the skater within 1.5 m of the puck who moved with it over the
  last 0.1 s, held 4 frames). The inference finds 70-84 % of the touches the game itself counts, so its loose share is
  too high by up to a fifth; thirdjam's own instrument puts "nobody" at 51-57 % (A206, `status/A206.md`).
- **`Bar.Brain.Interest`** (its automation test of lane A206; `probes/bots_tj_interest.sh`, parser
  `probes/bots_tj_interest.mjs`), 20 seeds a level, with the novice and the regular playtester. It counts passes and
  completion, shots by distance band, carries, the defence and the hits **in its own definitions**, which are close to
  ours but not the same (a pass is complete if a mate is the next carrier within 2 s).
- **The rendered game's event log** (`JAMEVENT` / `JAMHIT` lines, `probes/bots_tj_game.sh`, `probes/bots_tj_events.mjs`):
  three matches a level (12 / 11 / 5.9 minutes of match time; the hand's seed 1, 2, 3), its scripted hand on the
  human. This is the only place thirdjam counts the bots' pokes and cross-checks by side. **Three matches a level is a
  small sample**; it stands in where nothing else counts.

Rates are a minute of live play. The rinks differ: ours is 60 x 30 m with three skaters and a goalie a side; thirdjam's
is 90 x 45 m with five a side and no goalie (a back keeps the crease). Distances are given in metres as each game draws
them; where the rink's size matters, ours is also given at thirdjam's scale (x 60/90).

## 1. Aggressivity

**1.1 How soon and how many opponents meet the carrier (thirdjam / ours)**

| level | carrier | an opponent within 2.3 m inside 1 s of the take | never reached before he let go | opponents within 5 m (ours at rink scale 3.3 m) | within 10 m (ours 6.7 m) |
|---|---|---|---|---|---|
| rookie | all-AI: blue's carriers | 53 % / 39 % | 46 % / 56 % | 0.9 / 0.8 (0.5) | 1.8 / 1.8 (1.2) |
| rookie | the human (regular hand) | 66 % / 73 % | 34 % / 20 % | 1.1 / 1.1 (0.7) | 2.1 / 1.9 (1.4) |
| rookie | the human (newcomer / novice hand) | 62 % / 67 % | 35 % / 19 % | 1.0 / 1.1 (0.7) | 2.0 / 1.9 (1.4) |
| pro | all-AI: blue's carriers | 61 % / 51 % | 36 % / 42 % | 1.0 / 0.9 (0.5) | 2.0 / 1.9 (1.3) |
| pro | the human (regular hand) | 72 % / 70 % | 27 % / 18 % | 1.3 / 1.2 (0.8) | 2.3 / 1.9 (1.4) |
| pro | the human (newcomer / novice hand) | 69 % / 63 % | 30 % / 23 % | 1.2 / 1.1 (0.7) | 2.1 / 2.0 (1.5) |
| allstar | all-AI: blue's carriers | 56 % / 61 % | 42 % / 31 % | 1.1 / 1.1 (0.6) | 2.1 / 1.9 (1.4) |
| allstar | the human (regular hand) | 69 % / 78 % | 30 % / 12 % | 1.3 / 1.2 (0.8) | 2.3 / 1.9 (1.5) |
| allstar | the human (newcomer / novice hand) | 68 % / 63 % | 30 % / 20 % | 1.3 / 1.1 (0.6) | 2.3 / 1.9 (1.5) |

**1.2 Forecheck: red skaters in blue's end while blue carries there (thirdjam / ours)**

| level | cell | red forecheckers, mean | two or more |
|---|---|---|---|
| rookie | all-AI | 2.0 of 5 / 1.9 of 3 | 66 % / 86 % |
| rookie | regular hand | 2.0 of 5 / 2.0 of 3 | 65 % / 91 % |
| pro | all-AI | 2.1 of 5 / 2.0 of 3 | 69 % / 89 % |
| pro | regular hand | 2.3 of 5 / 2.1 of 3 | 77 % / 95 % |
| allstar | all-AI | 2.4 of 5 / 2.0 of 3 | 77 % / 93 % |
| allstar | regular hand | 2.7 of 5 / 2.2 of 3 | 84 % / 98 % |

**1.3 What the opponents do with stick and body, a minute (thirdjam / ours)**

| level | thirdjam rendered matches (minutes) | pokes tried | pokes that took the puck | checks + cross-checks tried | body checks landed | cross-checks landed | hits landed on the human (20 matches each) | ours all-AI: pokes / hits tried / body / cross landed |
|---|---|---|---|---|---|---|---|---|
| rookie | 3 (12) | 2.1 / 4.2 | 0.7 / 2.0 | 4.5 / 3.8 | 2.0 / 1.6 | 0.0 / 0.8 | 1.5 / 1.6 | 0.4 / 4.6 / 2.2 / 0.9 |
| pro | 3 (11) | 3.3 / 3.4 | 1.8 / 1.7 | 11 / 9.4 | 3.1 / 3.5 | 1.1 / 2.1 | 2.4 / 2.9 | 0.5 / 9.4 / 4.5 / 1.5 |
| allstar | 3 (5.9) | 4.4 / 3.3 | 2.7 / 1.6 | 11 / 10 | 4.4 / 3.9 | 0.7 / 2.4 | 2.0 / 2.9 | 0.4 / 11 / 5.3 / 2.1 |

thirdjam's columns in 1.3: pokes, checks and cross-checks from three rendered matches a level; "hits landed on the human" from
20 matches a level (its playtest line, `bot_hits_on_human`). Its own Interest instrument counts every skater's hits
together (human included): checks landed 6.1 / 6.8 / 4.6 and cross-checks landed 4.4 / 4.8 / 3.1 a minute by level, with
the regular playtester. Ours counts per side over 20 seeds.

**What the player meets** (`media/bots_aggr.jpg`: top row thirdjam at pro, its measured hand; bottom row ours at pro, the
regular hand; one frame a second). In thirdjam one or two orange skaters come at the carrier from open ice, and the
others hold lanes 15-25 m away. In ours the same number come, but they arrive into a knot that is already there: four to
six bodies, both colours, round one puck. The press is not stronger; it is never seen coming, because there is no space
for it to come across.

**How the level changes it** (the owner's 13 Nov direction for thirdjam: "difficulty = aggression").

| per level, rookie → pro → all-star | thirdjam | ours |
|---|---|---|
| Forecheck: two or more in the carrier's end (regular hand) | 65 → 77 → 84 % | 91 → 95 → 98 % |
| Opponents' pokes that take the puck, a minute | 0.7 → 1.8 → 2.7 (three matches each) | 2.0 → 1.7 → 1.6 |
| Cross-checks landed, a minute | 0 → 1.1 → 0.7 (three matches each) | 0.8 → 2.1 → 2.4 |
| Checks + cross-checks tried, a minute | 4.5 → 11 → 11 (three matches each) | 3.8 → 9.4 → 10 |
| Opponents' shots, a minute (regular hand) | 2.5 → 3.8 → 7.0 | 2.3 → 4.0 → 4.4 |
| Opponents skating faster than half top speed | 73 → 77 → 84 % of their time (Interest) | not measured the same way; mean speed 4.9 → 5.7 → 6.0 m/s against mates' 5.7-6.0 (N1 probe, 22 Nov, `media/probe.md`) |
| What the level is made of | pace 0.85 / 1.0 / 1.15, hunt radius 0 / 8 / 30 m (pro 11 m in the final build), poke after 14 / 2 / 0 frames in reach, checks from 6 / 1 / 2 m/s, sprint share 0.2 / 0.35 / 1.0, no stick on a man at rookie (`DifficultyProfile.cpp:35-144`, `JamAICore.h:568-592`) | thrust 0.55 / 0.795 / 0.83 of a mate's, reaction 18 / 12 / 7 frames, aim noise 6 / 4 / 2.5 deg, checks from 9.5 / 3.0 / 2.6 m/s (`data/levels/*.json`) |

Both games hit more as the level rises. Only thirdjam's stick gets better with the level and only thirdjam's forecheck
has room to grow; ours is already flat out at rookie, and our rookie is slow instead of clumsy.

### 1.5 Why ours does this (file:line under `engine/packs/hockey/`)

- **The pile.** The first man of each side to the loose puck plays `contest`: he skates straight at it
  (`scripts/ai/brain.gd:161-162`, `:245-246`) and returns before the separation from his mates is applied
  (`:254-255`; separation 4 m x 1.2 is at `:260`, for everybody else). With three a side on a 60 m rink and bodies of
  0.88 m, two contesters and the carrier are four bodies in 5 m. N3 tried two keep-off rules on 22 Nov and reverted both
  because red's hit rate fell (README, N3 section; commit `4fcdf37`).
- **One man presses, and with the stick only after a second.** Only the defending side's D roles act on the carrier at
  all (`brain.gd:232-234`); D2 and D3 only inside 5 m (`:276`); pokes and cross-checks only by D1 (`:286`, `:288`). No
  stick on any fresh carrier for 60 frames (`data/ai.json` `fresh_frames`, `brain.gd:279-280`), no body check for 15
  (`fresh_check_frames`, `:281`), and nothing at all on the human for 45 frames after he takes it (`yield_frames`,
  `:278`). In the all-AI cells our opponents try 0.4-0.5 pokes a minute: bot carriers pass inside that second, so the
  stick never comes. Against the human, who holds longer, it is 3.3-4.2.
- **The ladder is speed and lateness.** `brain.gd:137` multiplies red's thrust by `red_skill` (0.55 / 0.795 / 0.83) on top
  of `speed_scale` 0.9; reaction 18 / 12 / 7 frames (`data/levels/*.json`, read through `sense.ago`, `brain.gd:97`).
  Rookie checks only from 9.5 m/s of closing (`data/levels/rookie.json`), nearly a sprint, and our bots never sprint (no
  sprint call anywhere in `scripts/ai/`).
- **No hunt.** Nothing in our roles sends a second man at the carrier by distance (thirdjam's `HuntRadiusM`: 8 m at pro in the
  measured build, 11 m in the final one, 30 m at all-star); D1 "pressure" contains from a stick's length on the inside (`brain.gd:247-251`), it does not attack.

## 2. Ability to play hockey

**2.1 Passing and shooting, a minute (thirdjam / ours)**

| level | cell | side | passes | completed | touches per possession | shots | where from (thirdjam: shots by distance band <10 / 10-20 / 20-30 / >30 m, 20 matches; ours: distance) | goals |
|---|---|---|---|---|---|---|---|---|
| rookie | all-AI | red | n/a / 5.7 | n/a / 87 % | 3.2 / 2.1 | 2.9 / 1.1 | n/a / median 8.8 m, 54 % inside 9 m | 0.4 / 0.3 |
| rookie | all-AI | blue | n/a / 45 | n/a / 91 % | 2.2 / 4.9 | 2.3 / 4.4 | n/a / median 8.9 m, 50 % inside 9 m | 0.4 / 1.7 |
| rookie | regular hand | red | 19 / 7.9 | 60 % / 79 % | 2.5 / 2.0 | 2.5 / 2.3 | <10 17, 10-20 19, 20-30 0, >30 11 / median 9.6 m, 41 % inside 9 m | 0.2 / 0.3 |
| rookie | regular hand | blue | 9.3 / 6.9 | 50 % / 92 % | 3.1 / 2.3 | 4.1 / 3.3 | <10 9, 10-20 20, 20-30 2, >30 5 / median 13 m, 28 % inside 9 m | 1.4 / 1.5 |
| pro | all-AI | red | n/a / 8.1 | n/a / 87 % | 2.8 / 2.3 | 4.5 / 1.8 | n/a / median 11 m, 29 % inside 9 m | 1.0 / 0.5 |
| pro | all-AI | blue | n/a / 19 | n/a / 91 % | 1.7 / 2.9 | 3.3 / 3.3 | n/a / median 9.9 m, 42 % inside 9 m | 0.6 / 1.4 |
| pro | regular hand | red | 15 / 11 | 57 % / 86 % | 2.2 / 2.7 | 3.8 / 4.0 | <10 19, 10-20 31, 20-30 63, >30 88 / median 9.7 m, 41 % inside 9 m | 0.6 / 0.9 |
| pro | regular hand | blue | 8.2 / 5.5 | 52 % / 89 % | 2.3 / 2.4 | 3.8 / 1.9 | <10 20, 10-20 18, 20-30 4, >30 8 / median 13 m, 22 % inside 9 m | 1.2 / 1.1 |
| allstar | all-AI | red | n/a / 13 | n/a / 94 % | 2.2 / 2.7 | 6.1 / 2.2 | n/a / median 9.9 m, 34 % inside 9 m | 1.3 / 0.8 |
| allstar | all-AI | blue | n/a / 15 | n/a / 91 % | 1.8 / 2.8 | 4.4 / 1.6 | n/a / median 9.6 m, 42 % inside 9 m | 0.8 / 0.6 |
| allstar | regular hand | red | 21 / 14 | 57 % / 93 % | 2.3 / 2.8 | 7.0 / 4.4 | <10 26, 10-20 41, 20-30 52, >30 171 / median 10 m, 42 % inside 9 m | 1.0 / 1.4 |
| allstar | regular hand | blue | 10 / 4.8 | 48 % / 87 % | 2.3 / 2.1 | 2.1 / 1.0 | <10 5, 10-20 19, 20-30 7, >30 11 / median 13 m, 19 % inside 9 m | 0.8 / 0.6 |

thirdjam's passes, completion and shot distances come from its Interest instrument with the regular playtester; the
all-AI commandlet counts no passes and no shot distances, so those cells say n/a. Its shots and goals come from the
commandlet's own match lines. "Touches per possession" on thirdjam's side
uses the inferred carrier.

**Pass length.** Our completed passes have a median of 2.5-5.3 m; 13-31 % of all our passes are completed over 6 m.
thirdjam: 29-42 % of all its passes are completed over 6 m (Interest, `PASSQ`). On a rink a third shorter, ours are still
short.

**One-touch ping-pong.** A 6-seed check (rookie, all-AI, the probe's `pass_unseen` counter) found 230 of blue's 370 passes
released by a skater who did not hold the puck on the frame before: he takes it and passes it on in the same frame.
Red: 3 of 39.

**2.2 Shape and the man without the puck (thirdjam / ours)**

| level | cell | side | possession | spread | chasers within 5 m of the puck | two or more of one side chasing | mates' distance to their carrier | a mate at the net front while carrying | own slot covered while defending | idle 2 s, a minute |
|---|---|---|---|---|---|---|---|---|---|---|
| rookie | all-AI | red | 19 % / 27 % | 13 m / 6.5 m | 0.9 of 5 / 0.9 of 3 | 18 % / 24 % | 22 m / 9.1 m | 5 % / 2 % | 10 % / 8 % | 0.0 / 0.9 |
| rookie | all-AI | blue | 13 % / 32 % | 13 m / 7.5 m | 0.8 of 5 / 1.3 of 3 | 15 % / 38 % | 22 m / 10 m | 1 % / 6 % | 6 % / 19 % | 0.0 / 1.1 |
| rookie | regular hand | red | 19 % / 35 % | 12 m / 6.3 m | 1.0 of 5 / 1.1 of 3 | 22 % / 26 % | 19 m / 9.7 m | 2 % / 3 % | 5 % / 10 % | 0.0 / 0.3 |
| rookie | regular hand | blue | 18 % / 30 % | 15 m / 7.2 m | 1.0 of 5 / 1.2 of 3 | 22 % / 36 % | 21 m / 9.3 m | 3 % / 2 % | 13 % / 13 % | 0.0 / 0.7 |
| pro | all-AI | red | 23 % / 34 % | 14 m / 6.2 m | 1.0 of 5 / 1.1 of 3 | 20 % / 26 % | 21 m / 9.3 m | 5 % / 5 % | 11 % / 7 % | 0.0 / 0.6 |
| pro | all-AI | blue | 12 % / 29 % | 14 m / 7.6 m | 0.8 of 5 / 1.2 of 3 | 14 % / 33 % | 24 m / 10 m | 2 % / 4 % | 8 % / 12 % | 0.0 / 0.8 |
| pro | regular hand | red | 26 % / 36 % | 13 m / 6.8 m | 1.0 of 5 / 1.1 of 3 | 24 % / 25 % | 18 m / 10 m | 2 % / 8 % | 4 % / 19 % | 0.0 / 0.5 |
| pro | regular hand | blue | 15 % / 27 % | 15 m / 6.6 m | 0.9 of 5 / 1.1 of 3 | 20 % / 32 % | 23 m / 9.2 m | 5 % / 2 % | 14 % / 8 % | 0.0 / 0.5 |
| allstar | all-AI | red | 22 % / 39 % | 13 m / 6.7 m | 0.9 of 5 / 1.1 of 3 | 21 % / 29 % | 20 m / 9.8 m | 5 % / 10 % | 12 % / 14 % | 0.0 / 0.6 |
| allstar | all-AI | blue | 14 % / 28 % | 13 m / 6.8 m | 0.8 of 5 / 1.2 of 3 | 15 % / 34 % | 23 m / 9.7 m | 0 % / 4 % | 7 % / 8 % | 0.0 / 1.0 |
| allstar | regular hand | red | 21 % / 40 % | 13 m / 6.5 m | 1.0 of 5 / 1.2 of 3 | 23 % / 29 % | 19 m / 9.5 m | 5 % / 8 % | 15 % / 19 % | 0.0 / 0.4 |
| allstar | regular hand | blue | 14 % / 27 % | 13 m / 6.4 m | 0.9 of 5 / 1.2 of 3 | 19 % / 36 % | 20 m / 8.6 m | 1 % / 3 % | 9 % / 9 % | 0.0 / 1.1 |

**2.3 The puck and the match (thirdjam / ours)**

| level | cell | puck loose | 4+ skaters within 5 m of the puck | puck in blue's end / neutral / red's end | live minutes a match | blue wins |
|---|---|---|---|---|---|---|
| rookie | all-AI | 68 % / 39 % | 6 % / 16 % | 28 % 44 % 28 % / 11 % 49 % 39 % | 5.0 / 1.3 | 11/20 / 18/20 |
| rookie | regular hand | 63 % / 32 % | 10 % / 17 % | 20 % 44 % 36 % / 23 % 50 % 27 % | 2.2 / 1.6 | 20/20 / 19/20 |
| pro | all-AI | 64 % / 34 % | 7 % / 16 % | 25 % 43 % 31 % / 18 % 48 % 33 % | 2.6 / 1.6 | 6/20 / 16/20 |
| pro | regular hand | 59 % / 33 % | 10 % / 15 % | 17 % 43 % 40 % / 33 % 49 % 18 % | 2.3 / 1.7 | 16/20 / 11/20 |
| allstar | all-AI | 65 % / 31 % | 8 % / 17 % | 30 % 43 % 27 % / 26 % 52 % 21 % | 2.0 / 2.0 | 6/20 / 8/20 |
| allstar | regular hand | 65 % / 29 % | 11 % / 18 % | 33 % 43 % 24 % / 33 % 50 % 17 % | 2.2 / 1.5 | 7/20 / 6/20 |

**2.3b Getting into the attacking zone (thirdjam's own figures / ours; regular hand)**

| level | side | thirdjam: carrying in its attacking third | thirdjam: a bot carry ends in shot / pass / loss | ours: entries a minute / kept 2 s or shot (regular hand) | ours all-AI: entries / kept |
|---|---|---|---|---|---|
| rookie | red | 4.2 s a match | 3.0 / 50 / 46 % | 3.1 / 72 % | 1.2 / 81 % |
| rookie | blue | 12 s a match | 7.0 / 48 / 45 % | 3.3 / 72 % | 5.6 / 55 % |
| pro | red | 8.1 s a match | 11 / 42 / 48 % | 4.2 / 67 % | 2.2 / 71 % |
| pro | blue | 14 s a match | 7.0 / 45 / 47 % | 2.4 / 69 % | 4.2 / 56 % |
| allstar | red | 11 s a match | 17 / 47 / 36 % | 4.3 / 70 % | 3.5 / 56 % |
| allstar | blue | 6.6 s a match | 6.0 / 44 / 49 % | 1.9 / 74 % | 3.1 / 54 % |

Ours does not split an entry into carried, dumped or passed; thirdjam counts no entries at all (its nearest figures
are above). Neither instrument says how each goal was scored in this round.

**2.4 The human's mates and opponents (thirdjam / ours)**

| level | hand | mates' passes to him a minute | mates' shots a minute | opponents' hits landed on him a minute | his touches a minute | first touch (median) | his carries with an opponent within 4 m (thirdjam's own figure) |
|---|---|---|---|---|---|---|---|
| rookie | newcomer | 2.4 / 3.7 | 1.1 / 0.3 | 0.9 / 2.0 | 8.0 / 6.7 in his first 60 s | 1.8 s / n/a | 59 % / see 1.1 |
| rookie | regular | 2.9 / 3.4 | 1.1 / 0.2 | 1.5 / 1.6 | 12 / 7.8 in his first 60 s | 2.1 s / n/a | 59 % / see 1.1 |
| pro | newcomer | 2.5 / 3.0 | 0.9 / 0.1 | 1.6 / 2.3 | 8.2 / 4.2 in his first 60 s | 1.8 s / n/a | 59 % / see 1.1 |
| pro | regular | 2.6 / 2.5 | 1.0 / 0.2 | 2.4 / 2.9 | 13 / 7.2 in his first 60 s | 2.1 s / n/a | 55 % / see 1.1 |
| allstar | newcomer | 2.3 / 2.2 | 0.9 / 0.1 | 1.6 / 2.1 | 7.6 / 3.4 in his first 60 s | 1.7 s / n/a | 64 % / see 1.1 |
| allstar | regular | 2.8 / 2.0 | 0.8 / 0.0 | 2.0 / 2.9 | 10 / 4.8 in his first 60 s | 1.7 s / n/a | 64 % / see 1.1 |

"Mates' passes to him": thirdjam's `passes_received` (passes seated on his blade), ours the completed passes of an AI mate
taken by b0. "His touches a minute" for ours is the mean count in his first 60 s of play (the probe counts touches there).

**What the player meets** (`media/bots_play.jpg`, the same two clips, seconds 7-18). thirdjam: the carrier has room, a
mate 20 m away level with him, a back near each net; the puck travels. Ours: three to five figures inside one face-off
circle in every frame; the puck moves a few metres between sticks that touch.

**Broken or idle behaviour, counted** (ours, 20 seeds a cell; thirdjam from the same instruments)

| | thirdjam | ours |
|---|---|---|
| Field skater still for 2 s or more, a minute per side | 0.00-0.02 (trace; a back in his crease excluded) | 0.3-1.1 |
| Scrum (4+ within 5 m of the puck), share of play | 6-11 % | 15-18 % |
| Carrier circling (held 3 s, still within 4 m of his take), a minute | not measured | red 0.3-0.6, blue 0.0-0.15 |
| Goals whose last carrier was the defending side | not measured | 15 of 509 goals (3 %) |
| Interest's own idle: opponents standing (< 1.5 m/s, no puck) | 1.3-1.8 % of their time | not measured the same way |

### 2.5 Why ours does this

- **Short safe passes.** A pass is scored only through a lane at least 0.55 safe (`data/ai.json` `pass_min_lane`,
  `scripts/ai/carrier.gd:39-40`), weighted 2.6 and boosted by pressure (`carrier.gd:43`); a pass back toward our own end or
  across our own goal mouth is never made (`carrier.gd:35-36`, `:84-109`, the own-goal guards); the support spot is 6-14 m
  from the carrier (`scripts/ai/roles.gd:112`) but in a 6.5 m spread the nearest open stick is a few metres away.
- **One-touch re-pass.** A take makes the carrier decide at once (`brain.gd:111`, `:122`, the change of carrier) and
  `_execute` releases the pass in the same frame (`brain.gd:194-221`). Nothing makes a receiver settle the puck first.
- **Mates who do not shoot.** `carrier.gd:25` (no shot by a human's mate unless `assisted()`, 240 frames after the human's
  own pass or shot, `data/ai.json` `assist_frames`), `brain.gd:192-193` (he turns away within 5 m of their net),
  `brain.gd:196-197`, `carrier.gd:71-74` (he holds 8 m out for the feed).
- **Idle.** The support spot is re-chosen only every 30 frames (`roles.gd:99-100`) and the skater brakes onto it
  (`brain.gd:262-268`); the D3 guard post is a fixed point off the net (`roles.gd:76-78`).
- **The pinned end.** At pro with the regular hand, the puck is in blue's end 33 % of play and in red's 18 % (thirdjam
  17 % / 40 %): the human's side cannot get out, because his mates neither carry it in nor shoot.

**Rules of ours that exist to move a bot metric** (the README names each; none was asked for by a person's play):

| rule | where | the metric it moved |
|---|---|---|
| Mates shoot only within 240 frames of the human's pass or shot | `carrier.gd:25`, `brain.gd:196`, `ai.json` `assist_frames` | "the idle hand won 17 of 20 against rookie" (README, "Your mates set you up"; commit `30c1372` "idle hand wins 0/20") |
| Mates never carry it into the net; hold 8 m out | `carrier.gd:71-74`, `brain.gd:192-193` | idle-hand wins, rookie seed 7, pro seeds 1 and 20 (comments in place) |
| Own-goal guards: no pass across or back toward our own mouth, no shot or dump from behind our net | `carrier.gd:35-36`, `:54-56`, `:84-109` | idle-hand wins, rookie seed 7 (comments in place) |
| No stick on a fresh carrier for 60 frames, no check for 15 | `ai.json` `fresh_frames`, `fresh_check_frames`; `brain.gd:279-281` | N3's possession median (0.8 s → 3.5 s) while keeping red's hit rate (README, five bot metrics) |
| The carrier re-decides every 7-8 frames and the moment an opponent comes inside 3.5 m | `brain.gd:102-103`, `:114-119` | N3's "pass out of pressure" and completion (README) |
| The keep-off rules tried and reverted | commit `4fcdf37` | reverted because they cut red's hit rate |

## 3. The sandbox

Round 2 (14:00).

## 4. The behaviour sheet for our bots

Round 2.

## 5. What this could not see, and the evidence index

(Round 2 completes this section; the round 1 limits and evidence follow.)

- **No person played either game for this.** thirdjam's hands are its own scripted playtester (novice, regular) and, in the
  rendered match, its measured hand; ours are `TLHand` newcomer and regular driving a bot that reads the puck's true
  position. The owner's hand is the bar; these numbers say what bots do, not what he will feel.
- **thirdjam's carrier is inferred**, not read (its trace names nobody): 70-84 % of the game's own touches are found.
  Its "loose" share and "touches per possession" carry that error; its own instrument (Interest) is quoted beside them.
- **thirdjam's pokes and cross-checks by side come from three rendered matches a level** (12, 11 and 5.9 minutes).
  Treat them as direction, not firm rates. Its checks and hits on the human come from 20 matches a level.
- **Passes in thirdjam's all-AI cells were not counted** (the commandlet does not report them); Interest's passes are
  with its playtester on the human's skater.
- **Different boxes.** 3 v 3 with goalies on 60 x 30 m against 5 v 5 without goalies on 90 x 45 m. Counts of skaters
  "within 5 m" are absolute; ours at thirdjam's rink scale is in brackets. Shares of a team ("of 3", "of 5") are given
  where the team size matters.
- **The thirdjam build is the 15 Nov one (about H40), not the submitted H47.** Its pro presser is the older one (hunt 8 m).
- **Our nine cells ran with the probe before its `pass_unseen` counter**; that counter was added for the 6-seed check
  in 2.1 only. Everything else is the same file as `probes/bots_probe.gd.txt`.

| What | Where |
|---|---|
| Our probe (test, runner, summary, tables) | `probes/bots_probe.gd.txt`, `probes/bots_run.sh`, `probes/bots_sum.mjs`, `probes/bots_compare.mjs`; raw JSON in this tree's `.tl/probe/out/<level>_<hand>/s<seed>.json` |
| thirdjam commandlet cells and the trace reader | `probes/bots_tj_cell.sh`, `probes/bots_tj_trace.mjs`; raw in `.tl/tj-run/out/<level>_<hand>/trace.txt` (TRACE and match lines) |
| thirdjam Interest (its own instrument) | `probes/bots_tj_interest.sh`, `probes/bots_tj_interest.mjs`; raw `.tl/tj-run/out/interest_<hand>/rows.txt`, `ue.log` |
| thirdjam rendered matches (events) | `probes/bots_tj_game.sh` (seeds 2 and 3: `jam.ScriptHumanSeed`), `probes/bots_tj_events.mjs`; logs `.tl/tj-run/out/game_<level>[_s2,_s3]/game.log` |
| Sheets | `media/bots_aggr.jpg`, `media/bots_play.jpg` (frames of `media/thirdjam_pro_regular.mp4` and `media/ours_pro_regular_s1.mp4`, the first teardown's clips) |
| Our clip of the all-AI match at pro (a 22 s look at the bots alone) | `.tl/clip/ours_pro_ai_s3.mp4` (tool `probes/bots_clip.sh`) |
| thirdjam's recorded results quoted | `.tl/thirdjam/status/A206.md`, `docs/experiments/CURVE-14.md`, `BRAIN.md` (n23-teardown tree) |
