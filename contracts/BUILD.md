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

## Laws

- Blocks live only in the visitor's physics space (one static body per non-empty chunk, layer 1). They are never in a
  pack's space or a pack's state hash, so a game in the world still plays as it does alone (the `world` gate).
- Time is frames. A chunk is rebuilt within a frame-counted job budget, never on a wall-clock condition.
