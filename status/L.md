# Lane L: the hockey house game read from its own play camera

## L1 (started 03:55 by the machine clock; branch `spark-jam/hockey` at `9a1eb64`)

Evidence in the repo: `docs/experiments/hockey-look/` (README.md with the table, `sheet_before_after.jpg`, `before/`, `after/`, `camera-tried/`).
Scratch (not in the repo): `%TEMP%/l1/` (capture lists, PNG originals in `cap/`, bot reports in `rep/before|proof|after|final`, the gate's logs in `gate/`, plain copies of the pack for checks: `probe` prints event frames, `origpack` is the pack before L1, `proof` and `proofcam` put hashed values back).
How the stills are taken: `bash engine/tools/tl.sh capture --pack=engine/packs/hockey --cam=arena --frame=N --res=1920x1080 --hud=on --test=tests/<bot>.gd`, one at a time. The same bot, seed and frame before and after.

SEEN 04:02 baseline (before any change of mine): all 17 bots and smoke equal `status/H.md` after H7, hash for hash (bot_hockey 38cafb63 @3442 3:1 WIN ... smoke 5fd152fb).
SEEN 04:05 the before stills (19), looked at one by one at full size:
- the puck is a dark dot 5 pixels across (body 0.24 m, 20.4 pixels a metre): found after a search in 3 of 19 (04, 06, 08, alone on sunlit ice), at a glance in none.
- the ice is 1,225 of 1,920 pixels wide (64 %): stands, masts, scoreboards and bare ground take the rest; a skater is about 60 pixels.
- the north stand's shadow lies on the top 5.5 m of the ice; skaters in it lose their colour. Its rear wall is rows x 0.46 + 5.6 m high whatever the rows (`TLKitArena.stands`); the sun stands at 21 degrees, azimuth 30: a shadow 2.26 times the height southwards. Fewer rows would not help.
- the human's ring: yellow `#f2b230`, 0.09 m = 2 pixels, on warm white ice.
- nobody but the human has a mark: who carries cannot be read.
- the arena's scoreboards show "2 3" and "3 2" at 0:0 (the kit's fixed digits).
- "Level: None (data/ai.json as is)" in every bot that pins level none.
- nothing names a key; a goal changes one digit in a corner; WIN is one word, nothing says how to play again.
- the rule dial's text (790 pixels) lies across the blue line, a face-off circle, the crease and the scoreboard prop.
SEEN 04:10 the state hash covers every physics body's place, static ones too (`kernel/host/statehash.gd`): moving the stand moves every hash. `_pack_state` carries `game_line`: the level label moves the hash of every run on level none.
SEEN 04:12 a puck part's drawn scale is free of its body: `TLBall.create` takes the shape from the part's metadata and keeps the part as a child; the pack scales the part after `create` (which resets its transform). Body, and so play, unchanged.
SEEN 04:14 first framing (18 degrees off vertical, fov 40): rink fills the frame, but a figure about 4 m tall covers 1.4 m of ice behind it at centre and 2.6 m at the far board: the puck at the face-off and the far corner are under figures. Tried 10 degrees (fov 25): 0.7 and 1.5 m. Chosen 5 degrees (fov 20): 0.4 and 1.0 m. Stills of the three in `docs/experiments/hockey-look/camera-tried/`.
SEEN 04:20 a carried puck is under its carrier in every still (8 carriers of the after set looked at three times enlarged: `after/z_carriers_enlarged_x3.jpg`; from the side in `after/c1_chase_carry_far_corner.jpg`: the puck at his skates, the blade 1 m further out). The puck is carried 0.95 m ahead (`carry.offset`, a rule value); at scale 2.2 the trunk is about 1 m ahead of the feet and the blade about 1.9 m. Not the pack's dress: the wide ring under the carrier tells who has it instead.
SEEN 04:22 in the first 10 frames after a shot the puck is still under the shooter's figure (frame 2085 of bot_hockey); the shot still is taken at 2094.
SEEN 04:24 two figures whose bodies touch are one blob from above (02, 06, 14, 18): a stumble cannot be read from a still.
SEEN 04:26 the scoreboards bound with `TLKitSite.bind_scoreboard` show 1 and 1 at 1:1 (`after/w1_scoreboards_old_wide_camera.jpg`, taken from a copy of the pack with the old camera). The bind is once per board; the rules are new at every match, so `look.gd` frees the old face before binding.
SEEN 04:27 two captures of one frame differ only in particles (0 to 530 of 2,073,600 pixels): a still is evidence of the picture, not a byte-exact artefact, where a burst is in frame. A frame without particles is byte-equal (01 from `origpack` equals the first before still).
SEEN 04:29 proof copy (the pack after L1 with the stand, the entrance and the level label put back): 18 of 18 hashes equal the baseline. So camera, puck, rings, HUD lines, dial text and scoreboards are in no hash.
SEEN 04:36 a person's session through the device path (`tl.sh play --headless --devices`: keys and both mouse buttons): 0 script errors before and after, the same counts (shots 2, checks tried 3, dial skate +1); positions differ because the cursor's ray meets another point of the ice through another lens (the aim is the camera's). On a copy with the old camera and the hashed values put back: `pack_state` and hash trace equal the pack before L1.

What changed (all in `engine/packs/hockey`):
- `data/tuning.json`: `camera` pos [0,52,14] target [0,0,0] fov 55 -> pos [0,100.7,9.0] target [0,0,0.2] fov 20; `carry.ring_width` 0.09 -> 0.2; new block `look` (puck_scale 2.5, puck_height_scale 1.5, puck_rim 0.14, puck_rim_key hot, ring_key pine_light, carry_width 0.5, carrier_ring true, team_keys, level_none "Classic", goal, again, keys: three lines).
- `data/modes/big_ice.json`: `camera.pos` [0,66,18] -> [0,134.3,12].
- `data/venue_art.json`: `stands_n` z -19.5 -> -28; `entrance` z -30 -> -39 (it stood behind the stand and still does).
- `scripts/look.gd` (new, 94 lines): the puck's drawn size and rim, the rings, the HUD's lines (keys until the first input, GOAL during the pause, play again), the scoreboards bound to the rules.
- `scripts/main.gd` (573 -> 579 lines): creates `look`, hands it the puck's part, calls `look.setup`, `look.hud_lines`, `look.tick`; the level label from data.
- `scripts/dial.gd`: the dial's text (title alone, the keys on the last line: 790 -> 590 pixels).
- `gen/ring_hook.gd`: `make_ring(holder, radius, width, key, node_name = "ReachRing", y = 0.02) -> MeshInstance3D`.
Kernel members added: none. Contract text proposed: none. Patches for neighbours: none (see FOR LANE H: two rule values seen, not touched).

FOR THE KIT (each with its still; the full text is in `docs/experiments/hockey-look/README.md`):
1. kernel `TLHud`: no ground under a text (`after/11`, `after/01`); no centred lines in a label of several lines; a `bottom*` label of several lines grows off the screen (read in `tl_hud.gd`, not tried).
2. kernel `TLCameras`: no camera that follows without turning. `chase` turns with his heading (`after/c1`: half the frame is ground outside the rink); `orbit` has its yaw on the right-button drag, which is this pack's pass and body check, and its pitch held to 30..60.
3. rigs (or lane H): the stick's blade is about 1.9 m out, the puck is carried at 0.95 m: under the figure (`after/02`, `after/c1`, `after/z_carriers_enlarged_x3.jpg`).
4. rigs and kernel: two figures that touch draw as one (02, 06, 14, 18).
5. style and kit: a sun at 21 degrees shades the ice from everything north or east of it; the stand's wall is 5.6 m above its last row whatever the rows; left in: the north-east mast's shadow (36 m, a lattice across the east zone) and the north board's own 2.7 m strip.
6. kit `TLKitSite.bind_scoreboard`: binds once; could replace a face it finds.
7. kit `puck`: black, no colour or rim param.
8. style: the ice shows vertical bands about 8 m wide from above (minor).
9. kernel `TLVfx` `goal_flash`: 20 pixels from a camera that shows the whole rink (minor).

FOR LANE H (rule values, seen through the new marks, not touched):
- `carry.offset` z -0.95 against a blade at about 1.9 m: FOR THE KIT 3.
- at a face-off the human owns the puck at frame 1 without a key (puck 1.4 m from him, reach 1.45): his ring is already wide in `after/01`.
- bot_hockey frames 619 to 728: b2 and r0 take the puck from each other by pokes 8 times in 110 frames at (-18, -2): with the carrier's ring this is a ring that jumps between two figures every 20 frames (`look.carrier_ring: false` leaves only the human's ring).

