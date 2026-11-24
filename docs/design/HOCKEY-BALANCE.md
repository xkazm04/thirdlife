# hockey.thirdlife: the design of a hockey worth mastering (lane K8, night of 23-24 Nov 2026)

**Status: unplayed.** Nobody has played `hockey.thirdlife`. Every figure here is from a scripted or a planning hand (named each
time), never from a person. Nothing on this page can tell whether the game is fun; the owner's hand decides that. What this
page promises is narrower: that every change from thirdjam is deliberate, has a written reason, was measured before and after,
and comes with one line saying what he will feel.

What this is: the design that `hockey.thirdlife` is balanced toward, written before any number was changed. thirdjam
(`hockey.regular`) stays as it is, playable beside it. Sources: the owner's rulings (`docs/research/hockey-teardown/RULINGS.md`,
quoted with their R number), thirdjam's play as measured (`docs/research/hockey-teardown/PLAY.md`, "PLAY"), proven arcade
hockey (`docs/design/CASES.md` case A: NHL '94, NHL Hitz, Blades of Steel), the method (`docs/design/METHOD.md` sections 1-8a).
The experiments and their figures: `engine/cores/rink/lab/experiments/LEDGER.md`. Frames are at 60 a second.

## 1. The fantasy

**"I make the play. I keep the puck off their sticks, move it faster than they can skate, and finish with a shot I made room
for. When they have it, I take it back with a stick or a hit that I chose to throw."**

Aesthetics (METHOD 4): challenge and sensation. The player is a playmaker first and a hitter second: the owner asked for
both ("incentivize passing with other players", R-0041; "tackles and cross-checks can be vital for fun gameplay", R-0041), and
the order is his own from the first playtest: "The stick is the core verb" (R-0013).

## 2. What thirdjam plays like today (the measured meaning of "mediocre")

The owner: "a mediocre hockey game we delivered but at least it has set basic gameplay mechanics, AI, bugless graphics and
balanced speed". PLAY measured it with thirdjam's own scripted hands; this lane measured it again with a hand that plans
(section 7). Where the two agree, the finding is the game's. Where they disagree, it was the hand's.

| What a player runs into | thirdjam's regular hand, pro (PLAY) | the planning hand, regular, pro | Whose finding |
|---|---|---|---|
| Wins | 75.5 % | 77 % | (the calibration point) |
| Goals he walks over the line, a match | 0.54 of 2.02 | 0.33 of 2.27 | the game's |
| A carry lasts | 0.82 s | 0.68 s | the game's |
| Carries that end on an opponent's stick | 39 % | 38 % | the game's |
| Takes off a carrier with no key pressed | (gym: 20 of 20 head on) | 4.4 a minute of 8.3 | the game's |
| Knocked down, a match; seconds on the ice | 5.6; 11.2 s | 4.0; 8.0 s | the game's |
| One-timers, a match | 0.1 | 0.22 | the game's |
| Rookie: novice / regular / good | 97.5 / 100 / 100 % | 99 / 100 / 100 % | the game's |
| Passes that reach a team-mate | 38 % | 58 % | half the hand's: a hand that reads the lane completes 20 points more, and it is still only 58 % |
| Wins without the pass | +9 points | +8 points (±7, 60 seeds) | the game's: the pass does not pay either hand |
| Pro: novice / regular / good | 24.5 / 75.5 / 76 % | 55 / 77 / 97 % | **the hand's**: PLAY's "skill stops showing above the regular hand" is the script's ceiling, not the game's |
| All-star: novice / regular / good | 10.5 / 39.5 / 53.5 % | 29 / 69 / 77 % | the hand's in level, the game's in order |

(Planning hand: 100 seeds a cell, seeds 1-100, `.tl` raw deleted, table in the lane's round notes. thirdjam's hands: PLAY section 3, 200 seeds.)

## 3. The pillars

Each is a feeling, names what it rules out, and is tied to the owner's words, to a proven game and to a measured fault.

**P1. The puck is yours until someone takes it with a key.** With the puck I have a second to look up. I lose it to a poke
I left it open to, a stick lift I let him reach, or a hit I could see coming: never to a body that only skated into me.
- Rules out: the take with no key (PLAY 8); a carry that ends before a decision (0.8 s, PLAY 3); the puck loose a third of the time.
- The owner: "A carried puck leaves its carrier only by an action ... never by an unpressed blade or a body's touch" (R-0048, the
  Director's ruling from the design eye); "The puck inside his ring is his" (R-0069); "A tackle is an event, not a rhythm" (R-0049);
  "carrying is the fun" (R-0011).
- Proven: NHL '94, pillar 2 of CASES: "Rules out ... random turnovers with no cause the player can name".
- Targets: T4, T5.

**P2. The pass is the fastest thing on the ice, and it gets there.** Under pressure the pass is my way out; up the ice a pass
beats any skater. A pass through a stick is still cut: that is its risk.
- Rules out: a pass no faster than the defender who chases it (a 15 m tap flies 63 frames; a defender from rest covers 10 m in
  64); defenders who read every pass on the frame it leaves (thirdjam's bots react in 0 frames at every level).
- The owner: "They want to pass but no pass reaches the end" (R-0067); "passess need to be able to be hold enough to cross 1/3 of
  arena length on max" (R-0067, taken as given and untouched); "slight speed reduction ... to incentivize passing" (R-0041);
  "decide when to push solo, when to pass" (R-0045).
- Proven: NHL '94's pass-then-shoot one-timer, "the move" (CASES); "a pass beats skating".
- Measured: 38 % complete; removing the pass wins 9 more points for thirdjam's hands (PLAY 2).
- Targets: T3, and the one-timer row of the matrix.

**P3. Goals come from shots, and a shot comes from space.** I score because I found a lane, moved the man in the crease, or
one-timed a pass: three ways to beat him, each with its own price.
- Rules out: carrying the puck over the line (PLAY 1: a quarter of the hand's goals; 1.84 goals a match with every shot taken away).
- The owner: "shoot speed should double" (R-0067, taken as given and untouched). CASES pillar 1: "Every goal is a play you made".
- Why the walk-in is more than an oddity: thirdjam already has a finishing game (a tap the crease man saves, a charged shot that
  clears him but costs half a second, a deke that moves him, a one-timer that needs a pass). The walk-in goes round all of it,
  which is why the tap, the deke and the one-timer measure as dead keys.
- Targets: T1, T2.

**P4. A hit is a choice with a price, for both men.** I throw a hit when I have the angle and the speed; when I miss I am out of
the play for a moment. When I am hit I saw it coming, and I am back on my feet before the play has left me.
- Rules out: hits as a rhythm (thirdjam's hand presses the cross-check 9 times a minute); 8-14 seconds of every match on the
  ice (PLAY 11); a body check nobody presses because the cross-check does its job (0.3 presses a minute against 9).
- The owner: "Applying principles of physics law will make the game much more natural and logical" (R-0045: the attacker pays, the
  carrier cannot hit: kept); "The tackles and hard fouls will be key for dynamic gameplay" (R-0013); "which will become on harder
  difficulty a beating massacre" (R-0041); "Crosscheck should be holdable" (R-0064).
- **A tension for the owner** (section 10, question 1): "a beating massacre" at all-star against "a tackle is an event, not a
  rhythm". This design reads them together as: higher levels throw more hits and you see every one, but a knockdown costs you
  the puck and your place, not seconds of watching.
- Targets: T6.

**P5. Every key has its moment; a key without one is not in the game.** For each verb: what it costs, what it wins, when,
and what beats it. Taking a kept verb away from a hand that plans must cost that hand something; no verb may win alone.
- Rules out: decorations. A verb that cannot be made to matter is cut, and the cut is written down (section 8).
- The owner: "gameplay mechanics" before modes (R-0036); direction 9: "Subtract before adding".
- Targets: T7.

**P6. Skill shows at every level, and a level is harder by better play.** A better hand wins more at rookie, at pro and at
all-star. A harder level reads the play sooner, covers the pass, throws the hit: it does not skate faster than I can.
- Rules out: rookie won standing still (the idle hand wins 60.5 %, PLAY 6); rookie opponents at 0.68 of the human's top speed;
  all-star opponents averaging 11.0 m/s against the human's 9.5 and pushing their stick to 1.5 (PLAY 10).
- The owner: "A level is easy by clumsiness, never by absence" (R-0067); "focus more on aggressivity" (R-0041); "Skaters without
  puck should be 15% faster than now" for "bots and human alike" (R-0064); "difficulty setup fine for me" (R-0047, said of the
  ladder's win rates: so the regular hand's pro figure stays where it is).
- Targets: T8, T9.

## 4. The tempo frame: what stays

The owner called thirdjam's speed balanced. **No skater speed, acceleration, stop, turn or shot speed changes**: the free
skater's 12.65 m/s, the sprint's 14.55, the carrier's 10.12, the 3 m stop, the 36 and 52 m/s shots (PLAY section 1) are
thirdlife's too, and `rink.sh balance-thirdlife` prints the same gym rows for both cartridges. A change may move a **ratio**
only when a pillar needs it, and its ledger entry names the ratio:

| Ratio | thirdjam | thirdlife may move it | Why |
|---|---|---|---|
| A 15 m pass's flight against a defender's 10 m from rest | 63 f : 64 f (1.0) | yes (P2) | a pass must beat a skater |
| A bot's read of a pass against a person's reaction | 0 f : 6-14 f | yes (P2, P6), by level | a level reads later, not never |
| Opponents' mean speed against the human's | 0.87 / 1.01 / 1.16 (rookie / pro / all-star) | yes (P6), toward 1.0 | his own standing ruling; pro, the level he judged, is already 1.0 |
| Seconds down against the length of a possession | 1.0-2.5 s : 2.35 s | yes (P4) | a knockdown should not outlast the play |
| A sprint's speed after its bar is empty | kept for many seconds | yes (P5) | the bar must be the sprint's cost (PLAY 12) |
| Everything else in PLAY section 1 | | no | "balanced speed" |

## 5. The target matrix: every verb

"Dead" and the figures in the third column are PLAY section 2 (thirdjam's hands). The last column is this design's intent;
the ledger says how far each got.

| Verb | Cost / reward / window / answer, as designed | thirdjam today | thirdlife: decision and target |
|---|---|---|---|
| Skate, stick aim | free / position, the blade / always / a faster or better placed man | carries the game | **keep, unchanged** |
| Stop (reversing the stick) | your speed / a 3 m stop and the first-step burst / instant / a defender who holds his gap | carries the game (-13 to -19 pp) | **keep, unchanged**; its answer is the level's gap control (P6) |
| Sprint | the bar (3 s, 6 s to refill), lower stability / +15 % / while the bar lasts / a hit; the empty bar | matters (-10 to -14 pp), but the speed outlives the bar | **keep**; the speed must end with the bar (round 2) |
| Brake key | - | never pressed; the reversed stick stops in a quarter of the distance | **cut** (section 8) |
| Far-side carry (shield, sweep) | none / the puck out of a stick's reach for 12 f / while he is near / a body check, a poke from the front | helps one hand, costs the other | **keep**: it is P1's skill. Target: taking it away costs the planning hand carries |
| Spin | a quarter of the bar, 0.7x speed for 24 f, a harder fall / the puck behind the body / 19 f / a body check, the exposed tail | dead | **keep only if** it measures after P1's changes; else cut |
| Deke | a 30 f lockout / the crease man commits 15 f and the tap goes to the open post / 15 f / a poke on the new side | dead | **keep only if** it measures once the walk-in is closed (P3); else cut |
| Pass (tap, hold for power) | 12 f cooldown, the hold / the puck up the ice faster than a skater / the flight / a stick in the lane | hurts the hand (+9 pp without it) | **keep, repair** (P2). Target T3 |
| Saucer | - | the sim lifts a held pass by itself | **not a verb**: no key of its own (section 8) |
| One-timer | a pass must reach you / a full-power shot with no hold, 16 degrees of aim help / 10 f / cover on the receiver | dead (0.1-0.3 a match) | **keep, must matter**: the signature goal (CASES). Target: at least 1 a match, and its removal costs |
| Tap shot | 24 f cooldown / a quick low shot / none / the crease man's pads, a body in the lane | dead | **keep**: the close finish once the line is closed (P3) |
| Charged shot | 0.5 s hold, 0.8x stability / 52 m/s over the crease man / the release / a hit or a poke in the hold | matters (-9 to -13 pp) | **keep, unchanged** |
| Poke | a miss locks the stick 20 f / the puck, clean / 8 f / the far-side carry, the body between, the take grace | dead (5 % clean; 0 of 19 from behind) | **keep, repair**: the stick's answer from the front (round 2). Target: 1 in 4 clean for a hand that reads it |
| Stick lift and its cross-check | 30 f cooldown, 8 f wind-up / the strip, a shove / 10 f / the spin, the sweep | matters for one hand (-12 pp) | **keep**; its job against the body check's made distinct (round 2) |
| Body check | 8 f wind-up, a miss costs speed / a knockdown at speed / 12 f / a braced or standing man, the release grace | nearly dead (the cross-check does its job) | **keep**: the owner's "tackle" (R-0013, R-0032). Round 2 |
| Brace (the held cross-check) | 0.9x speed and turn, no sprint, no stick / the hit as you arrive / from 10 f of hold / a faster man | dead | **keep**: the owner asked for it by name (R-0064). Measure it honestly; say so if it stays dead |
| Ability | - | does nothing in `hockey.regular` | **cut from this cartridge** (direction 9) |
| Draw | moving early loses / the puck, 90 f unfellable / the first press after the drop / a quicker press | the good scripted hand does better never pressing | **keep**; re-measured with the planning hand |
| Team signal | - / the mates' plan / 600 f | never used by a hand; held all match it always costs | **keep as it is, unmeasured**: no hand here can time a signal (still weak, section 9) |

## 6. The measurable targets

Each is read on `hockey.thirdlife` beside `hockey.regular`, by both kinds of hand. "Now" is `hockey.regular`.

| # | Target | Now (thirdjam's regular hand, pro) | Now (planning hand, regular, pro) | Wanted |
|---|---|---|---|---|
| T1 | Goals walked over the line, either side | 27 % of the hand's goals | 15 % of the hand's goals | 0, by rule |
| T2 | The shot is how you score: wins lost when every shot is taken away | -8 pp | -8 pp (60 seeds) | at least -30 pp |
| T3 | Passes that reach a team-mate; and the pass pays | 38 %; no pass = +9 pp | 58 %; no pass = +8 pp (±7, 60 seeds) | at least 65 %; no pass = a loss |
| T4 | A carry: seconds; share lost to an opponent; puck loose; changes of side a minute | 0.82 s; 39 %; 34 %; 27 | 0.68 s; 38 % | at least 1.5 s; at most 25 %; at most 25 %; at most 18 |
| T5 | Takes off a carrier with no key | (gym 20 of 20) | 4.4 a minute | 0, by rule |
| T6 | Knockdowns of the human a match; seconds on the ice | 5.6; 11.2 s | 4.0; 8.0 s | at most 3; at most 5 s (pro) |
| T7 | Every kept verb costs the planning hand when taken away; none wins alone | 9 dead | (the matrix, round 3) | every kept verb at least 2 standard errors in wins or goal difference at one level; no single verb over 60 % of the full hand |
| T8 | The ladder: idle at rookie; neighbours apart at every level; regular at pro | 60.5 %; pro 75.5 / 76; 75.5 % | rookie 99 / 100 / 100 | idle at most 25 %; at least 10 pp between novice, regular, good at each level; 60-80 % |
| T9 | Opponents' mean speed against the human's, rookie / pro / all-star | 0.87 / 1.01 / 1.16 | the same | within 5 % of 1.0 at every level |
| T10 | Pace stays thirdjam's: a goal (either side) every; a match | 34 s of live play; 2.5 min | 27 s; 2.0 min | a goal every 25-45 s of live play; a match 1.5-3.5 min |

## 7. The hands: why these figures may be believed, and how far

Two kinds of hand play every table, because a dead key may be the hand's fault.

- **thirdjam's playtester** (novice, regular, good; `native/thirdjam/AI/JamPlaytester.cpp`): a script written for thirdjam's rules.
  It does not re-plan: when a rule changes it keeps pressing what it was written to press. It is the second opinion in every table.
- **The planning hand** (`engine/cores/rink/lab/lab_plan.h`, built by this lane): it has no script. Every third of a second it
  takes the game as a person sees it (late), runs the real simulation forward under each of up to eighteen plain intents
  ("drive the net", "pass to that man", "charge a shot", "poke him", "get goal-side"), and plays the one whose outcome is
  worth most. It never reads the bots' brain: it expects the others to keep doing what they were doing, opponents near the
  puck to go for it, and a man who reaches a carrier to use his stick. Its copies of the simulation are exact (a copy stepped
  with the true inputs hashed as the match on 10,847 of 10,847 frames), so a changed rule is the rule it plans with, and a
  verb taken away is a verb it plans without.
- **Its limits are a person's.** It sees the game 300 / 233 / 167 ms late (novice / regular / good), decides every 0.5 / 0.33 /
  0.2 s, misjudges an outcome by up to 0.15 / 0.08 / 0.04 goals, aims 10 / 5 / 2 degrees off, presses at most 3 / 5 / 8 buttons a
  second, looks 0.5 / 0.75 / 0.75 s ahead. The three settings differ only in those limits: the same menu, the same judgment.
- **Calibrated once, on one number.** With a script's reactions (6 frames, a decision every 10) and a perfect reading it won 16 of 16 pro matches and 13 of 16 at all-star: stronger than a person. The limits were set
  so that its regular setting wins what thirdjam's regular hand wins at pro on `hockey.regular` (77 % against 75.5 %); thirdjam's
  ladder is the one the owner called "fine for me" (R-0047). Nothing else was fitted, and nothing is refitted on `hockey.thirdlife`.
- **Repaired and fitted again in round 2 (24 Nov).** The hand held the first press of its poke, lift and check back by 20 to 40
  frames (my defect: it chose the body check 13 times a minute and pressed it 0.3 times). Repaired, it won 93 % of pro matches
  on `hockey.regular` with the limits above, so the same one number was fitted again (eight settings, 40 seeds each): it now
  sees the game **467 / 367 / 233 ms** late and decides every **0.67 / 0.5 / 0.27 s**; the other limits are unchanged. On
  `hockey.regular` it wins 50 / 78.3 / 91.7 % at pro (novice / regular / good), 60 % at all-star (regular), 98.3 % at rookie
  (novice) (60 seeds; `tables/plan_calibration.hockey.regular.seeds1-60.epoch-k8-4.json` in the lane folder). Every figure
  of round 1 and of experiments E01 to E05 was read through the hand before the repair; every figure after says "epoch k8-4".
  Re-read through the repaired hand on `hockey.regular` at pro, round 1's findings stand: 0.40 of its 2.13 goals a match
  walked in; a carry of 0.72 s, 40.8 % lost; 0.60 takes a minute straight off a carrier with no key (3.96 with one); 2.9
  knockdowns and 5.8 s on the ice; 0.07 one-timers a match; of its completed passes 55 % are followed first by an opponent
  carrying the puck, 39 % come back to it, 5 % become a mate's shot.
- **Validated by what it found unprompted on `hockey.regular`** (section 2): the walk-in goal, the take with no key, the carry
  that lasts two thirds of a second, the eight seconds a match on the ice, the one-timer that never comes, rookie won by
  everybody.
- **Its own ablation** (regular setting, pro, 60 seeds, each cell paired with its full hand's 76.7 %; table:
  `docs/shifts/2026-11-24-night/lanes/K8-balance/tables/plan_ablation.hockey.regular.pro.seeds1-60.json`): skating alone
  -58.3 points (18.3 %); no shot -8.3 (±8.0; PLAY: -8); **no pass +8.3** (±6.8; PLAY: +9); no draw +10.0 (±7.0; PLAY's good
  hand: +14); **no tap shot +11.7** and **no brace +13.3** (each over two standard errors: two keys that cost the hand that
  presses them); sprint, stop, far-side carry, one-timer, charged shot, deke, spin, poke, lift, body check: each inside ±5.
- **Where it contradicts PLAY**, the report says so: it completes 58 % of its passes (not 38 %); at pro its three settings win
  55 / 77 / 97 % (not 24.5 / 75.5 / 76 %); and it loses nothing measurable without the sprint or without the stop (PLAY: -12 and
  -13 for the script), because a hand that re-plans goes round a missing verb.
- **How far its ablation can see.** At 60 seeds a cell the standard error of a paired difference in wins is 5-8 points: a verb
  worth less than about 15 points to this hand is invisible in a screen. The matrix of round 3 runs 200 seeds and reads the
  goal difference beside the wins.
- **What it is not.** It is not a person and not the owner. Its judgment is a hand-written estimate of what a position is worth
  (who has the puck, how near which net, who gets a loose one first). It moves like a stick, not like eight keys. It cannot
  signal its mates. It does not learn: it goes on pressing the tap shot and the brace although both cost it, and it passes
  although the pass does not pay (its estimate trusts a mate with the puck almost as much as itself). It can say that a key
  is worth nothing to a planner with a person's limits; it cannot say that a key feels good.

## 8. Cuts (decided before the numbers)

| Cut | Why | What replaces it |
|---|---|---|
| The brake key | 0 presses in 2,400 matches; it stops in 12.9 m where the reversed stick stops in 3.0 m (PLAY 1). A second, worse way to do what the stick already does | the stop by reversing the stick, unchanged |
| The ability key (F) in this cartridge | `hockey.regular` has no ability; direction 9: no ability, pickup or mode until the plain game is good | nothing; it returns with the stat layer, as a cartridge's choice |
| The saucer as a verb of its own | the simulation lifts a held pass when a stick is in the lane; the player chooses power, not height | the held pass (power) |
| The walk-in goal | P3 | the finishing game thirdjam already has |
| The take with no key | P1 (round 2) | the poke, the lift, the hit |

A cut here is a design decision for the cartridge and its control legend. The keys themselves live in the shell (lane K3):
which ones `hockey.thirdlife` shows and binds is a question in this lane's report, not an edit.

## 9. How a change is made, and what is still weak

- One change at a time, from the cartridge as it stands (every kept change so far). A cartridge number first; a difficulty
  number next; a rule in a marked patch last (`engine/cores/rink/native/patches-thirdlife/`, applied to a copy; thirdjam's files
  are never edited, and the patched tree with every switch off plays `hockey.regular` hash for hash:
  `rink.sh balance-thirdlife --parity`).
- Each has a ledger entry before it runs: the hypothesis, the target it moves, the tempo ratio it moves. Then the same cells
  before and after, on the same seeds, by both kinds of hand. **Kept** only when its target moved the right way and no other
  target broke; otherwise **rejected**, with its figures. After every three kept changes the whole matrix runs again.
- A screen is 60 seeds a cell: enough to see a rule work (events by the thousand) and a large swing in wins, not a small one.
  The matrix and the final ladder are 100-200 seeds. The ledger prints the standard error beside every paired difference.
- Still weak, known before the first experiment: the team signal is unmeasured; the planning hand cannot tell a dull key from a
  pleasant one; every figure is a hand's; nobody has played it.

## 10. Questions for the owner

1. **Massacre or event?** "which will become on harder difficulty a beating massacre" (R-0041) and "a tackle is an event, not a
   rhythm" (R-0049) pull apart. This design: more hits thrown at higher levels, each one visible, each one shorter on the ice.
   If you want all-star to put you on the ice more, say so and T6 changes.
2. **Should a breakaway end with a press?** P3 closes the goal line to a carried puck: you must shoot, a tap is enough. If
   gliding it in is a pleasure you want kept, E01 is one switch (`net_carry_wall`) to turn off.
3. **Is pro the level you judged?** The design holds pro's opponents at your pace and brings rookie and all-star to it (P6).

## 11. What the owner will feel in the first minute (one line per kept change)

Filled from the ledger as changes are kept; the same lines are in `LEDGER.md` beside their figures.

| Change | In the first minute |
|---|---|
| E01b: the goal line is closed to a held puck | A breakaway now ends with a press. Glide the puck at the net and it stops on the goal line and lies there; tap shoot (a tap is enough) and it is in. The opponents cannot walk it in on you either. |
| E03: a carried puck stays with its carrier through a body's touch | Skating into a man who has the puck no longer gives it to you: you bounce off him and he still has it. Press the stick lift (or poke, or hit him) and it is yours. Your mates stop losing the puck to a bump the moment you pass to them. |
| E04: a knockdown lasts 0.7 to 1.5 s | When you are knocked down you are back on your skates in about a second, not two. You still lose the puck and your place; you no longer watch the play leave. |
| E05: nobody glides faster than he can skate | Shift is a spend now: when the bar is empty you are back at skating pace within half a second, and it must fill a quarter before it answers again. And when you pick the puck up at full speed you feel yourself slow to carrying pace: a man chasing you will catch you, so move it. |

## 12. Where the cartridge stands

### After round 1 (23 Nov, 23:00): one change kept

`hockey.thirdlife` is thirdjam with one rule changed. Every number of the cartridge file equals `hockey.regular`'s.

| Experiment | Verdict | In one line |
|---|---|---|
| E01 the goal line closed to a puck that rides with its carrier | rejected | the first form of the rule leaked: walked goals halved, not gone |
| E01b the goal line closed to a held puck | **kept** | no goal without a release, either side; a hand without any shot loses 35 (thirdjam's hand) and 58 (planning hand) points of wins at pro, where it lost 8 |
| E02 a tap pass arrives at 12.5 m/s instead of 8 | rejected | passes completed rose by 8 to 20 points, but the number is every bot's too: the opposing five gained more than the human's side and all-star collapsed (38 -> 7 % and 67 -> 27 %) |

| Target | After round 1 |
|---|---|
| T1 no walked goals | **met** (0 of every full hand's goals, both sides, 60 seeds a cell) |
| T2 the shot is how you score | **met** (-35 and -58 points of wins without it) |
| T3 passes arrive and pay | not met: 37 % (thirdjam's hand) and 57 % (planning hand) complete at pro; without the pass thirdjam's hand wins 23 points more (63 -> 87 %), the planning hand 3 fewer (85 -> 82 %, inside the noise) |
| T4-T7, T9 | not yet touched (round 2: possession, contact, dead verbs) |
| T8 the ladder | moved by E01b: thirdjam's regular hand at pro 75 -> 63 % (it cannot re-plan and still skates at the line); the planning hand 77 -> 85 %. The level table (round 3) owns this |
| T10 pace | held: matches 5-10 % longer |

What the round taught the design, beyond its two experiments:

1. **Skill already shows at pro, for a hand that plans** (55 / 77 / 97 %). PLAY's flat top was thirdjam's script. P6's work is therefore at
   the two ends (rookie won by anybody, all-star by speed), not in the middle.
2. **The pass has two faults, and speed is the smaller.** A faster pass arrives (E02), and still does not pay: in this game you are one
   fixed skater, so a pass hands the puck to a mate who plays worse than you and gives it back in 0.4 of the chances. NHL '94 solved this by
   moving the player with the puck ("control jumps to the receiver", CASES). thirdjam's camera is bound to one skater by the owner's ruling
   (R-0038), so the answer here has to be the mates: what they do with a pass, and how often it comes back (round 2).
3. **A number shared with the bots is a difficulty number.** The pass's speed, read by ten skaters, moved the ladder by 30 to 40 points at
   all-star. Changes for the human's feel go in the human's own rules; changes shared with the bots go through the level table.

### After round 2 (24 Nov, 23:30): four changes kept

`hockey.thirdlife` is thirdjam with three rules changed and one cartridge number: a goal must leave a blade (E01b); a carried
puck stays with its carrier through a body's touch (E03); a knockdown lasts 0.7 to 1.5 s (E04, `game.contact.down_frames_min`
40, `down_frames_max` 90); nobody glides faster than he can skate and an empty sprint bar refills a quarter before the next
sprint (E05). Every other number of the cartridge equals `hockey.regular`'s.

| Experiment | Verdict | In one line |
|---|---|---|
| E03 a carried puck stays with its carrier through a body's touch | **kept** | a take with no key head on: gym 12 of 12 to 0 of 12; in matches 0.60 to 0.27 a minute |
| E04 a knockdown lasts 0.7 to 1.5 s | **kept** | seconds on the ice down by 28 to 43 % for every hand; knockdowns a match not down |
| E05 nobody glides faster than he can skate | **kept** | a sprint ends with its bar (14.55 to 12.65 m/s in 28 frames); a pick-up at speed slows to carrying pace in 38 |
| E06 the mates pass to the open human in 0.8 of the chances | rejected | changed almost nothing: the share is rarely what decides |

| Target | After round 2 (the planning hand as repaired in round 2, regular, pro, 60 seeds unless said) |
|---|---|
| T1 no walked goals | **met**: 0 by the strict count |
| T2 the shot is how you score | **met**: -48 points of wins without it (+-8) |
| T3 passes arrive and pay | **not met**: 55 % reach a mate; the pass is worth nothing to the hand (+1.7 without it, +-7); thirdjam's scripted hand wins 28 points more without it. Of the passes that arrive, half are lost by the mate before anything comes of them |
| T4 a carry that skill can keep | **not met**: 0.79 s, 46 % lost to an opponent, 29 changes of side a minute, the puck loose 32 % (thirdjam: 0.72 s, 41 %) |
| T5 no take without a key | **nearly**: 0.27 a minute straight off a carrier (thirdjam 0.60); of seven traced, four were his own shot blocked at point blank; gym 0 of 12 |
| T6 knockdowns and time on the ice | **half**: 5.7 s on the ice (thirdjam 5.8 s for the same hand; 7.3 before E04 for the old hand); 4.5 knockdowns a match, not 3 |
| T7 every kept verb matters | **open**: at 60 seeds only the shot can be seen; no verb costs its user once the hand was repaired |
| T8 the ladder | pro 47 / 83 / 97 %, all-star 23 / 65 / 87 % (spread at both: met); regular at pro above the 60-80 band; rookie 100 / 100 / 100 and the idle hand 62 %: **not met at rookie** |
| T9 levels by play, not legs | untouched: opponents' mean speed against the human's 0.90 / 1.01 / 1.08 (rookie / pro / all-star) |
| T10 pace | held: a pro match 117 s for the regular hand |

What round 2 taught the design:

1. **thirdjam meant "no take by a body's touch" and leaked it one way.** The human took pucks by skating into carriers and
   the opposing bots took them from his mates the same way; nobody took them from him. Closing it protected the mates, not
   the human: his own carry was never the leak.
2. **The human's short carry is the bots' hands, not the rules.** Pro's bots press a stick or a hit the frame they can
   (reaction 0 frames at every level). That is a level number, and it is where T4 and T6 will be won or lost (round 3).
3. **The bar was never the sprint's cost.** In thirdjam a held Shift on an empty bar sprints every other frame.
4. **My instrument was wrong once, in a way that mattered.** The planning hand held its first poke, lift and check back by a
   third to two thirds of a second. Two "findings" (the brace and the body check cost their user) were that defect. The
   hand was repaired and fitted again to the same one number; what it says now is in the table above.
5. **A planner's ablation leans toward "this verb costs nothing"**, a script's toward "this verb is vital". Round 3 reads
   both, at 200 seeds.
