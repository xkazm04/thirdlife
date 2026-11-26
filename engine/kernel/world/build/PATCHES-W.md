# PATCHES-W: changes the water lane needs in files it does not own

Lane W (M5, spark world-sandbox, 27 Nov 2026). Nothing here was edited; each item names the file's owner, the change and
the evidence. The water layer works without them (W1 has a local fallback); W3 is a defect of the land, not of water.

## W1 (lane L, `land_scatter.gd` + `land_layer.gd`): one owner for the scatter's transforms

Valley trees and reeds standing in poured water must be hidden and come back when it is drained. `land_scatter.gd`
owns those MultiMesh transforms; the water layer meanwhile hides them itself (`water_scatter.gd`, the fallback: it
re-hides after every land body redraw, because `land_scatter.update` sets a transform back when the land under it
moves). Two writers of one transform is fragile. Proposed:

- `land_scatter.gd` `update(id, delta)`: an instance is also hidden when the water layer says its foot is wet:
  `water.wet_at(xf.origin.x, xf.origin.y + d, xf.origin.z)` (water_layer.gd `wet_at(x, y, z, wet := 0.05) -> bool`,
  already there), with `water = land.ctx.home.get_ref().layer("water")` (duck-typed, read only).
- `land_layer.gd`: a method the water layer calls after a flood or drain, `refresh_scatter(chunk: Vector2i)`, that puts
  the chunk into `bodies` (so `step` runs `scatter.update` and `hook.refresh` for it).
- Then lane W deletes `water_scatter.gd` and calls `land.refresh_scatter(chunk)` from `water_layer.gd` `step`.
  761 `water.scatter` holds the behaviour either way.

## W2 (lane L, `land_layer.gd` `trunk_foot`): no invisible trunk in a pond

`home/hook.gd` `_make` asks only `land.trunk_foot(foot)` whether a trunk collider stands. A tree hidden by water keeps
its trunk, so a person wading meets an invisible post. Proposed: `trunk_foot` returns null when
`water.wet_at(foot.x, foot.y + delta, foot.z)`; with W1's `refresh_scatter` the body is rebuilt after a pour or drain.

## W3 (lane L, `land_layer.gd` / `land_protect.gd`): the river shows in hollows dug 71-157 m from its line

The scout's hypothesis is real, measured both ways:

- The river ribbon (`home/places.gd` `river()`, `TLKitRoad.river_ribbon(channel, 136, 0)`) is a plane at
  `valley.level(z)` whose HALF width is `136 x (0.85 + 0.3 sin(0.31 i))` = 115.6-156.4 m either side of the line; the
  land's "river" band is 71 m. Headless (761 `water.river`): of 2,829 vertices 75-156 m from the line that the land lets
  a person sculpt, 1,476 can be dug 1 m below the river's level (their ground is within 24 m above it).
- In the exe (editor binary, crisp): at (-645, 72), 87 m from the line, ground -0.31 m, river -4.91 m, the sculpt tool
  lowering for 140 frames: the hollow fills with the river's water plane with no pour at all
  (`w-river-hollow.jpg` in the lane's scratchpad).

Proposed fix (keeps the 85 m of sculptable bank on each side): in `land_layer.gd` `can_apply` (and in the stroke's
filter, `stroke_end`), refuse a vertex whose new height is below `valley.level(3 j) * 100 + 30` cm when it lies within
157 m of the river's line (perpendicular: sample the line every 6 m, as `water_layer.gd` `_near_ribbon`), reason
`river: below the river's level here`. Widening the band to 157 m would also work but takes that land from every use.
The water layer already refuses floods there ("spills into the river": its own area rule, `area_rule`, and its pour).

## W4 (the Director, `contracts/BUILD.md` / BUILD.md "Layers"): what the water layer adds to the interface

Not a change request, a note for the docs: `read_region` gives `water_cells: [[i, j, level_cm], ...]` (PATCHES-C C3),
`water_runs` uses `y = floori(level_cm / 100.0)` (PATCHES-C C2), and `wet_at(x, y, z)` is public (W1, W2). Blocks and
the visitor do not stop a flood (a post may stand in a pond; a person may stand in the hollow he fills): the land
layer's area rule answers "blocks" / "too close" for them, and the water layer reads those two reasons as allowed.
