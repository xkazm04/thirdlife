# K8 balance, round 2 (24 Nov, from 21:10)

Nobody has played `hockey.thirdlife`. Every figure below is a hand's (named each time). The ladder is read from the planning
hand (the Director's ruling after round 1); thirdjam's scripted hand is the second opinion in every table.

## 1. The take with no key: the cause, confirmed both ways

Round 1's report guessed that the bodies' bounce throws the carrier's velocity so the puck stops riding with him.
**That guess was wrong.** `rinklab probe -which=take` (30 scenes: three pairs x five geometries x two stick positions,
nobody presses anything) shows the puck changes hands **one or two frames before the bodies touch**, and the carrier's
velocity does not move at all on that frame (a jump of 0.00 m/s).

What happens, in thirdjam's own code (`native/thirdjam/Private/JamSim.cpp`):
1. The carried puck rides on the blade, 0.85 to 1.6 m ahead of its carrier. A man skating at him meets the PUCK with his body
   before he meets the carrier.
2. `BlockCarried` (3867) rightly refuses the take (R-0048: no take by a body's touch): it pushes the puck out of that body.
   But it also takes out the puck's motion into the body (`Puck.Vel -= N * Vn`), so the puck now moves with the attacker, that
   is at the closing speed against its own carrier (measured: 14.16 m/s in the slow scene, the two skaters' 10.12 + 4.04).
3. `RidingCarrier` (853) calls a puck "riding" only while it moves within 4 m/s of its carrier. It no longer does: the puck is
   loose by the rule's own test.
4. A loose puck inside the human's ring is his on that frame (R-0069, `TryHumanRing`); a bot's pickup arc or body takes it the
   same way (`TryLoosePickup`, `BodyMeetsPuck`).

| Who skates at whom, no key | head on | head on, slowly | from the side | from behind | passing 1.3 m wide |
|---|---|---|---|---|---|
| the human at an opposing bot | **taken 2 of 2** | **taken 2 of 2** | kept | kept | kept (bodies do not touch) |
| an opposing bot at the human | kept (his own ring takes it back on the same frame) | kept | kept | kept | kept |
| an opposing bot at the human's mate | **taken 2 of 2** | **taken 2 of 2** | kept | kept | kept |

So the leak is one-sided: the human wins pucks by skating into carriers, the opposing bots win them from his mates the same
way, and nobody wins them from him. Both ways:
- **Take the cause away and the effect goes.** With patch 0003's switch (`carry_holds_body`: the puck keeps its carrier's
  velocity through another body's touch and through his own bounce) the same 12 head-on scenes: **0 of 12 taken**.
- **The cause without a body.** In the "passing wide" scenes the attacker's stick and ring pass over the puck and the bodies
  never touch: 0 of 6 taken on thirdjam itself. R-0048 holds until a body meets the puck.

In matches (the planning hand, regular, pro, 30 seeds; a take counted when the puck rode with an opponent at the end of one
frame and is the human's at the end of the next, with no stick or hit key of his in the 30 frames before): 1.23 a minute
without the switch, **0.33 with it** (19 in 57 minutes). Seven of those were traced (`-debuggoals`): four are the carrier's own
shot blocked at point blank on the frame he released it; one came off a puck at shot speed; two are a puck squeezed between
bodies at 0.52 m from its carrier. Not zero: about 0.1 a minute is left that I cannot call a block.

## 2. The experiments (60 seeds a cell; figures and standard errors in `LEDGER.md`)

All three measured with the planning hand as it was in round 1 (epoch k8-2). Wins are paired, match for match.

- **E03, kept: a carried puck stays with its carrier through a body's touch** (patch 0003, `carry_holds_body`).
  The planning hand's passes that reach a mate 56.7 -> 67.3 % at pro (its mates no longer lose the puck to a bump);
  knocked down 4.5 -> 3.7 times a match; the stick lift became worth 10 points (81.7 -> 71.7 % without it; before 85 -> 81.7).
  Price: the planning novice at pro 65 -> 43.3 % (-21.7 +-8.6), regular 85 -> 81.7, good 93.3 -> 96.7; all-star regular
  66.7 -> 55 (-11.7 +-9.2); thirdjam's regular at pro 63.3 -> 53.3 (-10 +-8.5).
- **E04, kept: a knockdown lasts 40 to 90 frames** (a cartridge number; thirdjam: 60 to 150). Seconds on the ice a match,
  planning hand at pro: 10.7 -> 6.1 / 7.3 -> 5.3 / 6.0 -> 3.5 (novice / regular / good). Knockdowns a match did not fall
  (3.7 -> 4.3). Wins inside the noise; one scripted cell at two standard errors (thirdjam's novice at pro 20 -> 8.3 %).
- **E05, kept: nobody glides faster than he can skate** (patch 0004: speed above your own top is shed at 4 m/s2; an empty
  sprint bar must refill a quarter before the next sprint). Found on the way: in thirdjam a held sprint key on an empty bar
  sprints again every other frame, so the bar never ends a held sprint. Taking the sprint away now costs the planning hand
  11.7 points at pro (before: 1.6); the pass turned from -8 to +8 for it (each +-7: a lead, not a result). Wins: planning
  regular at pro 78.3 -> 91.7 (+13.3 +-6.5), all-star 63.3 -> 51.7 (-11.7 +-8.6).

- **E06, rejected: the mates' share of passes to the open human 0.8 at every level** (thirdjam 0.6 / 0.4 / 0.2; a level
  tune, read through the repaired hand, epoch k8-4). It changed almost nothing: for thirdjam's regular hand at pro all 60
  matches ended as before; of the planning hand's completed passes 36.4 % came back before and 35.5 % after. The coin is
  rarely tossed: the conditions in front of it decide. Making the pass pay through the mates is the mates' behaviour (a
  patch to the brain's copy), not a level number.

## 3. A defect in my own hand, found and repaired (epoch k8-3, then k8-4)

The planning hand's poke, lift and check intents each held their FIRST press back by their own repeat gap (20, 30 and 40
frames from the moment the intent was chosen): a hand that decided to hit pressed two thirds of a second later, usually
after it had re-decided. In round 1's tables it pressed the body check 0.3 times a minute while choosing the intent 13 times
a minute. So this round's reading under E03 that "the body check costs its user", round 1's "the brace costs its user" and
part of "the poke is worth nothing" were the hand's fault, not the game's; round 1's report named the hand only as a suspect. Repaired (the gap is between presses, not before the
first; a spent brace is let go); every arm measured after this is epoch k8-3 and no k8-2 cell is reused.

The repaired hand is stronger, so its one calibration number moved and it was calibrated again on `hockey.regular`
(section 4). Round 1's validation figures stand as measured with the old hand; the six unprompted findings were re-read
with the new one (section 4).

## 4. The repaired hand, fitted again on `hockey.regular` and read again

With round 1's limits the repaired hand won 76.7 / 93.3 / 96.7 % at pro on `hockey.regular` (novice / regular / good, 60
seeds): too strong for the one number it is fitted to (thirdjam's regular hand at pro, 75.5 %). Eight settings of the
regular hand were tried there (40 seeds each, +-6.5):

| reaction (frames) | decides every | judgement noise | presses a second | wins at pro |
|---|---|---|---|---|
| 14 | 20 | 0.14 | 5 | 87.5 % |
| 16 | 24 | 0.12 | 5 | 85 % |
| 18 | 26 | 0.14 | 5 | 82.5 % |
| 14 | 20 | 0.20 | 5 | 82.5 % |
| 18 | 30 | 0.10 | 5 | 90 % |
| 20 | 30 | 0.16 | 5 | 82.5 % |
| 14 | 20 | 0.08 | 3 | 87.5 % |
| **22** | **30** | **0.08** | **5** | **77.5 %** |

Taken: reaction 22 frames (367 ms), a decision every 30; novice 28 and 40, good 14 and 16 (scaled alike; aim error, judgement
noise and presses a second as in round 1). On `hockey.regular`, 60 seeds: **50 / 78.3 / 91.7 %** at pro, 60 % at all-star
(regular), 98.3 % at rookie (novice). `tables/plan_calibration.hockey.regular.seeds1-60.epoch-k8-4.json`.

Round 1's unprompted findings, read again through it (regular, pro, `hockey.regular`): walked-in goals 0.40 of 2.13 a match;
a carry 0.72 s, 40.8 % lost; takes straight off a carrier with no key 0.60 a minute; 2.9 knockdowns and 5.8 s on the ice;
one-timers 0.07 a match; rookie 98.3 % for the novice. And one new reading: **of its completed passes, 55 % are followed
first by an opponent carrying the puck, 39 % come back to it, 5 % become a mate's shot, 4 % a goal.** That is the pass's
fault in one line: half the time the mate you gave it to loses it.

## 5. The mid-round matrix (after three kept changes; the repaired hand, epoch k8-4; 60 seeds a cell)

`hockey.thirdlife` as it stands (E01b, E03, E04, E05) beside `hockey.regular`, the same hand, the same seeds.
Table: `tables/mid_matrix.hockey.thirdlife.seeds1-60.epoch-k8-4.json`.

| The planning hand | `hockey.regular` | `hockey.thirdlife` |
|---|---|---|
| Pro: novice / regular / good, wins | 50 / 78.3 / 91.7 % | 46.7 / 83.3 / 96.7 % |
| All-star: novice / regular / good | - / 60 / - | 23.3 / 65 / 86.7 % |
| Rookie: novice / regular / good | 98.3 / - / - | 100 / 100 / 100 % |
| Regular at pro: goals walked in (strict count) | 0.40 of 2.13 a match (K4's count) | 0 |
| ... a carry; share lost to an opponent | 0.72 s; 40.8 % | 0.79 s; 45.7 % |
| ... takes straight off a carrier with no key, a minute | 0.60 | 0.27 |
| ... passes that reach a mate | 57.6 % | 54.6 % |
| ... of those: lost first / back to him / a mate's shot / a goal | 55 / 39 / 5 / 4 % | 49 / 36 / 12 / 2 % |
| ... knockdowns; seconds on the ice, a match | 2.9; 5.8 s | 4.5; 5.7 s |
| ... one-timers a match | 0.07 | 0.08 |
| thirdjam's own hands at pro: novice / regular / good | 24.5 / 75.5 / 76 % (PLAY, 200 seeds) | 18.3 / 60 / 85 % |
| The idle hand at rookie | 60.5 % (PLAY) | 61.7 % |

The planning hand (regular, pro, 83.3 %) without one verb, paired match for match:

| Without | wins, points | +- | goal difference |
|---|---|---|---|
| everything but skating | -75.0 | 5.8 | -3.57 |
| every shot | **-48.2** | 8.1 | -2.25 |
| the charged shot | -6.7 | 5.8 | -0.33 |
| the far-side carry | -3.3 | 6.3 | -0.18 |
| the stop | -1.7 | 7.3 | -0.10 |
| the brace | 0.0 | 6.7 | +0.15 |
| the tap shot, the pass, the body check | +1.7 each | 6.1, 6.9, 7.3 | +0.20, +0.17, -0.02 |
| the one-timer, the spin | +3.3 each | 4.1, 6.3 | +0.10, +0.22 |
| the draw | +5.0 | 6.0 | +0.28 |
| the sprint, the deke | +6.7 each | 6.2, 4.7 | +0.38, +0.27 |
| the poke | +8.3 | 4.9 | +0.42 |
| the stick lift | **+11.7** | 5.9 | +0.42 |

How to read it, plainly:
- **Only the shot is established** (and skating alone is nothing: 7 %). T2 holds at -48 points.
- **Sixty seeds cannot see one verb.** The paired error is 5 to 8 points; of sixteen comparisons one at two standard errors
  is what chance gives. The lift was worth 10 points to the old hand under E03 and costs 12 to the repaired one; the sprint
  was worth 12 to the old hand under E05 and costs 7 to the new one. Those readings do not survive a change of hand, so
  they are not findings. E03's and E05's "why" lines in the ledger quote them; they are superseded here.
- **The ablation leans toward "costs nothing".** Thirteen of sixteen removals come out at zero or above. A hand that
  chooses among near-equal intents with a noisy judgement does a little better with fewer to choose from, whatever was
  removed. So a few points of "better without it" is not evidence against a verb; a verb is shown to matter only when its
  removal clearly costs. Round 3 needs the other arm beside it (the key dead but still pressed, K4's way: it leans the
  other way) and 200 seeds.
- **The keys that "cost their user" do not, with the repaired hand**: the brace 0.0, the body check +1.7, the tap shot
  +1.7 (round 1: +13.3 and +11.7; E03: +8). It was the instrument. Nothing is cut on this evidence, and nothing is shown
  to matter either.
- **What did not move**: the human's own carry (0.79 s, 46 % lost to an opponent; T4 asks 1.5 s and 25 %) and the count of
  knockdowns (4.5 a match against 2.9 on `hockey.regular` for the same hand: he is up sooner and catchable, so he is hit
  again). Both are how fast and how often pro's bots press, which is the level table (round 3).

## 6. Decisions on the keys

- **The body check, the brace, the tap shot: kept, not cut.** With the repaired hand none costs its user (+1.7, 0.0, +1.7,
  each +-6 to 7); thirdjam's scripted hand agrees (the check 0.0, the brace -3.3 at pro). None is shown to matter either:
  that is T7's question for the 200-seed matrix with both ablation arms.
- **The poke from the front: not touched this round.** With the repaired hand 0.58 clean pokes a minute on `hockey.regular`
  (thirdjam's hand: 0.5); without the poke the hand does no worse (+8.3 +-4.9, in the leaning zone). The lift does the
  poke's job at arm's length and hands the puck to the lifter; the poke's own ground (reach, from the front, at speed) is
  not yet worth a key. A candidate for round 3, after the levels: the poke's reach or the lift's range, one of them.
- **The brake key, the ability key, the saucer as a verb: cut as decided in the design** (section 8 of HOCKEY-BALANCE.md);
  the shell's work (lane K3), nothing built here.

## 7. What my eye rejects

Nothing to look at (this lane draws nothing). What my reading rejects:
- My own instrument, twice this round: the take's cause I guessed in round 1 was wrong (measured before patching, so no
  harm), and the hand's late presses made two false findings before I found them.
- Three kept experiments (E03, E04, E05) were read through the defective hand. Their rule-level evidence (gym probes,
  strict counts, seconds on the ice) does not depend on it; their statements about single verbs did, and are withdrawn.
- The human's own carry did not get longer. The round's rules are right by the owner's rulings and they did not buy P1's
  feeling for the player himself.
- Knockdowns a match went UP against thirdjam for the same hand (4.5 against 2.9) while seconds on the ice stayed (5.7).

## 8. Deviations (beyond round 1's list)

1. `hockey.thirdlife` rules: `carry_holds_body` (patch 0003), `over_top_decel_mps2` 4 and `sprint_restart_share` 0.25
   (patch 0004); cartridge numbers `game.contact.down_frames_min` 40, `down_frames_max` 90. Each off or at thirdjam's value
   in `hockey.regular`; the patched tree with every switch off is thirdjam (parity, 600 of 600 hashes, 43 probes).
2. Patch 0003 adds `FJamPuckState::TlRider` (hashed only while its switch is on). Patch 0004 adds no state.
3. The planning hand changed (press timing, the brace's release) and was fitted again; arms are tagged by epoch and no
   older cell is reused. The raw arm round 1 kept on purpose was of the old epoch and was deleted.
4. The lab gained `rinklab probe -which=take|speed` (this lane's scenes; not part of `rink.sh balance`'s gym lines, which
   are unchanged) and three read-only counters (takes straight off a carrier, what follows a completed pass).
5. The mid-round matrix is 60 seeds and the planning hand's ablation only (33 cells), not the 51-cell matrix at 200 seeds.

## 9. Next (round 3)

The levels (how fast and how often each level's bots press: T4, T6; rookie by clumsiness, not slowness: T8, T9); the pass
through the mates as a brain patch (what a mate does in the first second after the human's pass, and when he looks for
him again); then the whole matrix at 200 seeds with both ablation arms, the cartridge, the owner's page.
