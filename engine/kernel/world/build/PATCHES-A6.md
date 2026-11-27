# PATCHES-A6: lane A6 (M6 round 3, assemblies, 27 Nov 2026) and the files outside its own

## Made under the brief's allowance (each named so the Director can check it)

- `home_build.gd` (frozen; CRLF kept): the one line `INPUT_OPS := {"pour": "water", "assemble": "blocks"}` (brief item 2).
- `seam_lists.gd` (frozen): `INPUT_OPS` the same (757's `Lists.ask_ops()` and seam_v3's `ops_now` check must know the
  op the ask now offers), and `TOOLS` gains `"shapes"` between `plant` and `rules` (brief item 4: a new tool; 754
  `seam.tools` wants `command` last and 775 `rules-tool.draw` wants T from rules to reach command, so it goes there).
- `build_mode.gd` (frozen): `TOOLS` gains `tools/assembly_tool.gd` between plant and rules (brief item 4).
- `blocks_layer.gd` (frozen except a new `expand_input`, brief item 2): the new section `expand_input(op, land_now)` at
  the end, AND two small things it needs, beyond the brief's letter:
  - `offers()` returns `["place", "remove", "assemble"]`: the ask's `ops` is every layer's `offers()` (command_ask.gd
    `ops_now`, and seam_v3 holds `ops_now` equal to the union of the offers), so the ask can offer `assemble` only
    through the layer that expands it, as the water layer offers `pour`.
  - `var home` and one line in `_init` (`home = ctx.get("home")`, the weakref home_build.gd already puts in every
    layer's ctx): the ground an assembly's piers, posts and bridge steps reach down to is the land layer's, and the
    blocks layer kept no way to it; home_build.gd passes the land only when the answer has land ops.
- `command_space.gd` (lane C's; this round A6's by the Director's 13:xx message): the combined jump limit.
- `command_m6_case.gd`, `command_fix_case.gd` (lane C's cases): the reachable fixture's gap moved from 2 cells to 1
  (below, "Expectations moved").

## Proposed, not made (Director's files)

- `BUILD.md` file table, two rows:
  `| assembly.gd, assembly_kinds.gd | M6 round 3: the input op assemble (contracts/BUILD.md "Assemblies"): malformed,
  expand (place ops, deterministic), left_out, turn / unturn, ground_of; the six kinds (wall, tower, house, stair,
  bridge, platform), walkable by construction |`
  `| assembly_case.gd, assembly_tool_case.gd | the headless case of 794 |`
  and in "Tools" the strip order "... plant, shapes, rules, command".
- `contracts/BUILD.md` "The LLM command bar, M6 additions": the space check's jump words "jumps of at most 1.2 m up and
  4 m across" no longer match the estimate (now: 1.0 m up within 2.5 m, 1.2 m only from the next cell, a flat gap or a
  drop within 3 m, from lane P's body measurement). And "Assemblies": the conventions the exe uses that the contract
  leaves open: `at`'s y is the floor row (the ground y), the turn is about the centre of the `at` cell, `h` is unused
  by bridge and platform and `d` by wall, tower and stair, and the least sizes (assembly.gd `size_error`).

## Expectations moved

- 785 `command-m6.reach` and 787 `command-findings.gap`: the course that must be reachable had a 2-cell gap onto a
  pillar 1 m higher: 3 m across AND 1 m up in one jump, exactly the hop lane P's body failed at a walk. With the
  combined limit it is (rightly) not reachable, so the reachable fixture now has a 1-cell gap (2 m across, 1 m up,
  inside the body's 2.5 m / 1.0 m). The 5-cell gap and the 2-block wall are unchanged and still not reachable.
- The Foreman's worked run (prompts/world_edit_rules.md) had the same 3 m + 1 m hop: now a 1-cell gap, its Fall zone on
  that one cell; the "Space" line says the new limits.

## Round 4: the contract wording for the ask's `land_refused` (Q-A7; Director's files, not made)

In contracts/BUILD.md "The LLM command bar (M4)", after the ask's refused columns (or in its M6 additions):

- The ask gains `land_refused`: `[{"reason":"<reason>", "runs":[[z, x0, x1], ...]}, ...]` in the shape of `refused`:
  the 1 m columns of the region where the ground ops (`land`, `paint`, `path`, `plant`, `flood`, `pour`) are refused,
  each with its reason; a column answers for its 3 m ground cell (`floor(x / 3)`, `floor(z / 3)`), asked as a paint of
  that cell with the visitor out of the way. Blocks may still be placed there (that is `refused`). Omitted when there
  are none. A land vertex may also be refused where no column is marked (a ploughed field refuses land only).

(Implemented: engine/kernel/world/build/command_ask.gd `land_refused`; foreman/src/world_edit.ts askSchema
`land_refused` (minItems 1), the prompt line; foreman/src/world_edit_land.ts, the feedback.)
