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
| `ops` | the op kinds the Home applies now: place, remove; land and paint once M2's layer is built; put and lift once M3's is (a stub answers "not built yet") |
| `blocks` | `[[x, y, z, shape, mat, rot, flip 0/1], ...]` in the region (`read_region`) |
| `ground` | `{min: [x, z], rows}`: `rows[z - min z][x - min x]` is the y of the cell a block takes standing on the ground there (the land layer's `height_at` once M2 gives it, else `home/hook.gd` `ground_y`) |
| `refused` | `[{reason, runs: [[z, x0, x1], ...]}]`: the columns protection refuses at their ground cell ("game lot", "authored structure (...)", "tree"), asked with the visitor out of the way. Absent: none |
| `shapes`, `mats` | `[{id, name, note}]`: the 8 shapes and the 9 block materials, with what each is for |
| `paints`, `parts` | the paint names and the kit parts (`{kind, note}`), only when paint and put are in `ops` |
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
  shows (`m4-ask.jpg`). The ask carries no water level (M5's), so the model infers a stream from the ground's dip.
- The refused columns are read at the ground cell only (a lot is a column; a house wall above the ground cell is
  found when the answer is kept).
- 754 `seam.tools` holds the command tool to the stub's line "Command: coming in M4"; the real tool cannot meet it
  (`PATCHES-M4.md` P1).
