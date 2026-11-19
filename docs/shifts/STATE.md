# Third Life: shift state

The campaign memory for `/shift` (`.claude/skills/shift/SKILL.md`). Read in full at the start of every shift; the wrap
writes it back. Newest shift-log entry last.

## Now
- Focus (owner, 18 Nov): the game must become playable and fun before anything is measured. The walking figure (look, jump,
  slides, run), camera and terrain immersion, the parkour course, and the minigame editor as the backbone of player-made
  games. Hockey decisions and win measurement deferred; the construction process later.
- Next 3: (1) the owner plays the morning exe (Pip by the road, parkour plot west, walker feel); (2) the editor's design
  direction, judged from the night's mockups and slice; (3) parkour fun pass after the owner plays it.

## Open owner verdicts
- Play exe f871d0c (or tomorrow's): Pip at the start, parkour plot at the west end of the road, `tl play parkour`.
- Walker: A/D sidestep or turn (walker-feel retro).
- The night of 19 Nov's verdict page (asks per lane).

## Backlog (accepted by the owner, not yet scheduled)
- Site Boss modelled in Blender (approved concept, second to Pip; Opus solo).
- Pip as a character with a role (concept: the photo-finish judge; the parkour finish is a natural home).
- A second real Foreman job through the hand checks; the construction process (deferred by the owner).
- ex_car asphalt look (held back 18 Nov: looked worse than grass).

## Decisions
- 2026-11-18: Astra trial routes (memory `project-astra-trial-results`): Opus directing Astra for code/review/tools; Astra
  alone for concept art and look by eye; Opus alone for Blender.
- 2026-11-18: losing trial arms removed on the owner's word; D's and E's parkour code was uncommitted and went with them
  (reports and stills kept in `.spark/Spark/briefs/astra-trial/results/`). Lesson: archive an arm's diff before removing it.
- 2026-11-18 20:40: night of 19 Nov handshake: lanes parkour polish, walker & terrain residue, bug hunt round 2, and the
  minigame editor UI/UX (owner's words in its brief); 3 lanes at once, mixed models; land + push by 08:00; verdict page
  with short videos.

## Shift log

### 2026-11-19 night: plan
Handshake 18 Nov 20:40: lanes parkour (Astra alone), walker (Opus directing Astra), editor (Opus + Astra mockups); hunt2
queued after the first landing. Start 00:03, standups hourly at :47, verdict 07:12, land + push by 08:00, verdict page with
clips. Plan: `docs/shifts/2026-11-19-night/PLAN.md`. Before the shift: `bugfix-37` (one Opus builder, the 37 hunt defects)
lands on main.
- 21:25 pre-shift: bugfix-37 landed (main `120208a`): 35 of 37 fixed, Q24 partly, Q31 deferred to the owner; full gate on
  main 14/14 green (kernel.selftest 219, +39), windowed tour PASS. Owner asks from it: slope jump (D14), camera near
  crowns (D5, three choices), slide hand (Q31); see `docs/reports/bugfix-37/REPORT.md` "For the owner".
- 00:08 launched parkour, walker, editor from c8b88fc (agents recorded in PLAN.md); hunt2 waits for the first landing.
- 00:55 parkour landed (merge `9ea78b0`, Astra alone 16 min, 183 k tokens); hunt2 launched from it.
- 00:47 merged tree after parkour: fast, kit 91/91, packs 34/34, world 8/8, headless tour PASS.
- 00:57 standup: parkour landed; walker, editor, hunt2 on track (editor near done); 37 GB free.
- 01:35 editor landed (merge `eac9e92`; fast 5/5, ui.selftest 116, item 91); re-dispatched: change a decision from the game sheet + Astra-alone look pass (worktree n19-editor2).
- 01:57 standup: walker, editor round 2 and hunt2 on track; walker's crest ink costs some bluff crawl (owner ask); 35 GB free.
- 02:20 editor round 2 landed (`c9fe14f`; ui.selftest 123, fast 5/5): change-a-decision + Astra-alone look pass; round 3 dispatched (lost click, village map as home).
- 02:45 hunt2 landed (`30cfbed`; 18 fixes, kernel.selftest 240): main full gate green except packs (hockey many_budget 1.07 ms under load 13; A/B vs pre-merge shows load, not a regression) and perf NOT RUN; both re-run at the verdict. 03:06 hunt2 round 2 dispatched (B8, A1, C9, B11, C8).
- 02:57 standup: walker nearly done (gate green but perf); editor round 3 found the lost click's mechanism; hunt2 round 2 fixed B8.
- 03:28 walker landed (`58a80d1`; crowns 0/0, V wedge, pad swap, ink coverage, crest ink, A/D behind TL_AD_KEYS; 2.04 M Astra tokens); blocks renumbered 400-430; full gate on main running. 03:31 walker round 2 dispatched (hunt2's B2, B4 highs, then walker-scope mediums/lows).
- 03:33 main full gate after walker: all PASS (kernel.selftest 250, packs 34/34, world 8/8) except perf NOT RUN (busy).
- 03:50 hunt2 round 2 (`376dc23`: B8, A1, C9, B11, C8) and editor round 3 (`d47f14b`: village board home; lost click = drive artefact, fixed) landed; fast 5/5 (devx 226), seeds 39, ui 125, hunt2. 36, gate. 7, windowed tour PASS. hunt2 and editor finished (editor's next item, the lot in the 3D village, needs walker's site.gd: after walker round 2). Live: walker round 2.
- 04:05 walker round 2 landed (`7b8c2bf`: hunt2 B2/B4 highs + B7, B3, B9, A13, H1, A5, B12; its gate one run green incl. perf, kernel.selftest 259); main full gate running. Editor round 4 dispatched: the chosen lot into the 3D village (claims site code now walker is done).
- 03:57 standup: three lanes finished and landed; editor round 4 on track; main full gate running.
- 04:40 editor round 4 landed (`16534db`: the chosen lot in the 3D village; the workbench now knows the river); every lane landed. 04:46 short last rounds (until 06:15) to fill idle capacity within the agreed scope: walker 3 (bluff crawl back, slide-entry dip, crown swing behind a flag), parkour 2 (D's cabin, pines, newcomer retry, road blend).
- 05:00 standup: walker round 3 landed; parkour round 2 done (review); then the verdict early.