SEEN 04:43 the final files (last edit 04:37: two comment lines in `scripts/main.gd`; the stills were taken at 04:23 to 04:30, after the last change of behaviour at 04:18): all 17 bots and smoke again: results and summaries equal the baseline 18 of 18, hashes equal the run before the comment 18 of 18.

Hashes (seed 1; before = `status/H.md` after H7 = my baseline of 04:02 / after L1). Every one moved, for the two hashed values named above; every result is equal:
bot_hockey 38cafb633924dd63 -> 6a3dfee83ba348d4 @3442 (3:1 WIN) | bot_hockey_regular 9ccc65c2faccfcea -> 01f88fd0cc84c5a3 @1666 (1:3) | bot_hockey_newcomer c10e63eb13306f1f -> 9ff50cfb83b67e9d @2458 (0:3) | ladder rookie/newcomer 6aaa4631fc05852d -> fe01f98cece09958 @1254 | rookie/perfect 22d7aeadbfbdb4b7 -> fc2bbecd28b7056f @5461 | pro/regular e41ab5e1f9c38f0f -> 30cd5127b9ab77eb @3682 | pro/perfect 4f5b5255c3070fb9 -> 70df7b88bd4bd1fe @4318 | all-star/sharp ab903dedfedda3b7 -> bba12fbd40d7271e @3864 | all-star/perfect 4b62bc8ee8ca624c -> bdebd38e8c30c0e0 @4712 | bot_hockey_ai 30695e16d0eab1bc -> 54b91fa586bc0957 @3711 | bot_reach 93820ed6ee806fad -> 4516776bb77ad686 @1854 (13/13) | bot_match 5ad8a38c4de71bf9 -> b25c81e030c78e1f @6001 | bot_check f358678f469e0743 -> 3a29633249dbfe60 @4049 | bot_modes 77b4cc501349c1f4 -> 3b4600c69571f914 @14875 | bot_dial f20c531896533e46 -> ea9422f2b8b10c02 @2293 | bot_aim eb2edf263a6de018 -> f04012343e1f5347 @876 | bot_buttons 64badbbc2ce074e6 -> 0e2c1788a97aee9f @206 | smoke 5fd152fb240ca79b -> 3de7166e7b4f7600.

