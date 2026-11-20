# The two teams and their four arms (each arm reads COMMON.md, then its own section here)

## The scopes (the same split in both teams)

### Astra arm: the frame and the figure
**Your files:**
- `engine/style/shaders/sky*.gdshader`, `grade*.gdshader`, `ink_post*.gdshader`, and new post, lens, sharpen or
  outline shader files;
- the sun, env, fog, sky, clouds, ink, grade, lights, `miniature_lens` and figure sections of your team's style file
  (new keys there);
- the `install()` part of `engine/style/tl_style.gd` (light, environment, post), `engine/style/tl_style_fx.gd`,
  `engine/style/dio/style_dio.gd` functions for the frame (`far_dof`, `shadow_filter` and new ones);
- camera hooks in `engine/kernel/api/tl_chase_cam.gd`, `tl_orbit_cam.gd`, `tl_cameras.gd`,
  `engine/kernel/world/terrain/crown_camera.gd` (presentation only);
- the character: `engine/rigs/**`, `engine/style/shaders/body*.gdshader`, `engine/kernel/world/visitor.gd` (rig build,
  clip and grip copy), the rig part of `engine/kernel/api/tl_biped.gd`, `engine/kernel/world/flight_wings.gd` (only
  to keep the wings fitting), `assets/**` and `engine/tools/assets/**` for the figure.
- project render settings in `engine/project.godot` (anti-aliasing, scaling, filtering): tell the Director in your
  standup, because both arms see the result.

**The figure's rails** (as last night): `TLBiped.create` options and behaviour unchanged; clip names and bone names kept
(`LeftHand`, `RightHand`, the sockets); `metrics()` height 2.0 and radius 0.3; at most 12k tris and 30 bones; hockey
skaters, the parkour runner, the village walker and the summoned wings still work; `rig.`, `moves.`, `flight.`,
`wings` and `character.` selftests pass (each moved expectation named with a reason). Blender 4.2 is at
`C:/Program Files/Blender Foundation/Blender 4.2/blender.exe` if you choose a modelled route.

**Not yours:** material response, terrain, nature, kit (the Fable arm).

### Fable arm: the world's surfaces and nature
**Your files:**
- `engine/style/shaders/toon.gdshader` (branches chosen by style keys, or a new variant), `water*.gdshader`, `holo*`,
  and new material, terrain, foliage or grass shader files;
- the palette, mat, detail, water, toon, terrain and nature sections of your team's style file (new keys allowed;
  existing palette keys are never renamed or reordered);
- the `material()` part of `engine/style/tl_style.gd` and the material-model functions of `engine/style/dio/style_dio.gd`;
- the terrain and nature look: `engine/kernel/world/terrain/village_terrain.gd`, `tree_crown.gd`, `village_parts.gd`,
  `engine/kernel/world/draw/**` (geometry changes bump `PIC_VERSION`);
- kit vertex tones and new kit detail in `engine/kits/**` (additions only);
- textures you make for the world under `engine/style/` or `assets/` (budgets: `contracts/ASSETS.md`).

**Not yours:** sky, light, post, lens, the figure (the Astra arm).

`tl_style.gd` is shared and held to 600 lines by `tl arch`: put new code in your own new file (e.g.
`engine/style/dio/*.gd`, `engine/style/cel/*.gd`) and call it from your part of `tl_style.gd`.

## Team cel: crisp cel, today's look evolved (style file `style_crisp.json`, `TL_STYLE=crisp`)
**Goal:** board 2 at concept fidelity, as a natural evolution of today's game. From `target/NOTES.md` § 2:
- **Astra arm (cel-astra), selftest block 600-609:**
  - light quantized into two or three bands with a crisp boundary; warm yellow on sunward planes, plum in cast shadows;
  - even dark contours (inverted hull or a post outline) that taper with distance so lattices stay open;
  - a saturated violet-to-peach sky with flat cream cloud shapes, each with one lavender underside, and no seam;
  - the runner built from distinct shapes (hair, collar, cuffs, boots), the jacket red through both bands, one dark
    seam between jacket and blue trousers; chunky, readable proportions from behind;
  - sharp at 1080p (no lens blur needed for cel).
- **Fable arm (cel-fable), selftest block 610-619:**
  - clean flat colour fields with painted accents: meadow with sparse grass tufts that keep the pine silhouettes,
    a warm dirt road with a few pebbles, layered bluffs with banded strata, the river as flat blue with light streaks;
  - trees, bushes and rocks as clean stylized forms (pines in tiers, round bushes, chunky rocks) that read at distance;
  - timber and props (fences, beam, scaffold) with crisp painted colour and an edge highlight;
  - surfaces stay calm in motion (no crawl or shimmer).

## Team dio: the toy diorama at concept fidelity (style file `style_diorama.json`, `TL_STYLE` unset)
**Goal:** board 4 at concept fidelity. Last night got the direction; the owner now finds it blurry and far below the
concept's fidelity. From `target/NOTES.md` § 4:
- **Astra arm (dio-astra), selftest block 620-629:**
  - **sharpness first:** the tilt-shift lens today blurs the near ground and smears the frame (see
    `docs/shifts/2026-11-20-night/lanes/combined/stills/01_walker_road.jpg`): keep the subject, the near ground and
    the middle sharp; blur only as a gentle far accent; clean edges;
  - warm raking light that shows fibres and tool marks; soft shadows with tight contact darkening at feet and posts;
  - the cotton-cloud sunset kept and refined;
  - the clay figure (Astra's, the owner's pick) toward the board: separate clay pieces for the red jacket, blue
    trousers and hair, shallow fingerprint normals, sparse chipped paint at cuffs and boots, a toy feel in motion.
- **Fable arm (dio-fable), selftest block 630-639:**
  - **fidelity:** the material model reads at 1080p as the board's (felt, clay, wood grain, resin), with no smeared
    textures (resolution, mipmaps, anisotropy);
  - felt pines in tiers and felt bushes with real form (not low-poly blobs); flocked ground; pebbles; layered clay
    bluffs; a glossy resin river with reflections;
  - wood grain along each dowel and fence rail; slightly uneven cream stripes with brushwork on the beam;
  - the kit and buildings (the grey slab walls today) as painted plastic or clay with edges and bevels.
