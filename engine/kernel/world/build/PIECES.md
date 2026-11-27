# Home pieces, stamps and unlocks (M3)

Spark `world-sandbox`, milestone 3 (26 Nov 2026). The wire formats are `contracts/BUILD.md` "Milestones 2-4"
(`put`, `lift`, `tl.build/2` `pieces`, `tl.stamp/1`, `tl.trophies/1`, `tl.unlocks/1`). Selftest blocks 756 (pieces,
stamps) and 758 (unlocks) hold this code to it.

| File | What it is |
|---|---|
| `pieces_layer.gd` | the `pieces` layer: put / lift, footprints, the cell and area rules, `pieces` in tl.build/2, read_region |
| `piece_catalog.gd` | the catalogue v1, knobs and choices, placement, footprint, prototypes (built once per kind + params) |
| `piece_draw.gd` | MultiMeshes per prototype per 16 m section (lit parts too); breakable parts as nodes (cap 48); the lit parts' kit lights as sockets of `home/day_lamps.gd` (the 48 nearest the camera burn when the Home's clock says the lamps are on); bodies |
| `piece_ghost.gd` | prototypes drawn in holo (red when refused) |
| `stamp_file.gd` | tl.stamp/1: from a box, validate, turn, ops, files, export / import as a `.tlitem` of kind `stamp` |
| `unlocks.gd`, `unlocks.json` | the rules and what is locked now, with the condition a person reads |
| `trophies.gd` | `<home>/trophies.json`, written by `kernel/dungeon/dungeon.gd` `close` |
| `tools/piece_tool.gd`, `tools/stamp_tool.gd` | the two build-mode tools |
| `pieces_case.gd`, `stamp_case.gd`, `piece_unlock_case.gd` | the headless cases (756, 758) |
| `engine/kits/part_town.gd` | the geometry of the two new kit parts `bench` and `street_lamp` (internal to TLKitParts) |

## A piece

- **Anchor and turn.** The part's origin stands on the anchor cell's floor centre, turned `rot` quarter turns about +y
  by the blocks' rule (rot 1 turns -z to -x). `fence` and `stones`, which run along +X from their origin, start at the
  cell's -x edge, so two fences 8 cells apart meet at a post. A part's front (+z) faces the viewer at the default rot
  (`rot_facing(camera forward)`, as stairs), R adds quarter turns.
- **Footprint.** The turned bounds of the part's meshes and collision shapes, in whole cells: every cell it reaches into
  by more than 0.1 m on each axis, from the anchor's y up (a thin part on a cell line takes the cell its centre is in).
  At most 32 cells a side (a 40 m fence is refused).
- **Standing.** When the anchor cell holds the ground, the piece is lifted onto the ground's height there (M2's
  `height_at` when the land layer has one, else the Home's rendered ground). The lift is never saved: it follows from
  the cell and the ground, and land under a piece is refused.
- **Seed.** Always written; a put that names none gets one from its cell and part. A part with a `seed` param that the
  op's params do not name is built with the param's default + (seed mod 4): four looks per kind and params, so
  pieces share prototypes and draws.
- **Refusals** (`can_apply`, short and stable): `occupied (<part>)`, `occupied (a block at x, y, z)`, `too large for a
  piece (at most 32 m a side)`, `out of range (y -16..111)`, `game lot`, `authored structure (<tag>)`, `tree`,
  `too close`, `no piece there`, `the cell holds another piece (<key>)`. A block in a footprint: `piece (<part>)` (the
  cell rule); land or paint under one: `piece (<part>)` (the area rule).
- **Locks are the tools' only.** A saved Home, a stamp file and an LLM answer load whatever they hold.

## Keys

Pieces (T to the fourth tool): wheel next / previous part, 1-9 a part of the page, Tab / Shift+Tab page, `[` `]` the
part's knob (fence length 2-16 m, tree height, house width ...), V its choice (fence style, tree species, bench back,
lamp light ...), R turn, LMB put, RMB lift the piece under the cursor (Ctrl or RMB held shows it red).

Stamps (the fifth tool): 0 a new box (LMB a corner, LMB the opposite corner: the block under the cursor or the cell on
the ground; the top is found from what stands there, the wheel moves it), **G** opens the name field (M5: a
`command_bar.gd` above the hotbar, the next free "Stamp N" in it and selected, so typing replaces it; at most 60
characters), **Enter** saves it as `<home>/stamps/<slug>.json` under that name and **Esc** cancels; while the field is
open the tool has the keyboard, and the key that closed it is held by the tool until it is let go (so that Enter never
opens the command bar and Esc never leaves build mode: `stamp_tool.gd` `_latched`, as the command tool's); 1-9 a saved stamp, Tab page, wheel next,
R turn, LMB place (one batch, one undo; a stamp `build.preview` refuses anywhere is not placed at all), X export to
`<home>/stamps/export/<slug>.tlitem`, I import every `.tlitem` dropped into `<home>/stamps/inbox/` (also done when the
tool is picked; a good one leaves the inbox, a bad one stays with its reason in the hotbar). `<home>` is
`%APPDATA%\ThirdLife\home` in the exe.

## Unlocks

`unlocks.json` ships five rules. "*" is every pack together (plays and wins summed, the best of any):

| Rule | When | Grants |
|---|---|---|
| first_play | any dungeon played once | bench |
| three_plays | any dungeon played 3 times | material 12 plaster (the street lamp is open from the start: lane F3, 27 Nov) |
| hockey_win | Ice hockey won once | watch_tower |
| paddle_five | 5 scored in one paddle court game | light_mast, material 11 brick |
| parkour_win | Parkour won once | house |

The player's side is the first of `rules.sides` (hockey's blue, paddle's "player", parkour's runner): no pack declares
one today. `plays` counts every end of a loaded dungeon a person played (`frames` 0); a counted run (`frames` > 0, the
gate's) and a headless run without `TL_HOME_BUILD_DIR` write nothing. New materials: 11 `brick`, 12 `plaster`
(palette keys in every style file); no new shape.

## Figures (26 Nov 2026, this machine, other lanes loading it)

- 700 puts (500 fences, 200 trees) applied in 144 ms (about 0.2 ms a put: footprint cells, protection, one space box
  query); drawn in 176 sections as 220 MultiMeshes holding 700 instances, 0 nodes, 192,780 triangles. In a 1600 x 900
  window over them (pieces_case.gd run without --headless): 128 draw calls a frame, render 0.14 ms CPU and 0.63 ms GPU
  (medians of 90 frames, RTX 4090).
- A walker driven at 4.5 m/s toward a placed cabin stops at frame 143 at its wall; lifted, he walks through.
- 752 bulk with the pieces' cell rule in protection: 34.6 us per block op (M1 measured 18 us on a quieter machine).
- Captures (the exe, `.spark/Spark/captures/world-sandbox/m3-*.jpg`): a street of lamps, a bench, a sign, a fence, a
  pine, a block house and its stamp turned three quarters; the piece tool's hotbar with locked slots and a lamp ghost;
  the stamp tool's ghost of the house.
