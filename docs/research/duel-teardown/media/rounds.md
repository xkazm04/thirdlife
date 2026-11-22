# How long a duel round lasts, and how it ends (N1 round 3, 22 Nov night)

The ladder tests of `engine/packs/duel/tests/bot_ladder_<rival>_<hand>.gd`, run headless on main `17973df`, seeds 1-8, one
best-of-3 match a seed (`.tl/duel/run.sh <cell> 8`; summary `.tl/duel/sum.mjs`; raw JSON in `.tl/duel/out/`). The hand is a
scripted `TLHand` through `tests/support/pilot.gd`: a bot that reads the game state, not a person.

| cell | matches won | rounds | rounds ended by KO | round length, median (min-max) | first 60 s of round 1, mean: hits landed / taken |
|---|---|---|---|---|---|
| the Wall, newcomer | 4 of 8 | 21 | 21 (100 %) | 20.6 s (10.3-30.9) | 6.3 / 1.8 |
| the Wall, regular | 6 of 8 | 19 | 19 (100 %) | 18.2 s (11.2-32.3) | 6.8 / 0.4 |
| the Duelist, newcomer | 1 of 8 | 20 | 20 (100 %) | 24.1 s (11.5-38.9) | 10.4 / 5.6 |
| the Duelist, regular | 8 of 8 | 17 | 17 (100 %) | 24.2 s (14.8-36.9) | 10.3 / 3.3 |
| the Dancer, regular | 8 of 8 | 16 | 16 (100 %) | 20.1 s (13.6-24.4) | 8.6 / 0.8 |

Every one of 93 rounds ended by a knockout, in a median of 18-24 s, against a round clock of 70 s (`data/tuning.json:5`).
The time limit was never reached.

The first 25 s with nothing pressed (`tl play duel`, a window, `sheet_duel_first25s.jpg`): during the Wall's lessons, the
player's health reads 100 at 0:01, 80 at 0:03, 60 at 0:05, 51 at 0:07, 42 at 0:09, 22 at 0:17 and 14 at 0:19. The lessons'
blows are real (`scripts/lessons.gd:8`: "The attacks are real: they hit, block, parry and count like any other").
