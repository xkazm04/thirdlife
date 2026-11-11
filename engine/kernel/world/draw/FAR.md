# P6: what a far game shows

The owner's ruling (2026-11-11): "we don't need to display full game from distance. We need to learn what to abstract
and hide from distance without destroying the view." This page is the study that answers it, the rules taken from
it, and what the draw layer does with them. The mechanism is in `draw.gd`; `DRAW.md` section 5 points here.

## 1. The study

Three games on a flat study ground (the village's own haze, sky, far plain and mesas; no hills, so nothing hides a
venue): the track (`seed_drive`, plot radius 64 m), the paddle court with its stand (`seed_paddle`, 40 m), the hockey
arena (job `ice-hockey-three-against-20261111-1`, 44 m). Each seen from the visitor's eye (1.7 m) and from a rise
(10 m + 12 % of the distance: 16, 28, 46, 82 m up), at 50, 150, 300 and 600 m **from the edge of its plot** (the
scheduler measures the same way). 1920x1080, vertical field of view 50 degrees. Twenty-four pictures per run, one
process per run:

```
node engine/kernel/world/draw/far_study.mjs walk full     <dir>/walk_full.json     --hockey=<pack dir>   # every game a sideline: drawn in full
node engine/kernel/world/draw/far_study.mjs walk backdrop <dir>/walk_backdrop.json --hockey=<pack dir>   # every game a backdrop
bash engine/tools/world.sh tour <dir>/walk_full.json --out-dir=<abs dir> --pictures-only
TL_DRAW_PICTURE=still bash engine/tools/world.sh tour <dir>/walk_backdrop.json --out-dir=<abs dir> --pictures-only
node engine/kernel/world/draw/far_study.mjs sheet <out.jpg> hockey:rise full=<dir> still=<dir> new=<dir>
```

Pictures, all under `engine/kernel/world/captures/p6/study/`:

| what | files |
|---|---|
| before: full game against the stand-in of N5b, per game, eye and rise | `before_drive.jpg`, `before_paddle.jpg`, `before_hockey.jpg` (frames, as JPEG, in `before_full/`, `before_still/`) |
| after: full, N5b's stand-in, the new pictures (middle at 50 and 150 m, far at 300 and 600 m) | `after_<game>_eye.jpg`, `after_<game>_rise.jpg` (frames in `after_auto/`). The "new" frames were taken after the land changes of P6, so they also show trees along the road, rocks at the pads and pines at the mesas |
| the far rows are enlarged crops of the middle of the frame | 150 m x1.5, 300 m x3, 600 m x4: the label of each cell says so |

How large things are on the screen (pixels at 1080 lines; court and arena, the track is a tenth smaller):

| from the plot edge | a metre | a skater (1.8 m) | a car (4 m) | a score digit (2 m, strokes 0.2 m) | a fence rail or a mast member (0.1 m) |
|---|---|---|---|---|---|
| 50 m | 12.9 px | 23 px | 41 px | 26 px, strokes 2.6 px | 1.3 px |
| 150 m | 6.1 px | 11 px | 22 px | 12 px, strokes 1.2 px | 0.6 px |
| 300 m | 3.4 px | 6 px | 13 px | 7 px, strokes 0.7 px | 0.3 px |
| 600 m | 1.8 px | 3 px | 7 px | 3.6 px, strokes 0.4 px | 0.2 px |

### The table

"Reads" = what a viewer can still tell. "Noise" = what is drawn and tells nothing (or flickers). "Missed" = what the
stand-in of N5b dropped and the eye looked for.

