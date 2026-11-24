# K6 round 3: the booth's voice and the hall's reactions, frame by frame

Generated from the selftest cases' own output (`TL_BOOTH_TABLE` of `engine/cores/rink/audio/review/booth_case.gd`,
`TL_REACT_TABLE` of `engine/cores/rink/arena/review/react_case.gd`). No ear has heard the voice: these are frames and files.

## 1. A recorded match: every line the booth said, every bark, every cut

The bare core, seed 1, bots at pro, an idle hand, 7163 frames, final score [2, 3], through the pack's own HUD (lane K5's
`hud.gd`: its booth, its caption picker, its bark lane; one picker). `voice`: the line the caption started that frame, said
from its own file at -9.24 dB (Volume 1 x 0.345, what thirdjam's own output gives a line: measured), the music ducked to 0.45; `bark`: MS_bark
for a bark said; `voice_cut`: the booth cut its line for a bark at the human and started none (FadeOut 9 frames).

| Frame | What | Line | Caption text | Clip |
|---|---|---|---|---|
| 0 | voice | period.take_1.01 | Welcome to the rink: blue against orange, first period. | vo/VO_Commentator_period_take_1_01.ogg |
| 90 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 308 | voice | shot.orange.01 | Orange shoots! | vo/VO_Commentator_shot_orange_01.ogg |
| 375 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 375 | voice_cut | | | (fade 9 frames) |
| 570 | voice | check.strip.03 | Check, and a turnover. | vo/VO_Commentator_check_strip_03.ogg |
| 810 | voice | pass.any.02 | Puck moves quickly. | vo/VO_Commentator_pass_any_02.ogg |
| 1050 | voice | board.rim.01 | Rimmed around the back. | vo/VO_Commentator_board_rim_01.ogg |
| 1127 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 1507 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 1936 | voice | pass.any.01 | Nice feed. | vo/VO_Commentator_pass_any_01.ogg |
| 2146 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 2326 | voice | board.hard.01 | Off the boards and out. | vo/VO_Commentator_board_hard_01.ogg |
| 2706 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 2864 | voice | pass.any.03 | Tape to tape. | vo/VO_Commentator_pass_any_03.ogg |
| 3020 | voice | pass.orange.01 | Orange moving it around. | vo/VO_Commentator_pass_orange_01.ogg |
| 3127 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 3127 | voice | goal.blue.01 | Blue scores! | vo/VO_Commentator_goal_blue_01.ogg |
| 3277 | voice | goal.for.02 | Picture perfect. | vo/VO_Commentator_goal_for_02.ogg |
| 3367 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 3458 | voice | breakaway.blue.03 | Blue on the break, nobody back! | vo/VO_Commentator_breakaway_blue_03.ogg |
| 3585 | voice | goal.blue.03 | It's in, for blue! | vo/VO_Commentator_goal_blue_03.ogg |
| 3735 | voice | goal.for.03 | Right where it had to go. | vo/VO_Commentator_goal_for_03.ogg |
| 3864 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 4050 | voice | pass.any.02 | Puck moves quickly. | vo/VO_Commentator_pass_any_02.ogg |
| 4277 | voice | shot.orange.03 | Orange lets it go! | vo/VO_Commentator_shot_orange_03.ogg |
| 4360 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 4524 | voice | poke.clean.02 | Quick stick, puck gone. | vo/VO_Commentator_poke_clean_02.ogg |
| 4704 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 4730 | voice | goal.orange.02 | In! Orange scores! | vo/VO_Commentator_goal_orange_02.ogg |
| 4880 | voice | goal.against.03 | Nothing anyone could do. | vo/VO_Commentator_goal_against_03.ogg |
| 4951 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 4951 | voice_cut | | | (fade 9 frames) |
| 5192 | voice | check.cross.10 | Cross-check! The glass felt that too. | vo/VO_Commentator_check_cross_10.ogg |
| 5376 | voice | pass.blue.02 | Blue playing keep-away. | vo/VO_Commentator_pass_blue_02.ogg |
| 5456 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 5456 | voice_cut | | | (fade 9 frames) |
| 5679 | voice | pass.any.03 | Tape to tape. | vo/VO_Commentator_pass_any_03.ogg |
| 5972 | voice | board.hard.02 | Rattles the boards. | vo/VO_Commentator_board_hard_02.ogg |
| 6022 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 6022 | voice_cut | | | (fade 9 frames) |
| 6214 | voice | pass.to_human.01 | Into your lane. | vo/VO_Commentator_pass_to_human_01.ogg |
| 6461 | voice | board.rim.02 | Wrapped around the boards. | vo/VO_Commentator_board_rim_02.ogg |
| 6616 | voice | shot.orange.02 | Shot from orange! | vo/VO_Commentator_shot_orange_02.ogg |
| 6626 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 6626 | voice | goal.orange.03 | It's in, for orange! | vo/VO_Commentator_goal_orange_03.ogg |
| 6776 | voice | goal.against.01 | That one stings. | vo/VO_Commentator_goal_against_01.ogg |
| 6902 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 7132 | voice | breakaway.orange.01 | Orange is in alone! | vo/VO_Commentator_breakaway_orange_01.ogg |
| 7163 | bark | | | sfx/bark_v0_s100_t0.ogg |
| 7163 | voice | lose.close.01 | So close. One goal in it. | vo/VO_Commentator_lose_close_01.ogg |

| | ours (bare core, idle hand, 7163 frames) | thirdjam (its own played match, scripted hand, 13620 frames) |
|---|---|---|
| lines said | 30 (15.1 a minute) | 53 (14.0 a minute) |
| barks (MS_bark) | 17 (8.5 a minute) | 34 (9.0 a minute) |
| lines cut | 4 | 0 (JAMVO_CUT lines) |

Two different plays (two hands): the rates are set beside each other, not the moments. thirdjam's picker is salted with
the wall clock (CommentarySystem.cpp:692), so its lines are not reproducible either; ours is seeded from the match's seed.

## 2. thirdjam's own match through our reactions

thirdjam's own log of a played match (K6 round 1's reference run, 13620 frames): its goal and board events fed to
`rink_react.gd`; beside each, the `JAMRINK react` line thirdjam's ARinkActor logged for the same event (it prints
Strength to 0.001, tilt and hop to 0.1, distance to 0.01). 45 of 45 answered, the same cap and piece every time.

