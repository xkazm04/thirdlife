# BUILD: `tl.edit/1` and `tl.build/1`, what a player (or an LLM) builds in the Home

Added 2026-11-26 (spark `world-sandbox`, milestone M1; `docs/TWO-WORLDS.md` "Build layers", Structures by blocks).
Reader and writer: `engine/kernel/world/build/` (`edit_log.gd`, `build_file.gd`); selftest block 752 holds the code
to this text. The working notes and the API are in `engine/kernel/world/build/BUILD.md`.

**One world, two ways to build.** A player builds by hand in build mode, and in M4 an LLM builds from a sentence.
Both write the same thing: a batch of `tl.edit/1` operations. Undo, saving and, later, sharing work on that log, so
an LLM's work is one batch the player can undo, adjust by hand or keep. Nothing in this contract depends on who wrote
an operation except the `author` field.

## The block grid

- A **cell** is 1 m, world-anchored, addressed by integers `[x, y, z]`: the cell spans `x..x+1`, `y..y+1`, `z..z+1` m.
  `y` is in `-16..111`.
- A **chunk** is the 96 x 96 m column `(floor(x / 96), floor(z / 96))`, the same grid as the Home's collider chunks
  (`engine/kernel/world/home/hook.gd`). Caps, saved records and one static body are per chunk. Drawing is per 16 x 16 m
  **section** (36 per chunk), so one edit redraws one section, not a chunk (measured: 2.5 ms against 47-75 ms).
- A cell holds at most one block. A block is a **shape**, a **material**, a **rot** (quarter turns about +y, 0-3) and
  an optional **flip** (upside down; stair, ramp and roof only).
- Shapes and materials have fixed ids. An id is never reused for something else; a retired id stays reserved.

| id | shape | joins |
|---|---|---|
| 1 | cube | hides faces against opaque full faces |
| 2 | slab (lower half) | as cube, on its full faces |
| 3 | stair | outer and inner corners from stair neighbours |
| 4 | ramp | outer and inner corners from ramp neighbours |
| 5 | post (0.25 m column) | joins vertically |
| 6 | window (frame in the material, a glass pane) | as cube on its frame |
| 7 | roof (45 degrees) | ridge, outer and inner corners from roof neighbours |
| 8 | fence | connects horizontally to fence, post and full faces |

| id | material (palette key) | | id | material (palette key) |
|---|---|---|---|---|
| 1 | `stone` | | 6 | `roof_slate` |
| 2 | `stone_dark` | | 7 | `concrete` |
| 3 | `plank` | | 8 | `rock_warm` |
| 4 | `wood_dark` | | 9 | `white` |
| 5 | `roof` | | 10 | `glass` (window panes only) |
|  |  | | 11 | `brick` (unlockable, M3) |
|  |  | | 12 | `plaster` (unlockable, M3) |

Joined forms are derived from the neighbours when a section is meshed. They are never stored. A stair is drawn as 4
steps of 0.25 m and collides as drawn (M5): the visitor steps up and down a riser of at most half a block on the Home's
blocks (`engine/kernel/world/terrain/walker_riser.gd`); a pack's walkers are unchanged.

## `tl.edit/1`: one operation

One JSON object per line, append-only:

```
{"v": 1,
 "op": "place" | "remove",
 "at": [x, y, z],
 "shape": <id>, "mat": <id>, "rot": 0..3,      on place: what is placed; on remove: what was removed
 "flip": true,                                  present only when true
 "author": "hand" | "llm",
 "batch": <int>}                                operations of one gesture or one LLM job share a batch
```

- Required: `v`, `op`, `at`, `shape`, `mat`, `rot`, `author`, `batch`. Unknown keys are errors; an absent value is an
  omitted key (never null).
- A remove carries what it removed, so every batch can be undone without reading the world. Undo and redo work per
  batch.
- An operation is applied only if the cell may take it. It is refused with a reason when the cell is in a game lot or
  an authored structure, overlaps the visitor, is outside `y`, or would pass a cap (32,768 blocks per chunk, 400,000
  per Home). A batch is applied as far as it goes; the refused operations are reported, never written to the log.

