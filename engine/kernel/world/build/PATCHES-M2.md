# PATCHES-M2: what lane M2 changed outside its own files, and what it asks of frozen files

Lane M2 (land sculpt and paint), 26 Nov 2026, worktree `spark-ws-m2` on the seam at 1264a323. The lane's own files are
`LAND.md`'s table. Every change below that is in `home/` was made by the lane (LANES.md lets M2 edit `home/ground.gd`
and `home/hook.gd` "only as the re-mesh and the colliders need it"); every change to a frozen file is a REQUEST.

## Made (home/, allowed by LANES.md)

**H1. `engine/kernel/world/home/ground.gd`** (+59, -4). The valley's `colors`, `custom` and `normals` are members
(were locals of `build`), so an edited chunk interpolates the valley's own colour, shading code and normal; `mesh` is
kept; `cell_index` maps a cell to its first index in `indices` (-1 for a village cell); `hide_cells(i0, i1, j0, j1, on)`
turns those cells' 6 indices into a degenerate triangle in the GPU's index buffer
(`RenderingServer.mesh_surface_update_index_region`, one region per run of cells in a row) or writes the originals
back; `hidden` remembers which. Vertices and `indices` never change, so `y`, `point` and the colliders read what they
read before. The index size is 4 bytes above 65535 vertices (the valley has ~109k); asking the renderer
(`mesh_get_surface`) read the whole surface back and is not used. Headless: no upload (`index_bytes` -1).

**H2. `engine/kernel/world/home/hook.gd`** (+50, -15). `var land: WeakRef` (the land layer sets it). `faces(id)` asks
`land.chunk_faces(id)` first and uses the valley's triangles (`valley_faces`, the old body of `faces`) when it is empty;
lanes and the deck are appended as before. `ensure`'s per-chunk body making moved into `_make(id, ws)` unchanged except
that each trunk asks `land.trunk_foot(foot)` (moved with the ground, or null: left out). `refresh(id)` drops and
rebuilds a loaded chunk's body. `ground_y` returns `land.height_at` when a land layer is attached. With no land layer
(or no edit) every output is what it was: 750 `home.a.*`, 751 `home.walk/bridge/trees/drops` pass.

## Requested: `seam_case.gd` (754), the rows the Director asked for

754 at 1264a323 fails `seam.stubs`, `seam.preview` and `seam.region` with the real land layer. Measured with the
replacement below applied to a temporary copy (then deleted): **8/8 ok, `HOME seam ok`**.

**S1. `seam.stubs`: two rows the built land layer refuses in a bare build** (`HomeBuild.new(null, null, {})`: flat
ground at 0 cm), each accepting the stub's reason or the layer's:
```
"land":  [{"op": "land",  "verts": [[1, 2, 0, 2500]]},          ["not built yet (M2)", "height limit (24 m"]],
"paint": [{"op": "paint", "cells": [[1, 2, "sand", "dirt"]]},   ["not built yet (M2)", "cells: [1, 2] is 'valley', not 'sand'"]],
```
(measured reasons: `height limit (24 m from the ground's own 0.0 m)` and `cells: [1, 2] is 'valley', not 'sand'`.)

**S2. `seam.stubs` row "land three numbers"** must change too: the contract allows `[i, j, to_cm]` on input
(contracts/BUILD.md "More operations"), so the built layer APPLIES `[[1, 2, 150]]`, and then "a refused op reached the
log" fails. A three-number vertex the layer refuses for another reason keeps the row's point:
```
"land three numbers": [{"op": "land", "verts": [[1, 2, 2500]]}, ["verts: every entry is [i, j, from_cm, to_cm]", "height limit (24 m"]],
```
(a journal line, strict, still refuses three numbers: `verts: every entry is [i, j, from_cm, to_cm]`.)

**S3. `seam.preview`** (line 341): the land op `[[0, 0, 0, 100]]` is refused by the built layer with `blocks` (the
preview's own blocks at (x, 10, 0) stand in that vertex's cells):
```
... or not (str(r.refused[0][1]) in ["not built yet (M2)", "blocks"]):
```

**S4. `seam.region`** (line 374): `read_region` now carries the land layer's keys `ground`, `paint`, `ground_refused`
(and M3's `pieces`):
```
... and (r.keys() as Array).slice(0, 3) == ["min", "max", "blocks"] and ...
```

The full diff is `seam-m2.diff` in the session scratchpad; the 5 lines above are all of it.

## Requested: smaller things, not needed for M2 to work

**R1. `home_build.gd preview`**: a scratch copy of the land layer checks protection through `protect.refusal_area`,
whose "area" rule is the REAL layer's, which reads the REAL block store. A batch that places blocks and then sculpts
under them previews the land op as allowed and is refused at apply (`blocks`). Fix: give each scratch copy the scratch
blocks store (e.g. `ctx` with `blocks` = the scratch blocks layer's store in `preview`) and let the land copy build its
own `land_protect.gd` over it. M4's accept path would then agree with its ghost.

**R2. `BUILD.md` "Build mode" keys table**: the sculpt keys are 1-4 (raise, lower, flatten, smooth), Shift inverts,
wheel / [ ] the brush; paint 1-8, 0 / Backspace eraser. The brief's F (flatten) and S (smooth) are flight and walking
back in `kernel/runner/visit.gd` (ACTIONS, lines 21-22), which still work while building, so they are not used.

**R3. `contracts/BUILD.md`** (Director/owner): say that a land record's cm (in ops and in the `land` file part) is the
vertex's absolute height, stored only where it differs from the ground's own height, and that "the ground's own
height" is the valley's DRAWN surface (its 12 m triangles) rounded to cm, not `valley.height`. The contract text reads
either way today; the lane chose absolute + drawn (LAND.md "The model").
