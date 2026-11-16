# Hockey read from its own play camera (lane L, package L1, 16 Nov 2026)

The house game `engine/packs/hockey` was looked at for the first time through the camera a player gets (view `arena`,
1920 x 1080, HUD on). 19 instants were captured before any change and again after, with the same bot, seed and frame.
The play is the same in both (all 17 bots and smoke: results and summaries equal, see "Nothing of the rules"), so each
pair shows the same instant.

- `sheet_before_after.jpg`: the contact sheet (before left, after right, half size).
- `before/NN_*.jpg`, `after/NN_*.jpg`: the pairs at full size (JPEG copies; the PNG originals stay in `%TEMP%/l1/cap/`).
- `after/c1..c3_chase_*.jpg`: the pack's second view (`chase`), for the question of a nearer camera.
- `after/w1_scoreboards_old_wide_camera.jpg`: the pack after L1 seen with the old wide camera (the arena's scoreboards
  and the north stand are outside the new frame).
- `after/z_carriers_enlarged_x3.jpg`: the carrier of eight after stills, three times enlarged.
- `camera-tried/`: the three framings tried (tilt from vertical 18, 10 and 5 degrees).

How a still is taken (one at a time):
`bash engine/tools/tl.sh capture --pack=engine/packs/hockey --cam=arena --frame=N --res=1920x1080 --hud=on --test=tests/<bot>.gd --out=<file.png>`.
Two captures of one frame differ only in the particles (0 to 530 of 2,073,600 pixels over a difference of 24).

## The numbers

| | before | after |
|---|---|---|
| camera (`data/tuning.json` `camera`) | pos [0, 52, 14], target [0, 0, 0], fov 55: 15 degrees off vertical | pos [0, 100.7, 9.0], target [0, 0, 0.2], fov 20: 5 degrees off vertical, a long lens |
| the ice across the frame | about 1,225 of 1,920 pixels (64 %), 20.4 pixels a metre | about 1,830 pixels (95 %), 30.5 pixels a metre |
| a standing skater | about 60 pixels | about 90 pixels |
| the puck as drawn | body 0.24 m across = 5 pixels, black | body unchanged; drawn 0.60 m across with an orange rim of 0.14 m: 0.88 m = 27 pixels |
| the human's ring | yellow `#f2b230`, 0.09 m = 2 pixels | green (`pine_light`), 0.2 m = 6 pixels; 0.5 m = 15 pixels while he carries |
| who carries | no mark | a ring 0.5 m wide under the carrier, in his team's colour (the human's: green) |
| the north stand's shadow on the ice | about 5.5 m deep along 52 m (read off the still) | none (the stand stands 8.5 m further back); the board's own 2.7 m strip stays |
| big ice (`data/modes/big_ice.json` `camera.pos`) | [0, 66, 18]: the ice 66 % of the width | [0, 134.3, 12]: 95 % |

## The table

"Puck" in the last column is my judgement of the after still at full size: **seen** (found at a glance), **partly**
(a piece of the rim shows), **not seen** (under a figure).

