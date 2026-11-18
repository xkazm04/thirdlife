# bugfix-37 lane `world`: report

All eight defects fixed at the root, each with a headless regression case (block `engine/tools/selftest.d/320-bugfix-world.sh`,
script `engine/kernel/world/walks/bugfix_world_case.gd`, one Godot run, one verdict per case). I seeded every case red: with the
six engine files temporarily put back to HEAD, all 8 cases printed `fail`, and with the fixes back all 8 printed `ok`.

| D-id | defect | status | files | regression case | proof (repro line before -> after) |
|---|---|---|---|---|---|
| D9 | the world's copy of a pack's box/sphere/capsule colliders loses its shape when the holder is freed | fixed | terrain/world_space.gd | `ground.ledger_shapes` | `ledger_collider immediate: FAIL ... actual_after=nan` / `sliced: FAIL ... nan` -> `actual_after=0.5` both |
| D3 | a shut pad is drawn with no collider under it (fall-through) | fixed | landscape.gd, terrain/world_space.gd (`add_pads`), terrain/village_terrain.gd (`faces_in_disc`), draw/view_seam.gd (`copy_colliders`) | `ground.shut_pad_solid` | `unloaded_pad: FAIL hole_radius=0.0 visible_pad_y=0.00 support_y=nan feet_y_after_60=-11.80` -> `support_y=0.0 feet_y_after_60=0.00` |
| D4 | the AABB of a rotated floor counts as rim coverage | fixed | draw/draw_base.gd (`ground_cover`), draw/view_seam.gd (rim cache key) | `ground.rotated_cover` | `rotated_ground: FAIL yaw=45 physical_coverage=48/144 reported=1.000 hole_radius=42.5` -> `reported=0.333 hole_radius=0.0`; P3 `run.py cover`: `reported_cover=1.000 rays_missing=122/144` -> `reported_cover=0.167` |
| D13 | a floor of a few large triangles is dropped from far pictures | fixed | draw/draw_pictures.gd (`_tri_meets_disc`), draw/draw_base.gd (PIC_VERSION 15) | `ground.crossing_faces` | `crossing_faces: FAIL subdivisions=0 ... mid_triangles=0 far_triangles=0` -> `mid_triangles=2 far_triangles=2` (control 30/30 unchanged) |
| D16 | the flat-ground path never shuts pending holes | fixed | landscape.gd (`ground()`) | `ground.flat_holes` | headless proof (P7 needs a window): before, material registered false (shut_holes returns early); after, a pending plot's hole is 27.5 m -> 0.0 m |
| Q15 | a road ending near the river: an out-of-bounds read aborts build() | fixed | landscape.gd, terrain/village_terrain.gd (`bridge_span`) | `ground.bridge_end` | `SCRIPT ERROR: Out of bounds get index '17'` + `'16'`, `bridge_endpoint: FAIL build_completed=false` -> `build_completed=true` (no bridge) |
| Q17 | `pad_h` falls back to the LIFTED plot origin | fixed | landscape.gd, terrain/world_space.gd (`pad_rim`) | `ground.pad_lift` | `pad_lift: FAIL explicit_pad=false pack_rim_y=0.00 pad_y=-5.00 collider_y_at_r39=-4.68` -> `pad_y=0.00 collider_y_at_r39=0.00` |
| Q21 | every road graded with the first road's half width | fixed | terrain/village_terrain.gd (`build_grid`, `_stamp`) | `ground.road_width` | `road_width: FAIL expected_y=19.98 wide_first=19.98 narrow_first=7.19` -> `narrow_first=19.98` |

## What each fix does

- **D9**: `step_pack` and `_add_pack_walk` now put the pack's primitive `Shape3D` in `_keep` before making the body that uses
  its RID. The shape is still shared, not duplicated.
- **D3**: in `build`, the terrain triangles that `collision_faces` leaves out inside a plot with ground of its own are added
  back for that plot, under the tag `"pad <i>"` and counted as `stats.space.pad_faces`. This only happens when the plot's game
  is not built yet; a holder whose `loaded` is true gets no pad, and neither does a holder with no `loaded` property, whose
  colliders `add_pack` copies right away. `view_seam.copy_colliders` calls `remove_tag("pad <i>")` when a plot's copy is
  complete (both the whole-now path and the sliced path).
  - The pad now carries the visitor whether the hole is shut or a cached picture is shown, until the game's own colliders are
    in. Once they are in, the pad is gone, so nothing is doubled.
  - The change touches only the visitor's space, which no game reads. The landscape is not built under a headless style, so
    the gate's `world` step (headless) runs no new code.