| distance | game | reads | noise | missed when dropped |
|---|---|---|---|---|
| 50 m | track | from a rise: the whole oval, red and white kerbs, the barn, the board, trees, the hollow it lies in; from the eye only what stands above the rim: board, barn roof, a tree, a mast | everything under 1.2 m that N5b's stand-in already drops (grass tufts, pebbles and the like: a few pixels each); the dark ink line along the lip of the hollow | the cars (41 px: the first thing the eye follows), the chimney smoke, the score (the board says "3 : 2" in every game: it is a prop, see below) |
| 50 m | court | the kind of place: a small court with a stand of blue seats, floodlight masts, a cabin, a house with lit windows; the pad ring and fence | the small things round the court (bench, signs, a sled); the fence rails and the mast lattice are already 1.3 px | the two paddles and the ball (small, but they are the game), the smoke of the house, lamps that light the court |
| 50 m | arena | from a rise: an ice rink (white sheet, red lines, a goal) inside a wall with a stand; from the eye: a long grey wall with pilasters, which could be any yard | the wall's joint pattern (drawn surface detail), the goal's net, flag poles | the skaters: six figures in two colours on white is what says "a match is on"; the score |
| 150 m | track | the oval and its kerbs as one red-white ribbon, the barn as a red block, the board as a dark plate with two light dots, single trees | every fence, the mast lattice (0.6 px: breaks into dashes), kerb blocks as separate things | a car is 22 px: still seen as a moving fleck of colour; smoke as a pale stroke; the score cannot be read from digits at eye height but can from a rise (12 px) |
| 150 m | court | stand (blue), court (pale), house (red), masts as lines, the board | fence, benches, everything under 2.5 m | movement on the court (paddles 5 px), the smoke plume (40 px tall: the strongest sign of life here) |
| 150 m | arena | the wall, the blue of the stand, the white of the ice, the board | pilasters as texture, lattice masts, flags | the skaters (11 px each, a cluster of red and blue 60 px wide), the score |
| 300 m | track | a flat ring in the land with a red block and a dark plate: "a circuit" only from a rise; from the eye a strip on the horizon with two bumps | all thin members; the kerb pattern (shimmers: alternate blocks are 1 px) | a car is 13 px on a rise: a moving dot is all that says the place is alive; smoke |
| 300 m | court | a pale patch with a blue-grey block and a red block beside it, inside a ring; "a small venue", not "a court" | everything under 5 m | the plume; the board as a light (it is the brightest thing on the plot) |
| 300 m | arena | white patch + blue band + grey wall: still "an ice arena" from a rise, the one game whose colours carry that far | wall detail, masts | the cluster of skaters as moving specks (6 px), nothing else |
| 600 m | track | from a rise the ring in the land (the hollow reads better than the track); from the eye nothing | everything but the ring, the barn and the board plate | movement: one or two specks (7 px for a car) |
| 600 m | court | a ring with two coloured blocks; the haze has taken a third of the contrast | everything else | the plume (still 15 px tall: it is the last sign of life to go) |
| 600 m | arena | the wall as a pale bar with a blue top edge and white beside it | everything else | specks on the white (3 px: at the edge of seeing; the far picture draws them 1.6 times larger) |

Three things the study found that the brief did not ask:

1. **Nobody could ever read who is winning.** The kit's scoreboard (`TLKitSite.add_scoreboard`) is a prop with fixed
   digits: every game showed "3 : 2" from every distance, in full and as a stand-in, at 0 : 0 and at full time. The
   real score lived only in the HUD of the game on stage.
2. **From 150 m on, full and stand-in are the same picture at screen size** (`before_*.jpg`): the stand-in's loss is
   not detail, it is life. What the eye misses is small and moving, or thin and rising: actors, the puck carrier's
   crowd, cars, smoke.
3. **From the eye, on level land, a venue is its skyline.** Only what is taller than a fence reads at all beyond
   150 m (board, masts, stand, roof, trees). The plan (oval, court, ice) reads only from a rise. So a far picture
   must keep the tall things and the large flat colours; nothing between matters.

## 2. The rules

1. **Life before detail.** A far game is drawn with less of its venue and all of its movement: every moving body
   stays in the picture as a mark for as long as the game is in memory.
