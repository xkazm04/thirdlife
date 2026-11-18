# The Site Boss

**Who it is.** Every plot in the village was once a building site, and the Site Boss is what the sites left behind: a
6 m golem that pulled itself together out of a concrete road barrier, two stacks of kerb blocks, a pair of crane-tower
lattice sections and the foreman's hard hat. It walks the plots after the last game of the day, beacon turning, and
it guards the one plot that is still "under construction". It is not evil, it is a stickler: it slams the ground to
knock players off unfinished ground, swats with its girder arms, and only the player who outplays it gets the plot
"handed over". It reads as the village itself turned against you, built from the same kit you have walked past
(barriers, cones, hazard stripes, planks, the crane), so it belongs instantly in this look.

**Silhouette.** Top-heavy wedge: a very wide barrier torso, short stumpy block legs, long arms that hang to knee
height with oversized fists, a tiny head sunk between two cone spikes. Readable as a black shape at any distance:
two cones + hat + beacon on top, two fists at the bottom corners.

**Palette (from `engine/style/style.json`).** Body `concrete` #cbbdb4 / `concrete_dark` #9c8f98; arms `steel` #8a85a0 /
`steel_dark` #4f4a60; hazard band `yellow` #f2b230 + `black` #2b2532; hat `yellow` #f2b230; beacon `beacon` #ffb030
(emissive); visor `bot_visor`/`cyan` #52f2ff (emissive); cones `cone` #f0702c + `hazard_white` #f3ece6; fist tape
`orange` #e8742c; plank `wood` #b9794a; straps `strap` #4a3f4a. Shading comes from the kit's toon/ink pass, not from the
mesh.

**Scale.** 6.0 m standing (3x the 2.0 m walker): legs 2.0 m (the walker's head reaches the bottom of the torso), torso
2.6 m tall and 3.6 m wide at the shoulders, head + hat 0.9 m, beacon 0.5 m. Fists 1.1 m blocks; arms reach to the
knees. Concept images: `boss_front.png`, `boss_three_quarter.png`, `boss_in_game.png` (in game it measures about 2.6x
on screen with the walker a step nearer the camera, about 3x at equal depth).

## Modelling notes (Blender, low poly)

- **Parts as separate rigid pieces, one bone each** (torso, head, 2x upper/lower arm, 2x fist, 2x thigh block, 2x
  shin block, 2x foot, 2x shoulder cone, back plank): no skinning needed, it animates like the kit's biped by
  rotating blocks. Target about 1.5 to 2.5 k triangles in total.
- **Torso = one beveled box**: 8-sided in plan (chamfered corners), slightly narrower at the bottom, two shallow
  rectangular inset slots on the chest (the barrier's forklift slots) and two U lifting hooks are optional detail. The
  hazard band is a separate thin strip of quads (or a 2-colour material split), not a texture, so the toon bands stay
  crisp.
- **Arms = square lattice girders**: four corner beams (box section, 4 sides) per segment with X bracing as flat
  boxes; two segments per arm joined by a collar band at the elbow. Keep the lattice open so the ink outline reads as
  a girder; if poly budget is tight, a solid box with the X cut as inset faces is the fallback.
- **Legs and feet = stacked chamfered boxes**: three blocks per leg, each slightly offset, and a wide wedge foot about
  1.6x the leg width. Feet flat on the ground so the walker's shadow and contact read clearly.
- **Head is small on purpose**: a rounded box with one recessed visor slot (emissive cyan quad), under an oversized
  10 to 12-sided hard-hat dome with a brim ring, beacon a 8-sided cylinder plus cap (emissive amber). Cones are
  8-sided cones with 2 white band rings, seated in a square base plate on each shoulder.
- **Proportions to keep**: shoulders 3.6 m vs hips 2.2 m (wedge), fists as wide as a leg, head width under a quarter of
  the shoulder width. Flat faces and hard edges everywhere (no subdivision), so the inner ink lines fall on the facet
  edges like the rest of the village.
