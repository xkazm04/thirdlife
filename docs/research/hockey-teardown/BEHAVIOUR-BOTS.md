# Hockey behaviour teardown: the bots, and the sandbox

Lane H2 of the day shift of 23 Nov 2026. Research only: nothing in `engine/`, `foreman/`, `contracts/` or `devx/` changed.
Round 1 (landed 2e33922): sections 1-2, the bots, measured. Round 2: section 3 (the sandbox), section 4 (the behaviour
sheet a builder applies), section 5.

**The owner, 23 Nov, after the first teardown (verbatim):** "Hockey - the points you identify plays minority role. You are
focused on visual perspective where as the core of gameplay design is in behavior, which is almost untouched by your
analysis. Please do repeat it - it is about sensitivity of movement (speed, accelaration, deaccelaration),
tackles/croschecks and their reactivity, bot aggressivity and ability to play hockey, openness to sandbox the game (bring
weapons, special equipment and boosts), stick control with puck and ability for puck to stick to players"

This file answers "bot aggressivity and ability to play hockey" (round 1) and "openness to sandbox the game" (round 2).
Lane H1 answers the body, the hits and the puck.

## 0. The verdict in ten lines

1. **Our bots are not less aggressive than thirdjam's.** By the same definitions an opponent reaches our human carrier
   within 1 s in 63-78 % of his carries (thirdjam 62-72 %), and opponents try about 4 / 10 / 10 checks and cross-checks a
   minute at rookie / pro / all-star in both (1.1, 1.3).
2. **Our press is a pile.** Four or more skaters within 5 m of the puck 15-18 % of play (thirdjam 6-11 %); two of one side
   chasing the same puck 32-38 % (15-22 %); a side spread 6.5 m round its centre (13 m) (2.2, `media/bots_aggr.jpg`).
