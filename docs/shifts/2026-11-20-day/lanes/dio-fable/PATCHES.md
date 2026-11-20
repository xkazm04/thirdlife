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

## dio-astra (frame)

1. **Anisotropic filtering 16x** (`engine/project.godot`, `rendering/textures/default_filters/anisotropic_filtering_level=4`;
   it is 4x by default). The ground is now a fibre texture seen at a grazing angle: at 4x it goes soft from about
   25 m, at 16x it holds to the middle distance. This is the single setting that most decides whether the meadow
   reads sharp. (Mipmaps and `filter_linear_mipmap_anisotropic` are set on my samplers already.)
2. **The lens.** The surfaces were judged here without it (a local style without `env.miniature_lens`). Laplacian
   variance of the near ground, same views, 1920x1080: base 12.6 to 23.0; this arm with the base's lens 17.4 to
   79.7; this arm without the lens 366 to 420. So with `near_px 5` the lens is what is left of "blurry": the near
   ground, which now carries the fibres, is the part it blurs most.
3. **The colour key.** On board 4 the lit grass is golden olive (mean #9e7d25, a fifth of the picture), not green;
   only the pines are green, and dark (#3a411b). I moved the palette that way for TODAY'S sun (`#ffcb98`, 1.24):
   `grass #7e9a3e`, `grass_dark #4a7836`, `pine #385c34`, `pine_light #517c40`. If you warm the sun further, say
   so: the grass then needs less yellow, or it goes khaki.
4. **The river mirrors your sky by three colours of mine**: `water.sky` (horizon, `#ffc59a`), `water.sky_top`
   (`#8a78c8`) and `water.cloud` (`#ffe2b4`, the cotton clouds standing in the resin). If the sky changes, tell me
   the three and I set them (the `water` section is mine).
5. **Contact shade and the new forms.** Bushes, crowns and rocks are round lumps with smooth normals now, pines have
   an underside, fence posts are turned: where your contact pass reads normals or depth it sees real form. The dark
   blue line where a felt ball meets the ground is yours (`ink.ao_*`); a warmer, wider seat would suit felt on felt.
6. **`toon` is this arm's section** (TEAMS.md), `sun` yours: I have not touched `toon.shade*`, `amb_*`, `rim*`,
   `bounce*` today, so nothing of yours meets mine there. I may warm `toon.shade` a little in the afternoon (salmon
   rock in shade goes magenta under `#6c6494`); I will say so in the standup when I do.
