# PATCHES-M4: changes the command bar needs in files M4 does not own

## P1 (needed to land): 754 `seam.tools` expects the command STUB's line

`seam_case.gd` `tools()` (frozen) requires the fifth tool's info line to be exactly `Command: coming in M4` and the line
after Enter to end with `coming in M4)`. The real command tool says `Enter: say what to build at the cursor` (and, in
that case's bare build mode with no Home folder, the red reason `the Home is not loaded here: nothing can be asked`).
Measured: 754 gives 7 of 8 with only `seam.tools` failing (`BAD T 5: 'Enter: say what to build at the cursor'`); 752
and 753 pass. M2 and M3 will meet the same check for sculpt, paint, pieces and stamps.

Proposed patch (`seam_case.gd`, `tools()`): hold a tool to its stub line only while its script is still a stub, and a
built tool to a non-empty line:

```gdscript
const Stub := preload("res://kernel/world/build/tools/stub_tool.gd")
...
		var t: RefCounted = bm.call("tool")
		var stub: bool = (t.get_script() as GDScript).get_base_script() == Stub
		if (stub and text != want[i]) or (not stub and text.is_empty()) or (hb.get("row") as Control).visible:
...
	var cmd_stub: bool = ((bm.call("tool") as RefCounted).get_script() as GDScript).get_base_script() == Stub
	if wrapped != "blocks" or back != "command" or cmd != "command" or (cmd_stub and not line.ends_with("coming in M4)")) or line.is_empty() ...
```

(`row` stays hidden for the command tool: it shows slots only while asks wait.) Measured: this patch applied to a copy
of `seam_case.gd` (run as its own script, the frozen file untouched) prints `HOME seam.tools ok` and `HOME seam ok`
with the M4 tool in place, and it holds the stubs of M2 and M3 to their lines as before.

## P2 (no change made): `kernel/runner/visit.gd`

The brief gave M4 a few lines in `visit.gd` so typing does not walk the visitor. None are needed: the visitor's input is
a `TLInput` with `accept_devices`, and `TLInput._sample` already reads no key while a LineEdit or TextEdit has the GUI
focus (`keys_taken`, the designer panel's rule); build mode's `_poll` does the same for B, T and its other keys
(`typing`). Measured in 757 `command.typing`: with W held and the bar open, a TLInput declaring W reads it not pressed;
after Esc closes the bar the same TLInput reads it pressed; B and T did nothing. `visit.gd` is unchanged (260-k8 is not
touched).

## P3 (question): a schema string for `<home>/settings.json`

The cap's settings file is `{"llm_calls_per_day": n}` with no `schema` key, because `tl arch` `schema-versions` fails on
any `tl.<name>/<n>` that no contract declares and contracts are the Director's. If the Home's settings get a schema
(`tl.home-settings/1`), `command_calls.gd` `open` adds the key to its allowed list and checks it.

## P4 (question): the ask's keys in the contract

`contracts/BUILD.md` names `tl.world-edit-ask/1` and what it carries but not its keys. They are in `COMMAND.md` "The
ask" and held by two readers that must agree: the exe's writer (`command_ask.gd`) and the Foreman's strict reader
(`foreman/src/world_edit.ts` `askSchema`, unknown keys refused); 759 runs both on one file. The Director may copy
that table into the contract.

## P5 (note): the model writes boxes

The Foreman's model-facing schema adds `fill` and `clear` boxes, expanded by the Foreman into `place` and `remove`
before the answer is written (`world_edit_check.ts`), so the answer file holds only the contract's ops and the
contract is unchanged. Reason: tokens and latency of Opus (a wall is one op instead of one per block).
