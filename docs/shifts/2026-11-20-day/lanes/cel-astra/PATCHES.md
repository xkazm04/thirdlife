# Cel surface handoff

## Operator note, 18:45 (for cel-fable and the Director): the dark C-band in 08

The large dark C-shaped band on the meadow in 08_parkour_above (integration 2) is the drifting cloud shadow,
`toon.cel_cloud` (cel-fable's key). Measured on a scratch archive of 5e4b5c8 (never in this worktree), with the same tour
in crisp and in crisp with `toon.cel_cloud` 0: the band disappears without it (`.tl/i2-cloud/08_pair.png`). It covers
10.2 % of the frame and paints the full cast depth: grass 77,103,37 against lit 174,182,33; road 110,65,65 against
225,133,64. From above it reads as one giant cast. Suggested, yours to decide: a shallower cloud shade than a cast
shadow, or a smaller or broken cover. Not isolated, only seen: 51_road_visitor has a lighter oval on the road around the runner (242,149,71 inside,
225,133,63 outside), possibly the same cover.

## Round 5 integration

The joined 40° key uses `sun.filter_quality = 5`, `shadow_blur = 1.0` and `shadow_splits = [0.027, 0.07, 0.22]`. The four cascades still reach 235 m. Their first three boundaries are now 6.35, 16.45 and 51.7 m. The palette fit uses the same light colour, energy, elevation, bearing and linear exposure as round 4.

On the left-hand fence cast in the playable west-facing road view, the old filter crossed halfway from shade to lit road 19 extra times in 120 scanlines. The new filter crossed once per row. The edge's RMS deviation from a fitted curve fell from 1.24 to 0.35 px. Its median 10–90% width fell from 2.62 to 1.45 px. Both native captures use the same pose at tick 1180. The same near edge in the frozen visitor view for shot 51 went from 1.34 to 0.36 px RMS, with 20 extra crossings reduced to zero. The boot cast still meets both soles. This resolves the filter request with the existing surface shadow cut.

With the delivery screen-space AA, the same near edge measures 1.53 px wide in both shot 51 and the playable west view. The middle edge has zero extra crossings in either capture. For palette work, use the existing surface values and the same 40° key. The new sky pigments are `horizon #ffbd84`, `mid #e177a7`, `upper #9a82ce`, `cloud #ffda9f` and `cloud_shade #dfa5c3`. [Fence comparison](stills/r5-fence.jpg) · [Sky beside board 2](stills/r5-sky.jpg)

With the same tuft mesh and paints, the share of fine grass pixels changing by more than 24 luma levels per frame fell from 8.82% to 4.06% on the village road and from 26.18% to 9.45% against the open sky. The thinnest tips still flicker during a pan. [Grass crops and reference](stills/r5-grass.jpg)

I repeated your `crawl.sh` on the integration and delivery trees. Review-horizon flips fell from 1.706% to 1.131%. The broad far-land band averaged 0.815 luma levels of change, down from 1.030, while its flips over 24 rose from 0.692% to 0.819%. Near-land flips were 0.156% and 0.155%. The paired recordings are in `.tl/astra-r5/surface-joined/` and `surface-delivery/`.

The integration already contains `toon.shade_k = 0.85`. Both the wardrobe and exported-AA clean-load assertions now pass.

## Round 4 integration

**Use the round-4 grade when fitting the meadow.** The direct key is `#ffe4a6` at energy 1.17, elevation 40° and azimuth 176°. Tonemapping is linear at exposure 0.93. The existing `grade.plum_density = 0.88` supplies the road's plum. The new `grade.olive_fill = 0.88` cools dark yellow-greens in the display grade. It reduces excess green and fills the missing blue up to a limit set by the incoming pigment. The selector sees colour, so dark leaves can pick it up too. Set **olive_fill alone** to zero in a private comparison to see the contribution under a new palette.

| Native sample | Round 3 RGB | Round 4 RGB | Board 2 RGB |
|---|---|---|---|
| Visitor tree cast on grass, (780,545) | 90, 123, 11 | 81, 107, 36 | 80, 106, 35 and 77, 103, 35 on grass beneath fence rails |
| Visitor lit grass, (300,600) | 184, 186, 27 | 184, 186, 27 | 191, 174, 22 and 198, 178, 19 |
| Lighter patch inside tree area, (640,560) | 165, 173, 26 | 165, 173, 26 | |
| Visitor boot cast on road, (1300,1010) | 117, 73, 71 | 117, 73, 71 | 124, 79, 74 in bush cast |
| Visitor lit road, (700,1000) | 241, 148, 70 | 241, 148, 70 | 247, 149, 69 |
| Parkour road, right-hand fence rail cast, (660,886) | 95, 126, 9 | 86, 108, 36 | 80, 106, 35 |
| Sunlit grass above that rail, (662,866) | 192, 191, 25 | 192, 191, 25 | 191, 174, 22 |

Visitor samples are 7 × 7 medians in shot 51. The two parkour samples are 5 × 5 in shot 07. In the parkour pair the cast keeps 45% of lit red and 57% of lit green, and blue rises from 25 to 36. In the board pair it keeps 42% and 61%, and blue rises from 22 to 35. The broad crown still shapes the visitor cast. The parkour fence shows what the same grade does on thin shadows. The remaining meadow differences are the sunlit paint and the distribution of tree crowns, rails and posts. [Board, tree and fence comparison](stills/r4-shadow.jpg)

**Joined-tree load repair.** The authoring correction for cel-fable is still `toon.shade_k: 0.90 → 0.85` in `style_crisp.json`. The validator already renders at 0.85. The higher authored value triggers the clean-load assertions in `character.cel.wardrobe` and `style.cel.exe_aa`.

## Round 3 integration

**Gate repair for cel-fable.** In `engine/style/style_crisp.json`, set `toon.shade_k` from `0.9` to `0.85`. The loader already renders the joined style at 0.85. It returns a clamp message on every load, which fails the clean-load assertion in `character.cel.wardrobe`. The fixture measured 12 wardrobes, 29 bones and zero grip error. The only reported error was `crisp load`. The exported joined build logs the same clamp. Please preserve the shared validator and the clean-load assertion.

**Tree patch in shot 51.** At (645,590) the grass reads (165,173,26), against (186,188,27) at (745,590). Both pixels stay identical with the ink pass hidden, directional shadows disabled or positional lights hidden, tested separately in the frozen view. Forcing a single grass paint in the diagnostic terrain shader makes both pixels (186,188,27). The shape comes from the selection between land paints. The probes are in `.tl/astra-r3/pool-study/`.

**Light and grade.** The palette still receives `#ffe4a6 × 1.17`, linear tonemapping and 0.93 exposure. In a frozen joined road view, removing `grade.plum_density` changed the cast from (119,74,72) to (128,103,60). Board 2 is (112,69,77), so the delivery keeps 0.88. Contact shade and fog sun scatter are both zero. The yellow glow around the disc is painted into the sky. A bridge control showed only about 1–2 levels of change on the facing hill from removing scatter.

The delivery key is 40° elevation, 176° azimuth, normal bias 2.8 and depth bias 0.043. In shot 51 the sunlit road is (241,148,70) and the interior of the tree cast is (118,73,72), within eight levels per channel of the board. The grass in that cast is (90,123,11) at x745–784, y566–580. Board grass shade is (80,104,35). That leaves a sampled difference of (+10,+19,−24), especially yellow-green in the shade. The operator’s original x1500–1699, y620–659 box now falls outside the cast. For lit grass, the fixed foreground is (182,185,27) against (200,182,22) on the board. These are display-space differences for evaluating the grass paints under the joined light.

**Bluffs in shot 13.** In the joined native image, the left mesa at x547–575, y251–273 reads (155,84,149). The right river-bank facet at x1755–1794, y372–382 reads (114,71,171). On the board at its native 1280 × 720, the left mesa at x317–367, y122–153 reads (168,94,120) and the right mesa at x890–949, y178–200 reads (169,94,127). On the joined left face red exceeds blue by 6 levels, against 48 on the board. Start with the shaded cliff paint there. Globally warming the grade would also move the already close tree cast on the road.

Under the delivery key, the same left mesa reads (151,78,150). The right-bank sample turns sunlit at (230,145,141). Re-evaluate the cliff pigment on the left face first. It remains in shade in both captures.

**Clean-load control.** With a private copy of the delivery engine and exactly the suggested 0.85 authoring change, the original assertions return `PASS character.cel.wardrobe` and `PASS style.cel.exe_aa`. Logs are in `.tl/astra-r3/clamp-control/`.

## Round 2 integration

The new sky warms the horizon in the visitor shot. The fixed lit-road sample at (1320,965) remains RGB (220,152,80) and the boot cast at (1250,1030) remains (128,71,97). Both are 15 × 15 medians at 1920 × 1080. Use those coordinates to judge the surface merge under the final sky. The tested material patch and its board comparison follow below. [Final visitor road and sky](stills/r2-sky.jpg)

## Round 1 proposal

For cel-fable and the Director at the first integration. The frame and figure already provide side light, a plum grade and three measured red jacket bands. Look at the tree shadow crossing the visitor road and the near side of the beam in the parkour still. The road still carries the shared screen-space hatch, and the soft edge of a single cast can pass through both diffuse thresholds. Those two details compete with the silhouette.

## Proposed crisp material settings

In `engine/style/style_crisp.json`, merge these entries into `toon`. Preserve all other entries and your own material work. The existing variant selector in `engine/style/dio/style_dio.gd` maps a model name to its uppercase shader define. If your integrated cel model already has a name, use its define in the shader hunk below.

```json
{
  "model": "crisp",
  "shade": "#535d99",
  "shade_ground": "#725786",
  "shade_k": 0.80,
  "amb_sky": "#897db8",
  "band_hi": 0.48,
  "band_lo": 0.18,
  "band_soft": 0.012,
  "wrap": 0.38,
  "hatch": 0.0,
  "rim_k": 0.18,
  "rim2_k": 0.12,
  "bounce_k": 0.26
}
```

## Proposed shader hunk

In the existing banded directional-light branch of `engine/style/shaders/toon.gdshader`, use surface angle to choose its paint. Use cast visibility once, after choosing its paint. Retain the existing diorama branch, positional lights and specular terms.

```diff
- float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION;
+ float lt = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
+#ifndef TL_CRISP
+ lt *= ATTENUATION;
+#endif
  ...
  vec3 col = mix(shc, midc, b_lo);
  col = mix(col, litc, b_hi);
+#ifdef TL_CRISP
+ col = mix(shc, col, smoothstep(0.40, 0.60, ATTENUATION));
+#endif
```

## Road test

I loaded the patch into a separate running renderer after world initialization and took the same 1920 × 1080 visitor shot. The shared toon shader on disk and the official round-one captures retain the original surface model. [Board, round one and proposal](stills/road-shadow-proposal.jpg)

The boot cast on the board measured median RGB (112,69,78) in a 7 × 7 sample at (780,678). In the game, a 15 × 15 sample centred at (1250,1030) measured (128,71,97) in round one. A first trial with literal plum shader inputs produced a brown (138,66,62) cast because the road pigment also colours the light. A cooler trial gave (120,60,101). The values above produced **(115,63,81)** and preserved the uninterrupted paint inside the cast. On the same patch, luma standard deviation went from 3.42 in round one to 0.08 in the proposal. Lit road at (1320,965) changed from (220,152,80) to (216,149,73). The board cast has a little more green.

Compare the grass and broadleaf crowns on the integrated tree as well. The weaker rims and bounce darkened them in this experiment. Tune the partner's surface shade under the shared key first, then review whether the frame still needs `grade.plum_density = 0.88`. The three isolated proposals and test harness are under `.tl/astra-r1/partner-study/`.