2. **Three pictures.** Near: all of it. Middle: every form of 2.5 m and more, no clutter, plus signs of life (marks,
   smoke, the strongest lights, the score). Far: the forms of 5 m and more in flat tones with one outline, its
   ground coarse, plus the marks (larger) and the smoke.
3. **A mark is the body's shape in its colour** (P13). A figure (a body with a rig) is a slim figure of its height:
   legs, a body to the shoulders, a head; anything else is the box of its meshes; never smaller than 0.45 m (a ball,
   a puck). A mark grows smoothly with the distance from the plot edge, from its own size at 150 m to 1.6 times at
   450 m: a 3 px speck is at the edge of seeing, a 5 px one is not. It casts a shadow only nearer than 120 m.
4. **The picture moves smoothly, one interval behind the game** (P13, the Director's decision of P6 question 2).
   Every drawn frame a mark is drawn between the last two places the pack's ticks left it at, by the share of the
   pack's own tick interval that has passed: a backdrop game ticked one tick in eight moves smoothly, eight frames
   late. It never feeds back into the game. A pack with more than 96 moving bodies still steps (round robin). A game
   in the ledger (not in memory) keeps its last marks: it is a still.
5. **One score at every distance.** Where a pack placed a kit scoreboard and has rules, the board shows the pack's
   real score, near, middle and far. It is the only text of a venue that is kept.
6. **Smoke is the last sign of life to go**, so it is kept in both far pictures (a copy of up to two standing
   emitters; an emitter of a hidden pack stops by itself).
7. **Lights only in the middle picture** (the four strongest): beyond 240 m a pack's lamps do not reach the eye;
   the lit windows and lamp heads are emissive palette colours and stay in every picture for nothing.
8. **Thin things go first, and whole.** A member under one pixel shimmers. The middle picture drops whole instances
   under 2.5 m; the far picture also drops, inside the merged meshes, every triangle narrower than 0.1 m and every
   triangle whose longest edge is under 0.4 m (at 270 m both are a third of a pixel), so a rail, a net, a lattice
   vanish as a thing instead of breaking into dashes. A venue is mostly ONE merged mesh, so the rule per triangle
   is the one that saves anything (section 4).
9. **Far forms keep the middle picture's tone and shadow** (P13; P6 leaned every normal half-way up and switched the
   shadow off). Watched in motion, both made the change of picture the one thing that popped: the wall went from
   pink-grey to blue-violet and its shadow band on the grass vanished in one frame (`captures/p13/motion/
   swap_before.jpg`). The style's shadow reaches 300 m from the CAMERA, the change happens 210 to 270 m from the plot
   EDGE: the far picture is inside the shadow. Now `far_flat` is 0 and the far picture casts its shadow (the engine
   draws none beyond 300 m anyway).
10. **The change between middle and far must not be seen**: it happens at 240 m from the plot edge with 30 m of
    margin both ways (far beyond 270 m, middle again inside 210 m). The two pictures have the same tone and shadow,
    the marks the same size at that moment (rule 3); what still changes is the thin members (rule 8: a mast's lattice,
    under half a pixel there). No cross-fade: the toon shader is opaque and is not this package's, and with equal
    tone and shadow there was nothing left to fade.
11. **The camera decides between middle and far, the scheduler between near and not near.** Near is the tier
    (`stage`, `sideline`); which far picture is the camera's distance, so a crane high above the village sees
    silhouettes and a visitor at a fence sees the middle picture of the next plot.

## 3. What is built (`draw.gd`)

| picture | when | venue | life | built |
|---|---|---|---|---|
| near | tier `stage`, `sideline` | all of it, at its plot (N5b) | all of it; the real score on its boards | nothing |
| middle | tier `backdrop`, `ledger`; camera within 240 m of the plot edge | one merged mesh: instances of 2.5 m and more | marks, smoke, 4 lights, score | once, with the far picture, in one walk over the pack |
| far | the same tiers; camera beyond | one merged mesh: instances of 5 m and more; inside them no triangle narrower than 0.1 m (rails, wire, lattice) and none whose longest edge is under 0.4 m; the kit's terrain re-meshed on a 6 m grid (the last 12 m before the rim kept, so the rim still meets the world's ground); normals leaning up; no shadow | marks x1.6, smoke, score | the same walk |
| still | only with `TL_DRAW_PICTURE=still` | N5b's stand-in (1.2 m and more) | none | for comparison |

