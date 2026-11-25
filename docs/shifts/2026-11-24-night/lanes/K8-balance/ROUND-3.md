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
