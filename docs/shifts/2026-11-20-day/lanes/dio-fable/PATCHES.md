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
