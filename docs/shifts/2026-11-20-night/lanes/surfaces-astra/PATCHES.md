# Frame integration

On the village road, the black line around each pine tier and the outlined clouds still read as ink at normal play distance. For the combined build, compare the frame arm's contour treatment on the road view and in parkour. The runner, beam and flags need to stay legible at play distance. The pine rims and cliff shoulders already carry their own light and shade.

The material relief uses a separate lighting normal. The depth and normal prepass still receives the geometric normal so that fingerprints, wood pores and individual fibres do not acquire ink outlines. The resin reads best under raking light. Check its sky and sun reflections from the bend as well as from above.

# Operator notes for the combined build (surfaces-astra, Opus operator)

- Merge seam with frame: when `detail.handmade` is on, the handmade branch of `toon.gdshader` `light()` replaces the
  directional diffuse with its own wrap term plus a constant warm pigment fill, built from `g_sun`, `g_amb_sky` and
  `g_amb_gnd`. A frame arm's new sun, ambient or shadow keys reach it only through those globals. If the frame arm
  also edits `toon.gdshader` `light()` or adds a contact-shadow/AO term there, the two edits meet in the same function,
  so merge by hand and re-take parkour-f520: this arm's ground p90/p10 shadow ratio is 2.20, classic is 1.54.
- Character / review scene: under diorama, the floor of `engine/rigs/review/review.tscn` loses its visible tile grid
  (the concrete class now takes the handmade surface). The figure itself is excluded (`tl_body.x > 0.5` keeps the old
  path). If the character arm needs the grid for foot-slide reading, it should ask surfaces for a class key on that
  floor, not change the floor.
- Picture cache: `PIC_VERSION` is 17 here. If the combined build also bumps it from another pillar, take the larger
  number + 1. The first windowed run after the bump has a cold picture cache, and packs may show late in a busy
  window run. This is not a look change; it happened in my first classic re-take.
