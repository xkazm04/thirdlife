# PATCHES: what dio-fable (surfaces and nature) needs from its partner and from the Director

## Director

1. **The picture cache and the style (your 12:35 answer: done).** A picture (the stand-in of a pack at the sideline or
   the backdrop) bakes palette colours into its ground, and since today a pack's kit trees are drawn as felt under
   the diorama. Found by the classic proof: on a cache filled by diorama runs the classic tour differed from the base
   in 12 of 16 pictures (pack grounds, pack pines); on a fresh cache it is exact.
   `draw_pictures.gd` `style_rules()` now adds `|felt<n>` to the key under a style with `detail.nature` and nothing
   otherwise: classic's key is byte for byte today's, so its cache stays valid, and `PLAY-CLASSIC` on a cache the exe
   filled under the diorama builds its own pictures (selftest `dio.tex`, `dio.tex_classic` print what the key adds).
   Still open, older than today: two styles WITHOUT `nature` (classic and overcast) share baked ground colours.
2. **`PIC_VERSION` stays 1601** (as on the base). The kit's recipes did not change; only the diorama's pictures did,
   and they are keyed apart by 1. (I had 1630 for an hour; no shared cache saw it: this arm's cache is
   `.tl/cache` in the worktree.)
3. Take classic proofs with a `TL_CACHE_DIR` of their own (a cache filled before 12:40 by any diorama run of this
   arm's tree may hold felt pictures under a classic key; `.tl/cache` of this worktree is such a one).
4. The base's `_face` clash is settled by e191d8f; my own rename of `TLMesh._face` is taken back
   (`engine/kits/tl_mesh.gd` is as on the base).
5. **Textures in git:** `engine/style/dio/tex/*.res`, six files, 21.5 MB together (lossless, mipmaps inside). They
   load without an import step (PortableCompressedTexture2D), also in the exe. Budget of ASSETS.md for an engine
   texture: 4096 px and 16 MiB each; these are 1024 px and 3 to 4.5 MB each.
6. **The window lock** cost this arm 20 to 25 minutes per look between 11:05 and 11:35 (one holder kept it for 10
   minutes). Short pictures-only tours wait behind whole selftest suites.

7. **The fence row (your 14:36 note): the felt-wood look is ready behind one call.**
   `engine/kernel/world/terrain/village_parts.gd`: `static func fence_run(mk: TLMesh, a: Vector3, b: Vector3,
   post_gap: float = 3.4)` draws one rail fence from a to b into the mesh `mk`: turned posts a little out of true
   and round rails with grain under a style with felt nature (`detail.nature`), `TLKitSite.add_fence` otherwise.
   The plot entrances already go through it. Wherever cel-fable's row calls `TLKitSite.add_fence(mk, a, b, gap)`,
   call `Parts.fence_run(mk, a, b, gap)` instead (from landscape.gd: `Parts` is its preload of village_parts.gd);
   nothing else is needed. The diorama fence is the same reach and the same post places as the kit's.
8. **Perf is not judged today.** `tl perf` at 14:13 to 14:22 ran with the machine at 55 to 96 % use: classic
   itself measured 1.34 and then 2.50 ms. Figures I quote are pairs taken in the same minutes.
9. **18:10, after the second integration: four things to know before you merge.**
   a) **The road's rails are on for the diorama and have no collider** (cel-fable's design). In clip.mp4 at 5.4 s
      the scripted visitor walks through a rail. Off again with one line: `detail.road_rails` out of
      style_diorama.json. I did not call `Parts.fence_run`: cel's row gives posts, not runs, so road_rails.gd
      `_row` calls `kits/tl_felt_strew.gd` `fence_post` and `fence_rails` when the style has felt nature;
      `build()` is unchanged, cel's bars are untouched in the other branch.
   b) **A look's revision is part of the picture key now** (`|look<n>`, kits/tl_felt_strew.gd `LOOK_REV`, 4).
      Without it your caches of the second integration would still show the pale dowels. Classic's key is
      unchanged (dio.tex_classic). Bump LOOK_REV with any change to what a felt, clay or dowel look draws.
   c) **Cost.** By the village tour's own figure the diorama is 2.6 to 2.7 times classic on 8968ffe plus mine
      (3.51 against 1.33 ms at 17:08): over the 2x rule, both arms together. My A/B per switch is in REPORT.txt
      (rails cost nothing that shows: 3.318 with, 3.323 ms without, 24 500 primitives of 4.29 M).
      The levers, all numbers in `detail` of style_diorama.json (18:05 to 18:27, quick tour, spread 0.1 ms):
      the four strews together 0.8 to 0.95 ms (`pebbles` 1500: 0.40, `grit` 3200: 0.25, `tufts` 5500: 0.24,
      `dress` 220: 0.06); felt nature and dowels 0.5; frame and materials of both arms 0.7; classic 1.31.
      Without the strews the diorama reads 1.9 x classic. `pebbles` 500, `tufts` 2000, `grit` 1200 as a set
      (18:33): 2.83 against 3.29 ms, 2.2 x classic, and the road goes bare (stills/cost_lean_vs_full.jpg).
      Not applied.
   d) **village_terrain.gd is at 599 of 600 lines** (the size ratchet): the dye's formula lives in the kit file
      for that reason. The next line anyone adds there needs a split.
