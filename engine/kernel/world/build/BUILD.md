# Home blocks: the build core (WP1)

Players build in the Home (Wren Valley) with 1 m smart blocks. This directory holds the core: the store, the shapes and
how they join, the mesher and collider, the edit log with undo and redo, save and load, and protection. It has no input.
Build mode (WP2) and the LLM command bar (M4) call the API below. The file formats are `contracts/BUILD.md`
(`tl.edit/1`, `tl.build/1`). Selftest block 752 holds this code to both texts.

| File | What it is |
|---|---|
| `home_build.gd` | the one object callers use (no `class_name`: `preload("res://kernel/world/build/home_build.gd")`) |
| `blocks.gd` | sparse store: cells to codes, per 16 m section; chunk counts, caps, dirty sections, chunk records |
| `shapes.gd` | shape table: canonical geometry, rot and flip, coverage masks, joined forms |
| `block_mesh.gd` | section mesher (toon palette surface and glass surface) and one static body per chunk |
| `edit_log.gd` | `tl.edit/1` ops: validation, batches, undo and redo, the journal |
| `build_file.gd` | `tl.build/1`: save (compaction) and load (build file, then the journal replayed) |
| `protect.gd` | where a block may not go, with the reason |
| `build_case.gd` | the headless case (`engine/tools/selftest.d/752-home-build.sh`) |

## The API

```gdscript
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
var build = HomeBuild.attach(landscape_node, walk_json, valley)   # space from meta "tl_space", lots from the walk and valley
build.load()                                                      # user://home; load(dir) for another place
build.protect.visitor_at = func() -> Vector3: return visitor_feet # drive() moves no body: the owner says where he is
# every physics frame:
build.step()                                                      # rebuilds at most STEP_BUDGET (4) dirty sections
```

| Call | Returns | What it does |
|---|---|---|
| `HomeBuild.new(parent, space, opts)` | builder | `parent`: the node `HomeBlocks` hangs under (null: no meshes). `space`: the visitor's WorldSpace (null: no bodies and no space checks). `opts`: `seed`, `section` (m, 16), `cap_chunk`, `cap_home` |
| `HomeBuild.attach(parent, walk, valley = null, opts)` | builder | as above. The space comes from `parent.get_meta("tl_space")`, the seed from `walk.landscape.seed`, and the protected lots from the walk's plots and lots and the valley's sites |
| `HomeBuild.code(shape, mat, rot, flip)` | int | packs a block (bits 0-4 shape, 5-9 mat, 10-11 rot, 12 flip) |
| `HomeBuild.rot_facing(dir)` | 0-3 | the rot of a stair, ramp or roof that rises away from a viewer looking along `dir` |
| `can_place(cell, code)` | `""` or a reason | occupancy, range, caps, the code itself (glass, flip), protection |
| `apply(op_or_array)` | `{ok, reason, applied, refused: [[i, reason]]}` | one `tl.edit/1` op, or an Array of them as one batch. A batch is applied as far as it goes. Refused ops are not logged |
| `place(cell, code, who = "hand")` / `remove(cell, who)` | as `apply` | one-op shorthands |
| `begin_batch(who = "hand")` / `end_batch()` | batch number / - | ops between them are one undo step (a drag, an LLM job). Calls nest |
| `undo()` / `redo()` | ops changed (0: nothing to do, or a batch is open) | one batch |
| `step(budget = 4)` / `flush()` | sections rebuilt | meshes and bodies follow the store here, never in `apply` |
| `cell_at_ray_hit(pos, normal, placing)` | `Vector3i` | placing: the empty cell in front of the face hit (on the ground, the cell holding the point just above it, so a block sits in the ground and never floats). Removing: the block hit, or `HomeBuild.NO_CELL` |
| `pick(from, to)` | `{}` or `{pos, normal, block, place, remove}` | a cursor ray against the visitor's space, which excludes the visitor |
| `save(dir = "user://home")` | `""` or what went wrong | compacts to `build.json` and empties `edits.jsonl`. Later edits are journaled there |
| `load(dir = "user://home")` | `{ok, reason, rev, blocks, replayed, bad}` | replaces the store. Undo and redo start empty. Meshes follow in `step` |
| `stats()` | Dictionary | blocks, chunks, sections, bodies, tris, pending, undo, redo, rev, dirty, rebuilt_sections, rebuilt_chunks |
| `dirty`, signal `dirty_changed(dirty)` | | true from the first change after a save or load until the next save |
| `free_all()` | | meshes freed, bodies dropped from the space (the store stays) |

Op input rules: `v`, `author` and `batch` may be left out (the log fills them in). A `batch` given on input is checked,
then ignored, because the log numbers batches itself. A remove may leave out what it removes. If it names `shape`,
`mat`, `rot` or `flip`, they must match the cell.

Refusal reasons are short and stable, so the hotbar can show them: `occupied`, `empty`, `out of range (y -16..111)`,
`chunk full`, `home full`, `game lot`, `authored structure (<tag>)`, `tree`, `too close`, `unknown key '<k>'`,
`<key> is missing`, `glass is only a window's pane ...`, `flip is for stair, ramp and roof`, `flip is written only when true`.

## How it works

