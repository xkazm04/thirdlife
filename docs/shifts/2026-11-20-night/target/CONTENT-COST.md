# How much harder would new games be in each style? (Director, 19 Nov 22:55)

The fast path today: a game (pack) names palette colours, places code-generated kit parts, and gets its character from
one `TLBiped.create` call. It never touches materials, light or the sky. Each style below is judged by what it would add
to that path, using the scout's facts (the look is about 80 % data in one style file and 10 shaders; there is no texture
pipeline; kit meshes are faceted and made in code; the figure is made in code).

| Style | Extra cost per new game | Engine work to get there | Risks |
|---|---|---|---|
| 1. Painted storybook | Low. The painting is a screen and material effect over the same parts; games still name colours. | Medium-high: brush-texture terrain and toon variant, painted sky and clouds, softer ink. It needs a small texture pipeline (brush maps), which we do not have yet. | Painted noise can crawl in motion (the walker-feel night fought shading crawl); readability of small props at a distance. |
| 2. Crisp cel | None. It is today's pipeline pushed further. | Low-medium: style.json, toon bands, ink weight, graphic clouds (also fixes the cloud seam), character polish. | Least new identity; the risk is "better, but the same". |
| 3. Stylized modern 3D | Medium-high. Kit parts must become rounded and bevelled (today they are faceted), and every new prop a builder makes must follow suit. TLMesh would need bevel and smooth-normal helpers. | High: AO/GI (SSAO or SDFGI), a new material model, rim light, rework of the kit generators. GPU cost goes up (today ~1.2 ms). | The biggest drift from what LLM builders make well today; performance. |
| 4. Toy diorama | Low. Simple code primitives read naturally as toys, so the fast path suits it well. | Medium: clay/plastic material response, soft contact shadows, tilt-shift depth of field, felt foliage. | Depth of field blurs distant play (flight, hockey overview): it needs a gameplay camera setting. |

The safest for content speed: 2, then 4 and 1. The costliest: 3.
