# K8 balance, round 3 (24 Nov 23:45 - 25 Nov)

Nobody has played `hockey.thirdlife`. Every figure below is a hand's (named each time). The ladder is read from the planning
hand (epoch k8-4: repaired and fitted again in round 2); thirdjam's scripted hand is the second opinion. At most 6 processes.

## 1. The experiments (60 seeds a cell; figures and standard errors in `LEDGER.md`)

| ID | The change | Where it lives | Verdict | In one line |
|---|---|---|---|---|
| E07 | a man who has just won the puck cannot be flattened for half a second | cartridge number `game.contact.take_shield_frames` 30 (thirdjam's own rule, shipped at 0) | **kept** | knockdowns of the regular planning hand at pro 4.5 to 3.6 a match, seconds on the ice 5.7 to 4.5; wins inside the noise |
| E08 | the give-and-go: for two seconds after a mate takes your pass he looks for you first | a patch to the brain's copy + a mates' tune key | rejected | the puck did not come back more often (35.5 to 35.0 % of completed passes); patch taken out of the series |
| E09 | rookie's opponents shoot from the slot with a wind-up and lift a stick now and then | sidecar `levels.rookie` (thirdjam's tune keys) | **kept** | the hand that never moves 65 to 28.3 %; thirdjam's novice 98.3 to 86.7 %; the planning novice 100 to 91.7 % |
| E10 | pro's opponents finish and move the puck as all-star's do (charged shot, deke, pass under pressure) | `levels.pro` | rejected | it made pro EASIER: they hold the puck to wind up and are stripped; goals against fell by a third |
| E11 | all-star's opponents skate at the human's pace | `levels.all_star` (`red_skill` 0.87) | **kept** | legs equal by rule (1.035 to 1.0); their mean speed only 1.07 to 1.06 of his (the rest is sprinting, which is play); wins inside the noise |
| E12 | pro presses as a matter of course: hunts from 16 m, lifts a stick again after a second | `levels.pro` | **kept** | the regular planning hand at pro 88.3 to 81.7 %; seconds on the ice 4.5 to 4.7 |

What the round's two rejections taught:
- **The pass (E06 in round 2, E08 here).** Neither the mates' coin nor the conditions round it hold the return back. Half
  of the passes that arrive are lost by the mate before he does anything. The mates are thirdjam's plainest bots at every
  level (no stick handling, no far-side carry); once the half-second graces end, pro's opponents strip them. The pass will
  pay when a mate can keep a puck for a second: the mates' SKILL, not their intention. Not done; T3 stays not met.
- **"Better play" is not a list of all-star's switches (E10).** A bot that winds its shot up, dekes or looks for a pass
  holds the puck for exactly the moments in which it is stripped. At pro's pace of pressure the tap from where it stands is
  the better play. What separates the levels in thirdjam's own table, apart from legs, is how they press; that is also the
  owner's own ladder (R-0041: aggression), and the kept rules (E03, E04, E07) are what make more pressure fair.

## 2. A target I wrote wrongly, corrected

T9 said "the opponents' mean speed within 5 % of the human's at every level". Mean speed in play is not legs: all-star's
opponents have the human's top speed exactly since E11 and still average 1.06 of his speed, because they sprint whenever
their bar allows, under the same bar rule as his (E05). T9 now reads: **every level's opponents have the human's own top
speed, acceleration and sprint rule; no level is harder by legs.** Met by construction at pro and all-star (speed_scale x
red_skill = 1.0) and at rookie (thirdjam's own `hk_opp_pace9` 1.0).

## 3. The final matrix (200 seeds a cell; both ablation arms)

**Round 3 was split at 01:52 on the Director's word: the ladder below is round 3a; the single-verb matrix is round 3b and was
still running when this was written.**

Wins, per cent, `hockey.thirdlife`, 200 seeds a cell (± 2.6 at 84 %, 3.5 at 50 %). `hockey.regular` in brackets.

| Hand | Rookie | Pro | All-star |
|---|---|---|---|
| A player who never moves | 23.5 (thirdjam 60.5) | 9.0 (9.5) | 6.0 (5.5) |
| Planning hand, slow | 92.0 (98) | 55.5 (50) | 22.5 |
| Planning hand, average | 99.5 | 84.0 (78) | 66.5 (60) |
| Planning hand, quick | 100 | 95.5 (92) | 88.0 |
| thirdjam's scripted novice | 89.5 (97.5) | 15.0 (24.5) | 11.5 (10.5) |
| thirdjam's scripted regular | 98.5 (100) | 68.5 (75.5) | 48.0 (39.5) |
| thirdjam's scripted good | 100 (100) | 75.5 (76) | 56.0 (53.5) |

The regular planning hand at pro is **above the band** (84.0 ± 2.6 against 60-80). Not pushed further tonight: the matrix
was already measuring this cartridge. The next step is written in E12's notes (pro's poke at once).

