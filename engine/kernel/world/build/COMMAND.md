# The LLM command bar (M4)

In build mode a person presses **Enter**, types a sentence ("a stone bridge across here", "make this house taller
with a slate roof") and presses Enter again. The ask goes to the Foreman (`foreman world-edit`), which asks the model
(Opus, `engine/ui/flags/real.json` "world_edit"). Building never waits for it: a holo pillar with "thinking... 0:23"
stands at the spot, and the person keeps building with the other tools. The answer comes back as a ghost at that spot
with a one-line note and its counts ("212 blocks, 6 refused: game lot"). **Enter** keeps it as ONE batch by
`author: "llm"` (one Ctrl+Z takes all of it back), **Esc** or **Backspace** reverts it. Without a connected model the
bar says why and does nothing. The wire formats are `contracts/BUILD.md` "The LLM command bar"; the tool interface is
`BUILD.md` "Tools".

| File | What it is |
|---|---|
| `tools/command_tool.gd` | the tool: Enter, the asks pending (at most 2), the answer as a ghost, keep and revert, its hotbar lines |
| `command_bar.gd` | the text field above the hotbar (a LineEdit: while it has the keyboard, TLInput `keys_taken` gives the visitor no key and build mode reads none) |
| `command_ask.gd` | writes the ask, `tl.world-edit-ask/1` (below) |
| `command_answer.gd` | reads the answer, `tl.world-edit/1`; counts refusals by reason |
| `command_link.gd` | the Foreman door (`ui/foreman_door.gd` `world_edit`), why it cannot ask, the probe once per session |
| `command_calls.gd` | `<home>/llm_calls.jsonl` and the per-day cap (`<home>/settings.json`) |
| `command_marker.gd` | the pillar and its "thinking..." text; later the note over the ghost |
| `command_devices.gd` | the test hook `TL_COMMAND_DEVICES` (an unattended exe run with captures) |
| `command_case.gd` | headless cases: `engine/tools/selftest.d/757-home-command.sh` (the flow) and `759-home-command-ask.sh` (the ask, read by the exe's case and by the Foreman's own reader) |
| `foreman/src/world_edit.ts`, `world_edit_check.ts`, `foreman/prompts/world_edit.md`, `world_edit.schema.json` | `foreman world-edit --in ASK --out ANSWER`: the prompt, the checks fed back (2 attempts), the expansion of boxes, the atomic answer file |

## Keys

| Key | |
|---|---|
| Enter | opens the bar at the cursor (it remembers the cell and the facing then), or says why it cannot: no Foreman, the model not connected, the day's cap reached, 2 asks already waiting, no cursor on the ground |
| (in the bar) Enter, Esc | send; close without asking |
| (a ghost shown) Enter | keep it: one batch, author llm, the counts recomputed now (the world may have changed while the model thought) |
| (a ghost shown) Esc, Backspace | revert: nothing is applied |
| W A S D, Space, C, F | walk round a ghost as usual. While the bar has the keyboard they do nothing (TLInput `keys_taken`), and B, T, E do nothing either |

A key that closed the bar or decided a ghost is held by the tool until it is let go, so build mode does not read it as
a new press (Enter would open the bar again, Esc would leave build mode). An answer that arrives while the person
uses another tool switches to the command tool and shows its ghost; one that arrives outside build mode waits until
build mode is on again.

## The ask: `tl.world-edit-ask/1`

`<home>/llm/<call id>.ask.json`, removed with its answer once the call is decided (`TL_COMMAND_KEEP=1` keeps both).

| Key | |
|---|---|
| `schema`, `sentence` | the person's words (one line, at most 400 characters) |
| `cursor` | [x, y, z]: the place cell the cursor named when Enter was pressed ("here") |
| `facing` | 0-3, `home_build.gd` `rot_facing` of the camera's forward: 0 the person looks north (-z), 1 west, 2 south, 3 east |
| `region` | `{min, max}`: 32 x 24 x 32 cells, x and z centred on the cursor, y from 4 below it. Every op must stay inside (the Foreman refuses the rest) |
| `ops` | the op kinds the Home applies now: every layer's `offers()` (place, remove; land, paint; put, lift; M5: pour, drain once the water layer is built, path, unpath once paths are, plant once plants are; a stub offers none) |
| `blocks` | `[[x, y, z, shape, mat, rot, flip 0/1], ...]` in the region (`read_region`) |
| `ground` | `{min: [x, z], rows}`: `rows[z - min z][x - min x]` is the y of the cell a block takes standing on the ground there (the land layer's `height_at` once M2 gives it, else `home/hook.gd` `ground_y`) |
| `refused` | `[{reason, runs: [[z, x0, x1], ...]}]`: the columns protection refuses at their ground cell ("game lot", "authored structure (...)", "tree"), asked with the visitor out of the way. Absent: none |
| `land_refused` | round 4 (lane A6, Q-A7): `[{reason, runs: [[z, x0, x1], ...]}]`, the columns where the ground ops (land, paint, path, plant, flood, pour) are refused, apart from the blocks' `refused`: each column answers for its 3 m ground cell (protect.gd `refusal_area` of the cell for a paint: the village and 72 m round it, game sites, lanes, the river band, authored structures, columns holding blocks), the visitor out of the way. A land vertex under a ploughed field is refused too and not marked. Absent: none (never `[]`). The prompt: one line under the refused columns, "Paths, land, paint, plants and water are refused on these columns (blocks may still go there): ..." as boxes; the Foreman feeds back a ground op that meets one (`world_edit_land.ts`) |
| `shapes`, `mats` | `[{id, name, note}]`: the 8 shapes and the block materials play has unlocked (1-9 always; M5: 11 brick and 12 plaster once granted, unlocks.gd), with what each is for |
| `paints`, `parts` | the paint names and the kit parts play has unlocked (`{kind, note}`; M5: locked kinds are left out), only when paint and put are in `ops` |
| `water` | M5: `[{y, runs: [[z, x0, x1], ...]}]`, the measured water: the valley's river and ponds (home/valley.gd `water`, where it stands above the ground) merged with the water layer's `water_runs` (the layer's wins in a column); `y` is the cell holding the surface (`floor(level)`). In a water column `ground` is the bed. Absent: none |
| `layers` | the other layers' `read_region` keys (M2's ground, M3's `pieces`), as they read them. Absent: none |
| `caps` | `{ops: 4000, blocks_left}` |

## The answer and the model's ops

`foreman world-edit` writes `tl.world-edit/1` (contract) atomically: `{schema, ops, note, model, durationMs,
tokensIn?, tokensOut?}` or `{schema, error}`. The model may also write two **boxes**, which the Foreman replays on the
ask's blocks and expands, so the answer file holds only the contract's ops:

- `{"op":"fill","from":[x,y,z],"to":[x,y,z],"shape","mat","rot","flip"?,"walls"?}`: every cell of the box gets that
  block; a cell holding another block is replaced (a remove naming what it removes, then a place), one already holding
  it is kept. `"walls": true` fills only the box's outer ring on every layer.
- `{"op":"clear","from","to"}`: a remove for every block in the box.

The Foreman refuses (and feeds back to the model, 2 attempts in all) ops outside the region, unknown keys and ids, glass
as a block's material, flip on a shape that has none, a place into a held cell, a remove of an empty one, op kinds the
ask does not offer, more than 4,000 expanded ops, more blocks than `blocks_left`, and an answer that changes nothing.
Columns the Home refuses are not refused there: the exe counts them ("6 refused: game lot").

Why boxes: an answer of single ops is about 55 characters a block, so a 600-block tower is about 11,000 output tokens
from Opus; a fill of a wall is one op. The prompt carries the measured facts only (ground, blocks, refused columns,
tables) and 2 worked examples (a stair onto a platform, a 5 x 5 hut with trim, door, windows and an overhanging gable
roof) plus the "taller" adjust as clear and fill.

## The calls log and the cap

`<home>/llm_calls.jsonl` (the exe: `%APPDATA%\ThirdLife\home`; under the editor binary
`%APPDATA%\Godot\app_userdata\Third Life Engine\home`; `TL_HOME_BUILD_DIR` moves both). One line per event of a call;
the LAST line of an id is the call: `{id, ts (UTC), day (local date), sentence, accepted: "pending" | true | false,
model?, tokensIn?, tokensOut?, durationMs?, ops?, applied?, refused?, error?}`. A call counts against the cap when it
is asked. The cap is `{"llm_calls_per_day": n}` in `<home>/settings.json` (default 30; an unknown key leaves the
default and the bar names the problem). The calendar day is the one place a day is used (the contract's billing
exception). `tl ledger` lists the calls after the jobs (`--home <dir>` names the folder; `--json` adds `home` and
`calls`). A replay never calls the model: the kept ops are in the journal like any other batch.

## The Foreman link

`TL_COMMAND_FLAGS=<flags json>` (else `res://ui/flags/real.json`): its `world_edit` entry is the command line's
settings. The bar's "not connected" reason is the door's `check()` problem (no `foreman/dist/cli.js` above the exe, no
node, no settings), else the result of `foreman probe --adapter <the adapter> --json`, run once per session on a thread
(an ask may be sent while it runs). The door's log is `<home>/llm/_ui_logs/`.

## The test hook

`TL_COMMAND_DEVICES="<when>:<kind>[:<arg>];..."`, `when` a build-mode frame or `ask<n>+<f>`, `ghost<n>+<f>`,
`kept<n>+<f>`; kinds `say:<sentence>`, `accept`, `revert`, `capture:<abs .jpg|.png>`, `state`, `quit`
(`command_devices.gd`). With `TL_BUILD_DEVICES` (B, the pointer) and `TL_EXE_START` it runs an ask in the exe and takes
the captures.

## Figures (26 Nov 2026, the exported exe, a window, claude-cli with `--model opus` = claude-opus-5-5)

| Ask | Model time | Tokens in / out | Ops (all places) | Refused | Frames from ask to ghost |
|---|---|---|---|---|---|
| "a small stone bridge with railings across the stream here" (cursor on the stream bed at -250, -30) | 39.0 s | 10,085 / 3,871 | 134 | 0 | 2,430 |
| "add a roof over the bridge" (the adjust: the 134 blocks were in its read) | 39.3 s | 13,483 / 4,047 | 132 | 0 | 2,415 |

One attempt each (no problem fed back). The bridge: x -257..-244 over the 12 m stream, 5 wide, a deck of dark stone
at y 0, steps from both banks, fence railings and four pale corner piers. The roof: 16 dark-wood posts, a slate gable
roof with white gable ends, standing on the bridge's deck. Captures: `.spark/Spark/captures/world-sandbox/m4-*.jpg`.
The ask file is 4.5 to 7.6 KB, the prompt about 9 KB.

## Known limits

- An ask still pending when the person leaves the Home is lost to this session: its line stays "pending" and the
  Foreman's answer file is left in `<home>/llm/`.
- The pending pillar stands on the cursor cell: on a stream bed it is under the water and only its "thinking..." text
  shows (`m4-ask.jpg`). M5: the ask carries the water (`water`), so the model no longer infers a stream from the dip.
- The refused columns are read at the ground cell only (a lot is a column; a house wall above the ground cell is
  found when the answer is kept).
- 754 `seam.tools` holds the command tool to the stub's line "Command: coming in M4"; the real tool cannot meet it
  (`PATCHES-M4.md` P1).

## M5 (lane C, 27 Nov 2026): water, the new ops, locks, the ghost per layer, the stamp name

- **Water.** The ask's `water` (above) and the prompt's "Water (measured)" section (`world_edit.ts` `waterFacts`: per
  surface y, the columns as boxes), with the rule: a bridge's deck stands at least 1 cell above the higher bank's ground
  y and 1 above the water's surface y and rests a cell on each bank; its steps start on a dry column at that column's
  own ground y and climb 1 per cell. A worked bridge (stream, deck, piers, steps on supports, railings) is in the prompt.
- **The new ops.** `pour`, `drain`, `path`, `unpath` and `plant` are taught in the prompt's more-ops section only when
  `ops` offers them, with a pond (land, then pour) and a path as worked examples. The Foreman checks them
  (`world_edit_check.ts`): in the region, the shapes of their entries, path paints (dirt, sand, stone, rock_warm,
  grass_dry, plank), plant growths (meadow, flowers, tall_grass, valley), 2-64 points 100-4,800 cm apart, width 150-800
  cm, paint names from the ask's `paints`. Their rules are the layers' (a stub refuses "not built yet: water").
- **Locks.** The ask lists only what play has unlocked (`Ask.make(..., Unlocks.new(<home>))`). The Foreman refuses a
  place whose `mat` is not in the ask's `mats` and a put whose `part` is not in its `parts` ("not unlocked yet"), fed
  back like any problem. The exe backstop: when a ghost is shown, and again at accept, `command_answer.gd`
  `split_locked` takes out every place naming a locked material or shape and every put naming a locked part; they are
  counted refused "locked: <condition>" and the rest is applied. Lift and remove are never locked; the layers never ask.
- **The ghost per layer.** Blocks are drawn by the tool's `preview`; every other layer's part by its own
  `preview_node` under `layer_ghosts` (`home_build.gd` `preview_nodes`). The pieces layer's (`pieces_layer.gd`
  `preview_node`) draws the pieces a dry run would put in holo and those it would lift in red (`piece_ghost.gd`, the
  holo fill UV (0.5, 2)). Land, water, paths and plants draw theirs when their lanes write `preview_node`.
- **The counts** read over every op, then the refusals by reason, most first (at most 3 named): "212 blocks, 5
  removed, 3 parts, land 40 points, paint 12 cells, pond 120 cells, 40 m path, plants 8 cells; 6 refused: game lot,
  locked: win Parkour once" (`command_answer.gd` `counts`; a remove whose cell a later place fills is not "removed").
- **The stamp name.** The stamps tool's G opens a `command_bar.gd` of its own pre-filled with the next free "Stamp N"
  (selected; at most 60 characters); Enter saves under that name, Esc cancels; the key that closed it is held as the
  command tool holds its keys (PIECES.md).
- **The case:** `command_m5_case.gd`, `engine/tools/selftest.d/765-home-command-m5.sh` (`HOME command-m5 ok`).

Figures (27 Nov 2026, the exported exe, a window, claude-cli `--model opus` = claude-opus-5-5, one attempt):

| Ask | Model time | Tokens in / out | Ops | Refused | Frames from ask to ghost |
|---|---|---|---|---|---|
| "a small stone bridge with railings across the stream here" (cursor on the bed at -254, -4, -30; water y -3, level -2.21 m) | 26.4 s | 15,029 / 2,608 | 136 (128 blocks) | 0 | 1,665 |

The bridge: a dark stone deck at y -2 (one above the water's cell -3 and the banks' -3 at its ends), x -258..-245 over
the 12 m stream, 5 wide, four rows of pale stone piers on the bed, three-wide stairs from both banks starting on dry
columns at their own ground y, wooden fence railings with corner posts. No white block. The ask was 11.8 KB (the
water key two levels, 384 columns); the headless ask with the water read takes about 50-65 ms of wall clock (765,
measured, not decided on). Captures: lane C's scratchpad `c-bridge-ghost.jpg`, `c-bridge.jpg`, `c-bridge-side-e.png`,
`c-bridge-side-w.png`.

## M6 (lane C, 27 Nov 2026): zones and rules, the space check

- **The ask** carries the rules layer's `ask_part(lo, hi)` at the top level (`command_ask.gd` RULES_KEYS): `zones` (the
  zones meeting the region), `rules` (the rules naming them, and those naming none), each omitted when none, and
  `rules_room` `{zones_left, rules_left, counters}` (always, once the rules layer offers `zone`). `home_build.gd`
  `read_region` merges the layer's `zones` and `rules` into its read; the ask takes them out of `layers`.
- **The prompt** (`foreman/prompts/world_edit_rules.md`, inserted by `world_edit.ts` `rulesFacts` only when the ask
  offers `zone`): the measured zones, rules and room, the four ops with every trigger, condition and effect, the ids
  (the answer's own; the exe renumbers), the space rules (a pad's or flag's bottom row is the feet cell over a floor,
  a coin is 1 x 2 x 1 on such a cell, every block rests on something, a run's way is walkable: half-block steps, jumps
  of 1 block up and 3 empty cells across) and two worked examples: a door that opens on E, a short run (start pad, a
  stair onto a ledge with a coin and a checkpoint, a 2-cell gap, a pillar with the flag). About 3.85 KB on a Home with
  no zones (selftest 785 measures it on a real ask and holds it under 4 KB).
- **The Foreman's checks** (`world_edit_rules.ts`, fed back like every problem, 2 attempts): the contract's every shape
  and limit (box low corner first, at most 64 a side, in the region and off the refused columns; look, name, ids
  positive and not made twice; triggers, conditions, effects and their ranges; 1-8 effects, at most 8 conditions; at
  most 8 counters in the Home with the room's; the room's zones and rules left), references resolved as the exe's
  `renumber` resolves them (an id some zone op of the answer makes names that zone, which must come before the rule;
  any other names a listed zone not removed earlier), `unzone` / `unrule` naming a listed zone or rule whole, and an
  `unzone` of a zone a remaining rule names refused (unrule it first, earlier in the answer).
- **The note** counts zones and rules and names the runs the answer starts: "17 blocks, 5 zones, 5 rules: Hop"
  (`command_answer.gd` `counts`; removals "2 zones removed", "1 rule removed").
- **The space check before accept** (`command_space.gd`; it never refuses): over the dry run's scratch copies it finds
  added blocks joined to nothing that was there and to no ground ("2 blocks float"), a pad or flag whose floor-centre
  cell has no floor ("the pad Start has no floor"), a coin whose centre is inside a cube or window or the lower half of
  a slab, stair, ramp or roof ("a coin is inside a block"), and for every run an added rule starts whether a feet cell
  of a finish zone is reached from one of the start zone ("finish not reachable"; the answer's coins out of that reach
  are counted, "1 coin out of reach"). Feet cells: an empty cell over a cube or window, a slab / stair / ramp / roof
  cell, or the ground's cell of an empty column, with 1.8 m of headroom. Moves: a walk or step of at most 0.55 m to a
  neighbouring column; a jump of at most 1.2 m up and 4 m across (cell centre to cell centre) or a drop within 4 m,
  nothing solid in the columns between nor over the two feet cells up to head height; a launch zone's longer jump
  (world_body.gd gravity 24 m/s2, at most 16 m); a teleport. A zone some rule opens is passable. The searched box is
  the answer's blocks and zones with 6 cells round them in x and z (at most 96 a side, clipped and said). The problem
  cells get red holo boxes (`marks_node`, at most 64) beside the ghost, and the line goes in the note after "check:"
  (the hotbar line and the label over the ghost). Measured in 785: 16-51 ms of wall clock for 224-350 feet cells.
- **The replay** (`command_replay.gd`): a Home's runs walked headless over the check's walk (start, each coin it can
  reach without crossing a finish, the nearest first, then the finish), the seam's `rules_run.gd` stepped 8 frames per
  feet cell with a recording facade: says whether the run starts, which coins are taken and whether the finish is
  recorded, when lane P's play is not in the tree. `command_m6_case.gd -- replay <home dir>` runs it on a saved Home.
- **The case:** `command_m6_case.gd`, `engine/tools/selftest.d/785-home-command-m6.sh` (`HOME command-m6 ok`, 6 cases).

Figures (27 Nov 2026, the editor binary in a window, `res://boot/boot.tscn`, claude-cli `--model opus` =
claude-opus-5-5, a fresh Home; cursor on the grass at (-69, 2, 21), 25 m north-west of the spawn, looking north):

| Ask | Model time | Tokens in / out | Ops | Refused | Space check | Frames from ask to ghost |
|---|---|---|---|---|---|---|
| "build a small stone tower with stairs and make it a parkour run: a start pad at the bottom, three coins on the way up and a finish flag on top" | 106.2 s | 41,791 / 11,554 | 548 (418 blocks, 9 zones, 9 rules) | 2: the "Fall" zone (game lot, protect.gd `refusal_box`) and the respawn rule naming it | nothing found; 483 feet cells in 48.9 ms | 6,435 |

The answer: a 9 x 9 tower of light and dark stone (x -71..-63, z 11..19, y 2..11) with windows and crenellations, dark
stone stairs and landings winding up its east, north and west sides; the start pad on the grass at its south-east, three
coins on the way up (y 5, 8, 10), three checkpoint landings, the finish flag on the roof (y 11), the run "Tower Climb".
The prompt was 26.0 KB (3.85 KB of it the zones-and-rules section). Tokens in are about twice the M5 bridge's single
attempt for a similar prompt, so the Foreman probably fed one problem back (it logs no attempt count). The kept Home
replayed headless (`command_m6_case.gd -- replay`): the walk reaches all 3 coins and the finish with hops of at most
2 m across and 1.2 m up (13 feet cells, the run recorded in 96 frames of scripted walk, both says shown); walking
alone (steps of 0.55 m, no jump) reaches no coin and no finish: it is a jumping course. Captures:
`docs/shifts/2026-11-27-day/lanes/C6-llm/c6-ghost.jpg`, `c6-built.jpg`.

## Round 2 (lane C, 27 Nov 2026): fix it, findings, the bridge's clearance, the fall pattern

- **Fix it (R).** When the space check finds anything, the hotbar note ends "R: fix it", the hint names "R fix it (asks
  the model again)" and the label over the ghost adds "R: fix it". R (not E, not a host key: blocks, pieces and stamps
  use R to rotate, but while a ghost is shown the command tool has the keyboard and the host reads none) sends ONE
  follow-up ask: the same sentence at the same spot, measured again, with `fix: {ops: the answer's ops as shown,
  findings: [the check's findings]}` (`foreman world-edit` reads it, `world_edit.ts` `fixFacts` puts the earlier ops
  and the findings in the prompt and asks for the whole corrected answer). The ghost stays while the fix is asked
  ("fixing... 0:12"; a second R sends nothing more); the corrected answer replaces it (the earlier call is logged
  reverted) and, like every ghost, is kept only by Enter. A fix is a call: the day's cap, `llm_calls.jsonl` with the
  sentence "fix: <sentence>", `tl ledger`. Without findings R does nothing. Test hook kinds `fix` and `settle` (Enter
  on the last ghost once no ask is pending). Case: `command_fix_case.gd -- fix`, selftest 786 (`HOME command-fix ok`).
