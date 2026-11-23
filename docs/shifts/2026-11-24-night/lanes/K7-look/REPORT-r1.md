K7 look, REPORT round 1 (23 Nov 2026): landable round 1
Worktree C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-look, branch hk-look (cut from hokej at 75844e9). Nothing committed.

OUTCOME

The skater now reads as thirdjam's: felt jersey with the number on the back patch and the team's crest on the chest,
clay skin and helmet, a soft face, cream trim, no ink line. It is thirdjam's own material ported node by node into a
new shader, lit by thirdjam's own 18 rig lights. Flat cel is kept as the second look, unchanged.
One thing must be wired before the game shows this light: see "For the Director", point 1.

ACCEPTANCE

1. Pairs, thirdjam above and ours below, four angles close and at game distance, blue and orange, looked at: MET.
   media/r1_pair_blue_close.jpg, r1_pair_orange_close.jpg, r1_pair_blue_zoom.jpg, r1_pair_orange_zoom.jpg,
   r1_pair_game_distance.jpg, r1_pair_far_end.jpg. thirdjam's side is its own figure in Unreal under LR_P3_Clay,
   dressed as its driver dresses it: 16 of 16 shots fresh. What my eye still rejects is in ROUND-1.md; the two that
   matter are below.
2. Numbers and crest for all ten skaters: MET. media/r1_ten_skaters_felt.jpg (7 13 42 4 5, 9 21 88 14 15; comet on
   blue, fox on orange) and selftest look.skater.numbers.
3. No existing shader byte changed: MET. look.skater.shaders_kept, surf.classic_source, celsurf.classic_files PASS.
   Cost for ten skaters: MET, with the limit of what was measured. Ten skaters before the game camera at 1280 x 720:
   whole frame 1.10 and 0.98 ms in felt, 0.98 and 1.09 ms in cel (two runs each, 600 frames), 0.80 ms with the ten
   hidden; GPU 0.52 ms in both looks against 0.46 hidden. Felt costs nothing measurable over cel there; nothing is
   added to the per-frame script work (the materials are set once). Measured on an RTX 4090 with plain clip playback,
   not with lane K2's driver, and not at a close camera.
4. node devx/bin/tl.mjs check --tier fast: MET, exit 0, 5 of 5 steps, 248 units (after `npm ci` in foreman/ and the
   API bump of point 3 below; before them: arch and devx.test FAIL on the unbumped API, foreman.typecheck NOT RUN).

GATES (last run of each)