3. **Our levels are not an aggression ladder, and our rookie is easy by absence.** Our forecheck is flat out from rookie
   (two or more in the carrier's end 91 → 98 %; thirdjam 65 → 84 %), our pokes that win the puck do not rise (2.0 → 1.6 a
   minute; thirdjam 0.7 → 2.7), and our rookie is slow (0.55 of a mate's thrust) where the owner ruled a level clumsy,
   never absent (R-0067).
4. **Our puck is always somebody's, passed short and safe.** Loose 29-39 % of play (thirdjam 51-68 %); passes complete
   86-94 % at a median 2.5-5 m (thirdjam 48-60 %); blue's bots re-pass 62 % of their passes the frame they arrive.
5. **The human's mates never shoot** (0.0-0.3 a minute; thirdjam 0.8-1.1), because a rule lets them shoot only within 4 s
   of his own pass or shot; with them parked 8 m out, his side is pinned in its own end (33 % of play against 17 %).
6. **Our bots stand still** for 2 s or more 0.3-1.1 times a minute per side (thirdjam about never), and **never sprint**.
7. **Most of these gaps come from rules written to move a bot metric or stop an idle hand winning the ladder** (1.5, 2.5,
   4.2): the 60-frame stick grace, mates who never shoot, own-goal guards, one presser, the contester exempt from spacing.
8. **The sheet (section 4) gives 18 changes in order of what the player meets**: spacing and the support ring, delete the
   mates' shooting ban, rookie at full pace and clumsy by aim and poke timing, a settle time before a re-pass, longer and
   riskier passes, a hunt and a forecheck that grow with the level, sprinting, no standing. Seven are data only.
9. **Sandbox: thirdjam is the more open game.** A new boost or piece of equipment there is one cartridge JSON (a timed
   "x multiply + add" on speed, mass, reach, puck or ice); ours needs about eight files of code for any new toy kind, and
   our friction is read-only to a pack. **But neither AI understands a toy**: thirdjam keeps toys out of bots' hands;
   ours hands them to bots through a second brain (`abilities.gd`) the hockey brain never sees.
10. **First three toys: the stat layer with rocket skates as its first item, sumo pads (mass), glue blade (the puck
    sticks)** (3.4). The layer belongs in the kernel so a player's item works in any Third Life game: a contract question
    for the Director. What none of this can see: a person's hand on either game (section 5).

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

## 3. The sandbox: weapons, special equipment, boosts

The question: how open is each game to a player who brings a toy into hockey, and what would a Third Life game need so
that he can? Sources: thirdjam's `GAME.md`, `docs/VISION.md`, `modes/MODES.md`, `docs/experiments/ABILITIES.md`,
`BOOSTS.md`, `contracts/RULINGS.md`, its sim and AI code; ours: `engine/packs/hockey` (`README.md` "Crazy modes",
`data/modes/*.json`, `data/boosts.json`, `scripts/modes.gd`, `boosts.gd`, `abilities.gd`), `engine/kernel/API.md`,
`docs/SHARING.md`. Paths marked TJ are relative to the thirdjam clone; the rest to `engine/packs/hockey/` unless they start
with `engine/` or `docs/`. Read, not played: no toy was tried with a hand in this lane.

### 3.1 What thirdjam has

| toy | what it does | where |
|---|---|---|
| **Abilities on F** (one at a time, from a mode or a pickup) | **shotgun**: the next shot leaves at 1.5 x and knocks down everyone within 1 m of its path; **hip check**: lands from a standstill, the victim stays down 1.5 x longer and is pushed 3 m; **shield**: no check or stick lift lands on you for 360 frames; **slow puck**: the next pass or shot leaves at 0.5 x and wakes up after 120 frames | TJ `Game/Source/JamCore/Private/JamSim.cpp:40-47` (names), `:4455-4468` (defaults), `:4502-4534` (`TryAbility`), `:4536-4590` |
| **Pickups (built-in effects)** | speed (skate speed and acceleration 1.5 x), precision (aim cone 2 x), heavy puck (drag 2 x, top speed 0.5 x), big puck (radius 1.5 x), reverse other (the other team's speed and turning halved) | TJ `Game/Content/Designer/builtin-effects.json` |
| **Custom effects (data only)** | a cartridge may declare up to 12 effects: a timed set of "x multiply + add" changes to a named stat, aimed at self, own team, other team, everyone, the puck or the rink, fired by a pickup, a goal, a landed or received check, a period start, a zone, or the Director | TJ `Game/Source/JamCore/Effects/JamEffectTypes.h:51`, caps 0.25-4 x at `:107-109`; stats enum `Public/JamModifiers.h:14-33` |
| **Zones, obstacles, rule hooks** | zones slow ice, fast ice, bumper, no shoot, boost only; obstacles box, pillar, bumper, goal shield; hooks add score, score multiplier, shrink or grow the rink, set a parameter, spawn a pickup, swap nets | TJ `JamSim.cpp:510-550` |
| **Director's Call** | change one tunable live, once a period | TJ `JamSim.cpp:552` (`SetParam`), `:348` (`ApplyLiveConfig`) |
| **Modes with toys** | Arsenal (pickups in a 70 x 14 m zone; all four abilities from pickups), Shotgun (on F, 1200-frame cooldown), Outnumbered (shield on F, 3 v 5), Glow Ice (neon, speed pickup), Cage (pillars), plus seven data-only modes (Bruisers, Fog of War, Marathon, Pond, Power Play, Sniper, Sudden Death) | TJ `modes/`, `modes/MODES.md` |

**Who owns the body and the puck.** The sim does (`UJamSim`). Base values are in `FJamGameConfig` (TJ
`JamCartridge.h:666-683`): skater speed, acceleration, mass, lateral grip (`:50-56`); puck radius, top speed, drag
(`:290-292`); ice friction, board restitution (`:32-33`); shot reach (`:313`). Each frame the sim takes
`base x product + sum` of the active effects (`JamModifiers.h:3`, `GetEffectiveStat` at `JamSim.cpp:480`) for skater
speed (`:1337`), skater mass (`:2537`, `:2588`, `:2610`), shot reach (`:868`), puck radius (`:918`, `:1668`), puck drag
(`:3022`, `:3141`) and ice friction (`:1345`, `:3189`). **So an item can change speed, mass, the puck and the ice at run
time from data alone.** The gap: stick reach (`Stick.ReachM`) is not a stat; a "long stick" needs code.

**Does its AI understand a toy?** Barely. Pickups are in the bots' view (TJ `AI/JamSimAdapter.cpp:236-250`); only all-star
bots detour for one within 8 m, never while carrying, and they do not read its kind (`AI/JamAICore.cpp:874-889`,
`JamAICore.h:758`). Bots steer round slow ice (`JamAICore.cpp:1823-1833`). **Bots never hold an ability**
(`JamSim.cpp:232-237`; "the brain never does" press F, `JamAICore.h:78`). The brain does not read active effects.

**To add one toy in thirdjam:**
- *A new stat-change toy (most boosts and equipment):* **one file**, a cartridge JSON (`game.effects[]` plus a pickup
  whose kind is the effect's id). Nothing compiles.
- *A new stat an effect may touch* (for example stick reach): `Public/JamModifiers.h:14-33` (enum), `:86-108` (name),
  `:121-143` (range), `:146`; the place in `JamSim.cpp` that reads it through `Eff()`; `schema/limits.json:215` and
  `schema/game.schema.json` about `:1629-1660`, then the schema generator.
- *A new ability (a behaviour, not a number):* `schema/game.schema.json:1537-1541`, `schema/limits.json:204`,
  `schema/DEFAULTS.md:169-170`, `schema/README.md:164`, `validate.mjs`; `JamSim.cpp:40-47`, `:4455-4468`, `:4502-4534`
  and the site it acts at (shot `:2850`, check `:2403` / `:2730`, puck `:4060-4080`); `Effects/JamPickupActor.cpp:438`,
  `:707`; `JamGame/Private/HUDGoalBanner.cpp:127`; `JamGame/Private/EffectsBinder.cpp:223`; `AI/JamPlaytester.cpp:814-845`;
  `JamNet/Private/JamNetPackets.cpp:327-360`; `abilities.commentary.json`; `JamAbilityTests.cpp`, `Tools/gen-parity.mjs`,
  `tools/fuzz/gen.mjs:307`, `:391`. About 15 files.
- *A new mode from existing toys:* a file in `modes/`, its slug in `UJamMenuFlow::ModeCards`
  (`JamGame/Private/MenuFlow.cpp:322-340`), its line in `tools/playtest/modes.mjs`.

**What the owner ruled** (TJ `contracts/RULINGS.md`, verbatim where quoted):
- R-0012: "let players design custom boosts, rules and aspects".
- R-0036 (3): "modes that change the character of a match (cartridge-defined, chosen from the menu as a Director's cut:
  rules, rink, team size, physics, bots, look) so a player makes creative variations without editing JSON".
- R-0041: "Director's mode then can produce via boosts fun aspects like one-shot shotgun, binding special abilities to
  'F' key. This can make whole concept of the game more raw and brutal promoting into its brand"; ruling (3): abilities on
  F, each "a cartridge-defined key under `game.abilities[]`, unknown keys errors, with a bark and a HUD slot".
- R-0043 (3): "no new mechanic after A84's abilities" (a freeze before submission, not a design rule).
- R-0059 (2): the whistle leaves every mode but Glass House.
- R-0064, his point 4: "Special boosts are not seen on ice, not seen equipped on players"; ruling (6): "Boosts are seen ...
  on the ice ... and on the skater who carries one".
- R-0069 point 4 is about the MODES screen only: a list of names on the left, sorted, the chosen mode's picture on the
  right, never stretched.

### 3.2 What ours has

| toy | what it does | where |
|---|---|---|
| Timed boosts (pickups) | speed (skate speed and acceleration 1.5 x), precision (a shot within 30 deg is turned onto the goal), big puck (`TLBall.set_radius` x 1.5), heavy puck (`linear_damp` 0.8, top speed x 0.5) | `scripts/boosts.gd:212-224`, `:232-237`, `:240-249`, `:110-118`, `:129-131`; numbers `data/boosts.json:7-16` |
| Abilities (thirdjam's four, its numbers) | shotgun, hip check, shield (through `hits.immune`), slow puck | `scripts/abilities.gd:94-116` (use), `:171-215` (shotgun flight), `:237-260` (release), `:268-297` (hip check) |
| Crazy modes | arsenal (beacons in 3 zones, 8 kinds by weight, abilities from pickups), shotgun (on F, cooldown 1200), glow (neon look) | `data/modes/arsenal.json:6-19`, `shotgun.json:5`, `glow.json:5`; a mode is crazy when it has pickups, abilities or neon (`scripts/modes.gd:85-86`) |
| Classic modes | outnumbered (3 v 5), sudden death, pond (no checks, no goalies), big ice (80 x 40) | `data/modes/*.json`, list at `data/tuning.json:50` |
| The rule dial | four dials once a period, both teams | `scripts/dial.gd:55-64` |

The L5 port of 21 Nov (`docs/shifts/2026-11-21-day/lanes/L5-crazy/BRIEF.md:11-22`) took thirdjam's four abilities,
four of its five pickups, the beacons, the holder's ring and the three toy modes. **It left out the custom effects layer**
(any stat, any target, any trigger), reverse other, rule hooks, zones, obstacles, the Director's Call and the other nine
modes.

**Who owns the body and the puck.**
- Speed: `scripts/skate.gd:165-191` rewrites each skater's `skate_speed` and `skate_accel` every frame; a boost multiplies
  after it because `crazy.post` runs after `api.apply_speeds` (`scripts/main.gd:500-501`).
- Mass: `TLBiped.body_mass`, set at `main.gd:265`, read live by the hits (`scripts/hits.gd:394`, `:420`, `:475`). Writable;
  no toy changes it.
- Reach: one pack-wide number, `rink_api.gd:17` (set `:88`, checked `:167-168`), and `poke_reach` beside it. Writable, but
  the same for everybody: a per-skater reach needs code.
- Puck: `TLBall` (`main.gd:224-226`); radius (`set_radius`, `engine/kernel/API.md:245`), `max_speed`, `linear_damp` change
  at run time. **Ice and puck friction do not**: the kernel's material tables are read-only for packs
  (`engine/kernel/API.md:124-130`). `TLBiped` setters for speed, acceleration, grip, turn rate and mass: `API.md:272`.

**Does our AI understand a toy?** The brain does not know toys exist: nothing in `scripts/ai/*.gd` mentions pickup,
ability, boost, crazy or mode. The toys drive the bots **around** the brain, from `scripts/abilities.gd`: every outfield
skater gets the mode's ability, bots included (`:54-62`); bots use it (`bot()`, `:300-319`, called `:160-165`,
`:356-358`) and fire an armed shotgun or slow puck on release (`:244-247`); a free bot turns aside for a pickup within
2.5 m, or 8 m when three or more are on the ice (`:322-341`); bots take pickups (`boosts.gd:197-207`). So two brains steer
one body, and the hockey brain never knows that the man it is about to check is shielded or twice as fast.
Opposite of thirdjam, where bots never hold an ability.

**To add one toy in ours:**
- *A new mode from existing toys:* data, three files: `data/modes/<id>.json`, its id in `data/tuning.json:50`, and the mode
  param's max in `pack.json:158`. Unknown keys are refused (`scripts/modes.gd:5-6`, `:42-142`).
- *A new pickup or ability kind (any new toy):* code, about eight files: `scripts/modes.gd:11` (pickup kinds) or `:13`
  (ability kinds); `scripts/boosts.gd:3-8` (fields), `:49` (colours), `:212-224` (what a take does) plus an apply function;
  `data/boosts.json:7-16`; `scripts/abilities.gd:72`, `:94-116`, `:237-260`, `:300-319` (bot use), `:390` (HUD word);
  `gen/crazy_hook.gd:40-62` (beacon shape); a new `tests/crazy_<toy>.gd` registered in `pack.json:78-83`.
- *Shared between players:* not possible today. `docs/SHARING.md` has no toy or mode item kind; the only data-only kind
  near it is `tuning` (`:21`), and anything with a script is `code` tier, not shareable until an isolation boundary exists
  (`:8-10`; `engine/kernel/API.md:947-949`).

### 3.3 What a Third Life game needs so a player can bring a toy

1. **A stat layer the toy speaks to, owned below the game.** thirdjam's one good idea: an item is data, a timed
   "x multiply + add" on named stats (speed, acceleration, mass, turn, grip, reach, shot speed, puck radius, puck drag,
   ice friction), aimed at self / team / opponents / everyone / the ball, fired by pickup, by key, by a hit given or taken.
   In Third Life it belongs in the kernel (a `TL*` modifier stack on `TLBiped` and `TLBall`), so a player's item works in
   hockey and in any other game that has bodies and a ball. Ours has the setters (`API.md:245`, `:272`) but no stack: each
   toy writes the number itself and the next frame's `skate.gd` rewrite has to be fought with run order (`main.gd:500-501`).
   **Kernel**; a contract question for the Director (an item schema in `contracts/`).
2. **Every number the toy can touch must be per body and read live.** Mass and speed already are. Reach is one pack-wide
   number (`rink_api.gd:17`); friction is read-only (`API.md:124-130`). **Pack code** (reach per skater) and **kernel**
   (friction or a drag zone a pack may set).
3. **The game must say which stats an item may touch, and by how much** (thirdjam caps 0.25-4 x). In ours, a declared
   list in `pack.json` or `data/` (unknown stats are errors, as every key is). **Pack data plus a kernel check.**
4. **The AI must read the stats, not the toy.** The brain should see, per skater, his live speed, mass, reach and shield
   (one more field in `sense.record`, `scripts/ai/sense.gd`), and its rules must use them: check a man only when your
   mass x closing beats his (the hits already decide by "momentum against stability", `hits.gd:394-420`); give a faster
   carrier more room (contain deeper); never check a shielded man; poke less at a sticky carrier (free: `poke_odds` is
   already read, `brain.gd:288`); go for a pickup by what it gives, not because it is near. And **one brain**: the item
   use now in `abilities.gd:300-341` moves into the carrier's and the presser's choices (`carrier.gd`, `brain.gd:_contact`),
   so the toy is a hockey decision. Without this a toy is noise: bots run into the sumo and bounce, and nobody plays round it.
5. **The toy must be seen** (R-0064): on the ice before it is taken and on the body that holds it, by the figure itself
   (R-0070: no rings or plates as the only message).
6. **A level must stay a level.** thirdjam keeps toys out of the bots' hands; ours gives them to everybody. For a player
   who brings his own item, the opponents should get toys only in a mode that says so.

### 3.4 Toys ranked by fun per cost (ours, after 3.3.1 exists unless the cost says otherwise)

Fun is judged from the owner's words ("raw and brutal ... its brand", R-0041; "beating massacre" on hard levels, R-0041;
"stick control with puck and ability for puck to stick to players", 23 Nov). Cost: XS = data only, S = a day of pack
code, M = pack code plus AI rules, L = kernel. Not built, not played.

| rank | toy | kind | what it does | touches | AI must know | cost |
|---|---|---|---|---|---|---|
| 1 | **Rocket skates** | equipment | speed and acceleration 1.5 x for 8 s; turning x 0.8 | exists as the speed boost; as an item: data on the stat layer | contain a fast carrier deeper; chase the man, not the spot | XS (S before 3.3.1) |
| 2 | **Sumo pads** | equipment | mass 2 x, top speed x 0.85: you win every body check, you turn like a bus | `TLBiped.body_mass` (writable, read live by `hits.gd`) | do not body-check a heavier man; poke him instead | S |
| 3 | **Glue blade** | equipment | the puck sticks: pokes against you at 0.4 x odds, the carry never loses it on a sprint turn | `scripts/poke.gd` odds factor, `carry.gd` dangle loss | nothing new: bots read `poke_odds` (`brain.gd:288`); they should switch to the body | S |
| 4 | **Shotgun shot** | weapon | exists (ability) | `abilities.gd` | already used by bots; the brain should aim it at a lane of bodies | XS |
| 5 | **Snowball launcher** | weapon | a key throws a slow projectile; whoever it hits stumbles 30 frames | the shotgun's flight code (`abilities.gd:171-215`) with a new release; the hits' stumble | dodge (sidestep a projectile in flight); throw at the carrier | M |
| 6 | **Shield** | equipment | exists (ability) | `abilities.gd`, `hits.immune` | never check a shielded man (today bots do) | XS |
| 7 | **Long stick** | equipment | reach and poke reach 1.5 x | per-skater reach (`rink_api.gd:17` is pack-wide) | pressure and poke from farther | S-M |
| 8 | **Big puck** | boost | exists | `boosts.gd:110-118` | none | XS |
| 9 | **Hex on the other team** (thirdjam's reverse other) | boost | the other team's speed and turning halved for 5 s | stat layer, team target | press harder while it lasts | S |
| 10 | **Ice-freeze trap** | weapon | drop a 4 m patch of slow ice | friction is read-only for packs: a drag zone needs kernel or a per-body drag in the pack | steer round it (thirdjam's bots do) | L |
| 11 | **Pinball bumpers** | arena | bumpers that kick bodies and puck | venue code, kernel physics | play the bank | M |

**The first three to build.**
1. **The stat layer with rocket skates as its first item** (rank 1 plus 3.3.1-3.3.3). The toy is nearly free; the layer is
   what makes every later toy data, and it is the only one of these that turns "bring an item" into something a player
   can do without code. Kernel plus a contract: Director's call.
2. **Sumo pads** (rank 2). It turns the hits the owner asked to be the brand into a choice: what you wear decides who
   falls. One number on a body that is already read live; the AI rule "do not check a heavier man" is the first toy-aware
   rule and teaches the brain to read stats.
3. **Glue blade** (rank 3). It answers his "ability for puck to stick to players" as a thing you can wear, and the AI
   already reads the poke odds it changes.

The shotgun, shield and big puck already exist; they need the AI rules of 3.3.4, not more code.

## 4. The behaviour sheet for our bots

What a hockey behaviour pass should apply so our bots press and play at least as thirdjam's do. Ordered by the expected
effect on what the player meets. Paths are under `engine/packs/hockey/`. "data" = a value in `data/ai.json` or
`data/levels/<level>.json` (a level file's `"ai"` block overrides `ai.json` for red only, `scripts/ai/brain.gd:53-54`);
"pack code" = GDScript in `scripts/ai/`; a new key must also be added to `KEYS` (`brain.gd:4-6`), or `ai.json` refuses it.
"kernel" = outside the pack. Figures "now" are this file's tables (20 seeds a cell); "target" is thirdjam's measured figure,
moved to our rink where the box matters. **[m]** marks a number in metres or m/s on our present box (60 x 30 m rink,
bodies 1.76 m wide, cruise 8-9 m/s): if lane H1's body scale or speeds land, re-derive it by the same factor (a length by
the rink or body factor, a closing speed by the skate-speed factor). Frame counts and shares need no re-deriving.

How to check each line: copy the pack to `.tl/`, add `probes/bots_probe.gd.txt` as `tests/bots_probe.gd` (and to
`pack.json` `tests`), run `probes/bots_run.sh <level> <hand> 20` for the nine cells, then `probes/bots_sum.mjs` and
`probes/bots_compare.mjs` (the thirdjam summaries it reads are kept, section 5).

### 4.1 The sheet

| # | what the player meets | rule or number (where) | now | target or replacement | type | figure it moves: now → target |
|---|---|---|---|---|---|---|
| 1 | **The pile** | separation from mates: `TLSteer.separate(me, mates, 4.0) * 1.2` (`brain.gd:260`), skipped by the contest role (`brain.gd:254-255`) | radius 4.0 m, weight 1.2, contester exempt | radius **6.0 [m]**, weight **2.5**; the contester keeps it from mates other than the carrier; plus thirdjam's split rule (`SplitClump`, `JamAICore.cpp:633-664`; 1.5 m and 3 m on its 0.8 m bodies): two mates within **2.5 [m]** for 45 frames both steer to **5 [m]** apart | pack code | two of one side within 5 m of the puck 32-38 % → **≤ 22 %**; 4+ skaters within 5 m 15-18 % → **≤ 10 %** |
| 2 | The pile | support spot ring (`scripts/ai/roles.gd:112`, `:116`: `d < 6 or d > 14`; ideal 6-9) | 6-14 m from the carrier | **9-18 [m]**, ideal 10-13; and never within **5 [m]** of the chaser or the carrier (thirdjam keeps support `MinSeparation` from the chaser, `JamAICore.cpp:1150-1155`) | pack code | mates' distance to their carrier 8.6-10 m → **≥ 13 [m]** (thirdjam 18-24 m x 60/90); side spread 6.2-7.6 m → **≥ 9 [m]** (thirdjam's 13 m at rink scale). In body widths thirdjam's spread is 16 (13 m / 0.8 m), ours 3.7; at our 1.76 m bodies no spread on a 30 m wide rink reaches 16 widths: that part needs H1's scale |
| 3 | **Mates who never shoot** | `carrier.gd:25` `(not feed or b.assisted())`; `brain.gd:196` `or (team == "blue" ... not assisted())`; `ai.json` `assist_frames` | a human's mate shoots only within 240 frames of the human's own pass or shot | **delete** the assisted() condition at both places and the key | pack code + data | mates' shots 0.0-0.3 a minute → **0.8-1.1** (thirdjam) |
| 4 | Mates who never shoot | `carrier.gd:71-74` (mate carries to 8 m out and holds "for the feed"); `brain.gd:192-193` (mate turns away within 5 m of their net) | on | **delete both** | pack code | the pinned end: puck in blue's end at pro, regular hand 33 % → **≤ 20 %** (thirdjam 17 %); red's end 18 % → **≥ 35 %** |
| 5 | Feeding the human | `ai.json` `feed_bonus` (`carrier.gd:44-45`) | +0.4 to a pass to the human, all levels | thirdjam's rule (`JamAICore.cpp:1686-1733`): when the human is open ahead, pass to him in **0.6 / 0.4 / 0.2** of the chances at rookie / pro / all-star; drop `feed_bonus` | pack code | mates' passes to him 2.0-3.7 a minute → **2-3**, falling with the level (thirdjam 2.3-2.9) |
| 6 | **Rookie easy by absence** | `levels/<level>.json` `ai.red_skill`, applied to thrust at `brain.gd:137` | 0.55 / 0.795 / 0.83 (of a mate's 0.9) | **1.0 / 1.0 / 1.05** (thirdjam: rookie pace floor 1.0, `DifficultyProfile.cpp:67`) | data | red mean speed at rookie 4.9 m/s → **the mates' 5.9-6.0** (re-measure with a speed counter) |
| 7 | Rookie clumsy, not slow | `levels/<level>.json` `ai.reaction_frames`, `aim_sigma_deg`, `shoot_min_xg` (new override per level) | 18 / 12 / 7 frames; 6 / 4 / 2.5 deg; xG 0.15 all | reaction **10 / 7 / 5**; aim **8 / 4 / 2** deg; `shoot_min_xg` **0.25 / 0.15 / 0.08** (rookie shoots only from close, all-star from anywhere; thirdjam shot reach +10 / pro / +60 m) | data | opponents' shots 2.3 / 4.0 / 4.4 a minute → **2.5 / 3.8 / 6-7**; at all-star half or more from beyond **13 [m]** (thirdjam three in four beyond 20 m, x 60/90) |
| 8 | **One-touch ping-pong** | none: a take re-decides at once (`brain.gd:111`, `:122`) and `_execute` releases the same frame (`brain.gd:194-221`) | 62 % of blue's passes re-passed the frame they arrive (rookie all-AI, 6 seeds) | new key `settle_frames` **10**: no pass or dump within 10 frames of a take unless it is a one-timer (`api.from_pass` and `one_timer_after`) | pack code | same-frame re-pass 62 % → **≤ 5 %**; re-passed within 15 frames ≤ 11 % (thirdjam's PASSQ 0-11 %); blue's passes in the all-AI rookie match 45 a minute → **10-20** |
| 9 | **Short safe passes** | `ai.json` `pass_min_lane`, `pass_weight` (`carrier.gd:39-43`) | 0.55; 2.6 | **0.35; 1.8** | data | completion 86-94 % → **60-75 %** (thirdjam 48-60 %); passes completed over 6 m 13-31 % → **30-40 %**; completed pass median 2.5-5.3 m → **≥ 7 [m]** |
| 10 | Short safe passes | own-goal guard, back-pass and corner branch (`carrier.gd:97-108`) | no pass back toward our own end whose miss would slide into our net or off the corner boards within 12 m | **delete** this branch; keep the guard on a pass across our own mouth (`carrier.gd:91-96`) | pack code | back passes possible again (Interest-style "back to the passer" share > 0); goals with the defending side's last carrier 3 % → **≤ 5 %** (watch) |
| 11 | **The stick, by level** | `ai.json` `fresh_frames` (`brain.gd:279-280`) | no stick on any fresh carrier for 60 frames, all levels | per level (level `ai` block): **20 / 6 / 0** frames (thirdjam pokes after 14 / 2 / 0 frames in reach, `DifficultyProfile.cpp:71`, `JamAICore.h:574`, `DifficultyProfile.cpp:97`) | data | pokes that take the puck 2.0 / 1.7 / 1.6 a minute → **0.7 / 1.8 / 2.7** (thirdjam, three matches a level); all-AI pokes tried 0.4-0.5 → **≥ 2** |
| 12 | The stick, by level | `cross_min_closing` in `levels/rookie.json` | 2.0 (rookie cross-checks 0.8 landed a minute) | **99** (never at rookie; thirdjam's rookie never lifts) | data | rookie cross-checks landed 0.8 → **0** |
| 13 | **The hunt** | none: only D roles act on the carrier (`brain.gd:232-234`); D2 and D3 only inside 5 m (`:276`); pokes and cross-checks only by D1 (`:286`, `:288`) | one presser | new key `hunt_m` per level **0 / 6 / 20 [m]** (thirdjam 0 / 8-11 / 30 m x 60/90): the nearest non-D1 defender within it goes at the carrier and may poke and cross-check (open `:286`, `:288` to him) | pack code | an opponent within 2.3 m inside 1 s of the human's take: keep **63-78 %**, rising with the level; "never reached" for the human: keep **12-23 %** |
| 14 | **The forecheck, by level** | none: roles by arrival time (`roles.gd:25-45`) send whoever is nearest | two or more in the carrier's end 91 / 95 / 98 % | new key `forecheck_men` per level **1 / 2 / 2** and a share **1.0 / 0.6 / 1.0** for the second: the rest hold at their own side of the carrier's blue line (`roles.gd:56-74` `safety` already computes a high spot) | pack code | forecheckers 2.0-2.2 of 3 → **1.2 / 1.4 / 1.6 of 3** (thirdjam 2.0 / 2.3 / 2.7 of 5); two or more **65 / 77 / 84 %** |
| 15 | Checks by level | `levels/<level>.json` `check_min_closing_red` | 9.5 / 3.0 / 2.6 [m/s] | **6 / 2 / 2 [m/s]** (thirdjam `DifficultyProfile.cpp:59`, `:114`; pro 1) | data | checks + cross-checks tried 3.8 / 9.4 / 10 → about **4.5 / 11 / 11** (thirdjam) |
| 16 | **Nobody sprints** | none in `scripts/ai/`; `skate.pace(i, held, move)` (`scripts/skate.gd:136-144`) takes a held flag for any slot | bots never sprint | new key `sprint_share` per level **0.2 / 0.35 / 1.0** (thirdjam `DifficultyProfile.cpp:58`, `JamAICore.h:588`, `DifficultyProfile.cpp:101`): a chaser, a hunter or a back-checker sprints in that share of his chases, stamina allowing; a defender's sprint stays faster than a carrier's (R-0045 law 4) | pack code | opponents faster than half top speed (thirdjam 73 / 77 / 84 % of their time): measure ours the same way first |
| 17 | **Bots standing still** | support spot re-chosen every 30 frames (`roles.gd:99-100`); brake onto the spot (`brain.gd:262-268`); D3 guard post fixed (`roles.gd:76-78`) | 30 frames; brakes to a stop | re-choose every **10** frames; brake only above **3 [m/s]**, then glide and turn to face the puck; the guard post follows the puck's z by 0.5 instead of 0.3 | pack code | still 2 s or more 0.3-1.1 a minute per side → **under 0.05** (thirdjam 0.00-0.02) |
| 18 | The human's first touch | `ai.json` `yield_frames` (`brain.gd:278`) | 45 frames nobody touches the human after he takes it | **30** (thirdjam's sim gives every taker 30, `JamCartridge.h:202`) | data | hits landed on him 1.6-2.9 a minute: keep **1.5-2.5** |

### 4.2 Rules to delete (they serve a bot metric or the idle-hand ladder)

| rule | where | why it exists | what deleting it risks |
|---|---|---|---|
| Mates shoot only within 240 frames of the human's pass or shot | `carrier.gd:25`, `brain.gd:196-197`, `ai.json` `assist_frames` | "the idle hand won 17 of 20 against rookie" (README; commit `30c1372`) | the idle hand wins rookie again; the human's mates score his goals and he feels a passenger. Answer with line 5 (feed him by level), not by benching them. The ladder is set last (R-0067) |
| Mate holds 8 m out for the feed | `carrier.gd:71-74` | idle-hand win, rookie seed 7 | as above |
| Mate turns away within 5 m of their net | `brain.gd:192-193` | idle-hand wins, pro seeds 1, 20 | a mate's blade puts it in; that is a goal, which is hockey |
| Back-pass and corner-carom own-goal guard | `carrier.gd:97-108` | idle-hand win, rookie seed 7 | an own goal now and then (3 % of goals today have the defending side's last carrier); watch it, keep the mouth guard `:91-96` |
| One fixed stick grace for every carrier | `ai.json` `fresh_frames` 60 | N3's possession median 0.8 → 3.5 s with red's hit rate kept | possession median falls (it was 0.8 s with pokes at 54-77 % of turnovers before N3); per-level values (line 11) keep rookie gentle |
| Keep-off rules reverted for the hit rate | commit `4fcdf37` | they cut red's hits | not a rule to delete but a decision to reverse: line 1 will lower red's body checks a little; lines 13 and 15 bring the hits back where the hockey is |

Keep: the carrier's pass out of pressure (`brain.gd:102-103`, `:114-119`); it was tuned to a metric, but it is
thirdjam's rule too (a pass when an opponent arrives inside 0.6 s or 5 m, `JamAICore.cpp:671-684`).

### 4.3 Ordering and what to build first

Lines 1-5 change what the player sees in the first ten seconds (no knot round the puck, mates who go to the net and
shoot). Lines 6-7 and 11-16 are the level ladder: build them together and set the ladder last, through a person's hand.
Lines 8-10 change the rhythm of the puck. Lines 17-18 are polish. Data lines (6, 7, 9, 11, 12, 15, 18) can land in an hour
and be measured with the probe; pack-code lines need a test each. Nothing here is kernel; the sandbox's stat layer (3.3.1)
is.

## 5. What this could not see, and the evidence index

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

- **The sandbox was read, not played.** No toy was tried with a hand or measured in either game in this lane; the fun
  ranking in 3.4 is judgement from the owner's words, the costs from the files one would touch.
- **The behaviour sheet's targets are thirdjam's measured figures moved to our box**, not proven on ours: nothing in
  section 4 was built or run. Each line names the figure to re-measure with the same probe.
- **No bot speed was measured with these instruments**; speeds quoted are N1's probe of 22 Nov (`media/probe.md`) and
  thirdjam's own "fast" share (Interest). Line 16 of the sheet asks for that measure first.
- **Raw thirdjam data was deleted to free disk** (the Director's order): the per-frame traces (about 1.3 GB), the copied
  runtime and the Interest editor logs. Kept: each cell's per-match lines (`matches.jsonl`), the summaries (`sum.json`),
  the Interest rows (`rows.txt`), the rendered matches' logs and `events.json`. The tables cannot be re-derived from the
  kept files alone; re-run `probes/bots_tj_cell.sh` (about 2 minutes a cell) against a copy of the build.

| What | Where |
|---|---|
| The one-touch check (6 seeds, rookie all-AI, with `pass_unseen`) | `.tl/probe/out_chk/rookie_ai/` (re-run 10:30 after a clean-up: the same 230 of 370) |
| Our probe (test, runner, summary, tables) | `probes/bots_probe.gd.txt`, `probes/bots_run.sh`, `probes/bots_sum.mjs`, `probes/bots_compare.mjs`; raw JSON in this tree's `.tl/probe/out/<level>_<hand>/s<seed>.json` |
| thirdjam commandlet cells and the trace reader | `probes/bots_tj_cell.sh`, `probes/bots_tj_trace.mjs`; kept in this tree's `.tl/tj-run/out/<level>_<hand>/sum.json` and `matches.jsonl` (traces deleted) |
| thirdjam Interest (its own instrument) | `probes/bots_tj_interest.sh`, `probes/bots_tj_interest.mjs`; kept `.tl/tj-run/out/interest_<hand>/rows.txt`, `sum.json` |
| thirdjam rendered matches (events) | `probes/bots_tj_game.sh` (seeds 2 and 3: `jam.ScriptHumanSeed`), `probes/bots_tj_events.mjs`; logs `.tl/tj-run/out/game_<level>[_s2,_s3]/game.log` |
| Sheets | `media/bots_aggr.jpg`, `media/bots_play.jpg` (frames of `media/thirdjam_pro_regular.mp4` and `media/ours_pro_regular_s1.mp4`, the first teardown's clips) |
| Our clip of the all-AI match at pro (a 22 s look at the bots alone) | `.tl/clip/ours_pro_ai_s3.mp4` (tool `probes/bots_clip.sh`) |
| The sandbox scout (round 2 notes with file:line) | `.tl/round2_scout.md` |
| thirdjam's toy sources | TJ `Game/Content/Designer/builtin-effects.json`, `modes/MODES.md`, `docs/experiments/ABILITIES.md`, `BOOSTS.md`, `contracts/RULINGS.md` (R-0012, R-0036, R-0041, R-0043, R-0059, R-0064, R-0069) |
| thirdjam's recorded results quoted | `.tl/thirdjam/status/A206.md`, `docs/experiments/CURVE-14.md`, `BRAIN.md` (n23-teardown tree) |
