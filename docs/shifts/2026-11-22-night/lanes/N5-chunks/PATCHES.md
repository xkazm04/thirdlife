# N5 world-chunks: what this lane asks of files that are not its own

## 1. Contract proposal: `tl.land/1` (for the Director; `contracts/` is Director-only)

Proposed as a new section of `contracts/README.md`'s schema list, or as `contracts/LAND.md`. The code that reads and
writes it is `engine/kernel/world/land/land_record.gd`; selftest `land.record` (block 740) holds it to this text.

> **`tl.land/1`: one chunk of a world's land.** A world's land is cut into chunks of 32 x 32 cells (96 x 96 m at the
> 3 m cell). The chunk lattice starts at the land's own grid origin (today the village terrain's low corner), so a
> chunk's cells are whole cells of the grid and a cell's diagonal is the same in the chunk as in the grid. A chunk at
> the land's far edge may hold fewer cells. A record is the source of truth for its chunk and is a **sparse delta over
> a procedural base**: the base is generated from the world (its kind and seed); a chunk nobody changed stores nothing
> but its header, and the land comes out of the base unchanged.
>
> ```
> {"schema": "tl.land/1",
>  "chunk": [cx, cz],                  integers: the chunk's place in the lattice
>  "origin_m": [x, z],                 the chunk's low corner in world metres
>  "cell_m": 3,                        the cell
>  "cells": [w, d],                    cells in x and z (32 x 32; fewer at the land's edge)
>  "base": {"kind": "village", "seed": 7},     the procedural base it is a delta over
>  "split": "alternate" | "fixed",     the cell's diagonal: "alternate" is the village's ((i + j) even: a-c, odd: b-d,
>                                      global grid indices); "fixed" is every cell on (x+1, z)-(x, z+1), the split
>                                      of a Jolt height field (land drawn so can use HeightMapShape3D colliders)
>  "h_zero_m": -32.0, "h_step_m": 0.002,       present exactly when "heights" is: h = h_zero_m + q * h_step_m
>  "heights": [[k, q], ...],           sparse; vertex k = vj * (w + 1) + vi of the (w+1) x (d+1) vertices, q a u16
>  "materials": [[c, id], ...],        sparse; cell c = cj * w + ci; id: 1 grass, 2 dirt, 3 rock, 4 sand, 5 cliff
>  "water": [{"level_m": y, "cells": [c, ...]}, ...]     flooded cells and their level
> }
> ```
>
> - Required: `schema`, `chunk`, `origin_m`, `cell_m`, `cells`, `base`, `split`. Unknown keys are errors; an absent
>   value is an omitted key (never null). Pairs are sorted by index, no index twice, every index in range.
> - A vertex on a seam belongs to every chunk that touches it. Records that both set it must agree: a loader reports a
>   disagreement and applies neither value. (This is the no-crack rule in data.)
> - A record whose `base` differs from the world's is refused.
> - Writers emit keys in the order above, so a record read and written again is the same bytes.
> - The land is static between edits and is never in a pack's state hash (a pack brings its own ground; WORLD.md
>   ruling 3).

## 2. `engine/kernel/world/tiers.json` (written by this lane, on the brief's item 3: named here because it is not in
   the lane's file column)
`backdrop_m` 0 -> 960 (ten chunks) and its note. Ledger is on: a game farther than 960 m (+ the 40 m margin) from the
player is unloaded and keeps its ticks, summary and saved data. No walk of today reaches it (the farthest plot edge in
any walk is heavy.json's far plot at 880 m; proof.json's at 580 m), so no tour, proof or gate changes. The value is a
first choice; whether the Home wants it nearer (the mid ring, about 600 m) is the owner's call once there are more
venues than a slice of 16 can carry.

## 3. `engine/kernel/world/tiers.gd` (written by this lane: item 3 needed it; 3 lines)
With `backdrop_m` above 0, a construction-site plot that is still held (site.gd `HELD_SIZE`, a negative footprint: "out
of reach") ranked as `ledger` at once, and its game then arrived through the ledger's rebuild instead of the build
queue (`site.arrived_yaw_entry` went red: entry from `ledger`, not `backdrop`). `decide` now caps a held plot's rank at
`backdrop`, exactly what every plot got while `backdrop_m` was 0. site. 25/25 with it.

## 4. `engine/kernel/world/TIERS.md` (not this lane's)
Its "Files" paragraph still says `backdrop_m` 0 in tiers.json. Suggested text: "`backdrop_m` 960 (since 22 Nov, lane N5:
ledger on beyond ten chunks; WORLD.md "Chunks")".

## 5. For the fast gate
`arch schema-versions` (and the two devx tests that run arch on the real tree) fail until `tl.land/1` is declared under
`contracts/`. Checked in-process with the text of section 1 as a virtual `contracts/LAND.md`
(`.tl/archcheck.mjs` in the lane's tree): the finding goes and only the six grandfathered world schemas remain.