PASS  arch              [12/12]
PASS  assets            [4/4]
PASS  cards             [3/3]
PASS  devx.test         [229/229]
PASS  foreman.typecheck
selftest look.skater (block 850): 6 passed, 0 failed (numbers, instances, shader, variants, render, shaders_kept)
selftest rig.skater (block 810): 4 passed, 0 failed
selftest surf.: 5 passed; celsurf.: 9 passed; style.: 10 passed; 0 failed
Shown red: numbers, instances and render, by setting the patch's NumberOn to 0 and the jersey's FeltMottle to 0.8.
NOT RUN: the full tier (the Director's). Block 811 (rig.skater.driver, .oracle, .red) is not in this tree's
selftest.d, so lane K2's oracle was not run against my two edits to its files.

WHAT MY EYE REJECTS (the two that matter; the full list of eight is in ROUND-1.md)

1. Top surfaces are darker than the running game's. Same camera and same place on the rink as the game's still
   (media/r1_same_camera_same_place_game_over_ours.jpg): jersey back, shoulder and pants agree within a few levels
   (#121242 / #10163f, #16174a / #181f50, #0b0505 / #0b090a), the helmet is about a fifth darker (#181746 / #111639)
   and the patch a sixth (#c5a373 / #a6875d). My reading is indirect light, which is not ported; it is not confirmed.
2. Orange measured at the rink's centre is darker and redder than the game's orange skaters (ours #8f2f15 to
   #a84625, theirs #a94921 to #c35527). They stood elsewhere and where is not known, so this is not like for like.
Not looked at: motion (no film this round), the figure inside lane K6's hall, the exported game, a world plot.

CHANGED FILES

New:
  engine/style/shaders/body_felt.gdshader (+ .uid)   the port
  engine/style/tl_style_felt.gd (+ .uid)             TLStyleFelt
  engine/style/felt/T_Felt_Fibre.png, T_Clay_Thumb_N.png, T_Clay_Dent_N.png      (3.4 MB)
  engine/rigs/skater/look/tl_rig_skater_look.gd      TLRigSkaterLook: felt | cel, thirdjam's instance values
  engine/rigs/skater/look/T_Numbers_Varsity.png, T_Crest_Blue_Comet.png, T_Crest_Orange_Fox.png   (1.0 MB)
  engine/rigs/skater/look/look_gym.gd, look_gym.tscn, gym_rig.json, look_case.gd  (+ .uid)
  engine/tools/selftest.d/850-skater-look.sh
  docs/shifts/2026-11-24-night/lanes/K7-look/: ROUND-1.md, STANDUP.md, REPORT.txt, media/ (11 JPG), tools/
Edited in lane K2's files, exactly:
  engine/rigs/skater/tl_rig_skater_body.gd: old lines 110-122 (the comment and body of set_team_colour) replaced by
    new lines 110-130: set_team_colour now hands the mesh to TLRigSkaterLook.apply; new set_look(variant),
    look_refresh(), and two variables _look, _look_colour. setup() is untouched.
  engine/rigs/skater/tl_rig_skater.gd: line 154 (the comment over SetNumber) reworded, one line added at 157
    (`look_refresh()` in SetNumber). The comment at line 151 in SetTeam still says the crest is not drawn; left for K2.
Edited elsewhere: engine/style/STYLE.md (a section), engine/rigs/RIGS.md (a bullet), engine/kernel/API.md (version,
  section 25), engine/kernel/runner/manifest.gd (KERNEL_API 1.19 -> 1.20), docs/generated/API-INDEX.md, API-V1.json,
  REPORTS.md (written by `tl arch --index`).

BEHAVIOUR CHANGES

- Every TLRigSkater is felt by default. Flat cel: sk.set_look("cel"), TLRigSkaterLook.default_variant = "cel", or the
  environment variable TL_SKATER_LOOK=cel for a run.
- A felt skater carries no ink line and takes no shadow; it casts its own.
- Headless nothing changes: no shader, no mesh copy; lane K2's block 810 passes as before.
- No test expectation was moved.

DEVIATIONS (ROUND-1.md has all nine with reasons)

No shadow of the rig on the figure; no sky light or bounce; lane K6's film curve and tone gain 6.0 as they are; bloom,
upscaler and reflections not ported; the clay tier only; the pose before skinning in a run-time copy of the mesh;
drawn after the ink pass; kernel API 1.20; two clay normal maps in the tree twice.

FOR THE DIRECTOR

1. Wire the rig, or the game shows the fallback. TLStyleFelt.set_rig has to be called where lane K6 calls
   TLStyleArena.set_rig (hk-arena engine/cores/rink/arena/rink_arena.gd, about line 73), with the same lights,
   exposure and the two gains. Without it the figures are lit by the style's sun, not by the 18 lights the pairs were
   made under. I did not touch K6's file. Once both are on hokej, the rig sum and the film curve in body_felt.gdshader
   should become `#include "hall_rig.gdshaderinc"` (the uniform names are already K6's).
2. KERNEL_API is 1.20 here; lane K6 adds TLStyleArena and will want the same number. One of us re-runs
   `node devx/bin/tl.mjs arch --index` after the merge.
3. The cel look has no number and no crest. Give it them (a pass of its own per figure), or keep it as the "before"?
4. Is indirect light worth porting for the helmet and patch gap, and from which stills? K6's camera log gives the
   human's place per frame, which is how the like-for-like picture was made.
5. Lane K3's and K2's packs build skaters through TLRigSkater.setup: nothing to change there.

FOR THE OWNER TO LOOK AT

media/r1_both_looks_for_the_owner.jpg (thirdjam, felt, cel; both teams), media/r1_running_game_vs_ours.jpg and
media/r1_same_camera_same_place_game_over_ours.jpg (his game above, ours below, same camera).
To see it move: godot --path engine res://rigs/skater/look/look_gym.tscn -- --mode=cost --frames=100000
(ten skaters striding before the game camera; add --look=cel for the other).

NEXT THREE

1. In lane K6's hall through one shared include; pairs at K6's camera spots with the figure where the game's stood;
   settle the indirect light.
2. Film: a skating figure in felt beside thirdjam's, ten at the game camera; the grain on moving limbs, shimmer far off.
3. The cel look: number and crest on it, or drop it.
