# The three pillars (each arm reads COMMON.md, then its own pillar here)

## frame: light, sky, atmosphere, camera (selftest blocks 570-579)
**Goal:** the frame of board 4.
- **Sky:** a warm sunset over a painted backdrop. Clouds are soft cotton or clay puffs; the vertical seam that cuts
  today's billboard clouds is gone.
- **Light:** a low, warm, raking sun that shows surface texture.
- **Shadows:** soft, with tight contact darkening where feet, posts and props meet the ground (AO or contact shadows).
- **Grade:** a gentle miniature grade.
- **Tilt-shift depth of field:** a camera setting that keeps the focus on the player and blurs the near rail and the
  far meadow. It stays readable in play: off or very gentle in flight and in the hockey overview, and you say how that
  is decided.

**Your files:**
- `engine/style/shaders/sky*.gdshader`, `grade*.gdshader`, `ink_post*.gdshader`, and new post or DOF shader files;
- the sun, env, fog, sky, ink, grade and lights sections of `engine/style/style_diorama.json` (and new keys there);
- the `install()` part of `engine/style/tl_style.gd` (light, environment, post) and `engine/style/tl_style_fx.gd`;
- camera depth-of-field hooks in `engine/kernel/api/tl_chase_cam.gd`, `tl_orbit_cam.gd`, `tl_cameras.gd` and
  `engine/kernel/world/terrain/crown_camera.gd` (presentation only);
- new `engine/tools/selftest.d/57x-*.sh`.

**Not yours:** material response (surfaces), the figure (character).

## surfaces: the world's materials (selftest blocks 580-589)
**Goal:** the surfaces of board 4.
- **Materials:** clay and painted plastic for kit, buildings and bluffs, with fingerprint and tool-mark detail.
- **Foliage:** felt pines and bushes.
- **Ground:** grass as felt or flocking.
- **Timber:** wood grain with uneven paint, e.g. the striped beam.
- **River:** glossy resin water.
- **Detail:** chipped paint at edges.

All detail is anchored in the world or the object and does not crawl in motion; measure it with
`bash engine/tools/look.sh boil` or the walker-feel crawl measures.

**Your files:**
- `engine/style/shaders/toon.gdshader` (diorama branches or a new variant chosen by style keys), `water*.gdshader`,
  `holo*`, and new material shader files;
- the palette, mat, detail, water and toon sections of `style_diorama.json` (new keys allowed; existing palette keys
  are never renamed or reordered);
- the `material()` part of `engine/style/tl_style.gd`;
- the terrain look: `engine/kernel/world/terrain/village_terrain.gd`, `tree_crown.gd`, `village_parts.gd`,
  `engine/kernel/world/draw/**`;
- kit vertex tones in `engine/kits/**` (additions only; `PIC_VERSION` bump);
- new `engine/tools/selftest.d/58x-*.sh`.

**Not yours:** sky, light, post, the figure.

## character: the toy figure and how it moves (selftest blocks 590-599)
**Goal:** the figure of board 4. It is a toy made of separate clay or painted pieces:
- a red jacket with a collar and cuffs;
- blue trousers;
- sculpted brown hair;
- boots;
- shallow fingerprint and chipped-paint detail;
- chunky, readable proportions, seen from behind.

The animation moves toward a toy feel that serves play: arm IK or hands that meet what they grab, secondary motion
(hair, collar), smoother transitions between run, jump and land, and a pleasing idle.

**The route is free on fixed rails.** Refine the code-built figure (`engine/rigs`), or model one in Blender and bring
it in. Blender 4.2 is at `C:/Program Files/Blender Foundation/Blender 4.2/blender.exe`, and the existing path for
imported meshes is `engine/tools/assets/pip_blender.py` and `wings_blender.py` with `TLKitAsset`. A skinned import
needs a new loader. Say which route you took, and why. The rails that must hold:
- **The API:** `TLBiped.create` options and behaviour stay unchanged; the clip names and bone names are kept
  (`LeftHand`, `RightHand` and the sockets).
- **Size and budget:** `metrics()` keeps height 2.0 and radius 0.3, so the capsules and hockey's hashes cannot move.
  The figure stays at 12k tris and 30 bones or fewer.
- **Every game still works:** hockey skaters (helmet, stick, team colours through `rig_params.colors`), the parkour
  runner, the village walker and the summoned wings. Show them in the shot set.
- **Tests:** `rig.`, `moves.`, `flight.` and `wings` selftests pass, or each moved expectation is named with a reason.

**Your files:**
- `engine/rigs/**`;
- `engine/kernel/world/visitor.gd` (the rig build and the clip and grip copy);
- `engine/kernel/api/tl_biped.gd` (the rig part);
- `engine/kernel/world/flight_wings.gd` (only to keep the wings fitting);
- `assets/**` and `engine/tools/assets/**`;
- a new `engine/style/shaders/body*.gdshader` (if the figure needs its own material);
- new `engine/tools/selftest.d/59x-*.sh`.

**Not yours:** sky, light, world materials.
