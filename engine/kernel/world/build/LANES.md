# LANES: who may edit what in `engine/kernel/world/build/` (M2, M3, M4 in parallel)

Written by the seam (26 Nov 2026, spark `world-sandbox`). Three lanes work at the same time in three worktrees and land
one by one: **M2** land sculpt and paint, **M3** pieces, stamps and unlocks, **M4** the LLM command bar. The wire
formats are `contracts/BUILD.md` "Milestones 2-4" (no lane edits a contract). The interfaces a lane fills are
`BUILD.md` "Layers" and "Tools". This file is the lanes' contract with each other: a lane edits only the files it
OWNS below and adds new files only under its own names. If a lane needs a change to a file it does not own, it writes
the change down in its `PATCHES-<lane>.md` and the Director makes it.

## Frozen (the seam's; no lane edits them)

`edit_log.gd`, `build_file.gd`, `home_build.gd`, `build_mode.gd`, `hotbar.gd`, `protect.gd`, `op_util.gd`,
`block_mesh.gd`, `ghost.gd`, `preview_mesh.gd`, `build_devices.gd`, `tools/stub_tool.gd`, `case_util.gd`,
`build_case.gd`, `build_mode_case.gd`, `seam_case.gd`, `BUILD.md`, `LANES.md`, `PATCHES-WP1.md`, `PATCHES-WP2.md`,
`engine/tools/selftest.d/752-*.sh`, `753-*.sh`, `754-*.sh`.

Every lane keeps 752, 753 and 754 green, unedited. A lane's own case goes in its own selftest block.

How a lane plugs in without editing a frozen file:

| Need | Hook (already there) |
|---|---|
| its ops validated, applied, undone, journaled, saved, loaded | its layer file (the interface in BUILD.md "Layers"); `home_build.gd` registers it |
| build.json made tl.build/2 before its first op is journaled | done by the log for every op that is not place or remove |
| its tool in the strip, its slots, info, keys, ghost | its tool file (BUILD.md "Tools"); `build_mode.gd` makes it, `hotbar.gd` shows what it says |
| a refusal of blocks in its area, or of ground edits under its things | its layer's `add_rules(protect)`: `protect.add_rule(Callable(self, "method"), "cell" or "area")` (home_build.gd calls it once when it registers the layer, never for a scratch copy) |
| another layer's data | `ctx.home.get_ref().layer("blocks" / "land" / "pieces")`, duck-typed, read only |
| a ghost of many blocks | `build.preview(ops)` and a `preview_mesh.gd` it adds under its tool's host |
| what is in a box (for an ask) | `build.read_region(min, max)`, with each layer's `read_region` keys |
| a landscape, a key press, a temp folder in a case | `case_util.gd` |

## M2: land sculpt and paint

- **Owns:** `land_layer.gd` (fill the stub: keep its op checks, replace the NOT_YET refusals, save `land` and `paint`),
  `tools/sculpt_tool.gd`, `tools/paint_tool.gd` (replace each stub; drop the `extends stub_tool.gd`), new files named
  `land_*.gd` (the delta store, the ground re-mesh with skirts, its protected areas), `land_case.gd`, `LAND.md`,
  `PATCHES-M2.md`, `engine/tools/selftest.d/755-home-land.sh`.
- **Outside this folder:** `engine/kernel/world/home/ground.gd` and `home/hook.gd` only as the re-mesh and the colliders
  need it (no other lane touches `home/`). Every edit there is listed in `PATCHES-M2.md`.
- **Gives the others:** the land layer's `read_region` keys (ground heights in cm on the lattice, paints, refused
  columns) for M4's ask, and a public `height_at(x, z) -> float` (the ground with its delta) for M3's pieces.
- **Must not touch:** pieces, stamps, unlocks, the command bar, foreman.

## M3: pieces, stamps, unlocks

- **Owns:** `pieces_layer.gd` (fill the stub: keep its op checks; footprints; save `pieces`), `tools/piece_tool.gd`,
  `tools/stamp_tool.gd` (replace each stub), new files named `piece_*.gd`, `stamp_*.gd`, `unlocks.gd`, `unlocks.json`,
  `trophies.gd`, `pieces_case.gd`, `PIECES.md`, `PATCHES-M3.md`, `engine/tools/selftest.d/756-home-pieces.sh` and
  `758-home-unlocks.sh`.
- **May also edit, only for shapes and materials that unlocks grant** (M1's shapes 1-8 and materials 1-9 are never
  locked): `blocks.gd`, `shapes.gd`, `blocks_layer.gd`, `tools/blocks_tool.gd`. No other lane edits these four. 752
  and 753 stay green.
- **Outside this folder:** where a dungeon ends (`engine/kernel/dungeon/`), to write `user://home/trophies.json`, as a
  patch in `PATCHES-M3.md` (the Director lands it); piece bodies go into the visitor's WorldSpace through
  `world_space.gd` `_static` as `block_mesh.gd` does (read, not edited).
- **Gives the others:** the pieces layer's `read_region` key `pieces` for M4's ask; an "area" rule so land and paint
  are refused under a piece, and a "cell" rule so blocks are refused in a footprint (both from its own files).
- **Must not touch:** the land layer, the sculpt and paint tools, the command bar, foreman.

## M4: the LLM command bar

- **Owns:** `tools/command_tool.gd` (replace the stub: Enter opens the bar, `blocks_input()` true while it is open, the
  pending marker, the answer as a ghost, accept as one batch with `author: "llm"`, revert), new files named
  `command_*.gd` (the ask writer, the answer reader, `user://home/llm_calls.jsonl`, the per-day cap), `command_case.gd`,
  `COMMAND.md`, `PATCHES-M4.md`, `engine/tools/selftest.d/757-home-command.sh` and `759-home-command-ask.sh`.
- **Outside this folder:** `foreman/src/world_edit*.ts` and its tests, the `world-edit` line of `foreman/src/cli.ts`
  (only M4 edits foreman), and `devx/lib/commands/ledger.mjs` for the calls log (only M4 edits it). M4 also owns the
  one change to `kernel/runner/visit.gd` that stops the visitor walking on W A S D typed into the bar (Director's
  decision, 26 Nov: no other lane touches visit.gd); keep it to a few lines and keep 260-k8 and 753 green.
- **Reads, never writes:** `read_region` (the land and pieces keys appear when M2 and M3 land; the ask works without
  them), `preview` and `preview_mesh.gd` for the answer's ghost, `apply` with the accepted ops as one batch.
- **Must not touch:** any layer file, the other tools, `unlocks.json`.

## Landing

One lane at a time onto the seam's branch: its own block green, 752, 753, 754 green, `tl check --tier fast`. A lane
that finds the seam wrong (a missing hook, a wrong reason) stops and reports it; it does not patch a frozen file.
