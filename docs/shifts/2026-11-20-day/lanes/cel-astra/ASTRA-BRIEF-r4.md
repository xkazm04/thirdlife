# cel-astra, round 4 brief (20 Nov 2026, 14:55; for GPT 6.2 Astra, a fresh session)

You are the designer and builder of arm **cel-astra** (team cel, "crisp cel"): the frame (sky, clouds, sun, light,
shadows, grade, post, antialiasing, sharpness) and the figure. An Opus operator runs you, re-runs every gate and looks
at every still; measured figures beat adjectives. This is a fresh session: your rounds 1-3 are written up in
`docs/shifts/2026-11-20-day/lanes/cel-astra/ASTRA-NOTES.md` (read the Round 3 section in full, the rest as needed);
it is your memory. Also read `ASTRA-BRIEF-r3.md` (the previous brief), `PATCHES.md` (yours) and
`docs/shifts/2026-11-20-day/lanes/cel-fable/PATCHES.md` (the partner's answers), `COMMON.md` and `TEAMS.md`
(rules and scope), and look at board 2: `docs/shifts/2026-11-20-night/target/2-crisp-cel.jpg`.

Worktree: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d20-cel-astra`. Read-only git is fine; **do not commit**.
Never kill a process you did not start. **Do not write lines into STANDUP.md** (the operator keeps it; last round a
line there said `done`, and the lane is not done until 19:45). Your notes go into ASTRA-NOTES.md and PATCHES.md.

## Rules that bite this round
- The ground's paints and bands (`toon` section, `toon_cel.gdshader`, the palette) are **cel-fable's**: pass it
  numbers in PATCHES.md, never edits. If you change the sun's colour, energy or the tonemap, say so there (its palette
  is fitted to your sun).
- `engine/boot/boot.gd` is at 600/600 lines and `tl_style.gd` near 600: put new code in your own files.
- `TL_STYLE=classic` stays exact; game hashes stay; figure rails as in TEAMS.md.

## The operator's verification of round 3 (my runs, tree as you left it)
- `check --tier fast` PASS 5/5. `check --tier full --only world,packs,kit.selftest`: world 8/8 (hashes as base),
  kit 95/95; packs 47/48: the one failure is hockey `invariants.many_budget` (frame p50 1.222 ms against a 1.0 ms
  wall-clock budget, a known load-sensitive check; I am re-running it alone). All 46 pack state hashes are identical
  to your round-1 reference base (`.tl/astra-r1/reference/.tl/gate-packs`).
- Classic proof: the 18 reproducible shots are 0/255 against `.tl/r0/classic`; the other 9 within their noise.
- Selftests: running while you start (`style.` so far 9 pass, 1 fail: `style.cel.exe_aa`, the clamp). The two clean-load failures (`character.cel.wardrobe`,
  `style.cel.exe_aa`) wait on cel-fable's `toon.shade_k` 0.85.

## The Director's words (14:35, verbatim)
"(a) The sky, the light bands and the figure read well. The visitor's road frame is the closest frame to the board.
(b) The meadow is one flat lemon field from the near ground to the horizon. That is Fable's field. Your part of it is
the cast shadows: the board's shadows are long, plum and cut; ours are big green-grey patches with no plum hue.
(c) Distant contours shimmer, as you found.
(d) The figure is small in frame compared with the board's chase camera (the board's runner fills about a third of
the height). Look at the chase-camera distance and FOV under crisp only.
Pick the biggest of these and build. Make the plum shadow hue your first round-4 item."

## Measurements for (b) and (d) (operator, medians of 7x7 or 9x9 patches)
Board 2 (1280x720):
| where | RGB |
|---|---|
| fence cast on lit grass, lower left (75,645) and (240,575) | 80,106,35 and 77,103,35 |
| lit grass beside it (60,612), (200,660) | 191,174,22 and 198,178,19 |
| bush cast on the road (418,525) | 124,79,74 |
| lit road (470,600) | 247,149,69 |
So on the board the cast on the road is a red-brown plum, and the cast on the grass is a dark olive in which blue
rises (22 -> 35) while red and green fall to about 0.4 and 0.6 of the lit grass.

Your round-3 51_road_visitor (my capture `.tl/op-r3v/crisp/51_road_visitor.png`, 1920x1080):
| where | RGB |
|---|---|
| tree cast on grass (700,580), (780,545), near the trunk (600,425) | 83,109,13 / 90,123,11 / 92,122,13 |
| a lighter patch inside that cast (640,560) | 165,173,26 |
| lit grass (300,600) | 184,186,27 |
| figure cast on the road (1300,1010) | 117,73,71 |
| lit road (700,1000) | 241,148,70 |
So the road cast is within 7 levels of the board's; the grass cast has blue 11-13 against the board's 35 (it falls
from the lit 27 instead of rising). The shapes: on the board, the casts on the meadow are thin long bands from fence
rails and posts; in 51 the casts on the meadow are the broad crowns of the trees.

(d) In 51_road_visitor the runner spans rows 590-985 of 1080 (36.6 %); on board 2 about 37 %. The parkour run
(31_parkour_run, the pack's own chase camera, HUD on) shows the blue runner much smaller. Please measure which cameras
the owner meets (the exe's village walk is the visitor camera; games have their own) before changing any.

## The round
Until about **16:05**: then a clean working tree, ASTRA-NOTES.md "Round 4" on top (what changed, keys, measurements,
selftests with their lines), PATCHES.md current. The plum cast-shadow hue first, then the biggest of (c) and (d) by
your measurement. Token budget for this session: please stay under about 450k.
