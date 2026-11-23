# K6 arena, round 1: thirdjam's hall stands round the rink (23 Nov 2026, 19:49 to 21:55)

First side-by-side at 20:25, 36 minutes into the two-hour box (`r1_first_sbs.jpg`). The export was not blocked.

## What stands

- **The reference, three ways.** A copy of the runnable build with HEAD's content over it (`.tl/tj-export`, 824 MB,
  not in git): (1) the game itself, 330 s of its measured hand with a still every 20 frames and the camera log
  (680 stills; the 8 used are kept, the rest deleted); (2) the same world seen by a scene capture from the logged
  camera poses (no HUD); (3) the played world written down: `engine/tools/arena/export_arena.py` plays thirdjam's own map
  in the editor and dumps what the game draws: 160 actors, every mesh component with its instances and materials, the
  18 spot lights with every property, the post volume, 218 materials with their parameters as the game had set them
  (dynamic instances and the look collection included), 52 meshes as glTF, the master materials as Unreal text.
- **Baked into the core** (`engine/cores/rink/arena/`, 5.0 MB): `arena.scn` (0.86 MB: 48 groups, 980 instances,
  516,834 triangles), `arena.json` (the table: pieces, thirdjam's material parameters, lights, post), four textures
  (4.1 MB). Nothing re-modelled or moved: a vertex is the glb's, a transform is Unreal's under the change of axes.
- **Drawn from thirdjam's own material formulas** (new style files, no existing shader touched): `hall_surface`
  (M_ClayBarn / M_ArenaWood: grain, wash, spill; M_Toon on the clay tier: bands, panels, joints, felt band, board wear
  line for line, the dented normal, the felt sheen), `hall_ice` (M_Ice: B19 mask and base, B23 pools, contact, board
  band, the twelve lamps' sheen), `hall_crowd` (M_ClayCrowd: vertex colour, per-instance coat and accent, the fill,
  the cheering pose), `hall_bulb`. All lit by **thirdjam's rig by the numbers**: the 18 spots' candela, cones and
  radii summed per fragment, the post volume's EV100, colour gain and Unreal's own film curve
  (TonemapCommon.ush:176-225).
- **The rink's own surfaces** as the clay tier wears them, drawn as skins over K3's rink: the ice (2 mm over K3's),
  the boards and the kick plate (4 mm proud), the red cap on the board top (new: K3 had none).
- **In the pack**: three call sites in `engine/packs/hokej/scripts/main.gd` (lines 39, 50-53, 89-91 of this tree),
  through a new door `ctx.cores.part("rink", "arena")`. The match's state hashes are K3's (REPORT.txt, Gates).
- **For the figures** (K7's felt skater, not in this tree): the rig and the film curve are one include of their own
  (`hall_rig.gdshaderinc`; the plot rule moved to `hall_plot.gdshaderinc`) and the rig is one value
  (`rink_arena.rig()`): REPORT.txt, "For the merge".
- **Found on the way**: thirdjam hides the glass and its rail on the clay tier (K3's "no glass" is right); the ice
  material itself paints the centre line (60 cm), the blue lines (60 cm), the goal lines (12 cm) and a centre circle of
  **9 m** radius; the board top is a red felt band with a matte red cap, not team colours.

## The numbers the eye is held to (game still | scene capture | ours, sRGB, 13 px patches, `probe_pixels.py`)

| Spot (pose) | thirdjam game | thirdjam capture | ours |
|---|---|---|---|
| ice near (boards) | 185, 169, 176 | 216, 203, 208 | 182, 171, 176 |
| ice near (end_own) | 183, 171, 184 | 213, 204, 214 | 180, 173, 183 |
| ice far (end_own) | 186, 173, 184 | 215, 205, 214 | 182, 173, 182 |
| stand post (boards) | 103, 54, 22 | 152, 59, 9 | 108, 60, 35 |
| floor outside the boards | 86, 44, 18 | 92, 28, 2 | 89, 48, 28 |
| far stands (boards) | 60, 41, 27 | 51, 36, 25 | 70, 55, 44 |
| stands (end_own) | 80, 37, 14 | 90, 26, 2 | 104, 56, 31 |

**The tone gain.** With the candela, the exposure 1 / (1.2 x 2^4.2) and Unreal's film curve as I read them, the
picture comes out about six times too dark in linear light. `TONE_GAIN = 6.0` (`rink_arena.gd`) is one number, set so
that the ice and the wood land on the game's stills (4.5 with the first curve I used, 6.0 with Unreal's own). It is
not derived and I do not know what in Unreal's chain accounts for it. Our darks stay bluer and lighter than
thirdjam's (the last two rows): Unreal runs its curve in a wider colour space with a red modifier, which is not ported.

## Cost and size

- 1280 x 720, RTX 4090, viewport render time, mean of 90 frames a pose over 8 poses, the machine shared:
  the hall adds **0.18 ms GPU and 0.08 ms CPU** a frame (0.58 against 0.41 ms GPU), of which the 664 fans are
  0.07 ms GPU and 0.04 ms CPU. A first run under other load read 0.63 to 0.98 ms GPU for the hall. All fans are drawn
  at their near level (608 triangles): thirdjam's far level is not used yet.
- `engine/cores/rink/arena/`: 5.0 MB (limit 40).

## What my eye rejects (looked at: r1_sbs_1.jpg, r1_sbs_2.jpg, r1_pair_boards.jpg, r1_pair_end_far.jpg, r1_pair_corner.jpg, r1_game_frames.jpg)

In ours:
1. **K3's markings lie on my ice in K3's paint**: a solid blue crease (thirdjam's is pale with a red rim), a strong
   blue centre circle of 4.5 m that thirdjam's picture does not have, a darker red goal. With the ice now painting its
   own lines, the centre line and the blue lines are painted twice. Not mine to change (K3's `tj_rink.gd`).
2. **The red cap is duller** than thirdjam's orange-red one. Its master (`M_Trim`) did not come out as text; I used the
   cap colour and its fill parameter.
3. **The upper walls and the roof show more than thirdjam's**: plank edges as rows of light dots, the bunting as
   dotted lines. In thirdjam the roof is nearly black. Same cause as the blue darks above.
4. **A contour line on the near hall** (kick plate, caps, the near stand's timbers). thirdjam draws none. The line is
   the style's, kept for the cel figures; it ends at 34 m.
5. **No mirror in the ice.** thirdjam's rig switches screen-space reflections on: its ice carries a faint image of the
   boards and the stands. Ours has the painted band and the lamps' sheen only.
6. **The lamps do not bloom** (thirdjam: bloom 0.5).
7. The crowd's dark coats are grey-blue where thirdjam's are black; faces a little pale.
8. The crowd sits still (the cheer is written, not yet driven: round 3).
9. One shadow under a figure, straight down, where thirdjam has up to four soft ones from its key spots.

No piece is missing or out of place in any of the 8 poses.

## Deviations

1. `TONE_GAIN` 6.0: a factor that is not derived on thirdjam's exposure (above).
2. The film curve is Unreal's, per channel on sRGB primaries: its AP1 working space, glow and red modifier are not
   ported. Bloom, the post volume's depth of field (focus 16 m, no blur amount) and screen-space reflections: not ported.
3. The sky light (0.35, a capture of a white dome at 0.418) is not ported: it adds about 0.5 lux against 3 to 32.
4. Light: no engine light is made. The hall's materials sum the rig analytically, without shadows (thirdjam's barn
   pieces cast none either; its benches and boxes do). The four key spots' shadows are one shadow of the style's sun,
   straight down, on the ice only.
5. The vignette: Unreal's 0.35 is set as 0.15 in the style's grade (`VIGNETTE_K`), by the ice's fall-off in stills.
6. The style's grade and ink are changed for the whole picture while the hall is up (`TLStyleArena.post`): no plum
   wash, no olive fill, no split toning; the contour ends at 34 m (`HALL_INK`, ours). The figures lose them too.
7. The felt fibre texture is not exported: the felt band and the felt sheen take it at its mean (0.5).
8. `M_Trim`: read by its parameters only; the cap's chipped paint (`ClayCapChips`) is not ported.
9. The fans' far level (146 triangles beyond 30 m) is not used.
10. The ice, the boards and the kick plate are drawn twice (mine over K3's). The scratch map's normal is not used.
11. The reference is HEAD's content on the 15 Nov binaries (`RinkActor.cpp` is identical in both).
12. Baked files live in `engine/cores/rink/arena/` (campaign rule 6), not in `assets/`; the textures are read with
    `Image.load_from_file` when not imported.
13. A door was added to lane K1's file: `TLCores.part(id, name)` (appended; nothing else in it changed).

## Next (round 2: the sound)

1. Export every sound source, the event table from `EffectsBinder` and the MetaSound graphs; the kernel's audio
   additions (files, loops, a music and a voice channel); wire from the core's snapshot events.
2. Carried from this round: the crowd's far level; the cap's master; the reactions wait for round 3.
3. The copy of the build stays in `.tl/tj-export` for the audio export.
