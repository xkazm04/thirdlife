# dio-astra, round 4 (about 15:10 to 16:05): brief for Astra

Round 3 is verified by the operator (below). Continue in this session's context: your notes, `ASTRA-BRIEF-r3.md`,
`ASTRA-FEEDBACK-i1.md`.

## Operator verification of round 3 (my own runs)
- Tour sharpness, joined -> r3 (my shots `.tl/j1/dio` -> `.tl/v3/dio`): far 232.8 -> 361.6, mid 224.7 -> 333.4,
  near 204.3 -> 277.5. Flight: 252.5 / 221.3 / 225.4 -> 460.8 / 373.4 / 340.7. Your figures reproduce.
- Classic, seeded capture, a fresh cache per side, fixed base vs r3: tour 14/16 and flight 6/6 at 0/255; 09/10_paddle
  differ (max 5 and 44), which two seeded base runs also do (noise). Parkour and both figure shots 0/255 in ordinary
  runs; hockey moves 95/255 in 0.01 % of pixels, as between two base runs.
- Gates: fast PASS; style. 11/11, rig. 14/14 (the rest of my run lands while you work; I will tell you if anything fails).
- By eye beside the board: 07 and 01 now carry warm low light, long shadows and cream clouds; the overall read is close
  to the board's mood. 13_lot_river_road is a dark backlit olive slope.

## Measured gaps for this round (factual)
The figure in the visitor view (`stills/diorama/visit_01_yard.jpg`) against the board's runner (1280x720 board crop
x 560-710, y 480-580 for the jacket and x 600-670, y 405-470 for the hair; ours x 850-1070, y 670-810 and
x 900-1010, y 580-680 at 1920x1080):

| | jacket red pixels: mean RGB | jacket luma p10 / p90 | hair mean RGB | hair luma p5 / p95 |
|---|---|---|---|---|
| board | (196,73,35) | 53 / 162 | (150,67,20) | 48 / 171 |
| ours, visit_01_yard | (157,68,37) | 44 / 177 | (90,37,19) | 37 / 69 |

On the board the hair carries bright warm highlights on each rolled piece; ours is a dark brown mass with p95 luma 69.
The jacket is less saturated red than the board's. The figure's own TEAMS.md items: separate clay pieces for jacket,
trousers and hair, shallow fingerprint normals, sparse chipped paint at cuffs and boots, a toy feel in motion.

Also open from your r3 notes: GPU cost +27 % on tour6 (busy machine), the river bank at 13 reads dark when backlit.

## This round
Pick the biggest gap you see in your scope, with the figure under the new light first in line (the owner preferred
your figure; it now stands in a warmer, higher-contrast frame). Your design.

**By 16:05** the tree is clean and working with gates green and classic exact; append "Round 4" to `ASTRA-NOTES.md`.
Integration 2 is 16:30. Keep the lane folder light: re-encode `clip.mp4` to about 8 MB (it is 30 MB), no new mp4
over 10 MB. Do not write `REPORT.txt` (that is the operator's deliverable); your summary goes in `ASTRA-NOTES.md`.
Rules as before (read-only git, no commit, your scope, no unfiltered full tier, never kill a process you did not start).