## `tl.build/1`: the saved Home

`user://home/build.json` plus `user://home/edits.jsonl` (the operations since the last compaction):

```
{"v": 1, "seed": <the Home's seed>, "rev": <int, +1 per save whose content changed>,
 "chunks": {"<cx>,<cz>": "<base64 of the chunk's (cell, code) pairs, sorted by cell>"}}
```

- `code` packs a block as bits 0-4 shape, 5-9 mat, 10-11 rot, 12 flip. The chunk-local cell index and the pair
  layout are documented in `engine/kernel/world/build/BUILD.md`, and the reader holds them to this text.
- A record whose `seed` differs from the Home's is refused. Empty chunks are omitted.
- It is written as a temporary file, read back and compared, the old file copied to `.prev`, then renamed (the
  `PlotFile.save` pattern). Writers emit keys in the order above, and `rev` does not move on a save with
  nothing new, so load then save gives the same bytes.

## Milestones 2-4: land, pieces, stamps, unlocks, the LLM (added 26 Nov, the seam)

The operator decided these on 26 Nov (spark `world-sandbox`, wave 4). The log stays one log: the new operations are
`tl.edit/1` operations with the same `v`, `author` and `batch`, and the same rules (unknown keys are errors, absent =
omitted, a removal carries what it removed). Each kind is owned by one **layer** in `engine/kernel/world/build/`
(blocks, land, pieces), which validates, applies, inverts and saves it.

### More operations

```
{"v":1, "op":"land",  "verts":[[i, j, from_cm, to_cm], ...], "author":..., "batch":...}
{"v":1, "op":"paint", "cells":[[i, j, "<from>", "<to>"], ...], "author":..., "batch":...}
{"v":1, "op":"put",   "at":[x,y,z], "part":"<kit kind>", "params":{...}, "rot":0..3, "seed":<int>, "author":..., "batch":...}
{"v":1, "op":"lift",  "at":[x,y,z], "part":"<kit kind>", "params":{...}, "rot":0..3, "seed":<int>, "author":..., "batch":...}
```

- **Land** (M2) is a height delta over the Home's procedural ground on a world-anchored **3 m lattice**. Vertex
  `[i, j]` is at world `(3i, 3j)`. Heights are integer centimetres: `to_cm` is the new height and `from_cm` the height
  before. A brush stroke is recorded as its result (the vertices it moved), never as the brush, so undo and replay
  need no brush code. Heights are absolute; a vertex is stored only where it differs from the ground's own height,
  which is the valley's DRAWN surface (its 12 m triangles) at that point, rounded to cm. Setting a vertex back to it
  removes its entry. On input (an LLM answer, a
  stamp), a vertex may be `[i, j, to_cm]`: the exe fills `from_cm` before it applies and journals the op.
- **Paint** (M2) sets the ground material of 3 m cell `[i, j]` (spanning `3i..3i+3`, `3j..3j+3`). Values are
  names: `grass`, `grass_dark`, `grass_dry`, `dirt`, `sand`, `stone`, `rock_warm`, `cliff`, and `valley` for the
  ground's own material (no paint).
- **Put / lift** (M3) place and remove a kit part anchored at cell `at`, turned `rot` quarter turns about +y.
  `params` are `TLKit` params checked by `TLKit.validate`, omitted when they are all defaults. `seed` is always written,
  so a part looks the same on every load. The part's footprint (its turned bounds, in whole cells) is occupied: blocks
  and other pieces may not overlap it. A piece
  standing on the ground is set to the ground's height in its anchor cell (derived, not saved).
- Land and paint are refused in the protected areas the land layer names (the village, game sites, lanes, the river
  band, columns that hold blocks or pieces, the visitor), with a reason, like blocks.
- **A stamp is not an operation.** Placing a stamp expands it into `place` and `put` operations in one batch (one undo).

### `tl.build/2`

