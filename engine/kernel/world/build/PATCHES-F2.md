# PATCHES-F2: what lane F2 (27 Nov day) asks of the seam

Lane F2 owns the Rules tool's preset alignment (`tools/rules_tool.gd` `stand_at`, `rules_tool_presets.gd`
`fit_ground`): a preset placed by the hand on natural ground now takes the cells the feet of a person standing on that
ground read (selftest 798: the playtest's Door, feet cell 2 against a zone of cells 3..4, holds the feet at 18 of 18
points after, 0 before; the playtest's Jump pad, feet 2.95 reading cell 3 against a pad in cell 2, 9 of 9 after, 0
before). That fixes what the hand places from now on. It does not fix:

- zones already saved in a Home (the playtest's `course4` Door stays cells 3..4 over feet in cell 2);
- zones the LLM writes (`op: zone` from Foreman, lane C), and zones a stamp brings (the starters bring their own block
  floor, so they are fine, but a person's own stamp made on a slope is not);

because all of these meet `rules_run.gd` `feet_cell` unchanged. The seam's file; the lane does not edit it.

## The ask (Director's choice; lane F2 recommends A)

**A. Read the feet a little higher as well (one extra cell, upward only).** In `rules_play.gd` `tick`, where the cell
is made (line 109 at 98988c51), the run is stepped with the feet cell; give the run a second cell, the cell of the
feet raised by `FEET_REACH` (0.3 m), and let a zone hold the visitor when it holds either. Upward only: the body is
1.8 m tall, so a zone whose floor is up to 0.3 m over his soles holds his shins (the playtest's Door: soles 2.90,
floor 3.0). Downward is not safe: feet on a block's top at 3.0 would read the cell under the block, and a hazard dug
under a bridge would fire on the bridge.

```gdscript
# rules_run.gd
const FEET_REACH := 0.3                  # m: a zone whose floor is this little over his soles holds him (his shins)

## The cells the feet at `feet` are read in: the feet cell, and the cell of the feet raised by FEET_REACH when that is
## another (the ground sinks a little under a zone drawn on blocks: the playtest's Door, soles 2.90, zone 3..4).
static func feet_cells(feet: Vector3) -> Array:
	var a := feet_cell(feet)
	var b := feet_cell(feet + Vector3(0.0, FEET_REACH, 0.0))
	return [a] if a == b else [a, b]

# step(at_frame, feet: Vector3i, use_down, also := []): `here` holds a zone whose box holds `feet` or a cell of `also`
	for z: int in zones:
		if Check.box_has(zones[z].box, feet) or also.any(func(c: Vector3i) -> bool: return Check.box_has(zones[z].box, c)):
			here[z] = true

# rules_play.gd tick (and uses_here, which asks the same of a `use` zone)
	var cells := RulesRun.feet_cells(feet as Vector3)
	...
	run.step(at_frame, cells[0], use, cells.slice(1))
```

Cost: one more `box_has` per zone per frame while a second cell exists (a few frames in a thousand on flat block
floors, about a third of the frames on natural ground). Hashes: a pack never runs these rules; the Home's rules do not
enter `state_hash` (world gate unchanged). Cases that would move: none of lane P's at 98988c51 walks a zone from under
its floor; 774 and 791 walk block floors. `command_space.gd` reads `feet_cell` for its estimate; it may keep the
single cell (an estimate that is kind by 0.3 m is still an estimate).

**B. Do nothing at the runtime** and leave the hand's presets fitted (what F2 shipped). Old Homes' and the LLM's
zones keep the playtest's failure. Lane C could fit the LLM's zones the same way (`fit_ground` is static; its
`stand` Callable needs only the blocks and the land layer).

## Also for the Director (no seam change)

- `fit_ground` lowers a Door's floor into the cell under its blocks when the ground in front sinks below them. When
  that door opens, a block in that lower cell of the wall's own column (a foundation set into the ground) is hidden
  with the door. The playtest's wall had none (its blocks stood on the ground's cell above); a wall sunk into a slope
  would show its foundation cell open while the door is open. Not seen in a window; named so it is not a surprise.
