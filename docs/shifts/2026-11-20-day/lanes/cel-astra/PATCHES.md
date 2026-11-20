# Cel surface handoff

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