```
{"v": 2, "seed": ..., "rev": ...,
 "chunks": {...as v1...},
 "land":   {"<cx>,<cz>": "<base64 of (vertex, cm) int32 pairs, sorted by vertex>"},
 "paint":  {"<cx>,<cz>": "<base64 of (cell, id) int32 pairs, sorted by cell>"},
 "pieces": [{"at":[x,y,z], "part":"...", "params":{...}, "rot":0..3, "seed":<int>}, ...]}
```

- `chunks` is required in v2, as in v1 (`{}` when there are no blocks); `land`, `paint` and `pieces` are omitted when
  empty. A land vertex or paint cell belongs to exactly one chunk, `(floor(i / 32), floor(j / 32))`. Its local index is
  `(i - 32 cx) + 32 (j - 32 cz)`, in 0..1023. Paint ids in the file: 1 grass, 2 grass_dark, 3 grass_dry, 4 dirt,
  5 sand, 6 stone, 7 rock_warm, 8 cliff. Pieces are sorted by `at` (z, then x, then y). Empty sections are omitted.
- A v2 reader reads v1. A v1 reader refuses v2 and never overwrites it. An exe writes `build.json` as v2 before it
  journals the first operation that v1 cannot read, so an older exe never compacts such an operation away.

### `tl.stamp/1` (M3)

```
{"schema":"tl.stamp/1", "name":"<title>", "size":[w,h,d],
 "blocks": [[x,y,z,code], ...],                  relative to the stamp's low corner, sorted by z, x, y
 "pieces": [{"at":[x,y,z], "part":..., "params":{...}, "rot":..., "seed":...}, ...]}
```

- Placing a stamp at a cell with a turn of `r` quarter turns turns each relative cell about +y and adds `r` to every
  block's and piece's `rot`. Shared, a stamp is an item of kind `stamp`, tier data (`docs/SHARING.md`).

### Unlocks from play (M3)

- `user://home/trophies.json`:
  `{"schema":"tl.trophies/1", "packs":{"<pack id>":{"plays":n, "wins":n, "best":n}}}`. It is written when a dungeon
  ends, from the pack's `TLRules` (`winner`, `scores`). `best` is omitted for a pack that keeps no score.
- `engine/kernel/world/build/unlocks.json`:
  `{"schema":"tl.unlocks/1", "rules":[{"id":"...", "when":{"pack":"...", "plays":n, "wins":n, "best":n},
  "grant":{"mats":[...], "shapes":[...], "parts":[...], "stamps":[...]}}]}`. A rule is met when every number it names
  is reached. Absent keys are omitted. `when.pack` may be `"*"`: every pack together (plays and wins summed, the best of
  any). `grant.mats` and `grant.shapes` are ids, as in operations; `parts` are kit kinds; `stamps` are stamp names.
- What M1 shipped (shapes 1-8, materials 1-9) is never locked. Locks apply to what M3 adds.

### The LLM command bar (M4)

- The exe writes an ask file `tl.world-edit-ask/1`: the sentence, the cursor cell and facing, and a measured read of a
  region round the cursor (blocks, pieces, ground heights, refused columns, the shape, material, part and paint
  tables). The Foreman (`foreman world-edit`, the `place` pattern) answers with `tl.world-edit/1`:
  `{"schema":"tl.world-edit/1", "ops":[...], "note":"<one line for the player>", "model":"...", "durationMs":n,
  "tokensIn":n, "tokensOut":n}`, or `{"schema":"tl.world-edit/1", "error":"..."}`. The ops are the operations above
  without `v`, `author` and `batch`, which the exe fills in (`author: "llm"`, one batch).
- The answer is shown as a ghost. The player accepts it (one batch, one undo), or reverts it. The exe never applies
  an answer without the player.
- Calls are logged to `user://home/llm_calls.jsonl` (sentence, model, tokens, duration, accepted), which `tl ledger`
  reads. There is a per-day call cap the player sets. A billing cap is the one place a calendar day is used: the
  world's simulation still counts frames.
- A replay never calls the model: the accepted operations are in the journal.

## Milestone 5: water, paths, plants (added 26 Nov, wave 5)