READY L1 04:43
| acceptance line | verdict | figure |
|---|---|---|
| each row of the table has its before / after pair | met | 19 rows, 19 pairs (38 stills) in `docs/experiments/hockey-look/before` and `after`; the same bot, seed and frame; the sheet `sheet_before_after.jpg` |
| the puck is findable at a glance in every after still (judged per still) | not met | seen in 7 of 19 (every still where it is loose or in flight: 04, 05, 06, 08, 09, 10, 19), partly in 3 (01, 11, 14), not seen in 9 (02, 03, 07, 12, 13, 15, 16, 17, 18: a carried puck under its carrier's figure). Before: at a glance in 0. In all 12 stills with a carrier the wide ring says who has it. Lever: `carry.offset` (a rule value, lane H) or the rig's stick pose (FOR THE KIT 3) |
| every bot passes with unchanged results | met | 17 of 17 pass; `ok`, outcome, frames and the whole summary equal in 18 of 18 (smoke included). All 18 hashes moved for two hashed values (the north stand's and the entrance's static bodies; the level label in `game_line`); with those two put back 18 of 18 hashes equal the baseline |
| four verbs green | met | lint passed; smoke passed 3de7166e7b4f7600 (4 of 4 checks); bot passed 6a3dfee83ba348d4 @3442 (6 of 6); invariants passed (10 of 10, both hashes twice) |
| `tl check --tier full --only packs` green | met | PASS [1/1] found 1, completed 1; verb runs 20 of 20 |
| 0 bypasses | met | `bypasses []`; `kit_parts_added` 1 (as before); script lines 1,510 + 23 gen |
| `tl check --tier fast --changed` | met | arch [9/9], assets [4/4], cards [3/3], devx.test [161/161], foreman.typecheck clean; the changed paths under `docs/experiments/hockey-look` match no step |

The Director's eight (the addendum), each as seen after:
| | verdict | what |
|---|---|---|
| (a) the puck not found | cured for a loose puck, not for a carried one | 5 -> 27 pixels with an orange rim; carried: under the carrier, the ring speaks for it |
| (b) the dial's text has no ground | not cured | narrowed 790 -> 590 pixels and off the blue line; a ground needs `TLHud` (FOR THE KIT 1) |
| (c) the stand's shadow | cured | 5.5 m -> 0 m of the stand's shadow on the ice (the stand 8.5 m further back); the north board's own 2.7 m strip stays; the north-east mast's lattice shadow stays |
| (d) the rink 60 % of the width | cured | 64 % -> 95 % (20.4 -> 30.5 pixels a metre); big ice 66 % -> 95 % |
| (e) "Level: None (data/ai.json as is)" | cured | "Level: Classic" (data: `look.level_none`); hash of level-none runs moved, results equal |
| (f) the scoreboards' digits | cured | bound to the rules: 1 and 1 at 1:1 (`after/w1_...`); they are outside the play camera's frame now |
| (g) nothing tells the keys | cured | three lines under the clock until his first input (not shown while a bot-only match runs or after the end) |
| (h) his ring thin and orange on white | cured | green, 0.2 m = 6 pixels; 0.5 m = 15 pixels while he carries |

Files: `engine/packs/hockey/data/tuning.json`, `data/modes/big_ice.json`, `data/venue_art.json`, `scripts/look.gd` (new), `scripts/main.gd`, `scripts/dial.gd`, `gen/ring_hook.gd`; `docs/experiments/hockey-look/` (README.md, sheet_before_after.jpg, before/ 19, after/ 19 + c1..c3 + w1 + z_carriers, camera-tried/ 6); `status/L.md`. 19 MB of JPEG in the docs folder: the Director decides what of it is committed.
Not judged: motion (a stumble, the get-up, the ring when the puck changes hands 8 times in 110 frames); a person aiming with his eyes on the picture (the aim's reach through the new lens is computed: 108 m to the farthest corner, 144 m on big ice, against `aim.reach` 200); sound; the world view; `tl play` in a window.