Thresholds proposed for `tiers.json` (the loading builder's file; `PATCHES-P6.md` entry 1). Until they are there the
draw layer uses the same numbers from its own defaults; it reads them through the world host's `cfg`:

```
"picture_far_m": 240,                      camera to plot edge: beyond it a backdrop game shows its far picture
"margin_m": { ..., "picture": 30 }         hysteresis both ways
```

What the draw layer reads from a pack, and never writes: `frames_done` of the holder (has it ticked), the global
transform and `visible` of its moving bodies, `scores` of its `TLRules`, the transform of nodes whose `tl_kind` is
`scoreboard`. It connects no signal and adds no node to a pack.

## 4. Cost

`bash engine/kernel/world/draw/far_cost.sh <abs out dir>`: N packs on a 140 m grid (N5b's six, cycled:
`seed_drive, seed_paddle, seed_wall, ex_kit, ex_walker, ex_car`), every pack played by its bot and ticked on every
frame, the crane over the whole grid, 1920x1080, Direct3D 12, RTX 4090 / Ryzen 7 7800X3D. Pack 0 is the stage pack
and is always drawn in full; the other N - 1 show the picture named. Totals of the frame as the engine counts them,
shadow passes included. "before" = N5b's stand-in, which is what a far game was until today. Raw lines and pictures:
`captures/p6/cost/` (`cost_run1.txt`; the far rows are `cost_run2_far.txt`, taken after the rule per triangle).

| packs | picture | draw calls | primitives | objects | render GPU ms | draw layer ms per frame |
|---|---|---|---|---|---|---|
| 6 | near (all in full) | 493 | 644,790 | 713 | 0.912 | 0.168 |
| 6 | before: still | 53 | 170,490 | 229 | 0.778 | 0.035 |
| 6 | middle | 80 | 171,938 | 256 | 0.761 | 0.129 |
| 6 | far | 54 | 124,635 | 230 | 0.742 | 0.108 |
| 12 | near | 953 | 1,099,198 | 1,231 | 1.489 | 0.457 |
| 12 | before: still | 50 | 179,036 | 223 | 1.319 | 0.063 |
| 12 | middle | 111 | 182,492 | 284 | 1.545 | 0.262 |
| 12 | far | 59 | 97,357 | 232 | 0.762 | 0.220 |
| 30 | near | 2,344 | 2,344,020 | 2,797 | 3.718 | 1.166 |
| 30 | before: still | 62 | 263,578 | 235 | 0.851 | 0.199 |
| 30 | middle | 225 | 273,394 | 398 | 1.821 | 0.730 |
| 30 | far | 109 | 130,065 | 282 | (3.701: disturbed) | 0.643 |

Read:

- **Draw calls and primitives are the figures to trust.** A middle game costs a tenth of a near one in draw calls
  (30 packs: 2,344 -> 225) and an eighth in primitives; a far one half of a middle one again (225 -> 109 draw
  calls, 273,394 -> 130,065 primitives).
- **The GPU and frame times are not separable on this machine tonight.** Four other builders ran windows at the same
  place; the same scene measured 0.76 ms and 1.5 ms minutes apart, one run was throttled to 270 ms a frame, and the
  last far run (30 packs) reads 3.7 ms against 0.74 and 0.76 for 6 and 12. None of the runs was a quiet run. The
  ordering near > middle > far holds in the 6 and 12 pack rows; do not quote the milliseconds.
- **The middle picture is not lighter than N5b's stand-in**: the same venue triangles (13,072 for the paddle seed
  in both: at `scenery = "plot"` a venue is 6 instances, one of them the merged static mesh, so a size rule per
  instance drops nothing) plus its life: 27 more draw calls at 6 packs (marks and their shadow, two smoke copies,
  boards). That is the price of a far game that moves and shows its score.
