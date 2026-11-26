# Home blocks: the build core (WP1)

Players build in the Home (Wren Valley) with 1 m smart blocks. This directory holds the core: the store, the shapes and
how they join, the mesher and collider, the edit log with undo and redo, save and load, and protection. It has no input.
Build mode (WP2) and the LLM command bar (M4) call the API below. The file formats are `contracts/BUILD.md`
(`tl.edit/1`, `tl.build/1`, since the seam `tl.build/2`, since the M5 seam `tl.build/3`). Selftest block 752 holds this
code to both texts; 754 holds the seam (layers, tools, v1/v2/v3, preview, `read_region`, the M5 layer interface). Which
lane owns which file is `LANES.md`.

| File | What it is |
|---|---|
| `home_build.gd` | the one object callers use (no `class_name`: `preload("res://kernel/world/build/home_build.gd")`) |
| `blocks.gd` | sparse store: cells to codes, per 16 m section; chunk counts, caps, dirty sections, chunk records |
| `shapes.gd` | shape table: canonical geometry, rot and flip, coverage masks, joined forms |
| `block_mesh.gd` | section mesher (toon palette surface and glass surface) and one static body per chunk |
| `edit_log.gd` | `tl.edit/1` ops: the layer registry, batches, undo and redo, the journal (no op kind of its own) |
| `op_util.gd` | what every layer's validation shares: the common keys `v`, `author`, `batch`, integers from JSON, cells |
| `blocks_layer.gd` | the `blocks` layer: `place` and `remove` (M1's checks, records and `chunks`) |
| `land_layer.gd` | the `land` layer: `land` and `paint` (M2) |
| `pieces_layer.gd` | the `pieces` layer: `put` and `lift` (M3) |
| `water_layer.gd`, `paths_layer.gd`, `plants_layer.gd` | the M5 layers `water` (`flood`, `drain`; the input op `pour`), `paths` (`path`, `unpath`), `plants` (`plant`). Stubs until their lanes land |
| `stub_layer.gd` | what an M5 stub layer does (refuses every op "not built yet: <what>", offers nothing, saves nothing); the stubs extend it |
| `plant_scatter.gd` | M5: `scatter(...)`, the seeded tree and bush `put` ops of a scatter stroke (below). A stub until lane P lands |
| `build_file.gd` | `tl.build/1`, `/2` and `/3`: save (compaction), load (build file, then the journal replayed), `mark_v`, the version tables `KEY_V` and `OP_V` |
| `protect.gd` | where a block may not go, with the reason; the rules layers add (`add_rule`) and ground areas (`refusal_area`) |
| `preview_mesh.gd` | draws a store as a hologram (a dry run's ghost: M4's answer, M3's stamp) |
| `build_case.gd` | the headless case (`engine/tools/selftest.d/752-home-build.sh`) |
| `seam_case.gd`, `seam_v3.gd`, `case_util.gd` | the seam's headless case (754; `seam_v3.gd`: its tl.build/3 and M5 cases) and what build cases share (a landscape, a key, removing a folder) |
| `seam_lists.gd` | the layers, op kinds, tools and stub lines the frozen cases (754, 757) are held to, in one place |

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
| `register(layer)` / `layer(id)` | - / the layer or null | adds a layer (one that owns an op another layer has replaces that layer whole); `id` is `blocks`, `land`, `pieces`, `water`, `paths` or `plants` |
| `read_region(min, max)` | `{min, max, blocks: [[x, y, z, code], ...], ...}` or `{error}` | a cell box (inclusive, at most 128 per axis): blocks sorted by z, then x, then y, plus each layer's own keys (its `read_region`). M4's ask reads this |
| `preview(ops)` | `{ok, reason, applied, refused, store, removed, scratch}` | a dry run of one batch on scratch copies of every layer (same rules and protection; no mesh, body, log or file). `store`: a blocks.gd store of the cells it would fill or change, `removed`: those it would empty, `scratch`: `{id: layer copy}`. Draw it with `preview_mesh.gd` `show_stores(r.store, r.removed)`, or every layer's part with `preview_nodes(r)` |
| `preview_nodes(r, skip = [])` | `Array` of Node3D | the ghost of a dry run, one node per layer whose `preview_node(r.scratch[id])` returns one (blocks: added in holo, removed in red), in layer order, each with the meta `tl_layer` = its id; layers in `skip` are left out. The caller adds them to the tree and frees them |
| `expand_input(ops)` | `{ops, refused: [[i, reason], ...]}` | an LLM answer's input-only ops (`INPUT_OPS`: `pour` -> the water layer's `expand_input(op)`) replaced by the ops they stand for; every other op passes through. An expanded op takes the input op's `author`. The command tool calls it before `preview` |
| `protect.add_rule(callable, on = "cell")` | | a layer's refusal provider: `"cell"` rules `(cell, code) -> reason` are asked by `refusal` after the circles, rects and boxes; `"area"` rules `(rect: Rect2, what) -> reason` by `refusal_area(rect, what)` |

Op input rules: `v`, `author` and `batch` may be left out (the log fills them in). A `batch` given on input is checked,
then ignored, because the log numbers batches itself. A remove may leave out what it removes. If it names `shape`,
`mat`, `rot` or `flip`, they must match the cell.

Refusal reasons are short and stable, so the hotbar can show them: `occupied`, `empty`, `out of range (y -16..111)`,
`chunk full`, `home full`, `game lot`, `authored structure (<tag>)`, `tree`, `too close`, `unknown key '<k>'`,
`<key> is missing`, `glass is only a window's pane ...`, `flip is for stair, ramp and roof`, `flip is written only when true`.

## Layers (the seam, for M2 and M3; M5 additions)

Each op kind belongs to one layer. `edit_log.gd` validates, applies, inverts and journals an op through its layer; it
knows nothing of cells or heights. `home_build.gd` makes the six layers (`LAYER_KINDS`) with one context `ctx` (`blocks` the
store, `mesh` its mesher, `check` the protection callable, `protect`, `space` the visitor's WorldSpace or null,
`root` the node meshes hang under or null, `seed`, `home` a WeakRef of the builder: a layer never holds the builder
itself, so there is no cycle) and registers them. A layer is a RefCounted script, `_init(ctx)`, duck-typed:

| Member | What it does |
|---|---|
| `id` | `"blocks"`, `"land"`, `"pieces"`, `"water"`, `"paths"`, `"plants"` |
| `ops() -> PackedStringArray` | the op kinds it owns |
| `malformed(op, strict) -> String` | "" or why the op is not well-formed (unknown keys first, then its keys, then `author` and `batch`: `op_util.gd` `head` and `tail`). `strict`: a journal line, every required key present |
| `can_apply(op) -> String` | "" or why the rules refuse a well-formed op now (the store, caps, protection) |
| `raw(op) -> Dictionary` | the op as it is journaled: complete (a removal names what it removes), keys in the contract's order, `v` first, no `author` or `batch` (the log appends them last) |
| `fits(rec) -> String` | "" or why a complete record does not fit (undo, redo and a replayed journal apply without the rules) |
| `apply(rec)` | applies a record that fits |
| `invert(rec) -> Dictionary` | the record that undoes it (keys in order, no `author` or `batch`) |
| `dirty_regions(rec) -> Array` | the world AABBs it changes (redraws of other layers, ghosts) |
| `save_part() -> Dictionary` | its keys of `tl.build/3` (`chunks`; `land`, `paint`; `pieces`; `water`; `paths`; `plants`), `{}` when it has nothing. The file's version is the highest any saved key needs (`build_file.gd` `KEY_V`); a key no version names is not written |
| `load_part(doc) -> String` | reads its keys from the whole build file (the layer was `clear`ed first); "" or what is wrong. Absent keys are an empty layer |
| `clear()`, `size() -> int`, `content_hash() -> String` | empty it; what it holds; the identity of what it saves (rev moves only when one changes) |
| `step(budget) -> int`, `pending() -> int` | redraws at most `budget` units (sections for blocks) per physics frame; work left (`flush` loops on it) |
| `copy() -> RefCounted` | a scratch copy with the same content and rules and no mesh or body (`preview`) |
| `read_region(min, max) -> Dictionary` | its keys for `home_build.read_region` (blocks: `blocks`; M2: ground; M3: `pieces`) |
| `add_rules(protect)` (optional) | called once when `home_build.gd` registers the layer (never for a scratch copy): its `protect.add_rule` calls |
| `free_all()` | meshes freed, bodies dropped |
| `offers() -> Array` (M5, optional) | the op kinds the LLM may write for this layer now (command_ask.gd `ops_now` is the layers' offers in order): blocks `place`, `remove`; land `land`, `paint`; pieces `put`, `lift`; water `pour`, `drain` (the model pours, the exe floods); paths `path`, `unpath`; plants `plant`. `[]` for a stub: 754 and 757 tell a stub layer from a built one by this |
| `preview_node(scratch) -> Node3D` (M5, optional) | its part of a dry run's ghost, drawn from its own scratch copy after the ops (`home_build.preview`'s `r.scratch[id]`); null when it has nothing to show. Blocks: `preview_mesh.gd` of the cells added and removed (`diff(scratch)`). Land and pieces have none yet (lanes L and C add it) |
| `expand_input(op) -> Dictionary` (M5, the water layer) | an input-only op (`pour`) as `{"ops": [...]}` or `{"error"}`; the stub answers `{"error": "not built yet: water"}` |
| `water_runs(lo, hi) -> Array` (M5, the water layer) | the measured water in a cell box, shaped as the ask's `water` key: `[{"y": <cell y of the surface>, "runs": [[z, x0, x1], ...]}]`; `[]` when there is none (the stub). command_ask.gd `water_of` writes it into the ask; the river's water is merged there |

The stubs check their ops strictly (keys, types, ranges, names, the cells, the points) and refuse to apply them with a
reason starting `not built yet` (M5: `not built yet: water` / `paths` / `plants`). They offer nothing, save nothing and
load an absent or empty key only. A lane replaces the file of its stub with the real layer (drop the extends of
`stub_layer.gd`; add files of its own); see `LANES.md`. Its `malformed` keeps the convention every case relies on:
`op_util.gd` `head` first (unknown keys), `tail` last (`author`, `batch`; a journal line's missing `batch`).

**tl.build/1, /2 or /3.** `build_file.gd` `text_of(layers)` writes the lowest version that holds every saved key
(`KEY_V`: `chunks` 1; `land`, `paint`, `pieces` 2; `water`, `paths`, `plants` 3), so a Home of blocks only is v1 byte
for byte as M1 wrote it and a Home without M5 content is v2 byte for byte as main wrote it (754 `seam.files`,
`seam.v3`). It reads 1, 2 and 3 and refuses a higher version (`load_into(..., max_v)`; a case passes 2 to stand for
an older exe) without writing it. Every op kind names the version it needs (`OP_V`: place, remove 1; land, paint, put,
lift 2; flood, drain, path, unpath, plant 3; a kind not named needs `MAX_V`). The log calls `before_journal`
(home_build.gd `_mark_v`, `build_file.gd` `mark_v(dir, seed, n)`) before it journals the first op whose version is
above build.json's (no file counts as 1): build.json gets `"v":n` with its content unchanged (a missing file becomes
an empty Home of version n and rev 0), so its journal stays valid and an older exe refuses it instead of compacting the
op away. If that write fails the op is refused. Undo and redo of such a batch ask the same first. A load or save tells
the log the version on disk (`edits.file_v`; `v2_ready` is its old name, `mark_v2` a wrapper).

**The plant scatter** (`plant_scatter.gd`, M5: lane P writes it, lane L's plant tool calls it). Static, reads the
Home, never writes it:

```gdscript
const PlantScatter := preload("res://kernel/world/build/plant_scatter.gd")
var ops: Array = PlantScatter.scatter(build, centre, radius_m, "tree", per_100m2, seed)   # kind "tree" or "bush"
build.apply(ops)                                                                      # one batch, one undo
```

It returns `put` ops (`{"op": "put", "at", "part": "tree" | "bush", "params"?, "rot", "seed"}`, no v, author or batch)
the pieces layer would take, for a disc of `radius_m` m round `centre` at `per_100m2` plants per 100 m2; the same
arguments give the same ops (the seed, never the clock). The stub returns `[]`.

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

## Build mode (WP2)

A person in the Home presses **B** and builds. `build_mode.gd` is the node; `hotbar.gd` (the CanvasLayer) and
`ghost.gd` (the holo preview) are its parts; `build_mode_case.gd` is the headless case (selftest block 753).

| File | What it is |
|---|---|
| `build_mode.gd` | the node, host of the tools: keys and buttons, the cursor ray, tool switching, undo and redo, autosave; `mount` is called by `home/hook.gd` `grow` |
| `tools/blocks_tool.gd` | M1's hand building: shapes, materials, rot, flip, place and remove, drags as batches |
| `tools/sculpt_tool.gd`, `tools/paint_tool.gd` | M2 (`LAND.md`): sculpt 1 raise, 2 lower, 3 flatten, 4 smooth, Shift the other way, wheel or [ ] the brush (1-8 cells); paint 1-8 the ground paints, 0 or Backspace the eraser. F and S are not used: they are flight and walking back in `visit.gd` |
| `tools/piece_tool.gd`, `tools/stamp_tool.gd` | M3 (`PIECES.md`): pieces wheel or 1-9 a part, Tab a page, [ ] its size, V its kind, R turn, LMB put, RMB lift; stamps 0 a new box, G save, 1-9 a stamp, R turn, LMB place (one undo), X export, I import the inbox |
| `tools/command_tool.gd` | M4 (`COMMAND.md`): Enter asks, Enter keeps the ghost (one batch by llm), Esc or Backspace reverts. M5 seam: the answer's input ops are expanded (`expand_input`) before the dry run, blocks are drawn as before and every other layer's part under `layer_ghosts` (`preview_nodes(r, ["blocks"])`); the counts name the other kinds applied ("24 blocks, 3 paint, 1 refused: occupied") |
| `tools/water_tool.gd`, `tools/path_tool.gd`, `tools/plant_tool.gd` | M5 stubs ("Water: coming in M5" ...); lanes W, P and L replace them |
| `build_devices.gd` | the test hook `TL_BUILD_DEVICES` |
| `hotbar.gd` | bottom centre while building: the tool strip, the current tool's slots, its swatch and info line, save state, the refusal reason, its keys. It reads only the tool interface (`state_of`). Boot's key line names "B  build" while walking and hides itself while building (boot.gd reads the meta `tl_build_mode`) |
| `ghost.gd` | the next edit as a hologram (`TLStyle.material("holo")`; red: a private copy tinted `hazard_red`), the shape's own triangles (`shapes.gd` `entry`, form 0) |
| `build_mode_case.gd` | input events as a person makes them, frames counted (`engine/tools/selftest.d/753-home-build-mode.sh`) |

**Mounting.** `home/hook.gd` `grow` sets the landscape's meta `tl_valley_sites` (PATCHES-WP1 P1) and calls
`BuildMode.mount(landscape, valley)`. The walk (for the game plots) is the landscape's meta `tl_walk` when a test set it,
else the view's `world.walk` (the way `landscape.gd` reads it). The builder is the meta `tl_build`, the node the meta
`tl_build_mode`. The node runs at physics priority 150000, after the view (100000: visit `sample`, `steer`, the
visitor's step) and before boot (200000), and calls `build.step()` there. P3: protection asks the visitor's feet
(`protect.visitor_at` reads `view.visitor.feet`; `drive` moves no body).

**Loading and saving.** The Home loads its save when a person walks it: the view's visit reads devices (not a replay)
and runs no device script (not a test). The folder is `user://home` (the exe: `%APPDATA%\ThirdLife\home`), or
`TL_HOME_BUILD_DIR=<abs dir>`. A case calls `open(dir)`. Saves (`save_now`): on leaving build mode, `autosave_frames`
(1800) physics frames after the first unsaved change (never in the middle of a drag), and on quit (`tree_exiting` and
the window's close request). Nothing is saved where nothing was loaded. A build file that cannot be read is never
written over: the hotbar says so and nothing is saved. A save error is shown in the hotbar ("save failed: ...") and
printed (`home_build_save` line, `push_error`).

**Keys** (polled from the engine's input state once per physics frame, as TLInput polls; the wheel from its events;
nothing while a text field has the keyboard; B does nothing while a game is on stage, and a game taking the stage ends
build mode):

| Key | While building |
|---|---|
| B, Esc | leave build mode (autosave if unsaved). Esc never quits from build mode: `visit.gd` does not quit while `active` |
| T, Shift+T | next, previous tool: blocks, sculpt, paint, pieces, stamps, water, paths, plants, command (the hotbar's strip lights the current one; a stub says "coming in M<n>", seam_lists.gd `STUB_LINES`) |
| Enter | the command tool (M4's bar; the stub shows a disabled line). Reserved: no other tool takes it |
| LMB | place; held and moved: a line of cells, one batch (one undo step) |
| RMB | remove; held and moved: one batch |
| wheel, 1-8 | shape (ids 1-8) |
| Tab, Shift+Tab | material (ids 1-9; a window's pane is glass by itself) |
| R | turn: +1 rot on top of `rot_facing(camera forward)` (stair, ramp, roof, window; other shapes keep rot 0) |
| F2 | flip (stair, ramp, roof). Ctrl+F is not used: F is flight and visit.gd would take it too |
| Ctrl+Z, Ctrl+Y (or Ctrl+Shift+Z) | undo, redo one batch |
| hold MMB or Alt | look: the mouse is captured and turns the view while held |
| W A S D, Shift, Space, C, F | as while walking (the visitor walks, jumps, flies). E does not enter a game while building |

LMB, RMB, the wheel, 1-8, Tab, R and F2 are the blocks tool's: another tool gets them (its `press`, `key`) or ignores
them. Ctrl+Z, Ctrl+Y, B, Esc, T, Enter, MMB and Alt are the host's and mean the same in every tool.

**Tools** (the seam, for M2, M3, M4 and M5). A tool is a RefCounted script in `tools/`, made once by build mode (`TOOLS`,
in strip order: blocks, sculpt, paint, piece, stamp, water, path, plant, command), duck-typed. The M5 stubs
(`tools/water_tool.gd`, `path_tool.gd`, `plant_tool.gd`) extend `tools/stub_tool.gd`; a lane replaces its file:

| Member | What it does |
|---|---|
| `id`, `title` | `"blocks"`, `"Blocks"` ... `"command"`, `"Command"` (the strip shows `title`) |
| `setup(host)` | `host` is build_mode.gd: `build`, `hit` (the last pick), `ray()`, `reach(from)`, `forward()`, `frames`, `scripted()`, `ghost`; a tool may add nodes of its own under it |
| `polled() -> Array` | the physical keys it wants; the host polls them once per physics frame with its own and hands their presses to `key` |
| `key(event) -> bool` | a key press (an InputEventKey with `shift_pressed` and `ctrl_pressed`) or a wheel notch (InputEventMouseButton); true: taken |
| `slots() -> Array` | hotbar entries `{key, label, lit}` |
| `status() -> Dictionary` | `info` (the line beside the swatch), `swatch` (a Color, optional), `reason` (red, "" none), `dim` (true: greyed, a stub) |
| `hint() -> String` | its keys line |
| `aim(hit, mode)` | every drawn frame while building and not looking: `hit` is `pick`'s result, `mode` the held state `{ctrl, shift, alt, lmb, rmb}` |
| `ghost_state() -> Dictionary` | what the shared block ghost shows: `{cell, code, mode: "place" / "refused" / "remove"}`, `{}` hidden |
| `press(button, mods) -> bool` | LMB or RMB went down (`mods` as `mode`); true: the tool holds the button (a drag) |
| `drag(hit)` | each physics frame while it holds the button |
| `release(button)` | the button went up, or the hold was cut (undo, look, leave, a tool switch); a drag's batch ends here |
| `selected(on)` | build mode turned on or off with this tool current, or the tool was picked or left |
| `blocks_input() -> bool` | true while it has the keyboard (M4's text field, an open panel): the host reads no key and ends any hold |
| `tick(frame)` | every physics frame for every tool, current or not (M4 polls its answer file here) |

- **The cursor.** Each drawn frame the ray from the camera (its interpolated pose) through the mouse goes to `pick`,
  reaching **24 m past the visitor** (`REACH` plus the camera's distance to his feet). A reach counted from the camera
  would be 24 m on foot (the camera is about 5 m behind him) but about 10 m round him in flight (the camera is about
  14 m behind), so the roof of a house could not be reached from the air.
- **The ghost** shows the place cell in holo, red with the reason in the hotbar when `can_place` refuses. While RMB is
  held or Ctrl is down it shows the remove cell (a red cube).
- **A drag** keeps to the plane of the surface first pressed: the press point's coordinate along the axis of the face
  normal (the ground's height there, a row's top, a wall's side). Every cell the cursor crosses on that plane is edited
  (the line between frames is filled in), at most 64 per drag. On the ground the plane is the ground's height, so the
  cursor sliding over the terrain stays on the cells it shows. An earlier try used the cell's mid-height and moved
  the first cells by a whole cell when the ground stood near a cell top. A row is built by pressing on the row below
  and sliding along its tops. Refused cells in a drag are skipped and the last reason shows.
- **The test hook** (`build_devices.gd`) `TL_BUILD_DEVICES="<frame>:<kind>[:<args>];..."` counts this node's physics frames, which equal
  boot.gd's in the exe (both start on the same tick: B at boot frame 150 was seen at 151). Kinds: `px:x,y`,
  `at:x,y,z` (the pointer on the pixel of a world point, followed every frame), `mouse`, `lmb|rmb|mmb:1|0` (held
  buttons are pressed again after a focus loss, as boot does for keys), `key:<Key>:1|0`,
  `fill:x0,y0,z0,x1,y1,z1,shape,mat` (one batch), `state` (prints a `build_state` line). While it runs, each edit prints a
  `build_edit` line. `TL_EXE_KEYS` cannot click or set an absolute pointer, so this hook does that part.

**Figures** (26 Nov 2026, this machine: RTX 4090, the exported exe, a window, vsync off by `TL_EXE_FRAMES_TIMES=1`, other
sessions loading the machine). 5,000 blocks (10 walls of 25 x 10 x 2, `fill`) in front of the visitor:

| | frames | p50 ms | p99 ms |
|---|---|---|---|
| walking, no blocks | 5857 | 1.36 | 5.26 |
| walking near 5,000 blocks | 4690 | 1.41 | 6.55 |
| building near 5,000 blocks, idle (ghost and refusal check every frame) | 456 | 1.42 | 7.15 |
| building near 5,000 blocks, a click every 60 frames | 5815 | 1.43 | 6.70 |

The frame of a click is at most 18.7 ms (the first one; one section and one chunk body). The frame of a leave-save of
5,000 blocks is 16.7 ms. The largest frame in the building window, 133 ms, was boot's own capture (TL_EXE_CAPTURE).

**Glass on its own instance (WP2 round 2).** A section's glass is drawn by a child MeshInstance3D "Glass" of the
section's mesh. With both surfaces on one instance, every pane was drawn 1 m off along world +x, beside its frame,
seen at any angle (straight along x it hid in its own depth). Instance uniforms are numbered per shader in declaration
order: toon's slot 0 is `build` (default 1.0), glass.gdshader's slot 0 is `tl_plot`, so the glass read (1, 0, 0, 0)
as its plot offset. Shown: the same pane on the toon material sat in its frame. The mesh data was right (pane at 0.5 of
its cell for every rot). Selftest 752 `build.glass` holds the separate instance and the pane planes.
