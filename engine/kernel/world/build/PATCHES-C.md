# PATCHES-C: what lane C (M5: the LLM bar, locks, the stamp name) needs in files it does not own

Written 27 Nov 2026 by lane C (spark `world-sandbox`, wave 5). The Director makes these; lane C made none of them.

## C1. BUILD.md (frozen): three lines are stale once lane C lands

- "Layers", `preview_node` row: "Land and pieces have none yet (lanes L and C add it)" -> "Pieces: the pieces a dry run
  puts in holo and those it lifts in red (`piece_ghost.gd`). Land has none yet (lane L adds it)".
- "Build mode", `tools/command_tool.gd` row: the counts example "24 blocks, 3 paint, 1 refused: occupied" -> "24
  blocks, paint 3 cells; 1 refused: occupied" (COMMAND.md "M5": every kind counted, refusals after a `;`, up to 3
  reasons), and add "an op naming a locked material, shape or part is refused `locked: <condition>` when shown and at
  accept".
- "Build mode", `tools/piece_tool.gd`, `tools/stamp_tool.gd` row: "G save" -> "G name (a field, "Stamp N" selected),
  Enter save, Esc cancel".

## C2. Lane W: the `y` of the ask's water, one rule for both sources

`command_ask.gd` `water_of` writes the valley's river and ponds with `y = floor(level in m)` (the cell holding the
surface: the stream near the spawn, level -2.21 m, is `y` -3) and lets the water layer's `water_runs` win in a column.
`water_runs` should use the same rule (`floori(level_cm / 100.0)`), or the model reads two different meanings of `y`.
The prompt says: "surface in cell y Y (a block at y Y or lower in these columns stands in the water)".

## C3. Lane W: the drain level the model must name

A `drain` op names `level_cm`, and the ask's `water` holds only the cell `y`. The model can name the level only when
the water layer's `read_region` gives it (the ask's `layers` key carries every layer's `read_region`). The prompt says
"level_cm is its level now"; a water layer whose `read_region` lists `[i, j, level_cm]` makes that a measured fact.

## C4. Lane L: the land layer's `preview_node`

In 765 `command-m5.ghosts` a land and paint answer is shown with no ghost of its own (the case names `land` among
"layers that took ops but draw no ghost yet"). When lane L writes `land_layer.gd` `preview_node`, the case expects a
node for it with no change.