- **Findings** (`command_space.gd` `findings`): one line per problem with its cells, the words the fix ask carries:
  "1 block floats (joined to no block and no ground): (706, 38, -56)"; "the pad Sky (zone 1, box [...]) has no floor:
  ... at (x, y, z)"; "the coin (zone 2, box [...]) has its token inside a solid block"; "finish of Hop not reachable
  from its start; the nearest the walk gets: a gap too wide: from feet cell (..) to the finish's (..) is 6.0 m across
  (5 empty cells); a climb too high: from feet cell (..) to the finish's (..) is 2.0 m up. A step climbs 0.55 m ...";
  "the coin ... is out of reach of the walk from the start". Case: `command_fix_case.gd -- findings`, selftest 787.
- **The bridge rule** (from lane LP's patch): the deck stands at least 1 cell above the higher bank's ground y AND at
  least 2 above the water's surface y (the water's top is somewhere inside its surface cell, so the deck's underside
  clears it by 1 m or more); the steps start on a dry column (in none of the water's runs) at its own ground y, and
  there are (deck y + 1) - (that ground y) of them, the first on the ground, the last meeting the deck.
- **The fall pattern**: a zone of look none under EACH jump gap, on the floor the walker lands on if he misses, just
  the gap's cells (enter, if running, respawn at the last checkpoint), never one zone round the whole course (the
  real tower's 11 x 9 "Fall" zone was refused next to a lot and would have caught the start and the stairs). The
  worked course has one under its 2-cell gap. The zones-and-rules section is 4.26 KB (4.40 KB with one listed zone).

## Round 3 (lane A6, 27 Nov 2026): assemblies, the body's jump

- **Assemblies** (contracts/BUILD.md "Assemblies (M6, round 3)"; `assembly.gd`, `assembly_kinds.gd`): the ask's `ops`
  offers `assemble` (the blocks layer's `offers()`), the prompt teaches it (`world_edit.ts` `ASSEMBLE_TEXT`, 2,040 bytes
  with a worked tower and the water example's bridge as one op: "PREFER ASSEMBLIES for walls, towers, houses, stairs, bridges and platforms; place or fill
  single blocks only for details"), the Foreman checks its shape in the exe's words plus the ask's material table and
  region (`world_edit_assemble.ts`: the core footprint, turned, inside the region) and feeds a bad one back; the answer
  keeps the assemble as written, and the exe expands it when it shows the ghost (`home_build.gd` `expand_input` ->
  `blocks_layer.gd` `expand_input` -> `assembly.gd` `expand`), so the space check, the ghost and the counts see the
  blocks. Conventions: `at` is the low corner, its y the ground y (the floor row sits in that cell); `rot` turns about
  the centre of the `at` cell (rot 0: the front faces north and the shape covers x at..at+w-1, z at..at+d-1). The
  hand's Shapes tool (`tools/assembly_tool.gd`) writes the same op.
- **The jump the body makes** (Director, from lane P's headless body over lane C's tower: about 1.0 m up with about
  2.5 m across at a run; 3 m across + 1 m up in one jump failed at a walk): the estimate's separate limits (1.2 m up,
  4 m across) became one combined limit (`command_space.gd` `Grid.reach_up`): up to 1.0 m (`JUMP_UP`) within 2.5 m
  (`JUMP_ACROSS`, cell centre to cell centre), 1.2 m (`MANTLE_UP`) only from the next cell, a flat gap (at most 0.25 m
  up, `GAP_UP`) or any drop within 3 m (`GAP_ACROSS`, 2 empty cells). Walks and steps (0.55 m) and launches and
  teleports are as before (a launch adds to 1.2 m up and 3 m across). `Grid.jump_up` / `jump_across` still cap it for a
  stricter walker. The findings end with `JUMPS`, these limits in words; the zones-and-rules prompt's "Space" line says
  them, and its worked run's gap is 1 cell (it was the 3 m + 1 m hop). 785 `reach` and 787 `gap`: the reachable
  fixture's gap is 1 cell (was 2: 3 m + 1 m up, now rightly not reachable).
- **The real calls** (27 Nov, the editor binary in a window, claude-cli `--model opus` = claude-opus-5-5, fresh Homes,
  the same cursors as lane C; scripts `.tl/a6/tower-call.sh`, `bridge-call.sh`, one call each, no fix call):

| Ask | Model time | Tokens in / out | Ops | Refused | Space check | assemble used |
|---|---|---|---|---|---|---|
| the tower sentence (lane C: 106.2 s, 41.8k / 11.6k; 92.5 s, 41.3k / 10.1k) | 53.7 s | 18,285 / 5,510 | 226 (192 blocks, 5 zones, 5 rules) | 0 | 1 coin out of reach | no |
| "a small stone bridge with railings across the stream here" (lane C: 32.2 s, 18.4k / 3.3k, 154 blocks) | 29.8 s | 19,456 / 3,015 | 160 blocks | 0 | nothing | no |

  Neither answer used `assemble`: the model hand-placed both (fills), though the prompt offered it, said "PREFER
  ASSEMBLIES" and (for the bridge) gave the water example's bridge as one op. Both were single attempts by their tokens
  (lane C's towers were about two). The tower: a 5 x 5 stone tower 8 high with windows and a dark top, a dark-stone
  stair on solid fill up its west side to the top, 3 coins, the flag on top; the replay (`command_m6_case.gd --
  replay`) finishes it with every hop at most 2 m (11 feet cells, 2 of 3 coins: one coin floats 1 m over its stair).
  The replay's tour was fixed this round: a coin out of reach no longer fences the finish off (it walked round the
  finish while any coin was left). Captures: `docs/shifts/2026-11-27-day/lanes/A6-assemblies/a6-tower.jpg`,
  `a6-bridge.jpg`, and the Shapes tool `a6-shapes-tool.jpg`, `a6-shapes-built.jpg`.
- **Round 2 (the Director's Q-A1 (a))**: `assemble` is the FIRST op under "# Operations" (`{{assemble}}`, the rule "BUILD
  WALLS, TOWERS, HOUSES, STAIRS, BRIDGES AND PLATFORMS WITH ASSEMBLE ... place or fill single blocks only for
  details"), the stair, hut and bridge worked examples are assembles (plus a detail block), and the assemble section's
  example is a run up an assembled tower (its stair cells named, coins on them, the flag on top; checked walkable
  headless). The rendered prompt on the round-1 tower ask: 26,058 -> 24,429 bytes (-1,629). ONE real call, the tower
  sentence, same spot: **it used assemble** (1 tower + 5 zones + 5 rules = 11 ops, 316 blocks), 31.6 s, 37,004 in /
  3,186 out (the tokens in suggest two attempts: one problem fed back, not logged), 0 refused, check clean; the replay
  takes 3/3 coins and finishes, every hop one cell. Against round 1 (53.7 s, 18.3k / 5.5k, 192 hand blocks) and lane
  C (92-106 s, 41k / 10-12k): fewer output tokens (3.2k against 5.5-11.6k) and the fastest of the four, more input.
  (c), the one-sentence top rule, was not needed. Capture `a6-tower-2.jpg` (+ ghost).
- **The body over assemblies** (lane P's `play_llm_probe.gd`; Homes made by `assembly_probe_home.gd`, a dev tool: the
  assemble expanded as an answer is, a start pad and a flag): a 3 x 14 bridge over the stream at (-258..-245, -1,
  -27..-29): onto the deck by the west steps at a walk 316 frames, at a run 646; off by the east steps 184 / 180; 0
  stuck. A 7 x 10 tower with outside stairs on flat ground (29, 1, 34): to the top at a walk in 441 frames, 0 stuck; at
  a run (9 m/s autopilot) it finished but fell off twice where the stair turns a corner (the outside stairs have no
  railing). The model's assembled tower: walk 694 frames, finished, 3 coins, 1 stuck (the estimate's path joined the
  stair run from its side, not its foot).
- **Round 3**: outside stairs have a stringer of trim on their outer side at each stair's level and a slab-high
  parapet at each landing (the Director's Q-A5), each under a fence (without it the stringer's tops were a second stair
  of 1 m steps that the estimate and the body took); nothing reaches the ground, so the door's front stays open. The
  estimate joins a stair only along its rise (its foot, or its top from a landing) or onto a run's first step from the
  side as a walk (`Grid.stair_entry`, Q-A6). The body probe at a run round an assembled tower's corners: 0 stuck, no
  fall (walk 452 frames, run 349), the path through the door step onto the first stair. Two more real calls (one each,
  a window): "a tall stone watchtower, 5 wide, stairs inside, a lookout on top with a flag": 11.4 s, 17,248 / 809, 2 ops
  (a tower 5 x 14, stairs inside, windows, crenels + a Lookout flag on its top) -> 268 blocks, clean; "a little wooden
  house with a door, two windows and a stone path to it": 15.0 s, 17,236 / 915, 2 ops (a house 7 x 3 x 5 of planks,
  roof trim + a stone path) -> 115 blocks, the path refused "village" (land_protect.gd's 72 m round the village).
  Neither copied the example's 7 x 10. The house's front had no window (the every-3 rule put its only front window in
  the door's place): the front's windows now flank the door.
- **Round 4**: a house's `opts.windows` (contracts/BUILD.md, Q-A8): how many windows on its front, beside the door,
  0..w-3 (`assembly.gd` `house_windows_max`), nearest the door first (`assembly_kinds.gd` `front_windows`: the cells 2,
  5, 8 ... from the door, then 1, 3, 4, ...); absent: round 3's default (a 7-wide house: 2, either side). The
  Foreman checks it in the exe's words; the Shapes tool's ] walks house presets (default, 4, 0). And the ask's
  `land_refused` (above): at the house call's spot (-69, 2, 21) the village's band covers x -84..-64, z 15..36 for
  ground ops, which is why that answer's path was refused; it adds 314 bytes to that prompt.