```
{"v":1, "op":"flood",  "cells":[[i, j, level_cm], ...], "author":..., "batch":...}
{"v":1, "op":"drain",  "cells":[[i, j, level_cm], ...], "author":..., "batch":...}
{"v":1, "op":"path",   "id":<int>, "pts":[[x_cm, z_cm], ...], "width_cm":<int>, "paint":"<path paint>", "author":..., "batch":...}
{"v":1, "op":"unpath", "id":<int>, "pts":[...], "width_cm":<int>, "paint":"...", "author":..., "batch":...}
{"v":1, "op":"plant",  "cells":[[i, j, "<from>", "<to>"], ...], "author":..., "batch":...}
```

- **Water** is still water over 3 m land cells (the paint grid). `flood` sets the surface of cell `[i, j]` to the
  absolute height `level_cm`; `drain` removes it and names the level it removes (so undo needs no lookup). A cell holds
  at most one level. The **pour** tool computes the fill: from the clicked cell it floods 4-neighbour cells up to just
  under the spill level (the lowest rim the water would cross), refused with a reason when the fill reaches 2,048
  cells, a protected area, or the river band ("spills"). Water has no collider: a walker wades on the bed, as at the
  river. Water follows no later sculpt by itself: a land op under water leaves the level as it is.
- **Paths** are splines draped on the ground. `pts` are 2-64 control points in world centimetres, consecutive points
  100-4,800 cm apart; `width_cm` is 150-800; the path paints are `dirt`, `sand`, `stone`, `rock_warm`, `grass_dry` and
  `plank`. `id` is a positive integer, unique in the Home (the layer gives the next free one). `unpath` carries the
  whole path it removes. Grading is not part of the op: the path tool writes a `land` op in the same batch.
- **Plants** set the growth of 3 m cell `[i, j]`: `meadow`, `flowers`, `tall_grass`, or `valley` for the ground's own
  growth. Growth is drawn by the ground's shader (no instances). Trees and bushes are `put` ops (the scatter brush
  writes one seeded `put` per tree).
- Flood, path and plant are refused in the protected areas, with a reason, like land and paint.
- **On input only** (an LLM answer), `{"op":"pour", "at":[x,y,z]}` asks the exe to compute a fill from that cell. The
  exe expands it into one `flood` op when it shows the answer; a `pour` is never journaled or saved.

### `tl.build/3`

```
{"v": 3, ...every v2 key...,
 "water":  {"<cx>,<cz>": "<base64 of (cell, level_cm) int32 pairs, sorted by cell>"},
 "paths":  [{"id":<int>, "pts":[[x_cm, z_cm], ...], "width_cm":<int>, "paint":"..."}, ...],
 "plants": {"<cx>,<cz>": "<base64 of (cell, id) int32 pairs, sorted by cell>"}}
```

- Chunks and local cell indices are as for `paint`. Plant ids in the file: 1 meadow, 2 flowers, 3 tall_grass. Paths
  are sorted by `id`. `water`, `paths` and `plants` are omitted when empty.
- **Every operation kind names the file version it needs**: place, remove: 1; land, paint, put, lift: 2; flood,
  drain, path, unpath, plant: 3. An exe writes `build.json` at the needed version before it journals the first
  operation of a higher one. A reader refuses a version above its own and never overwrites that file.

### The LLM command bar, M5 additions