- **The far picture is a third of the middle one in triangles**: paddle seed 13,072 -> 4,487, wall seed 13,704 ->
  3,592 (8,435 and 9,862 triangles dropped by the rule per triangle; the coarse ground saved 150). Before that rule
  the far picture had 12,922: my first assumption, that the terrain holds the triangles, was wrong and the
  measurement showed it.
- **Building**: both pictures of a seed are built in one walk in about 160 ms (measured on a busy machine; N5b's
  one stand-in took 110 ms on a quiet one). It happens once per pack, in the frame it first goes far.
- **The draw layer's own work is no longer nothing for a far pack**: about 0.02 ms per pack and frame in these runs,
  where every pack ticks on every frame (0.73 ms for 29 packs). It is the marks: reading the transform of every
  moving body after each of the pack's ticks. A backdrop pack ticks one world tick in 2 to 16, so a scheduled world
  pays a half to a sixteenth of that; a pack whose bodies all rest still pays the reading.
- The ledger scenario `tour6` (the tour's world, six packs, a visitor): `node devx/bin/tl.mjs perf run --scenario tour6 --no-record` after P6: 280 draw calls, 1,977,056
  primitives, GPU 1.266 ms, frame 3.134 ms, on a machine the tool judged BUSY (use 100 %), so nothing was recorded
  and the times are not comparable. The last quiet line of the ledger (before P6, 12:19 UTC): 249 draw calls,
  1,911,582 primitives, GPU 1.227 ms, frame 2.073 ms. The tour draws 31 calls and 3.4 % primitives more than before:
  that is the land (rocks at the pads, trees and bushes at the roads, pines at the mesas) and the life of its
  backdrop games. With shadows on the 337 pad rocks it was 288 calls and 2,237,536 primitives (+17 %): their shadow
  was switched off for that reason.

## 5. Still wrong

The far pictures:

- A mark is a box. A skater is a slim box in his team's colour, a car a box in the car's colour: right at 150 m and
  beyond, crude at 50 m, where the middle picture is also shown (a backdrop game can be 30 m away when the walk's
  `sideline_m` is small). The middle picture needs a nearer limit of its own, or figures that keep a pose.
- Marks are not moved between a pack's ticks. At one tick in sixteen they step four times a second. That is the
  truth about the game's pace, and it looks like stutter.
- The pictures are built once. A body that was frozen then and moves later is in the merged mesh and has no mark;
  a static thing that a game removes later still stands in its far pictures.
- The middle picture keeps the thin members of a merged mesh (a mast's lattice): at 50 m they are wanted, at 200 m
  they are dashes. Whether lines shimmer in either far picture was NOT looked at in motion: every picture here is
  a still.
- No real decimation. The far picture's saving is the rule per triangle, the coarse ground and no shadow pass; a
  chamfer strip of a large box is a thin triangle and goes too, which leaves slits of a few centimetres that no
  picture showed.
- Both pictures of a pack are built in the frame it first goes far (the figures are in section 4): a hitch.
- The score shows the first two sides of the rules, 0 to 9 each. A game with one side, laps or a clock shows only
  what fits. In a single-pack run (no draw layer) the board is still the prop with "3 : 2".
- Lights of the middle picture are second instances of the pack's own lights, with whatever shadow setting they
  have; their cost was not measured apart.
- The copy of a smoke emitter starts from nothing each time a pack goes far.
- The camera decides between middle and far, so two cameras would disagree; there is one.
- Style was not changed. Item 3 of the brief (lines, haze and tone with distance) is done through the far picture's
  geometry only (which instances, which normals); the ink pass already thins and fades with distance (N1), and the
  haze of a world is the landscape's `haze` key as before. A venue at 300 m and at 600 m reads through it in the
  sheets; at 600 m it has lost about a third of its contrast.

The land (`landscape.gd`, pictures `captures/p6/land_before/`, `land_after/`, `overview_vs_concept.jpg`):

- A pad is still a circle: the plot cut is a circle and the fence follows it. What is uneven now is its worn ring
  (2 to 8 m wide), the rock edge that replaces the fence on the side away from the gate, and the lots. From high up
  the circles still show.
- The grass foot of a mesa is a straight-sided cone in one pale tone; from high up it reads as an apron lighter
  than the plain. It joins the mesa to the ground from the eye and from a low hill, which is where it was looked at.
- The ground's angular patches were not touched.
- The far half of the high overview is still pale: the haze was not changed, the plain now carries pine clumps.
- The village was not made more compact: plots belong to the walks.
- Against the concept the middle ground is still thin: trees and bushes along the roads are all that was added;
  there are no huts, no workers, no carts between the venues.


## 6. P13: the far picture in motion

**The tool.** `node engine/kernel/world/draw/far_study.mjs motion <hockey|drive|paddle> <abs out dir> --hockey=<dir>
--label=<name>`: one game alone on the study ground, ticked as a backdrop; the draw layer's own camera
(`TL_DRAW_CAMERA`, a file of keys [tick, from, to]) runs three times 90 consecutive frames: approach 320 -> 180 m
(far -> middle at 210 m), stand at 260 m while the game plays, retreat 180 -> 320 m (middle -> far at 270 m). Godot's
movie writer records every frame (one frame = one tick); ffmpeg cuts a 15-cell sheet (every 6th frame, the middle half
of the frame at full resolution) and an mp4 per run. Pictures: `captures/p13/motion/` (`before_*`, `after_*`,
`swap_before.jpg`, `swap_after.jpg`: eight consecutive frames around the change).

**What was seen (before):**
- The change far -> middle popped, three things at once: the wall changed its tone (normals leaned up in the far
  picture), the shadow band of the wall appeared, and the marks shrank from 1.6 times to their size.
- The marks were tall red and blue boxes (doors, not players) at 200 m.
- Standing at 260 m, the rink changed only every second frame (frame-to-frame difference of the rink region in the
  mp4: large on every other frame, codec noise between): the marks stepped with the pack's ticks.
- The thin members (mast lattice) appear at the change: under half a pixel; left as it is.

**After:** tone and shadow equal (rule 9), marks a slim figure that grows smoothly (rule 3), drawn between ticks
(rule 4): the rink region changes on every frame (`after_hockey_still.mp4`). The middle picture at 50 m
(`captures/p13/study/mid50_hockey.jpg`) shows figures in their team colour on the ice: acceptable, not pretty.

**Pictures are built off the frame and kept** (`draw_pictures.gd`): the walk over the pack's nodes on the main thread
only lists what goes where; the surface arrays are read and merged on a worker; the meshes are made when it is done
(a pack is drawn in full until then: `far_pending`). The merged meshes are written to
`user://tl_cache/pictures/<key>_<kind>.res`, the key being the content hash of the pack's directory (read on a worker
from the start), the plot's radius and rim, and the picture rules (`PIC_VERSION`). A plot whose game is not built yet
shows its last known picture from that cache; a holder with no pack and no cached picture is never made far.
`TL_PICTURE_WORKER=off` and `TL_PICTURE_CACHE=off` give P6's behaviour for measuring.

| the frame in which a pack first goes far (6 packs, view.sh shot, `far_start_ms_max`, busy machine) | ms |
|---|---|
| P6: both pictures built in the frame (`TL_PICTURE_WORKER=off`) | 108 (97 of it the build) |
| P13: listed in the frame, merged on a worker (cache not yet known) | 7.6 to 9.5, plus 4 to 20 ms in the later frame that makes the meshes |
| P13: from the picture cache | 11.8 (two meshes loaded) |