| still (bot, frame) | what did not read before | what changed | what is left after |
|---|---|---|---|
| 01 face-off (no input, 2) | puck not found; the human found only because he stands at centre; nothing names a key; the scoreboards say 2 3 at 0:0 | the keys in three lines under the clock until his first input; his ring green and 3 times as wide; the rink fills the frame | puck **partly**: its rim shows between the two centres, under the blue centre's stick. The keys' lines lie on the ice with no ground under them |
| 02 the human carries (bot_hockey, 30) | puck not found; cannot tell that he has it | his ring grows to 0.5 m while he carries | puck **not seen** (a sliver at his skates): it is carried 0.95 m ahead of him, under his own figure. The red centre is drawn on top of him: two figures, one blob |
| 03 a carrier in the far corner (bot_hockey, 1400) | four figures in the stand's shadow, colours dulled; puck not found; who has it: unknown | the stand's shadow is off the ice; the wide red ring says red has it | puck **not seen**; three figures on one another at the board; the human's ring half under them |
| 04 a pass in flight (bot_hockey, 775) | puck: a 5-pixel dot, found after a search | | puck **seen** |
| 05 a shot (bot_hockey, 2094) | puck not found (a dot among shadows) | | puck **seen**, 3 m from the net. (In the first 10 frames of a shot it is still under the shooter's figure: frame 2085, `%TEMP%/l1/cap/a5/05_shot.png`) |
| 06 a stumble (bot_check, 940) | puck found after a search; the two figures at centre are one blob; "Level: None (data/ai.json as is)" | "Level: Classic" | puck **seen**. The stumble is not readable from a still: hitter and hit are one blob |
| 07 a knockdown (bot_hockey, 1020) | the downed man is 60 pixels; puck not found | the wide red ring under the carrier | the downed man reads (sprawled, arms out, stick away). Puck **not seen** (under the carrier) |
| 08 the get-up (bot_hockey, 1070) | puck: a dot beside the centre line | | puck **seen**. The rising man looks like a standing man with a raised stick: not to be told from a still |
| 09 a goal for (bot_hockey, 2110) | one digit changes in a corner; puck not found | "GOAL: BLUE" in the centre during the pause | puck **seen** in the net. The kit's goal flash is 20 pixels |
| 10 a goal against (bot_hockey, 1556) | as 09; the scrum in the stand's shadow | "GOAL: RED" | puck **seen** at the post |
| 11 the rule dial (bot_dial, 123) | the text 790 pixels wide across the blue line, a circle, the crease and the scoreboard prop | the title alone on the first line, the keys on the last: 590 pixels, right of the blue line | still no ground: it lies on a face-off circle and a skater's stick. Puck **partly** |
| 12 mode base (bot_modes, 300) | puck not found; who has it: unknown | the carrier's ring | puck **not seen** |
| 13 mode outnumbered (bot_modes, 3560) | five red figures, no puck | a wide blue ring: a mate has it | puck **not seen**; carrier and checker one blob |
| 14 mode sudden death (bot_modes, 6800) | as 12 | his own wide ring | puck **partly**; red drawn on top of him |
| 15 mode pond (bot_modes, 7300) | as 12 | the carrier's ring | puck **not seen** |
| 16 mode big ice (bot_modes, 11600) | the rink 66 % of the width, a third of the frame bare ground | the rink fills the frame | a skater is 68 pixels (the rink is 80 m). Puck **not seen** |
| 17 level rookie (bot_ladder_rookie_newcomer, 250) | a downed man small; no puck | | the downed man reads. Puck **not seen** |
| 18 level all-star (bot_ladder_allstar_sharp, 2740) | a pile of figures | his wide ring under the pile | three figures on one spot. Puck **not seen** |
| 19 the end (bot_hockey, 3441) | "WIN", nothing about playing again | "R: play again" under it | puck **seen** in the net |

Puck in the 19 after stills: seen 7 (every still where it is loose or in flight: 04, 05, 06, 08, 09, 10, 19), partly 3
(01, 11, 14), not seen 9 (02, 03, 07, 12, 13, 15, 16, 17, 18: every one a carried puck under the carrier's figure). In all
12 stills with a carrier his wide ring says where the puck is. Before: found at a glance in none; found after a search in 3
(04, 06, 08).

## What the stills answer

- **Can he find the puck in under a second?** Loose or in flight: yes. Carried: he finds the carrier (the ring), not the
  puck: it lies under the carrier's figure (`after/z_carriers_enlarged_x3.jpg`, `after/c1_chase_carry_far_corner.jpg`).
- **Can he tell his skater from his mates?** Yes: the green ring, on sunlit ice and in shadow.
- **Who has the puck?** Yes: the wide ring, team colour.
- **Is a downed man clearly down?** Yes in 07 and 17 (sprawled). A stumble and the get-up: not to be told from a still.
- **Do figures cover each other or the puck?** Yes, both. Two bodies that touch (centres 1.23 to 1.32 m apart, H7) are
  drawn as one blob: a trunk is about 1.2 m across (1.6 m with the arms) and the skating pose carries it about 1 m ahead
  of the feet (both read off the stills), so two who meet head-on have their trunks in one place. The carried puck is
  under its carrier for the same reason.
- **Is the ring a technical mark?** It is a flat ring on the ice under a figure and nothing else is drawn; nothing at a hit.
- **Does the HUD fit and say which game this is?** It fits; the bottom line names level and mode. No text has ground.
- **The camera.** The whole rink is in frame at both ends and nothing is small because it is far: the view is 5 degrees
  off vertical through a long lens, so the ends are as large as the middle. A figure is about 4 m tall (the rig at scale 2.2) and
  covers the ice behind it by its height times the tangent of the angle it is seen at. Tilts tried: 18 degrees (fov 40):
  seen at 19 degrees at centre and 33 at the far board, 1.4 and 2.6 m covered; 10 degrees (fov 25): 0.7 and 1.5 m; 5 degrees
  (fov 20, chosen): 0.4 and 1.0 m. Steeper still and a figure is a helmet. The loss: he sees
  helmets and shoulders, not faces.
- **Would a nearer, following camera serve?** Yes, and the kit has none that fits. `chase` (the pack's second view, stills
  c1 to c3) shows a figure at 350 pixels and the carried puck at the carrier's skates, but it turns with his heading (c1:
  half the frame is ground outside the rink) and holds about 20 m of rink (mates and opponents are out of frame, a
  figure stands in front of the lens in c2). `orbit` follows without turning by itself, but by the API's text (not tried)
  its yaw is on the right-button drag, and the right button is this pack's pass and body check; its pitch is held to 30..60. What would serve is a
  side camera that follows without turning: see FOR THE KIT 2.

## Nothing of the rules

All 17 bots and smoke, seed 1, before and after (`%TEMP%/l1/rep/before`, `after`): `ok`, outcome, frames, the bot's own
`ok` and its whole summary text are equal in 18 of 18. Every state hash moved, for two values that are in the hash:

1. `data/venue_art.json`: the north stand and the entrance moved (z -19.5 to -28, -30 to -39): the kit's stand has a
   static body, and the hash covers every physics body's place.
2. the HUD's game line for level none, "Level: None (data/ai.json as is)" to "Level: Classic": `_pack_state` carries
   `game_line`.

Proof that nothing else is hashed: a copy of the pack as it is after L1 with those two values put back
(`%TEMP%/l1/proof/hockey`) gives 18 of 18 hashes equal to the baseline. So the camera, the puck's drawn size and rim, the
rings, the keys' lines, GOAL, play again, the dial's text and the bound scoreboards move no hash.

| run | before (= `status/H.md` after H7) | after L1 | result |
|---|---|---|---|
| bot_hockey | 38cafb633924dd63 @3442 | 6a3dfee83ba348d4 @3442 | blue 3:1 WIN, equal |
| bot_hockey_regular | 9ccc65c2faccfcea @1666 | 01f88fd0cc84c5a3 @1666 | 1:3 LOSE, equal |
| bot_hockey_newcomer | c10e63eb13306f1f @2458 | 9ff50cfb83b67e9d @2458 | 0:3 LOSE, equal |
| ladder rookie/newcomer | 6aaa4631fc05852d @1254 | fe01f98cece09958 @1254 | 0:3, equal |
| ladder rookie/perfect | 22d7aeadbfbdb4b7 @5461 | fc2bbecd28b7056f @5461 | 2:3, equal |
| ladder pro/regular | e41ab5e1f9c38f0f @3682 | 30cd5127b9ab77eb @3682 | 3:1, equal |
| ladder pro/perfect | 4f5b5255c3070fb9 @4318 | 70df7b88bd4bd1fe @4318 | 1:3, equal |
| ladder all-star/sharp | ab903dedfedda3b7 @3864 | bba12fbd40d7271e @3864 | 3:2, equal |
| ladder all-star/perfect | 4b62bc8ee8ca624c @4712 | bdebd38e8c30c0e0 @4712 | 0:3, equal |
| bot_hockey_ai | 30695e16d0eab1bc @3711 | 54b91fa586bc0957 @3711 | red 3:1, equal |
| bot_reach | 93820ed6ee806fad @1854 | 4516776bb77ad686 @1854 | 13/13, passes 10 of 10, equal |
| bot_match | 5ad8a38c4de71bf9 @6001 | b25c81e030c78e1f @6001 | 3:2, 0 skater-frames outside, closest 1.226 m, equal |
| bot_check | f358678f469e0743 @4049 | 3a29633249dbfe60 @4049 | the table, equal |
| bot_modes | 77b4cc501349c1f4 @14875 | 3b4600c69571f914 @14875 | five modes ended, equal |
| bot_dial | f20c531896533e46 @2293 | ea9422f2b8b10c02 @2293 | equal |
| bot_aim | eb2edf263a6de018 @876 | f04012343e1f5347 @876 | equal |
| bot_buttons | 64badbbc2ce074e6 @206 | 0e2c1788a97aee9f @206 | 4 of 4, equal |
| smoke | 5fd152fb240ca79b | 3de7166e7b4f7600 | |

## A person's hand

A session through the device path, not through a bot's verbs (`tl.sh play --headless --frames=420 --devices=...`: D held,
left button, T, W, right button, A held, left button; the cursor where a headless window has it, in a corner):
0 script errors before and after; shots 2, checks tried 3, dial `skate +1` in both. The positions differ, and the cause
is the camera alone: the aim is the cursor's ray on the ice, and the same cursor position meets another point of the
ice through another lens (stick heading [-0.474, -0.88] before, [0.595, -0.804] after). The same session on a copy with
the old camera and the two hashed values put back (`%TEMP%/l1/proofcam`) gives the same `pack_state` and the same hash
trace as the pack before L1. A person aiming with his eyes on the picture was not run (no window but the capture's).

## What was changed (all in `engine/packs/hockey`)

- `data/tuning.json`: `camera`; `carry.ring_width` 0.09 to 0.2; a new block `look` (the puck's drawn scale and rim, the
  rings' palette keys and width, the level label, the HUD's lines).
- `data/modes/big_ice.json`: `camera.pos`.
- `data/venue_art.json`: the north stand and the entrance.
- `scripts/look.gd` (new, 94 lines): the puck's drawn size, the rings, the HUD's lines, the scoreboards bound to the rules.
- `scripts/main.gd` (573 to 579 lines): calls into `look`; the level label from data.
- `scripts/dial.gd`: the dial's text.
- `gen/ring_hook.gd`: `make_ring` takes a node name and a height and returns the mesh (the carrier's ring, the puck's rim).

Lint: bypasses `[]`, `kit_parts_added` 1 (as before).

Every look value is data in `data/tuning.json` `look`: `carrier_ring: false` leaves only the human's ring (the
others' wide ring was judged on stills only, not in motion); `puck_scale`, `puck_rim`, `puck_rim_key`, `ring_key`,
`carry_width`, `team_keys`, `keys` (the lines), `goal`, `again`, `level_none`.

## FOR THE KIT (kernel, kit, rigs, style: not the pack's to cure)

1. **`TLHud` has no ground under a text** (kernel). The rule dial (`after/11`), the keys' lines (`after/01`) and GOAL lie on
   the picture: white letters with an outline over lines, circles and figures. Wanted: a plate behind a widget (the HUD's
   own look), and with it: lines centred inside a label of several lines, and a label on a `bottom*` anchor that grows
   upwards (by the code, `tl_hud.gd` places a label once and a longer text grows downwards, off the screen there: not
   tried; it is why the keys sit at the top).
2. **`TLCameras` has no camera that follows without turning** (kernel): a fixed heading and pitch, following a subject (or
   the middle of two: the player and the puck) inside bounds, no pointer actions. With 35 m of rink across the frame a
   figure would be 160 pixels instead of 90.
3. **The stick's blade and the carried puck are 1 m apart** (rigs; or lane H's rule value). At body scale 2.2 the blade
   lies about 1.9 m from the body's centre and the trunk about 1 m ahead of the feet (read off the stills); the puck is carried 0.95 m
   ahead (`carry.offset`, a rule value: changing it moves reach geometry and bot results, so not L1's). Either the skate
   pose holds the blade at the puck, or the puck is carried at the blade. Stills: `after/02`, `after/c1`, `after/z_carriers`.
4. **Two figures that touch draw as one** (rigs and kernel). Body diameter 1.32 m, a trunk about 1.2 m across and about
   1 m ahead of the feet, H7 measured centres down to 1.226 m. Stills 02, 06, 14, 18. A stumble cannot be read while hitter and hit are one blob.
5. **A low sun and a venue** (style, kit). The sun stands at 21 degrees (azimuth 30): everything north or east of the ice
   shades it by 2.26 times its height. The stand's rear wall is rows x 0.46 + 5.6 m whatever the rows (`TLKitArena.stands`),
   so fewer rows do not help: the pack moved the stand. Left in: the north-east mast (14 m, a shadow of 36 m across the
   east zone, a lattice of thin lines) and the north board's own strip of 2.7 m. A pack may not make a light: a venue
   would want a style key (a higher sun for an arena) or a stand without the wall.
6. **`TLKitSite.bind_scoreboard` binds once** (kit). A pack that builds new rules for a new match must free the old face
   itself (`look.gd` `_bind`). It could replace a face it finds.
7. **The kit's `puck` is black and has no colour or rim param** (kit): the rim is made in the pack's generator.
8. **The ice shows vertical bands** from above (style, minor): strips about 8 m wide of slightly different tone.
9. **`goal_flash` is 20 pixels** from a camera that shows the whole rink (kernel `TLVfx`, minor).

## FOR LANE H (rule values, seen and not touched)

- `carry.offset` z -0.95: see FOR THE KIT 3.
- At a face-off the human owns the puck at frame 1 without a key (the puck lies 1.4 m from him, reach 1.45; his ring is
  already wide in `after/01`). If that is meant, nothing to do.
- bot_hockey, frames 619 to 728: b2 and r0 take the puck from each other by pokes 8 times in 110 frames on one spot
  (-18, -2). With the carrier's ring this shows as a ring that jumps between two figures every 20 frames.

## Not judged

Motion: a still shows no stumble, no get-up, no pass's speed, nor how the carrier's ring looks when the puck changes hands
often (8 times in 110 frames in bot_hockey, frames 619 to 728). A person's mouse through the new lens: the
aim is the cursor's ray on the ice at most `aim.reach` = 200 m from the camera; the camera is 108 m from the farthest
corner (144 m on big ice), computed, not played. Sound. The world view (a visitor outside the game) and `tl play` in a
window were not run.

## L2 (16 Nov, 05:31 to 05:55): plates under the texts, lane H's blade re-read, the final sheet

The pack changed under these pictures between L1 and L2 (lane H, `36ba652`): the puck is carried on the blade of the
stick, a non-human carrier's ring shows after 20 frames of holding, the HUD names the result at full time; the kernel
(API 1.5) gained `TLHud.set_plate`, `set_align` and bottom labels that grow upwards. The L1 table above describes the
pack at `a37ca43`; its "puck not seen" rows are answered here.

- `final_sheet.jpg` (546 KB): six stills of the game as a person meets it tonight.
- `l2/*.jpg`: the 18 L2 stills (PNG originals in `%TEMP%/l1/cap/l2/`), `l2/z_C_at_boards_enlarged_x3.jpg`.

### The texts (1)

Every text that lies on the picture has the HUD's plate now, only while it has a text: the keys (one label of three
centred lines under the clock: `l2/A`), GOAL (`l2/I`), the result with "R: play again" (one label, centred: `l2/K`), the
rule dial (lines left: `l2/J`), the rule line after a dial change (`l2/L`). The rule line moved from the left edge at
the height of the nets (905 pixels wide, its plate ran into the centre circle: `l2/L_rule_line_at_left.jpg`) to the top
under the clock, on the north board's shadow strip; it can never meet the keys there (the keys go at his first input,
and the rule line needs T). Not plated: the scores, the clock and the level line: they lie on the apron, which is calm.
The keys stayed at the top: a centred block at the bottom would lie on the level line (750 to 975 pixels long).