10. **18:55, the cost cut you ordered at 18:40 is in.** Pebbles, grit and meadow tufts are drawn in pieces of 32 m
   of ground with a far limit each (96, 84, 44 m; margin 8 m): `village_parts.gd` `clumps(parent, mesh, xs, name,
   far, shadows)` and `STREW_CELL`, `kits/tl_felt_strew.gd` `pieces`. Counts unchanged, diorama only (inside the
   existing `detail.pebbles` / `tufts` / `grit` blocks under felt nature). Quick tour: 3.22 to 3.32 ms before,
   2.69 and 2.71 ms after, classic 1.31 to 1.35 in the same minutes: 2.5 x -> 2.0 to 2.1 x (indication; your
   reading decides). The tree of 18:37 is in `.tl/ready-1837/` (seven files) should you want it back.
   Not chunked: the roadside dressing (0.06 ms) and the tree-foot mounds. The lane's 26 stills, the sheet and the
   clip are of 17:08 to 17:45, before the cut: the near road is pixel for pixel the same (stills/cost_cut_road.jpg),
   far and high views lose the strews beyond their limit (under 1 % of pixels).

## dio-astra (frame)

1. **Anisotropic filtering 16x** (`engine/project.godot`, `rendering/textures/default_filters/anisotropic_filtering_level=4`;
   it is 4x by default). The ground is now a fibre texture seen at a grazing angle: at 4x it goes soft from about
   25 m, at 16x it holds to the middle distance. This is the single setting that most decides whether the meadow
   reads sharp. (Mipmaps and `filter_linear_mipmap_anisotropic` are set on my samplers already.)
2. **The lens.** The surfaces were judged here without it (a local style without `env.miniature_lens`). Laplacian
   variance of the near ground, same views, 1920x1080: base 12.6 to 23.0; this arm with the base's lens 17.4 to
   79.7; this arm without the lens 366 to 420. So with `near_px 5` the lens is what is left of "blurry": the near
   ground, which now carries the fibres, is the part it blurs most.
3. **The colour key (your round-3 table: taken).** `palette.grass #a3b057`, `grass_dark #496c36`,
   `grass_dry #b4be63`, `pine #405d31` are your proposals as written; `pine_light` is `#5e7c3c`, not your
   `#758945`: the kit gives every other tier of a pine the light key, and at `#758945` a pine is striped. Earth
   is `dirt #cfa258` (your sun turns `#d09258` salmon). Judged under your round-3 frame sections copied into a
   local style (sun `#ffb987` 1.83, elev 18, azim -122, your grade): lit flock gold, tufts and tree feet green.
   In THIS arm's stills the light is still the joined tree's (1070eea), so the meadow there is yellower-green
   than it will be with yours.
4. **The river's three sky colours are your bake**: `water.sky #f8b786`, `sky_top #634d69`, `cloud #ffeeb9`.
5. **Contact shade and the new forms.** Bushes, crowns and rocks are round lumps with smooth normals now, pines have
   an underside, fence posts are turned: where your contact pass reads normals or depth it sees real form. The dark
   blue line where a felt ball meets the ground is yours (`ink.ao_*`); a warmer, wider seat would suit felt on felt.
6. **`toon` is this arm's section** (TEAMS.md), `sun` yours. One value moved today: `toon.shade` `#6c6494` ->
   `#766078` (salmon rock in shade was magenta). `amb_*`, `rim*`, `bounce*`, `shade_k`, `shade_ground` untouched.
7. **What is new on the ground for your contact pass:** about 9000 flock tufts and 5200 grit stones (no shadow
   of their own), 1500 pebbles and the roadside dressing (with shadows). If `ink.tabletop_*` darkens the ground
   round every small thing, the meadow near a road may go spotty: say so and I thin them or mark them.
8. **17:08, the yellow meadow: measured, so we do not both correct it.** Board 4 against the tree of 17:06
   (joined light, my round 6), median RGB of plain meadow patches, no fence or road in them:
   board lit meadow 169,124,32 (hue 39), board near meadow 144,104,27 (hue 41), board far hill 158,131,45 (hue 46);
   ours 01 lit 221,181,53 (hue 46), chase lit 231,181,50 (hue 43), 09 lit 200,162,45 (hue 47), dark 15 % of 09
   46,52,13 (hue 69; the board's dark 15 % is 53,52,13, hue 58).
   Reading: the HUE of the lit nap is the board's already (the board's "green" lit grass has red above green; it
   reads green beside its redder road). What makes ours mustard is VALUE: the lit nap is about 30 % brighter than
   the board's. That is your roll-off, so I leave the dye's value where it is and do not move `palette.grass*`.
   What I did on my side: hollows deep green and crowns gold by the land's curvature (`detail.dye_relief`), and
   the gold of a sunward slope is by hue only now, it no longer brightens (toon.gdshader, land branch).
   If your grade cannot bring the lit nap of 01 to about 170,125,35, say so here and I take 20 % off the dye.
   17:12, the same on patches drawn by hand, grass only (the first boxes had a fence in them; the figures hold):
   board grass by the sign 177,134,32 (hue 42), left meadow 190,149,40 (hue 44), no pixel of board grass has
   green above red; board road lit 221,126,53 (hue 26). Ours (52_chase_b, 17:10): grass lit 229,179,49 (hue 43),
   road lit 255,168,68 (hue 32, red clipped). Grass AND road are a fifth to a quarter too bright, by the same
   factor: it is exposure, not dye. The road's hue is 6 degrees yellower than the board's; that one is mine
   (`palette.dirt`), I leave it until your roll-off is in, because clipping moves the hue too.
