# N1 look journal

Start 2026-11-11 00:03:32 (time-box ends 01:23:32; gates and report from 01:13).

## Step 1: look.sh and the before set (00:06 to 00:09)
- Wrote `engine/tools/look.sh` (shots, sheet, px, one).
- `look.sh shots look/before`: 12 seed frames + lab hero, 1 m 44 s for the set.
- Before stats (k.sh stats main hero, 2560x1440): see below.
- Before stats: main hero draw_calls 245, primitives 1670668, objects 268; two_rinks hero draw_calls 222, primitives 1700366.

## Step 2: lines (00:09 to 00:13)
- `ink_post.gdshader` rewritten around four opposite tap pairs on two rings (same 26 texture reads as before):
  width by distance (`near_px` 4.2 near, `outer_px` from `bold_far`), damped width noise (`even`), soft flank (one wide
  tap = part tone), thin-member rule (both opposite taps see background -> hairline on the lower right only, no crease
  line), crease distance rule (`inner_near`/`inner_far`).
- `TLStyle._apply_view`: SMAA on the host viewport (`env.line_aa`), because the ink quad is not multisampled.
- Looked at `look/wip/crop_hero_a.png` and `crop_wall_a.png` (before | after at 100 %): scaffolds and crane lattices are
  coloured bars again instead of black wire; the hero's contour is bold and smooth. Kept.

## Step 3: colour (00:13 to 00:17)
- style.json: sun #ffd9a0 x1.12 at 21 degrees (was #ffc488 x1.25 at 11.5: orange, and whole seed venues lay in forest shadow),
  shade #5a60c0 k 0.70 (was #34306e k 0.78: crushed greens), bounce 0.3, grade sat 1.24 / contrast 1.14 / split 0.06
  (was 1.34 / 1.22 / 0.09), fog #d9b6a8, tarmac #66666e (was purple grey).
- Looked at `look/wip/quad_b.png`, `quad_c.png`: grass is green, ice is white with a cool shadow, tarmac grey,
  shadows violet against warm light. Kept.

## Step 4: cameras (00:14 to 00:18)
- `tl_cameras.gd`: frame(), subject_px(), shake(), set_subject(), subject_of(); TL_LOOK_PX=1 prints the size every 30 frames.
- `tl_chase_cam.gd`: fov 58, `follow` (place) split from `stiffness` (heading), smoothed aim, snap().
- `tl_orbit_cam.gd`: fov 50, eased focus/yaw/pitch/distance (`smooth`), raw yaw untouched (yaw_basis feeds the walker).
- Seeds: wall frames the walker at 0.26, drive frames the car at 0.2, paddle court view steeper and tighter + set_subject.
- `look.sh px 1500`: paddle 0.087/0.102/0.124, drive 0.169/0.184/0.279, wall 0.259/0.273/0.284 (min/median/max).

## Step 5: ground (00:18 to 00:23)
- `tl_kit_terrain.gd`: near and far ground that is not steep gets one colour and one normal per grid vertex (tri_n) instead of
  one per triangle; steep faces stay faceted. Positions, triangle count, collision unchanged.
- `toon.gdshader` class ground: tufts (three tapered strokes, grass only), pebbles (disc with a dark rim, anywhere), two-tone
  patches with a crisp wobbly edge, one drawn edge where grass meets dirt.
- Looked at `look/wip/wall_d.png` (triangles gone from the yard; first try drew tufts on dirt like bird tracks: fixed, tufts are
  grass only) and `look/wip/hero_g.png` (far hills smooth). Kept.

## Step 6: light (00:20 to 00:23)
- Engine SSAO with light_affect 1, intensity 2: PSNR 57 dB against the frame without it on the cabin crop: nothing visible.
  Removed from data; `ssao_enabled = false` stated in code with the reason.
- Contact shade drawn by the ink pass instead (`ink.ao_k`, 8 more depth taps): `look/wip/crop_wall_f.png` shows the violet
  foot under the barrier blocks. A per-pixel turn of the taps speckled flat grass: fixed pattern now. Kept.

