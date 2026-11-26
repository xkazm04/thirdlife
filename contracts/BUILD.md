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
steps of 0.25 m and collides as its 45-degree ramp, because the visitor's walkers do not climb a vertical riser
(`engine/kernel/world/build/PATCHES-WP1.md` P2). When the walker steps up risers, stairs collide as drawn.

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

## Laws

- Blocks live only in the visitor's physics space (one static body per non-empty chunk, layer 1). They are never in a
  pack's space or a pack's state hash, so a game in the world still plays as it does alone (the `world` gate).
- Time is frames. A chunk is rebuilt within a frame-counted job budget, never on a wall-clock condition.