- The ask gains `water`: `[{"y": <cell y of the surface>, "runs": [[z, x0, x1], ...]}, ...]`, the measured water in
  the region (the river and the player's water), omitted when there is none. In a water column, `ground` is the bed.
- The ask's tables list only what the player has unlocked: `mats` adds 11 brick and 12 plaster once granted; `parts`
  leaves out locked kinds. The Foreman refuses an op that names a mat or part not in the ask's tables. The exe still
  refuses a locked mat or part at accept ("locked: <the condition>").
- `ops` may name `pour`, `drain`, `path`, `unpath` and `plant` once their layers are built.
- Every layer shows its own part of an answer as a ghost before accept (blocks, land, paint, pieces, water, paths,
  plants).

## Milestone 6: rules and runs (added 27 Nov, day shift, Director with the owner away)

A build can do something: **zones** (boxes on the block grid) and **rules** (when, if, do) make a door that opens, a
jump pad, a coin, a hazard, and a **run** (start, checkpoints, finish) that times itself. Thesis and sources:
`docs/research/sandbox/THESIS.md`.

```
{"v":1, "op":"zone",   "id":<int>, "box":[[x0,y0,z0],[x1,y1,z1]], "look":"<zone look>", "name":"<text>", "author":..., "batch":...}
{"v":1, "op":"unzone", "id":<int>, "box":[...], "look":"...", "name":"...", "author":..., "batch":...}
{"v":1, "op":"rule",   "id":<int>, "when":{...}, "if":[...], "do":[...], "author":..., "batch":...}
{"v":1, "op":"unrule", "id":<int>, "when":{...}, "if":[...], "do":[...], "author":..., "batch":...}
```

- **Zones.** `box` is two block cells, inclusive, `x0 <= x1`, `y0 <= y1`, `z0 <= z1`, at most 64 cells a side, in the
  block grid's bounds. `id` is a positive integer, unique among zones in the Home (the layer gives the next free one).
  `look` is one of `none` (invisible in play), `pad` (a flat glowing disc on the zone's floor), `coin` (a turning token
  at the zone's centre), `flag` (a pole and flag at the zone's floor centre). `name` is optional, 1-24 printable
  characters. A Home holds at most 512 zones and 512 rules. A `zone` op on an id that exists is refused (remove it first: `unzone` then `zone` in one batch).
  `unzone` carries the whole zone it removes, so undo needs no lookup. Zones are refused in the protected areas of
  blocks, with the blocks' reasons. Zones may overlap each other and blocks.
- **Rules.** `id` is a positive integer, unique among rules. `when` is exactly one trigger, `if` an optional list
  (omitted when empty) whose conditions must all hold, `do` 1-8 effects applied in order. `unrule` carries the whole
  rule. A rule that names a zone id that does not exist is refused; `unzone` of a zone a rule names is refused (remove
  the rule first, in the same batch).
- **Triggers** (`when`):
  - `{"on":"enter", "zone":<id>}`: the visitor's feet cell enters the zone (fires once per entry).
  - `{"on":"leave", "zone":<id>}`: it leaves the zone.
  - `{"on":"use", "zone":<id>}`: the use key (E) goes down while the feet cell is in the zone.
  - `{"on":"every", "frames":<60-36000>}`: every N frames while the Home is visited (not while building).
  - `{"on":"count", "counter":"<counter>", "at":<1-999>}`: a counter reaches the value (fires once per run).
  - `{"on":"start"}` / `{"on":"finish"}`: a run starts / is finished.
- **Conditions** (`if`): `{"running":true|false}` (a run is or is not going); `{"counter":"<counter>", "min":<0-999>}`
  and/or `"max":<0-999>` in the same object.
- **Effects** (`do`):
  - `{"do":"start", "run":"<run name>"}`: starts a run (1-24 printable characters) from this frame: the run's clock
    is 0, counters are 0, every zone is closed and every coin is back. Starting the run that is going restarts it.
  - `{"do":"checkpoint", "zone":<id>}`: the run's respawn becomes the zone's floor centre.
  - `{"do":"finish"}`: ends the run that is going and records it (below).
  - `{"do":"respawn"}`: puts the visitor at the run's respawn (the start zone's floor centre until a checkpoint), or
    where the visit began when no run is going.
  - `{"do":"add", "counter":"<counter>", "by":<-99..99, not 0>}`: counters are named `[a-z_]{1,16}`, at most 8 per
    Home, 0 at the start of a run and of a visit, clamped to 0-999.
  - `{"do":"take", "zone":<id>}`: the zone's look (a coin) is hidden until the run restarts or the visit ends.
  - `{"do":"open", "zone":<id>}` / `{"do":"close", "zone":<id>}` / `{"do":"toggle", "zone":<id>}`: the blocks inside
    the zone stop being drawn and stop colliding while it is open (a door, a gate, a bridge that appears). Opening
    never changes the saved blocks; every zone is closed when a visit or a run starts.
  - `{"do":"launch", "up_cm":<0-3000>, "fwd_cm":<0-3000>}`: sets the visitor's velocity: up, and forward along his
    facing, in cm per second (a jump pad).
  - `{"do":"teleport", "zone":<id>}`: puts the visitor at the zone's floor centre.
  - `{"do":"say", "text":"<text>", "frames":<30-600>}`: shows a line of 1-60 printable characters on the screen.