## Hashes after camera + shake lines (00:23): bc93a9a4c892 / b9adbb1967e3 / da4bdc3f65cc (unchanged). Lint bypasses [].
Gates started in the background at 00:23 (scratchpad gates1.log).

## Step 7: second round (00:25 to 00:36)
- Far blur tried at 0.06 and 0.02 (`look/wip/crop_hero_h.png`, `crop_hero_i.png`): it softens far contours the concept
  keeps crisp. Off in data (`env.dof_far` 0); the option stays.
- Dirt got scratches and grit, tufts only on grass (`look/wip/wall_i.png`); tufts stand upright on screen
  (`look/wip/paddle_k.png`; the first version looked like bird tracks from above, `paddle_j.png`).
- Paddle court camera cut the near wall and lost the paddle (subject_px 0.000 at one sample): pulled back, min 0.094.
- Sun painted at 8 degrees while the light stays at 21 (`sky.sun_draw_elev`, `look/wip/pair_l.png`).
- Tarmac under the warm light read brown: palette tarmac moved to a blue grey #5c6478 (`look/wip/pair_m.png`).
- First background gates: selftest 63/0, seeds 24/0, kit 86/0. NOTE: lines in another date format appeared inside
  scratchpad/gates1.log (some other writer used the same file name); the final gates go to a uniquely named file.
- Motion: `TLStyleFx.squash` and `TLStyleFx.trail`, checked by a scratch probe outside the project
  (`look/wip/motion_probe.png`: ball squashed to 1.10 x 0.82, scale back to 1 and helper node gone at the end, trail
  drawn). Shake lines in the three seeds. Hashes unchanged after the shake lines.
- Docs: `look/API-cameras.md`, STYLE.md section "N1 look pass". Overcast style still loads and draws
  (`look/wip/hero_overcast.png`); `k.sh validate`: 7 files, 0 failed.
- `engine/look/.gdignore` added: Godot was importing every capture in this folder as a project resource.

## Step 8: final set (00:36 to 00:38)
- `look.sh shots look/after` (13 frames), `look.sh sheet` -> `look/sheet_before_after.png`, looked at.
- Stats at 2560x1440: main hero 239 draw calls / 1667300 primitives (before 245 / 1670668); two_rinks hero 221 / 1699918
  (before 222 / 1700366).
- `look.sh px 3000`: paddle court 0.094 / 0.109 / 0.128, drive chase 0.166 / 0.184 / 0.279, wall player 0.259 / 0.276 / 0.289.
- Final gates started 00:38 (scratchpad n1look_gates_final_<pid>.log): selftest 63 passed 0 failed (00:41), seeds 24 passed
  0 failed (00:45), kit 86 passed 0 failed (00:46). Hashes bc93a9a4c892f2ab / b9adbb1967e36108 / da4bdc3f65cc07ae.

## Step 9: one more line step (00:46 to 00:50)
- `ink.outer_px` 2.8 -> 3.4, `near_px` 4.2 -> 4.4, `bold_far` 60 -> 80: mid-distance contours a little bolder
  (`look/wip/crop_yard_n.png`, `crop_paddle_n.png`: left before the step, right after). Thin members still keep colour. Kept.
- After set and sheet captured again (00:48) and looked at. `k.sh validate` 7 files 0 failed; smoke hashes unchanged;
  main hero stats 239 draw calls / 1667300 primitives.
- All three gates started again at 00:50 on this final state (scratchpad n1look_gates_last_<pid>.log).
- Result (00:57): selftest 63 passed 0 failed, seeds 24 passed 0 failed, kit selftest 86 passed 0 failed.
  Hashes bc93a9a4c892f2ab / b9adbb1967e36108 / da4bdc3f65cc07ae: unchanged. Nothing edited after this run.
- End 00:57 (54 minutes from 00:03:32). Report written as the final message.