### Lane H's blade, by eye from the play camera (2)

| still (bot, frame) | what it shows | reads? |
|---|---|---|
| `l2/B` (bot_hockey, 300) | the human carries in open ice | yes: the puck on his blade, clear of every figure, his ring wide |
| `l2/C` (bot_hockey, 650) | the human carries at the south board | partly: the puck is pulled in to his skates on the board line, half under him; his stick is drawn through the board, the blade lies outside the rink on the apron (`l2/z_C...`) |
| `l2/F` (bot_ladder_rookie_newcomer, 4212) | a mate carries in a scrum of five | partly: the puck's rim shows between the sticks; the mate's wide blue ring says whose it is |
| `l2/D1`, `D2`, `D3` (bot_hockey, 226, 229, 236) | the take after a face-off: one frame before, 2 and 9 frames after | before: the puck is under the two centres, not seen; 2 frames after it lies on his blade 3.1 m from him. In stills it appears there; whether the jump of at least 1.6 m in a frame reads as a take is motion: not judged |
| `l2/E1`, `E2` (bot_hockey, 1100, 1118) | a mate takes at the north board: 8 and 26 frames after | yes: at 8 frames no ring and the puck on his blade says it; at 26 the wide blue ring is there |
| `l2/G` (ladder, 5555) | a pass from a mate to the human | yes |
| `l2/H`, `H2` (ladder 3915; bot_modes 4612) | a knockdown | H: the downed mate is half under the red carrier; H2: the human down, stretched out, the puck loose: reads |

What does not read, and whose it is:
- **His ring no longer holds his puck.** The ring is his reach for a loose puck (1.45 m); the carried puck rides on the
  blade at 3 m, outside it (B, D2, D3). It reads as "this is me, the puck is on my stick", which is true; the ring's
  width still says he has it. Named, not changed: the radius is a rule value's picture (lane H).
- **A stick through the board** (C): the rig's stick knows no board; at the boards the puck is pulled in (lane H's
  fallback) but the blade is drawn outside the rink. Rigs.
- **The take** (D1 to D2): motion, see the table.
- **The face-off** (A): at frame 2 the human's blade lies across the dot with the puck on it: he has won the face-off
  before a key is pressed (named in L1; lane H).
- bot_hockey's first face-off: a shot at frame 1 from the dot is a goal at frame 98 (seen in the probe's event list;
  lane H's to judge).

### Nothing of the rules (L2)

17 bots and smoke before L2 (`36ba652`) and after: results and summaries equal 18 of 18, hashes equal 18 of 18. No HUD
value in `_pack_state` moved: `result` in the state is still WIN / LOSE / DRAW; "R: play again" is only in the label.