- **Running.** Rules run only while the Home is visited and build mode is off, once per physics frame, in the visitor's
  space only (never a pack's, never in a pack's state hash). Each frame: the triggers are read from the visitor's feet
  cell and keys, then every fired rule runs in ascending `id`, each checking its `if` when it fires; an effect sees
  the effects before it in the same frame. A rule fires at most once per frame. The same inputs from the same saved
  Home give the same frames: a run is deterministic.
- **Settled at the seam (27 Nov, Director)**: a taken zone fires no `enter`, `leave` or `use` until it is back; `if`
  holds at most 8 conditions; `start`, `finish` and `count` triggers caused by an effect fire on the next frame; a
  run started by a rule with no zone respawns at the floor of the feet cell it started on; E fires `use` (and does not
  enter a nearby game) when the feet cell is in a zone that a rule triggers `on: use`. Stamps do not carry zones or
  rules yet.
- **Runs are recorded** in `user://home/records.json`:
  `{"schema":"tl.records/1", "runs":{"<run name>":{"plays":<int>, "finishes":<int>, "best_frames":<int>}}}`
  (`best_frames` omitted until the first finish). `plays` counts starts, `finishes` counts finishes. A finish shows a
  card: the run's name, its time, the best time, and "new best" when it is.

### `tl.build/4`

```
{"v": 4, ...every v3 key...,
 "zones": [{"id":<int>, "box":[[x0,y0,z0],[x1,y1,z1]], "look":"...", "name":"..."}, ...],
 "rules": [{"id":<int>, "when":{...}, "if":[...], "do":[...]}, ...]}
```

- Sorted by `id`; omitted when empty; `name` and `if` omitted when absent. zone, unzone, rule and unrule need version 4.

### The best run's ghost (M6, round 2)

- When a finish is a new best, the run's path is kept in `user://home/runs/<slug of the run name>.json`:
  `{"schema":"tl.run-ghost/1", "run":"<run name>", "frames":<int>, "step":2, "track":"<base64 of float32
  x, y, z, yaw per sample>", "clips":[[<frame>, "<clip>"], ...]}`: the figure's feet and facing every `step`
  frames from the start to the finish, and each change of its animation clip. It is written as the build file is
  (temp, read back, rename) and replaces the earlier best's file. Unknown keys are errors.
- When that run starts again, a ghost of the figure (the holo look, no collider, no shadow) walks the kept track from
  frame 0 beside the visitor, so a person races their own best; it vanishes at the track's end. It is drawn only in
  the visitor's view, never in a pack's space or hash. A key in play hides or shows it for the rest of the visit
  (not saved; every visit starts with it shown).

### Courses travel: `tl.stamp/2` and the share code (M6, round 2)

```
{"schema":"tl.stamp/2", ...every tl.stamp/1 key...,
 "zones": [{"id":<int>, "box":[[x0,y0,z0],[x1,y1,z1]], "look":"...", "name":"..."}, ...],   relative cells, ids local to the stamp
 "rules": [{"id":<int>, "when":{...}, "if":[...], "do":[...]}, ...]}                         naming the stamp's zone ids
```

- A stamp box takes the zones whose box lies wholly inside it and every rule that names only those zones (a rule
  with no zone is not taken). A stamp with no zones and no rules is written as `tl.stamp/1`, byte for byte as before.
