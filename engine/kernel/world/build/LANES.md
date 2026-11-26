# LANES: who may edit what in `engine/kernel/world/build/` (M5 and its follow-ups, five lanes in parallel)

Written by the M5 seam (27 Nov 2026, spark `world-sandbox`, wave 5; the M2-M4 table it replaces is in git at
151c329e). Five lanes work at the same time in five worktrees and land one by one: **W** water, **P** paths and the
plant scatter, **L** the land look and plants, **C** the LLM bar's M5 part, locks in the ask and the stamp name,
**K** walker steps, the results card and the kernel API. The wire formats are `contracts/BUILD.md` "Milestone 5" (no
lane edits a contract). The interfaces a lane fills are `BUILD.md` "Layers" (with the M5 additions `offers`,
`preview_node`, `expand_input`, `water_runs`), "Tools" and "The plant scatter". This file is the lanes' contract with
each other: a lane edits only the files it OWNS below and adds NEW files only under its own prefix. If a lane needs a
change to a file it does not own, it writes the change down in its `PATCHES-<lane>.md` (`PATCHES-W.md` ...) and the
Director makes it.

## Frozen (the seam's; no lane edits them)

`edit_log.gd`, `build_file.gd`, `home_build.gd`, `build_mode.gd`, `hotbar.gd`, `protect.gd`, `op_util.gd`,
`block_mesh.gd` (K: see its row), `ghost.gd`, `preview_mesh.gd`, `build_devices.gd`, `blocks.gd`, `shapes.gd`,
`blocks_layer.gd`, `stub_layer.gd`, `seam_lists.gd`, `seam_case.gd`, `seam_v3.gd`, `case_util.gd`, `build_case.gd`,
`build_mode_case.gd`, `tools/stub_tool.gd`, `tools/blocks_tool.gd`, `BUILD.md`, `LANES.md`, `PATCHES-*.md` of earlier
waves, and `engine/tools/selftest.d/752-*.sh`, `753-*.sh`, `754-*.sh`, `758-*.sh`.

Every lane keeps 752, 753, 754, 755, 756, 757, 758 and 759 green. 754 (`seam_case.gd`) and 757 (`command_case.gd`)
read their lists from `seam_lists.gd` and tell a stub from a built layer by its `offers()` (a stub offers nothing) and a
stub tool by its base script, so a lane that replaces its stub changes no case: its built layer must offer its ops,
keep `op_util.gd` `head` first and `tail` last in its `malformed` (754 asks every M5 kind for "unknown key 'brush'"
and a journal line's "batch is missing"), and its built tool must show a non-empty info line. A lane's own case goes
in its own selftest block, reserved below as a stub that prints `HOME <name> stub ok`: the lane replaces that file.

How a lane plugs in without editing a frozen file:

| Need | Hook (already there) |
|---|---|
| its ops validated, applied, undone, journaled, saved, loaded | its layer file (`water_layer.gd`, `paths_layer.gd`, `plants_layer.gd`; BUILD.md "Layers"); `home_build.gd` registers it (`LAYER_KINDS`) |
| build.json made tl.build/3 before its first op is journaled | done by the log: flood, drain, path, unpath and plant need version 3 (`build_file.gd` `OP_V`); its saved key (`water`, `paths`, `plants`) makes the file v3 (`KEY_V`) |
| its ops offered to the LLM | its layer's `offers()` (command_ask.gd `ops_now` lists every layer's offers) |
| its part of an LLM answer shown before accept | its layer's `preview_node(scratch)` (home_build.gd `preview_nodes`; the command tool shows every layer's node) |
| a pour in an answer | the water layer's `expand_input(op)` (home_build.gd `expand_input` routes `pour` there; the command tool calls it) |
| the ask's `water` key | the water layer's `water_runs(lo, hi)` (command_ask.gd `water_of`) |
| trees and bushes from a brush | `plant_scatter.gd` `scatter(...)` (P writes it, L's plant tool calls it; BUILD.md "The plant scatter") |
| its tool in the strip, its slots, info, keys, ghost | its tool file (`tools/water_tool.gd`, `path_tool.gd`, `plant_tool.gd`; BUILD.md "Tools"); `build_mode.gd` makes it |
| a refusal of blocks in its area, or of ground edits under its things | its layer's `add_rules(protect)`: `protect.add_rule(Callable(self, "method"), "cell" or "area")`; `protect.refusal_area(rect, what)` asks every area rule (`what`: "land", "paint", "flood", "path", "plant") |
| another layer's data | `ctx.home.get_ref().layer("blocks" / "land" / "pieces" / "water" / "paths" / "plants")`, duck-typed, read only |
| a landscape, a key press, a temp folder in a case | `case_util.gd` |

## W: water

- **Owns:** `water_layer.gd` (fill the stub: keep its op checks; flood, drain, the pour fill with its spill level and
  its refusals, `expand_input`, `water_runs`, `offers` `["pour", "drain"]`, `preview_node`, save `water`), new files
  `water_*.gd` (the store, the fill, the surface mesh in the still-water look), `tools/water_tool.gd` (replace the
  stub), `PATCHES-W.md`, `engine/tools/selftest.d/761-home-water.sh`.
- **Outside this folder:** none. The river's level is read, not edited (`valley.gd`, `places.gd`); the water look is a
  style material (`TLStyle`), never a hand-made one.
- **Gives the others:** `water_runs` for C's ask; an "area" rule so land under water stays editable (water follows no
  later sculpt) but flood is refused in the protected areas and the river band ("spills").

