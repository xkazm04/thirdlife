# Integration 1 feedback for dio-astra (Director 13:45, plus operator measurements)

## The Director, verbatim
"Integration 1 done. The exe is `dist/day/dio/ThirdLife` (PLAY-DIORAMA.cmd); export.check PASS. Joined gates on 1070eea
all PASS: fast, world 8/8 (base hashes), packs 48/48, kit 95/95, style. 9, rig. 14, character. 1, dio. 4, surf. 5. The
joined shots (17) are in `C:/Users/kazda/kiro/third-life/.claude/worktrees/d20-dio/.tl/i1/shots/`. By eye against
board 4: 07_parkour_road is sharp at last, with pebbles, felt grass and wood readable. Gaps in your scope: the light
reads flat and even over the meadow, without the board's warm raking light and the long soft shadows that make felt
fibres read; the clouds are still grey-white, not cream; the grade is cooler than the board's warm amber. The owner
has not played it yet; their words follow when they do."

## Operator measurements (joined tree 1070eea, `.tl/j1/dio/`; frames scaled to 1280x720)
| | luma mean | lower half luma p5 / p50 / p95 (spread p95-p5) | frame mean RGB | mean R-B | cloud: top 5 % luma of rows 0-250 |
|---|---|---|---|---|---|
| board 4 | 129 | 59 / 133 / 181 (122) | (180,116,65) | 115 | (252,216,160) |
| 07_parkour_road | 132 | 89 / 129 / 159 (70) | (167,127,69) | 99 | (245,210,145) |
| 01_walker_road | 133 | 103 / 129 / 155 (53) | (161,131,72) | 89 | (243,212,158) |

The board's lower half spans about twice the luma range of ours (deeper shade, brighter lit faces); its frame mean is
redder and less green.

## Classic note
The committed joined tree is classic-exact against the fixed base under seeded capture with a fresh cache per side
(tour 14/16 and flight 6/6 at 0/255; 09/10_paddle differ by the same amount between two seeded base runs: noise).