- Placing a `tl.stamp/2` turns and moves the zones as it does the blocks (a box stays a box: its corners turned, then
  sorted), and writes the zones and rules in the same batch as the blocks, with the next free ids and the rules'
  references rewritten (as an LLM answer's ids are). When a placed course's run name already exists in the Home,
  the tool asks once in a name field prefilled `<name> (2)` (the next free number): Enter renames the placed rules'
  runs, Esc keeps the name (the two courses then share one record: records are by name).
- **The share code** is a stamp as one line of text: `TL1-` followed by the URL-safe base64 (no padding) of the
  zlib stream (RFC 1950, deflate inside: Godot's `COMPRESSION_DEFLATE`; Node `zlib.inflateSync`) of the UTF-8 of the stamp's JSON. Copying a stamp puts its code on the clipboard; pasting a code (Ctrl+V
  in the stamp tool) checks it as a stamp file is checked (unknown keys and bad shapes refused with a reason) and adds
  it to the stamps like an import. A code longer than 65,536 characters is refused.

### The LLM command bar, M6 additions

- The ask gains `zones` and `rules`: the zones whose box meets the region and the rules that name them (and every rule
  with no zone), in the file's shapes, omitted when there are none; and `rules_room`: `{"zones_left":<int>,
  "rules_left":<int>, "counters":["<counter>", ...]}` (the counters already used).
- `ops` may name `zone`, `unzone`, `rule` and `unrule`. Ids in an answer are the answer's own: the exe gives each new
  zone and rule the next free id when it shows the answer, and rewrites the answer's references to match.
- Before accept, the exe checks an answer's space and shows what it finds with the ghost (it does not refuse): blocks
  that rest on nothing, a pad or a flag with no floor under it, a coin inside a solid block, a run whose finish cannot
  be reached from its start (an estimate over standable cells: walking, steps of at most 0.55 m, and jumps of at most
  1.2 m up and 4 m across).
- **Fix it** (round 2): when the check found something, R sends one follow-up ask with the same sentence and cursor
  and an optional key `fix`: `{"ops": [the answer's ops], "findings": ["<a finding naming cells and distances>", ...]}`
  (omitted in every other ask). The answer replaces the ghost; only Enter keeps it. It counts as a call.

### Assemblies (M6, round 3)

On input only (an LLM answer, or the hand's assembly tool), `{"op":"assemble", "kind":"<kind>", "at":[x,y,z],
"size":[w,h,d], "rot":0-3, "mat":<id>, "trim":<id>, "opts":{...}}` asks the exe to build a parametric big shape;
the exe expands it into `place` ops when it shows the answer (as `pour` is expanded into `flood`): an `assemble` is
never journaled or saved. `at` is the low corner cell before the turn, `size` in cells (each 1-48), `mat` and `trim`
block materials from the ask's tables (trim omitted = mat). Kinds (v1) and their `opts` (each optional):
- `wall`: a straight wall `w` long, `h` high, 1 thick; `opts.door` (cell offset along it, a 1x2 opening),
  `opts.windows` (every N cells at sill height 1), `opts.crenels` (true: merlons on top).
- `tower`: a hollow square tower `w` x `w`, `h` high, walls 1 thick; `opts.door`, `opts.windows`, `opts.crenels`,
  `opts.stairs` (`"inside"` or `"outside"`: a stair run climbing to the top, with landings).
- `house`: walls `w` x `d` x `h` with a door, windows, a floor, and a pitched roof of roof blocks over the long side.
- `stair`: a stair run `w` wide climbing `h` cells along +z (turned by `rot`), with a landing every 6 steps.
- `bridge`: a deck `w` wide and `d` long at y of `at`, railings (fences) on both sides, piers every 6 cells down to
  the ground or bed, and steps at both ends down to the ground.
- `platform`: a floor `w` x `d` at y of `at` with a railing round it and posts down to the ground.
Blocks an assembly would place in a protected or occupied cell are left out with the place ops' reasons; the shape
is the same for the same input (deterministic, no randomness).


## Laws

- Blocks live only in the visitor's physics space (one static body per non-empty chunk, layer 1). They are never in a
  pack's space or a pack's state hash, so a game in the world still plays as it does alone (the `world` gate).
- Time is frames. A chunk is rebuilt within a frame-counted job budget, never on a wall-clock condition.
