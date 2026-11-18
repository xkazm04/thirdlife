# Brief for Astra: adversarial review of seven candidate findings (15 minutes, read only)

Same repo rules as docs/reports/astra-trial/d5/astra/brief_common.md (no git, edit nothing except the output file named below,
headless Godot only, kill only what you start). You are now the SKEPTIC. Each candidate below already has a repro that prints
FAIL. Your job is to find out, by reading the real callers in the engine, whether the failing situation can actually happen in
the shipped game (the world/visitor running real walks in engine/kernel/world/walks/*.json and engine/boot/*.json), or whether
something elsewhere already prevents it / the behaviour is intended. Cite file:line for every claim. Do not write new repros
unless a 5-line change settles it.

1. b_ledger_collider (world_space.gd `_static(sh, ...)` without `_keep`): when a pack holder is replaced (draw.gd replace_holder,
   a next round rebuilt from its seed) or unloaded, are the world-space copies removed / re-added anyway? Or do primitive pack
   shapes really vanish from the visitor's collider while the plot is still drawn?
2. b_unloaded_pad (view_seam.gd close_holes shuts the hole visually; collider stays open): can the visitor's body actually stand
   inside an unarrived plot radius (when do packs arrive relative to his distance)? 
3. a_stage_input (a bot's held `press` survives into a person's play on stage): does anything release the bot's injected presses
   when `bot_off` becomes true (pack.gd, life, TLHand, the stage entry in visit.gd / view.gd)?
4. b_pad_lift (landscape.gd:103 fallback pad height = lifted plot origin): which real walks omit landscape.pad_h, and do any of
   their packs get a non-zero lift? If none, say it is latent.
5. a_camera_wall (cast_motion ignores a body the sphere already overlaps): the visitor capsule radius is 0.35 > avoid_margin 0.3,
   so layer-1 walls stay clear of the look axis. Can the LOOK POINT (anchor-smoothed, 1.7 m up) be within 0.3 m of / inside a
   layer-1 or layer-4 (canopy) body in real play (jump under a tree crown, anchor lag on stairs/slopes)? Give the geometry.
6. r_slide (held slide pose leaves the trailing left hand 0.31 m above the floor; RIGS.md says it trails on the floor): is the
   hips offset of the slide pose applied in the repro the same as in the game, i.e. would the hand touch in the real visitor?
7. a_camera_cut_wall (one interpolated frame of the camera inside a box during a 90 degree turn in one tick): can a person's
   mouse turn 90 degrees in one tick in visit.gd (sensitivity, clamps)?

Write docs/reports/astra-trial/d5/astra/review.md: per item a verdict `REAL in play` / `LATENT (real code defect, not reached by
shipped walks)` / `NOT A DEFECT`, with the evidence. Reply with the seven verdicts, one line each.