| Frame | Reaction | Ours | thirdjam's log |
|---|---|---|---|
| 1163 | cap | cap 41, tilt 26.00 deg, hop 22.00 cm, 0.711 m | cap 41, tilt 26.0 deg, hop 22.0 cm, 0.71 m |
| 1307 | goal | end -x | end -x |
| 1786 | cap | cap 10, tilt 19.99 deg, hop 16.92 cm, 0.553 m | cap 10, tilt 20.0 deg, hop 16.9 cm, 0.55 m |
| 1786 | rattle | ArenaBenchPos 2.692 deg | ArenaBenchPos 2.69 deg |
| 2419 | cap | cap 4, tilt 26.00 deg, hop 22.00 cm, 0.709 m | cap 4, tilt 26.0 deg, hop 22.0 cm, 0.71 m |
| 2476 | cap | cap 6, tilt 19.24 deg, hop 16.28 cm, 1.248 m | cap 6, tilt 19.2 deg, hop 16.3 cm, 1.25 m |
| 2484 | cap | cap 5, tilt 12.53 deg, hop 10.60 cm, 1.738 m | cap 5, tilt 12.5 deg, hop 10.6 cm, 1.74 m |
| 2493 | cap | cap 6, tilt 13.90 deg, hop 11.76 cm, 0.209 m | cap 6, tilt 13.9 deg, hop 11.8 cm, 0.21 m |
| 2742 | cap | cap 56, tilt 22.28 deg, hop 18.85 cm, 0.970 m | cap 56, tilt 22.3 deg, hop 18.9 cm, 0.97 m |
| 2755 | cap | cap 56, tilt 21.98 deg, hop 19.63 cm, 0.409 m | cap 56, tilt 22.0 deg, hop 19.6 cm, 0.41 m |
| 2784 | cap | cap 54, tilt 17.58 deg, hop 14.87 cm, 1.232 m | cap 54, tilt 17.6 deg, hop 14.9 cm, 1.23 m |
| 3531 | cap | cap 3, tilt 26.00 deg, hop 22.00 cm, 1.513 m | cap 3, tilt 26.0 deg, hop 22.0 cm, 1.51 m |
| 3903 | cap | cap 10, tilt 26.00 deg, hop 22.00 cm, 1.774 m | cap 10, tilt 26.0 deg, hop 22.0 cm, 1.77 m |
| 3903 | rattle | ArenaBenchPos 3.500 deg | ArenaBenchPos 3.50 deg |
| 3957 | cap | cap 12, tilt 18.77 deg, hop 15.88 cm, 1.375 m | cap 12, tilt 18.8 deg, hop 15.9 cm, 1.37 m |
| 3957 | rattle | ArenaBenchPos 2.527 deg | ArenaBenchPos 2.53 deg |
| 4252 | goal | end -x | end -x |
| 4670 | cap | cap 16, tilt 12.95 deg, hop 10.96 cm, 0.529 m | cap 16, tilt 13.0 deg, hop 11.0 cm, 0.53 m |
| 4670 | rattle | ArenaBenchNeg 1.743 deg | ArenaBenchNeg 1.74 deg |
| 4951 | cap | cap 21, tilt 13.23 deg, hop 11.20 cm, 0.570 m | cap 21, tilt 13.2 deg, hop 11.2 cm, 0.57 m |
| 4957 | cap | cap 21, tilt 12.27 deg, hop 10.38 cm, 1.433 m | cap 21, tilt 12.3 deg, hop 10.4 cm, 1.43 m |
| 5323 | cap | cap 53, tilt 20.96 deg, hop 17.73 cm, 1.137 m | cap 53, tilt 21.0 deg, hop 17.7 cm, 1.14 m |
| 5341 | cap | cap 54, tilt 24.41 deg, hop 20.66 cm, 1.231 m | cap 54, tilt 24.4 deg, hop 20.7 cm, 1.23 m |
| 5894 | cap | cap 57, tilt 26.00 deg, hop 22.00 cm, 1.307 m | cap 57, tilt 26.0 deg, hop 22.0 cm, 1.31 m |
| 5917 | cap | cap 57, tilt 21.37 deg, hop 18.08 cm, 0.234 m | cap 57, tilt 21.4 deg, hop 18.1 cm, 0.23 m |
| 5979 | cap | cap 57, tilt 20.07 deg, hop 16.98 cm, 1.348 m | cap 57, tilt 20.1 deg, hop 17.0 cm, 1.35 m |
| 6350 | cap | cap 4, tilt 15.26 deg, hop 12.91 cm, 0.543 m | cap 4, tilt 15.3 deg, hop 12.9 cm, 0.54 m |
| 6383 | cap | cap 2, tilt 23.95 deg, hop 20.26 cm, 1.215 m | cap 2, tilt 24.0 deg, hop 20.3 cm, 1.21 m |
| 6385 | cap | cap 2, tilt 26.00 deg, hop 22.00 cm, 1.611 m | cap 2, tilt 26.0 deg, hop 22.0 cm, 1.61 m |
| 6393 | cap | cap 1, tilt 20.55 deg, hop 17.39 cm, 0.379 m | cap 1, tilt 20.6 deg, hop 17.4 cm, 0.38 m |
| 6519 | cap | cap 66, tilt 24.93 deg, hop 21.10 cm, 1.034 m | cap 66, tilt 24.9 deg, hop 21.1 cm, 1.03 m |
| 6572 | cap | cap 71, tilt 25.22 deg, hop 21.34 cm, 0.251 m | cap 71, tilt 25.2 deg, hop 21.3 cm, 0.25 m |
| 7257 | cap | cap 35, tilt 12.01 deg, hop 10.16 cm, 1.593 m | cap 35, tilt 12.0 deg, hop 10.2 cm, 1.59 m |
| 7299 | cap | cap 56, tilt 20.90 deg, hop 17.69 cm, 0.726 m | cap 56, tilt 20.9 deg, hop 17.7 cm, 0.73 m |
| 7656 | cap | cap 69, tilt 26.00 deg, hop 22.00 cm, 1.783 m | cap 69, tilt 26.0 deg, hop 22.0 cm, 1.78 m |
| 8464 | cap | cap 2, tilt 23.89 deg, hop 20.22 cm, 0.951 m | cap 2, tilt 23.9 deg, hop 20.2 cm, 0.95 m |
| 8476 | cap | cap 1, tilt 26.00 deg, hop 22.00 cm, 1.231 m | cap 1, tilt 26.0 deg, hop 22.0 cm, 1.23 m |
| 8624 | cap | cap 7, tilt 24.91 deg, hop 21.08 cm, 1.422 m | cap 7, tilt 24.9 deg, hop 21.1 cm, 1.42 m |
| 12221 | cap | cap 33, tilt 26.00 deg, hop 22.00 cm, 0.563 m | cap 33, tilt 26.0 deg, hop 22.0 cm, 0.56 m |
| 12240 | cap | cap 33, tilt 26.00 deg, hop 22.00 cm, 1.419 m | cap 33, tilt 26.0 deg, hop 22.0 cm, 1.42 m |
| 12364 | cap | cap 41, tilt 13.65 deg, hop 11.55 cm, 0.733 m | cap 41, tilt 13.7 deg, hop 11.6 cm, 0.73 m |
| 12426 | cap | cap 44, tilt 26.00 deg, hop 22.00 cm, 0.401 m | cap 44, tilt 26.0 deg, hop 22.0 cm, 0.40 m |
| 12462 | cap | cap 42, tilt 26.00 deg, hop 22.00 cm, 1.046 m | cap 42, tilt 26.0 deg, hop 22.0 cm, 1.05 m |
| 12928 | cap | cap 67, tilt 26.00 deg, hop 22.00 cm, 0.227 m | cap 67, tilt 26.0 deg, hop 22.0 cm, 0.23 m |
| 12936 | cap | cap 67, tilt 29.52 deg, hop 24.98 cm, 0.696 m | cap 67, tilt 29.5 deg, hop 25.0 cm, 0.70 m |
