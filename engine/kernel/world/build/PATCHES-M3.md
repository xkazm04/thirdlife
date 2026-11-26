# PATCHES-M3: what lane M3 needs outside its files (for the Director)

## P1 seam_case.gd `seam.stubs` (754) expects put and lift to be refused "not built yet (M3)"

The pieces layer is built, so a well-formed put of a crate and a lift of it apply; 754 `seam.stubs` reports
`BAD put: '', want 'not built yet (M3)'; lift: ''; a refused op reached the log`. Proposed rows instead (both refused
by the real layer, nothing logged):

```
"put": [{"op": "put", "at": [3, 20, 4], "part": "fence", "params": {"length": 40.0}, "rot": 1, "seed": 7}, "too large for a piece"],
"lift": [{"op": "lift", "at": [3, 20, 4]}, "no piece there"],
```

(`seam.tools` is fixed by 50b4a55a; `seam.region` stays green: the pieces layer leaves `pieces` out when the box holds none.)

## P2 contracts/BUILD.md: rows the lane added under the brief

- Materials 11 `brick` and 12 `plaster` (palette keys added to style.json, style_crisp, style_diorama, style_overcast,
  with `mat` entries masonry and concrete). The materials table stops at 10.
- `tl.unlocks/1` `when.pack` "*": every pack together (plays and wins summed, the best of any). The contract names a
  pack only; the "play 3 dungeons" rule needs it.
- `grant.mats` / `grant.shapes` are ids (as in ops).
- A piece standing on the ground is lifted to the ground's height in its anchor cell (not saved; follows from the cell).

## P3 a pack's player side: a manifest key `dungeon.results`

trophies.gd takes the first of `TLRules.sides` as the player's (true of hockey, paddle and parkour today). Proposal: an
optional `pack.json` key `"dungeon": {"results": {"side": "<side>"}}` for a pack whose player is another side, and
`"score": false` for a pack whose `scores` are not the player's. Contract change (PACK.md); not made.

## P4 kernel/dungeon/dungeon.gd: the edit made (2 lines)

A preload `const Trophies: GDScript = preload("res://kernel/world/build/trophies.gd")` and, in `close()` inside
`if loaded:` just before `life.teardown()`: `Trophies.record(run, result, frames_target)`. It writes nothing for a
counted run (`frames` > 0) or headless without TL_HOME_BUILD_DIR, so 640 and the gate's dungeons write no trophies.

## P5 preview_mesh.gd / block_mesh.gd: a ghost of blocks is a white glare in the exe

`m3-stamp-ghost.jpg`: a stamp's preview drawn in holo washes out to white over the whole house. block_mesh.gd
`_surface` writes UV (0, 0) on every vertex; holo.gdshader reads UV as edge lines (y) and a dissolve front (x), so
every face is all edge. ghost.gd fills with UV y 2. Proposal: when `look` is set, write UV (0.5, 2.0) (piece_ghost.gd
does this for kit meshes, `ghost_mesh`; measured: the lamp ghost went from a white glare to a cyan fill).

## P6 protect.gd: a block touching a piece's body says "authored structure (home pieces)"

A piece's body may reach up to 0.1 m into a cell outside its footprint (the footprint takes cells it reaches into by
more than 0.1 m). A block in that cell is refused by protect.gd's space query with the tag `home pieces`. Proposal: map
the tag `home pieces` to "piece" in protect.gd's reason, or count it as ground there (the footprint rule already
refuses real overlaps).

## P7 kernel API

The two new kit parts are rows of `TLKit.PARTS` (data); their geometry is in `engine/kits/part_town.gd`, internal to
TLKitParts, so `tl arch` api-v1 needs no bump. Whether new parts should move KERNEL_API is the Director's call.
