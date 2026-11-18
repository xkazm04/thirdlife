# Bugfix-37, lane `walker`: the visitor's body and the visitor

All five defects fixed at the root. Each one has a regression case that fails on HEAD and passes on the fix
(`walker/cases_on_head.txt`). Walk cases: 14 of 14 pass (9 before); the 5 new ones live in walk_case_b.gd. The parkour pack runs on world_body.gd through
TLBiped walker feel: all 6 verbs pass, and every state_hash is the same as on HEAD.

| D-id | defect | status | files | regression check | proof (repro line before -> after) |
|---|---|---|---|---|---|
| D6 | put at rest on ground steeper than the limit, he stands and can jump | fixed | world_body.gd | `walk.steep_rest` | `REPRO steep_rest: FAIL ... grounded_ticks=120/120 downhill_metres=0.000` -> `REPRO steep_rest: other ... grounded_ticks=0/120 downhill_metres=9.575` |
| D7 | the slide pose stays on after a game visit | fixed | visitor.gd | `walk.stage_pose` | Q9: `FAIL ... rig clip='slide'` -> `PASS ... rig clip=''`; R4: `2 s after put() ... rig clip 'slide'` / `walking ... 'slide'` -> `''` / `''` |
| D14 | slope-mode trap: no jump out of a steep-walled pit | fixed (with a feel note, below) | world_body.gd | `walk.slope_pit` | R2 62 deg: `out at tick -1, jumps 0, { "slope": 1200 }` -> `out at tick 44, jumps 2`; 45 deg control: out at tick 62 both times |
| D19 | a slide pressed on the edge tick keeps the slide pose through the fall | fixed | visitor.gd | `walk.edge_slide` | `rig clip 'slide'; 10 ticks later ... 'slide'` -> `''` / `''` |
| D20 | the jump buffer is effectively 6 ticks, not 8 | fixed | world_body.gd | `walk.jump_buffer` | `k1..k6:jumps k7:no k8:no` -> `k1..k8:jumps k9:no k10:no` |

## What changed

- **D6** (`world_body.gd`, the standing branch of `drive()`): when he stands still in `ground` mode, the probe now
  checks the ground's normal, not only that ground is there. If it is steeper than the limit and the ray under his
  middle confirms a slope (not the round foot on an edge), the slope slide starts (`mode = "slope"`, event `slope`).
  The jump he could make on that bank went away with it. The one exception is the very first tick after a `put`:
  the jump check runs before the standing check.
- **D20** (`world_body.gd`): a press sets `_buffer = BUFFER + 1`, meaning the press tick and BUFFER ticks after it.
  The air branch now takes a buffered jump on the landing tick itself (`land` and `jump` in one tick). So a press 1 to
  8 ticks before landing jumps, and 9 does not. A buffered jump that used to fire the tick after landing now fires on
  the landing tick, one tick earlier.
- **D14** (`world_body.gd`): `can_jump` now includes `slope`. A new `_take_jump()` holds the jump; it is shared by the
  pre-move check and the landing tick. A jump from a slope also adds `SLOPE_JUMP_PUSH` (4.5 m/s) along the face's
  level normal, away from the face, and emits `end_slide`, so the slope_slide clip ends.
  - R6 stays true: hopping does not climb a steep bank. In `walk.slope_pit` he runs at 9 m/s into the 65 degree,
    8 m bank of walk.steep for 1200 ticks. The highest he stands or slides on its face is 1.62 m with jumps from the
    ground only, and 1.62 m with jump pressed every tick. Highest in the air: 1.62 m before the fix, 2.56 m after.
    He falls back each time and never reaches higher on the face.
  - `walker/hop_probe.gd.txt` (run by `walker/hop_probe.sh`) compares HEAD and the fix with jump cadences 1, 3, 6, 10, 20 and 36 ticks, at 4.5 and
    9 m/s. "Highest on the face" is the same as HEAD in 9 of the 12 runs. Three rose: cadence 20 at 4.5 m/s
    (1.33 -> 1.41), cadence 36 at 4.5 m/s (1.41 -> 1.57) and cadence 20 at 9 m/s (1.33 -> 1.58). None goes above
    HEAD's highest over all runs (1.90 m, from a ground jump at a run), and none builds up over time.
- **D7** (`visitor.gd`): when he is hidden (a game on stage) and the body was in `slide` or `slope`, the hidden branch
  of `_drive_step` now plays `&""`. `put()` also plays `&""`: a teleport ends any held clip.
- **D19** (`visitor.gd`): `end_slide` also plays `&""` when this tick's events hold `slide`, meaning a slide that
  started and ended in one tick. The gate on the previous mode stays, so a stale `end_slide` (Q26, left as it is)
  still cannot cut another clip.

## Commands

From W (`C:/Users/kazda/kiro/third-life/.claude/worktrees/bugfix-37`):
```
bash docs/reports/bugfix-37/walker/run_repros.sh          # the six hunter repros (b_steep_rest, r2, a_stage_pose, r4, r8, r9)
bash engine/tools/selftest.sh walk.                       # all 14 walk cases (one Godot process, about a minute)
bash engine/tools/selftest.sh walk.steep_rest             # one case; also walk.slope_pit, walk.jump_buffer, walk.stage_pose, walk.edge_slide
bash docs/reports/bugfix-37/walker/parkour_check.sh       # parkour: lint, smoke, 3 bots, invariants with state_hash
bash docs/reports/bugfix-37/walker/hop_probe.sh old     # HEAD copy of the body (walker/old/*.gd.txt); without `old`: the tree
```
P5 / P6: `python docs/reports/bugfix-37/hunt-P/repro/run.py bank|gate`. I did not run these separately. The same
mechanisms are covered by b_steep_rest and r4 above.