## 4. What my eye rejects

Nothing to look at (this lane draws nothing). What my reading rejects:
- The pass still does not pay. Two tries at the mates, both rejected. This is the pillar the cartridge does not deliver.
- The player's own carry is as short as thirdjam's. The rules made every loss have a cause; they did not make a carry last.
- The regular planning hand at pro sits at the upper edge of the band after E12, not inside it.
- The planning hand cannot time a team signal, cannot feel a key, and was repaired once already: its single-verb
  readings are only as good as section 3's two arms agree.

## 5. Deviations (beyond rounds 1 and 2)

1. Cartridge number `game.contact.take_shield_frames` 30; the sidecar's `levels` now carry three tune strings (thirdjam's
   own difficulty tune keys, applied on top of each level's profile).
2. Patch 0005 (the give-and-go) was written, proven neutral with its switch off (parity, 600 of 600), measured, rejected
   and moved out of the series to `engine/cores/rink/lab/experiments/rejected/`. The series is 0001-0004.
3. The lab gained `-plankeep` (the dead-key arm of the planning hand's ablation) and two cell sets (`final`, `pladder`).
4. Level experiments ran on their own level's cells only (a level's tune cannot touch another level's matches).

## 6. Round 3b: the final matrix (200 seeds a cell; the planning hand, epoch k8-4; both ablation arms)

**Wins, per cent (± one standard error), 200 seeds a cell unless said.**
| hand, level | hockey.regular | hockey.thirdlife |
|---|---|---|
| planning novice, rookie | 98.0 ±1.0 | 92.0 ±1.9 |
| planning novice, pro | 49.5 ±3.5 | 55.5 ±3.5 |
| planning novice, all_star | 23.5 ±3.0 | 22.5 ±3.0 |
| planning regular, rookie | 100.0 ±0.0 | 99.5 ±0.5 |
| planning regular, pro | 85.0 ±2.5 | 84.0 ±2.6 |
| planning regular, all_star | 50.0 ±3.5 | 66.5 ±3.3 |
| planning good, rookie | 100.0 ±0.0 | 100.0 ±0.0 |
| planning good, pro | 95.5 ±1.5 | 95.5 ±1.5 |
| planning good, all_star | 77.5 ±3.0 | 88.0 ±2.3 |
| the idle hand, rookie | 60.5 ±3.5 | 23.5 ±3.0 |
| the idle hand, pro | 9.5 ±2.1 | 9.0 ±2.0 |
| the idle hand, all_star | 5.5 ±1.6 | 6.0 ±1.7 |
| thirdjam's novice, rookie | 97.5 (PLAY) | 89.5 ±2.2 |
| thirdjam's novice, pro | 24.5 (PLAY) | 15.0 ±2.5 |
| thirdjam's novice, all_star | 10.5 (PLAY) | 11.5 ±2.3 |
| thirdjam's regular, rookie | 100 (PLAY) | 98.5 ±0.9 |
| thirdjam's regular, pro | 75.5 (PLAY) | 68.5 ±3.3 |
| thirdjam's regular, all_star | 39.5 (PLAY) | 48.0 ±3.5 |
| thirdjam's good, rookie | 100 (PLAY) | 100.0 ±0.0 |
| thirdjam's good, pro | 76 (PLAY) | 75.5 ±3.0 |
| thirdjam's good, all_star | 53.5 (PLAY) | 56.0 ±3.5 |

**The regular planning hand at pro, the play itself.**
| figure | hockey.regular | hockey.thirdlife |
|---|---|---|
| goals for / against a minute | 1.631 / 0.682 | 1.582 / 0.713 |
| goals walked over the line (strict), share of his side's | 7.4 % | 0 % |
| a carry, seconds; share lost to an opponent | 0.7; 40.4 % | 0.79; 45.5 % |
| takes straight off a carrier: with a key / with none, a minute | 3.85 / 0.61 | 4.3 / 0.2 |
| passes a minute; share that reach a mate | 4.35; 56.7 % | 3.47; 60.9 % |
| of those: lost first / back to him / a mate's shot / a goal | 51.7 / 36.4 / 9.8 / 4.7 % | 49.4 / 34.6 / 12.4 / 3.4 % |
| one-timers a match | 0.08 | 0.06 |
| knockdowns a match; seconds on the ice | 3.54; 7.16 | 3.76; 4.64 |
| changes of side a minute; puck loose | 28.35; 32.9 % | 28.12; 32.2 % |
| share of play time sprinting; his mean speed | 22.3 %; 9.43 m/s | 22.6 %; 9.41 m/s |
| a match, seconds | 111.3 | 115.4 |

**The regular planning hand at pro without one verb: wins in points against the full hand, paired match for match (± one standard error). x = out of its menu and keys (it re-plans; leans toward "costs nothing"); k = still pressed, never heard (leans toward "vital").**
| without | thirdlife, x (200 seeds) | thirdlife, k (200 seeds) | regular, x (60 seeds) |
|---|---|---|---|
| shoot | -56.5 ±4.0 * | - | -11.7 ±7.2 |
| charge | -10.0 ±3.9 * | -9.5 ±3.9 * | -5.0 ±7.3 |
| tap | -1.5 ±3.1 | -2.5 ±3.0 | +0.0 ±4.8 |
| onetimer | +3.5 ±2.2 | +0.5 ±1.1 | +0.0 ±3.4 |
| deke | +6.5 ±2.3 * | +1.5 ±2.5 | +5.0 ±4.4 |
| pass | +5.0 ±3.1 | +6.0 ±3.2 | +16.7 ±6.4 * |
| sprint | -9.5 ±4.1 * | -3.5 ±3.8 | +0.0 ±5.8 |
| stop | -10.0 ±4.0 * | -5.0 ±4.0 | +0.0 ±7.9 |
| shield | -2.5 ±3.6 | -6.0 ±3.6 | +5.0 ±7.7 |
| spin | +2.0 ±3.2 | +3.0 ±3.4 | +0.0 ±7.1 |
| poke | +3.5 ±3.1 | -4.0 ±3.1 | +6.7 ±6.7 |
| lift | +0.5 ±3.6 | -2.5 ±3.4 | +3.3 ±7.1 |
| check | -5.5 ±3.6 | -9.0 ±3.8 * | +3.3 ±7.9 |
| brace | +2.0 ±3.4 | -0.5 ±3.1 | +3.3 ±7.1 |

thirdjam's regular hand at pro on hockey.thirdlife: 68.5 ±3.3; without the pass 71.0 ±3.2; without any shot 20.5 ±2.9.

### The T7 verdicts

| Verdict | Verbs | The figures (re-planning arm / dead-key arm, points of wins, 200 seeds) |
|---|---|---|
| **Carries the game** | every shot | -56.5 ± 4.0 |
| **Matters** (two standard errors in at least one arm, the same sign in the other) | the charged shot; the stop; the sprint; the body check | -10.0 / -9.5; -10.0 / -5.0; -9.5 / -3.5; -5.5 / -9.0 |
| **Leans to mattering, not shown** | the far-side carry | -2.5 / -6.0 (± 3.6) |
| **No worth shown, alone** | the tap shot; the stick lift; the poke; the brace; the spin; the one-timer | -1.5 / -2.5; +0.5 / -2.5; +3.5 / -4.0; +2.0 / -0.5; +2.0 / +3.0; +3.5 / +0.5 |
| **Costs the hand that uses it** | the pass; the deke | +5.0 / +6.0 (± 3.2); +6.5 / +1.5 (± 2.4) |
| **Wins alone** | none | skating alone wins 7 % (round 2's matrix, 60 seeds) |

How to read the verdicts, and what I would do with them (nothing was changed in round 3b: the matrix measures the
cartridge as landed in 3a):
- **Two arms, because each leans.** A planner without a verb re-plans (it leans toward "costs nothing"); the same hand still
  pressing a dead key leans the other way. A verb "matters" here only when one arm shows two standard errors and the other
  agrees in sign. The sprint and the stop, which round 2's 60 seeds could not see, are clear at 200.
- **The three ways to take a puck hide each other.** The lift, the poke and the body check do one job; take one away and
  the hand uses the others. Alone, only the check shows (-9.0 with the key dead). Their worth as a GROUP was not measured
  (the matrix has no cell without all three): the first cell I would add.
- **The pass costs about five points in both arms** (and thirdjam's scripted hand wins 2.5 more without it; on thirdjam
  itself it won 9 more). It is less bad than in thirdjam and it does not pay: T3 is not met.
- **The deke is the one verb I would cut.** Dead in thirdjam by PLAY, worth nothing here with the key dead (+1.5), and the
  hand does better without it in its menu (+6.5 ± 2.3). The spin shows nothing in either arm: the second candidate.
  Cutting is a design decision for the next round (the Director: no cartridge change in 3b), and the keys are the shell's.
- **The one-timer is dead because the pass is.** It is the genre's signature goal (CASES: NHL '94); it will show when a
  pass arrives and comes back. Kept, tied to T3.
- **The brace** shows nothing in either arm (+2.0 / -0.5). The owner asked for it by name (R-0064): kept, reported as not
  shown to matter, his to judge by hand.