- **Grid.** A cell is 1 m, world-anchored, and `y` runs -16..111. A chunk is 96 m (`home/hook.gd`): caps, saved
  records and one static body are per chunk. Cells are stored and meshed per **section** of 16 x 16 m (36 per chunk),
  so one edit redraws 1 section (2 to 4 when it is within 2 cells of a section edge) and refreshes the chunk's body, which holds one concave
  shape per non-empty section. An edit marks every section within 2 cells horizontally. A neighbour's joined form
  reads cells one away, and a hidden face reads the neighbour's form.
- **Shapes** (`shapes.gd`). Each shape is built in a unit cell that rises toward -z, then flipped and turned. Rot k is k
  quarter turns about +y: 0 rises toward -z, 1 toward -x, 2 toward +z, 3 toward +x. A window's pane faces z at rot 0.
  - The geometry: cube and slab are half-cell voxels with merged faces. The stair has 4 steps of 0.25 m on a 4 x 4
    height field. Ramp and roof are 45-degree wedges whose tops split on the crease diagonal. The post is 0.25 m square,
    the fence post 0.2 m, and rails sit at 0.35-0.5 and 0.7-0.85 m. The window is a 0.125 m frame in the block's
    material with a glass pane (`TLStyle.material("glass")`).
  - Every polygon on a cell face carries an 8 x 8 sample coverage mask. A polygon is hidden when the neighbour's
    opaque mask on the touching face covers all of its samples. Glass covers nothing.
- **Joined forms**, derived at mesh time and never stored:
  - Stair, ramp and roof take outer and inner corners from a same-shape, same-flip neighbour behind or in front that
    faces across (Minecraft's stair rule).
  - A fence links to a fence, a post or a full opaque face. A post grows rail stubs toward fences. Stacked posts hide
    their end faces.
- **Colliders** use the same triangles as the drawing, wound counter-clockwise from outside. The physics reads the
  winding (`home/hook.gd` `facing_up`). The **stair** is the exception: it collides as the ramp of its own form,
  because the visitor's walkers stop at any vertical riser (see the figures and `PATCHES-WP1.md` P2). The body lives
  only in the visitor's space (tag `home blocks`, stat `block_faces`, layer 1), never in a pack's space or hash.
- **Look.** One toon surface in the palette material (`TLStyle.material("white")`, CUSTOM0 = cell-local xyz + face axis
  + 4 * grain + 16 * palette column, as `TLMesh`) plus one glass surface. No hand-made material.
- **Edit log.** An undo appends the inverse ops as a new batch, and a redo appends the batch again, so replaying
  `edits.jsonl` in order always gives the store back. The undo and redo stacks live in memory only.
- **Files.** The chunk-local cell is `lx + 96 * (lz + 96 * (y + 16))`, with `lx` and `lz` in 0..95. A chunk record is
  the little-endian int32 pairs `(cell, code)` sorted by cell, in base64. Chunks are written sorted (z, then x) with
  keys in contract order. `rev` goes up by 1 only on a save whose content differs from the last save or load: a
  save with nothing new writes the same bytes. A build file whose seed is not the Home's is refused.
- **Protection** (`protect.gd`). The checks, in order:
  1. circles and rectangles: the walk's plots (circle and footprint), the site lots (`landscape.lots`), the valley sites
     (footprint turned by its yaw);
  2. boxes added with `add_box`;
  3. the visitor's capsule (`visitor_at`, or the body's transform when unset), within 5 cm;
  4. a 0.98 m box query of the visitor's space. A hit on anything except ground (`terrain`, `home ground` shape 0,
     `home blocks`, `pad *`) refuses as `authored structure (<tag>)`. A trunk shape on a `home ground` chunk refuses as
     `tree`.

  The space only knows what is loaded round the visitor (`home/hook.gd` KEEP).

## Figures (build_case.gd, 26 Nov 2026, this machine; wall clock is measured and never decided on)

- 20,000 placements in 80 house batches over chunks (7..8, -3..-2): 5,000 blocks and 34,480 triangles per chunk.
  Applying them took 357 ms (18 us per op with the protection query).
- The first build was 144 sections in 281 ms (52-56 ms of sections per chunk). A section rebuild took 1.30 ms median
  and 5.5 ms max.
- One edit inside a section rebuilt 1 section (2.5 ms) and 1 chunk body (1.05 ms). One on the x = 768 seam rebuilt
  2 sections and 2 chunks.
- With 96 m sections (one mesh per chunk), the same edit costs a 47 ms median rebuild, about 3 frames. That is why
  the mesh is split into sections.
- The same op list gave the same 4 chunk mesh hashes twice. Save, load and save gave byte-identical files (213,420 B).
  Undo of 80 batches left 0 blocks, 0 bodies and 0 meshes, and redo restored the store and mesh hashes.
- Walkers on a 3-wide, 3-block stair onto a platform, then into a 3-high wall:

  | Walker | On the platform at frame | Stopped at frame | Distance from the wall |
  |---|---|---|---|
  | `walk`, 4.5 m/s | 73 | 122 | 0.378 m |
  | `drive`, 4.5 m/s | 76 | 126 | 0.350 m |
  | `drive`, 9 m/s | 44 | 69 | 0.350 m |

- With the stair drawn as two 0.5 m steps and colliding as drawn, neither walker climbed it at all. With the collider
  wedge raised 0.125 m (a 0.125 m riser in front), `drive` at 4.5 m/s stalled at the riser.

`TL_BUILD_TRACE=1` prints the walkers' frames.