## Files

Changed:
- `engine/kernel/world/terrain/world_body.gd`
- `engine/kernel/world/visitor.gd`
- `engine/kernel/world/walks/walk_case_b.gd` (new, with its `.gd.uid`): the 5 cases plus the helpers `pit()`,
  `_buffer_run()`, `_visitor()` and `_free_visitor()`. It has the same contract as walk_case.gd (WALKCASE lines,
  `_want` on the printed name, `WALKCASE done`, exit 2 on an empty selection) and uses walk_case.gd's static
  `bank` / `flat`. They are in a second script for arch size-ratchet: walk_case.gd would have been 736 lines against
  a budget of 600.
- `engine/kernel/world/walks/walk_case.gd`: only the Director's `_want` / `_initialize` change (474 lines).
- `engine/tools/selftest.d/280-walk.sh`: runs walk_case.gd and walk_case_b.gd, concatenates both outputs, and has the
  5 names in both lists. A case with no line is still a FAIL.
- `engine/kernel/world/WORLD.md`: the jump row, the steep row and the clip sentence. Lane `world` is editing other
  lines of this file at the same time; its lines are intact.

Added (evidence only, under `docs/reports/bugfix-37/walker/`):
- `run_repros.sh`, `parkour_check.sh`, `hop_probe.sh`, `hop_probe.gd.txt`
- `old/world_body.gd.txt`, `old/world_space.gd.txt` (HEAD copies for hop_probe)
- `arch_after.txt`
- before/after outputs: `walk_before.txt`, `walk_after.txt`, `repros_before.txt`, `repros_after.txt`,
  `cases_on_head.txt`, `parkour_head.txt`, `parkour_after.txt`

## Tests run and expectations that moved

- **Walk cases** before: 9 of 9 PASS. After: 14 of 14 PASS.
  - Every figure of the 9 old cases is the same, including walk.jump (0.943 m, 33 ticks, buffered press 4 ticks
    early jumps), walk.steep (54 ticks sliding, 14.00 m/s, stop at tick 83), walk.idle_bank (0.0000 drift) and
    walk.biped_parity (identical visitor/pack).
  - The one exception is walk.canopy's "nearest camera" (1.91 -> 2.83 m). That comes from lane `cam`'s chase-camera
    change, not from this lane: I touched no camera code.
  - No case was loosened. In walk.jump, the buffered second jump now fires on the landing tick (38) instead of the
    tick after (39), and the case still counts 2 jumps.
- **Parkour** (lint, smoke, bot_course, bot_geometry, bot_obstacles, invariants): all ok. state_hash is identical on
  HEAD and on the fix (smoke fc06244c..., course 5b103a8c..., geometry 7ae4f852..., obstacles 17835b3f...).
  Hockey does not use world_body.gd.
- **`tl check --tier full --only world`**: not run by me. The Director runs it at the end, and other lanes are
  changing world files right now. The visitor's body is in no pack's space.

## Questions for the Director

1. **New member.** `SLOPE_JUMP_PUSH` is a new public constant on world_body.gd (not a `TL*` class), and
   `_take_jump()` is private. KERNEL_API is not bumped. Through TLBiped walker feel, a pack's runner can now jump from
   a slope too. API.md:310 ("buffered and coyote jumps, step and 55-degree slope limit") is still true. Whether API.md
   should mention the slope jump is for the Director, since API.md is not in my lane.
2. **Owner feel (D14).** A jump from a slope pushes him 4.5 m/s off the face. My judgement is that this escape is
   safe:
   - one steep bank cannot be climbed by hopping (measured above);
   - in a narrow steep V or chimney he could in principle wall-jump from face to face.

   Options for the owner: keep it; lower `SLOPE_JUMP_PUSH`; or allow one slope jump per touch of walkable ground (this
   reopens the trap if that one jump fails).
3. **New finding, not fixed (outside D14).** In a V channel whose bottom is narrower than the capsule, he wedges
   between the two walls in **`air`** mode and stays there for good: no jump, since the coyote time is over. The ray
   under his middle sees the walkable floor strip, so slope mode never starts. Seen on HEAD and on the fix alike: a
   4 m V of 62 or 75 degree walls with a 0.1 m floor, `walker/hop_probe.sh` "HOP V channel", `modes { "air": 1200 }`.
   A fix (treat a wedged, supported, unmoving fall as standing) changes how he meets creases and edges, so it needs
   its own lane and the owner's eye. Nobody has shown that the shipped landscape has such a crease.

## After the Director's size-ratchet note

- `tl arch`: size-ratchet PASS, and walk_case.gd is no longer reported.
- `uid-orphans` still FAILs with 42 findings. None of them is this lane's: the hunters' repros (hunt-P 2, hunt-Q 29,
  hunt-R 10) and 1 under `docs/reports/bugfix-37/world/`. walker/ holds no `.gd` now.
- `selftest.sh walk.`: 14 PASS.
- `selftest.sh gate.walk_case_filter`: PASS.
- walk_case_b.gd run alone: `-- walk.no_such_case` exits 2 with `WALKCASE done 0 0`; `-- walk.slope_pit` exits 0
  with `WALKCASE done 1 1`.
- `run_repros.sh` names the hunters' `.gd` files. If those are renamed to `.gd.txt`, it needs the copy-to-temp step
  that hop_probe.sh uses.