## P: paths and the plant scatter

- **Owns:** `paths_layer.gd` (fill the stub: path and unpath, ids, the ribbon draped on the ground, `offers`,
  `preview_node`, save `paths`), new files `path_*.gd`, `tools/path_tool.gd` (replace the stub; it writes the grading as
  a `land` op in the same batch), `plant_scatter.gd` (fill the stub), `PATCHES-P.md`,
  `engine/tools/selftest.d/762-home-paths.sh`.
- **Outside this folder:** none (the ribbon's look comes from L's terrain material; ask L through PATCHES-P.md).
- **Gives the others:** `scatter(...)` for L's plant tool.

## L: the land look and plants

- **Owns:** `land_layer.gd` and every `land_*.gd` (`land_mesh.gd`, `land_brush.gd`, `land_protect.gd`,
  `land_scatter.gd`, ...: the cosine brush, slope rock by steepness, blurred paint weights, the density channel in the
  land mesh's UV), `tools/sculpt_tool.gd`, `tools/paint_tool.gd`, `plants_layer.gd` (fill the stub: plant, `offers`,
  `preview_node`, save `plants`), new files `plant_*.gd` except `plant_scatter.gd`, `tools/plant_tool.gd` (replace the
  stub), `land_case.gd`, `LAND.md`, `PATCHES-L.md`, `engine/tools/selftest.d/755-home-land.sh`, `763-home-plants.sh`,
  `764-home-look.sh`.
- **Outside this folder:** `engine/style/dio/toon_cel.gdshader`, only its growth-density channel (no other change; the
  style's own cases stay green); `engine/kernel/world/home/ground.gd` and `home/hook.gd` only as the land mesh needs.
- **Gives the others:** the land layer's `preview_node` (sculpt and paint in an LLM answer's ghost).

## C: the LLM bar's M5 part, locks in the ask, the stamp name

- **Owns:** every `command_*.gd` (the ask: `water` merged with the river's water, tables of what is unlocked only, the
  M5 ops in the prompt facts; the answer's counts), `tools/command_tool.gd` (the ghost per layer, the lock backstop at
  accept), `tools/stamp_tool.gd` (the stamp name through the bar's LineEdit), `pieces_layer.gd` only for its
  `preview_node` (one method), new files `command_*.gd` and `piece_*.gd`, `command_case.gd` (757), `pieces_case.gd` and
  `stamp_case.gd` (756, as the stamp name needs), `COMMAND.md`,
  `PIECES.md`, `PATCHES-C.md`, `engine/tools/selftest.d/756-home-pieces.sh`, `757-home-command.sh`,
  `759-home-command-ask.sh`,
  `765-home-command-m5.sh`.
- **Outside this folder:** `foreman/src/world_edit*.ts` and their tests, `foreman/prompts/world_edit*` (the prompt's
  water rules and the bridge example; the seam added only the wire names and shape checks), the `world-edit` line of
  `foreman/src/cli.ts`, `devx/lib/commands/ledger.mjs` for the calls log. Only C edits foreman.
- **Reads, never writes:** `unlocks.gd` / `trophies.gd` (what is granted), `read_region`, `preview`, `preview_nodes`,
  `expand_input`, `apply`.

## K: walker steps, the results card, the kernel API

- **Owns:** `engine/kernel/world/terrain/world_body.gd` (the visitor-only flag that lets the visitor's walker climb a
  riser) and the walker files it needs in `engine/kernel/world/terrain/` (`walker_space.gd`, `world_space.gd`: list
  each edit in `PATCHES-K.md`), `engine/kernel/dungeon/**` (the results card's data at `close`: plays, wins, best,
  newly unlocked; `trophies.gd` and `unlocks.gd` are read, not edited), `engine/boot/hub.gd` and `engine/boot/menu.gd`
  as the results card needs, `engine/kernel/API.md`, `engine/kernel/runner/manifest.gd` `KERNEL_API` (1.30 -> 1.31),
  `docs/generated/API-V1.json`, `PATCHES-K.md`, `engine/tools/selftest.d/766-walker-steps.sh`, `767-results-card.sh`.
- **May also edit, only for stairs colliding as drawn once the walker steps risers** (contracts/BUILD.md "The block
  grid"): `block_mesh.gd`'s stair collider. 752's walker rows (`build_case.gd`, at its 600-line cap) change only through
  `PATCHES-K.md`, with the new figures measured.
- **Must not touch:** any layer, tool or command file; 260-k8 and the `world` gate stay green (a world game plays as
  it does alone).

## Landing

One lane at a time onto the seam's branch: its own block green, 752-759 green, `tl check --tier fast`. A lane that
finds the seam wrong (a missing hook, a wrong reason) stops and reports it; it does not patch a frozen file.