- **D4**: `ground_cover` now counts a rim point as covered when it lies inside the XZ projection of a triangle of a kept wide
  mesh (`Mesh.get_faces()`, transformed into the holder's frame). Degenerate triangles, such as a box's sides, don't count.
  Each triangle is first rejected cheaply against the ring band (radius ± 2).
  - The rim cache key in `view_seam.rim_of` goes from `|cover` to `|cover2`, so a rim cached under the box rule is not read
    again (a new key means one rebuild of each pack on the first visit).
- **D13**: the per-triangle plot cut keeps a triangle whose corners are all outside the plot if one of its edges passes within
  the radius or the triangle contains the centre (`_tri_meets_disc`). `PIC_VERSION` goes from 14 to 15 so cached pictures are
  rebuilt; the comment beside it says to count it up when a picture's rules change.
- **D16**: `Landscape.ground()` stores its material as the meta `tl_ground_mat` on `parent`, as `build` does.
- **Q15**: the bridge span is now `village_terrain.bridge_span()`. It returns (-1, -1) when fewer than 3 road samples are
  within reach. Then there is no bridge, the road strips run on, and neither `Parts.bridge`'s piers (`a+2`, `b-2`) nor the rail
  probe (`mid ± 1`) can read out of range.
- **Q17**: without `pad_h`, a pad stands at the lifted origin plus the rim (`world_space.pad_rim`). The rim comes from the
  viewer's own `rims` (which include `--lift`), else `edge_height` of the world's holder, else 0.
- **Q21**: `_stamp` also records, per vertex, the half width of the nearest road (`road_hh`). Grading uses that half width
  instead of the first road's.

## Commands

```
W=C:/Users/kazda/kiro/third-life/.claude/worktrees/bugfix-37; G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe; cd $W
for s in b_ledger_collider b_unloaded_pad b_rotated_ground b_crossing_faces b_bridge_endpoint b_pad_lift b_road_width; do
  timeout 200 "$G" --headless --path engine --script "$W/docs/reports/bugfix-37/hunt-Q/repro/$s.gd" 2>&1 | grep -E "REPRO|SCRIPT ERROR"; done
python docs/reports/bugfix-37/hunt-P/repro/run.py cover          # P3 (headless); P2/P7 need a window: not run
bash engine/tools/selftest.sh ground.                             # 290-ground (1) + 320-bugfix-world (8)
timeout 200 "$G" --headless --path engine --script "$W/docs/reports/bugfix-37/world/measure_village.gd" -- <out>   (copy measure_village.gd.txt to measure_village.gd first) [<before.bin>]   # shipped village terrain
```

## Files

- Changed: `engine/kernel/world/terrain/world_space.gd`, `engine/kernel/world/terrain/village_terrain.gd`,
  `engine/kernel/world/landscape.gd` (exactly 600 lines, still within the `tl arch` size budget),
  `engine/kernel/world/draw/view_seam.gd`, `engine/kernel/world/draw/draw_base.gd`, `engine/kernel/world/draw/draw_pictures.gd`,
  `engine/kernel/world/WORLD.md` (two sentences: the pad stays until the game's colliders are in; a bridge needs at least
  three samples near the river).
- Added: `engine/kernel/world/walks/bugfix_world_case.gd` (+ its `.uid`, written by Godot),
  `engine/tools/selftest.d/320-bugfix-world.sh`, `docs/reports/bugfix-37/world/measure_village.gd.txt` (measurement only; copy to .gd to run),
  `docs/reports/bugfix-37/world/{baseline,after}-selftest.txt`.
- Line endings kept as in HEAD: CRLF for landscape.gd, view_seam.gd, draw_base.gd and draw_pictures.gd; LF for the rest.

## Behaviour changes and tests

- **Shipped village (Q21 changes it, as expected).** I measured `boot/village.json`'s landscape headless with real terrain,
  HEAD against fixed (`measure_village.gd`; `has_ground` taken as true for every plot, because the rims need the packs).
  - Terrain heights: 5 of 58,015 vertices moved by more than 1 cm, by at most 3.1 cm (mean 2.0 cm), at (-120, -6), 5.8 m
    from a spur road.
  - Unchanged: road 560 m, 10 spurs, bridge 32 m, the rail, tree and rock probes, the pads, the height range, 785 trunks, 296
    canopies, 105,760 terrain collider triangles.
  - New in that run: 9,296 pad triangles in 8 bodies (with no world every plot gets a pad; in a window only plots whose game
    is not built when the landscape is built get one).
- **Q17**: walks without `pad_h` (`tour_views.json`, `site.json`, `site_arrival.json`) now get their pads at the plot's
  authored y when the pack has its own ground with a rim other than 0. Before, the pad sat at the lifted y. All other shipped
  walks state `pad_h` for every plot and are unchanged.
- **D4/D13**: cached rims (`|cover` key) and pictures (PIC_VERSION 14) are not reused. The first visit on a machine rebuilds
  them once.
- **Tests run**, before -> after, all headless:
  - `selftest.sh ground.`: 1/1 -> 9/9.
  - `walk.`: 9/9 -> 14/14 (the walker lane added cases in the meantime; all pass).
  - `world.`: 15/15 -> 15/15, every hash identical (walk_proof, tour, next_round, compact...).
  - Final after-run figures: `docs/reports/bugfix-37/world/after-selftest.txt`.
- **Not run**, because they need a window: `site.solid` and the P2/P7 repros. No test expectation moved and no test was
  loosened.

## Questions for the Director

1. `engine/kernel/world/draw/view.gd:65` (lane cam) says in a comment that the rim cache key ends in `|cover`; it is now
   `|cover2`. `engine/kernel/world/draw/DRAW.md:330` says the same ("The rim cache key ends in `|cover`") and should become
   "`|cover2` (bugfix-37 D4: cover measured on triangles)". I own neither file.
2. New public members on kernel-internal scripts:
   - world_space.gd: `add_pads()`, static `pad_rim()`, and an optional `stat` argument on `add_faces()`.
   - village_terrain.gd: `faces_in_disc()`, `bridge_span()`, and two optional arguments on the private `_stamp()`.
   - draw_pictures.gd: static `_tri_meets_disc()`.

   None are `TL*` API; I did not bump KERNEL_API.
3. With D3, when a game's colliders arrive while the visitor stands on its pad, the pad goes and the game's own floor takes
   over. If that floor is higher than the pad, he may start inside it for a tick (step-up 0.55 m handles small steps). Before
   the fix he fell through instead. Watch it in the first windowed tour.
