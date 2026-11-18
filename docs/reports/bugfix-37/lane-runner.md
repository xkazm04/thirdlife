# Bugfix-37 lane `runner`: kernel runner and kernel teleports

| D-id | defect | status | files | regression check | proof (repro before -> after) |
|---|---|---|---|---|---|
| D2 | stage recording lost when the holder is rebuilt on stage | fixed | engine/kernel/runner/visit.gd | runner.stage_record_rebuilt | Q3: `REPRO stage_record: FAIL ... file exists=false` -> `PASS ... file exists=true` |
| D10 | bot's held injected press survives the hand-over | fixed | engine/kernel/runner/visit.gd | runner.stage_handover | Q4: `FAIL ... gas active on 120/120 player ticks` -> `PASS ... 0/120` |
| D15 | kernel `place()` teleports are drawn as a glide | fixed | tl_ball.gd, tl_biped.gd, tl_vehicle.gd | runner.place_no_glide | R6: `frames drawn with the puck between the two places: 3 [1.11, 13.53, 25.95]` -> `0 []` |

## What changed
- **D2** (`visit.gd`). `_stage_rec` gets a fifth item: how many samples the input had taken. In the devices+record case
  `stage()` connects the stage input's `tree_exiting` to `_on_stage_input_leaving`. That handler reads `_ticks` while the
  input still exists: world.gd `_rebuild` frees the holder's children inside the tree, and pack_life.gd makes `ctx.input` a child of
  the holder. `_close_stage_record` is now one path with the same rule for an alive and a freed input:
  `length` = the input's `_ticks` (alive) or the count read as it left the tree (rebuilt), never below the last
  recorded frame + 1. The connection is dropped when the record closes. A write error now gives a `push_error` and the
  `[visit] <err>` line in both cases. Before, the rebuilt case ignored the error and the record was lost without a message.
  Limit: an input freed *outside* the tree (only in the hunters' synthetic repros) has no count to read, so its length falls back to the last
  frame + 1. That record is valid, but it does not count the trailing empty ticks. This is why P1 (`run.py record`)
  still prints `REPRODUCED record` with `rebuilt=true ... saved=true length=19`, where it wants 20. Before the fix it printed `saved=false length=-1`.
  The real path, inside the tree, is exact: my check gives length 20 with the last row at frame 12. Getting an exact count outside the tree
  would need a hook in tl_input.gd, which is outside my scope.
- **D10** (`visit.gd` `stage()`): `c.input.release_all()` (existing helper) at the hand-over to the person (after
  the "same game told again" early return, before devices/feed are set). Only runs on stage with a person.
- **D15**: `reset_physics_interpolation()` at the end of `TLBall.place`, `TLBiped.place`, `TLVehicle.place` (in tree only;
  it propagates to the visual children). Draw-only.

## Re-run commands (from W, G = the Godot console exe)
```
"$G" --headless --path engine --script "$PWD/docs/reports/bugfix-37/hunt-Q/repro/a_stage_record.gd"
"$G" --headless --path engine --script "$PWD/docs/reports/bugfix-37/hunt-Q/repro/a_stage_input.gd"
"$G" --headless --path engine --script "$PWD/docs/reports/bugfix-37/hunt-R/repro/r6_place_interpolated.gd"
python docs/reports/bugfix-37/hunt-P/repro/run.py record      # see the limit above
bash engine/tools/selftest.sh runner.
```
Selftest result: `PASS runner.stage_record_rebuilt (written=true length=20 rows=1)`,
`PASS runner.stage_handover (control_held=30/30 on_stage_down=0/30 bot_off=true)`,
`PASS runner.place_no_glide (placements=24 frames ball=57 biped=57 vehicle=57 worst_m 0.000 x3 control_glides=51/51)`.
Each check also fails on the unfixed code: with HEAD's visit.gd, `record fail no record written` and `handover fail gas down on 30/30`.
With the resets disabled: `place fail ball/biped/vehicle glide on 58/59 frames (worst 29.58 m)`.
The place check does not depend on frame timing. It compares the interpolated transform with the target on every frame drawn between a place and the next tick. It needs at least one such frame per body, and a hand-moved twin without the reset must glide (the control).

## Files
- changed: engine/kernel/runner/visit.gd, engine/kernel/api/tl_ball.gd, engine/kernel/api/tl_biped.gd, engine/kernel/api/tl_vehicle.gd
- added: engine/kernel/runner/bugfix_runner_stage.gd, engine/kernel/runner/bugfix_runner_place.gd,
  engine/tools/selftest.d/340-bugfix-runner.sh
- API.md: not edited. Every sentence about place() is still true.

## Existing tests run
- `selftest.sh p11.` 3/3 PASS (world_alone hashes unchanged in shape), `selftest.sh k8.` 1/1 PASS.
- `tl check --tier full --only packs` (once): **FAIL**, 1 of 2 packs. parkour passed all its units. Hockey passed lint, smoke and all
  bots, 32 of 33 verb runs in total. The only failure was `hockey invariants: invariants.many_budget: frame p50 1.051 ms (budget 1.0 ms)`,
  a frame-time budget measured at load 7.21 while the other lanes ran Godot. It is a timing figure, not a hash, and my change adds one call per teleport.
  The Director should re-run it on a quieter machine.
- Hockey's hash is unchanged by D15. In the same tree, with the reset lines disabled and then restored, the bot hashes match the gate run exactly:
  bot_hockey a29dcdf02a16dd1c, bot_faceoff 7cf722bf5ee97135, bot_goals f163f020c0cbedb5, bot_match 4eb1193dbedfdb44,
  parkour bot_course 5b103a8c06fb916c.
- No test expectation moved.

## Questions for the Director
- KERNEL_API is not bumped and no public member was added. `_on_stage_input_leaving` is private to visit.gd.
- D2 exactness outside the tree: if wanted, TLInput could let a recorder read its count at predelete. That would be a tl_input.gd change, outside this lane.
