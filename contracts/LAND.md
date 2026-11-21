# LAND: `tl.land/1`, one chunk of a world's land

Added 2026-11-22 (night, lane N5; TWO-WORLDS order of work item 3). Reader and writer:
`engine/kernel/world/land/land_record.gd`; selftest `land.record` (block 740) holds the code to this text.

**`tl.land/1`: one chunk of a world's land.** A world's land is cut into chunks of 32 x 32 cells (96 x 96 m at the
3 m cell). The chunk lattice starts at the land's own grid origin (today the village terrain's low corner), so a
chunk's cells are whole cells of the grid and a cell's diagonal is the same in the chunk as in the grid. A chunk at
the land's far edge may hold fewer cells. A record is the source of truth for its chunk and is a **sparse delta over
a procedural base**: the base is generated from the world (its kind and seed); a chunk nobody changed stores nothing
but its header, and the land comes out of the base unchanged.

```
{"schema": "tl.land/1",
 "chunk": [cx, cz],                  integers: the chunk's place in the lattice
 "origin_m": [x, z],                 the chunk's low corner in world metres
 "cell_m": 3,                        the cell
 "cells": [w, d],                    cells in x and z (32 x 32; fewer at the land's edge)
 "base": {"kind": "village", "seed": 7},     the procedural base it is a delta over
 "split": "alternate" | "fixed",     the cell's diagonal: "alternate" is the village's ((i + j) even: a-c, odd: b-d,
                                     global grid indices); "fixed" is every cell on (x+1, z)-(x, z+1), the split
                                     of a Jolt height field (land drawn so can use HeightMapShape3D colliders)
 "h_zero_m": -32.0, "h_step_m": 0.002,       present exactly when "heights" is: h = h_zero_m + q * h_step_m
 "heights": [[k, q], ...],           sparse; vertex k = vj * (w + 1) + vi of the (w+1) x (d+1) vertices, q a u16
 "materials": [[c, id], ...],        sparse; cell c = cj * w + ci; id: 1 grass, 2 dirt, 3 rock, 4 sand, 5 cliff
 "water": [{"level_m": y, "cells": [c, ...]}, ...]     flooded cells and their level
}
```

- Required: `schema`, `chunk`, `origin_m`, `cell_m`, `cells`, `base`, `split`. Unknown keys are errors; an absent
  value is an omitted key (never null). Pairs are sorted by index, no index twice, every index in range.
- A vertex on a seam belongs to every chunk that touches it. Records that both set it must agree: a loader reports a
  disagreement and applies neither value. (This is the no-crack rule in data.)
- A record whose `base` differs from the world's is refused.
- Writers emit keys in the order above, so a record read and written again is the same bytes.
- The land is static between edits and is never in a pack's state hash (a pack brings its own ground; WORLD.md
  ruling 3).
