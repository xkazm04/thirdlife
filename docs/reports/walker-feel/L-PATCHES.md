# Lane L: changes wanted outside the lane's files

Nothing here blocks lane L; each entry is what, why, the exact change.

## 1. `engine/kernel/world/visitor.gd` (lane M): send the vertical speed and the real `grounded`
Why: the rig's air pose (rise / apex / fall) reads `velocity_local.y`, and the depth of the `land` clip is the last
`velocity_local.y` the rig saw while `grounded` was false. With `y = 0` in the air he shows the apex tuck all the way and every
landing is the soft one. The wire in common.md item 14 already says "vertical y in m/s"; this is a reminder, not a change.
```gdscript
rig.call("set_locomotion", Vector3(local_v.x, vertical_speed_mps, local_v.z), on_floor)
```
`slope_slide` is a looping clip (he keeps balancing), `slide` holds; both end with `rig.play(&"")` as the wire says.
`land` needs no parameter. `jump` is 0.30 s and ends in the air pose by itself.

## 2. `engine/kits_lab/tools/selftest.gd:246` (kit lab): the list of required biped clips
Why: it names 11 clips; the biped has 16. The case still passes and every clip is run for 120 frames by the loop below it
(all five new ones PASS, in and out of the tree), so this is only the label.
```gdscript
var want: Array = ["idle", "walk", "run", "skate", "skate_stop", "shoot", "pass", "cheer", "fall", "carry", "work", "jump", "land", "slide", "slope_slide", "air"]
...
ok(lacking.is_empty(), "rig biped has the 16 required clips", ", ".join(lacking))
```

## 3. Generated files (Director, at merge)
`docs/generated/API-INDEX.md` and `docs/generated/REPORTS.md` were regenerated in this worktree with
`node devx/bin/tl.mjs arch --index` (the gate's `api-index-fresh` / `reports-index-fresh` rules need them). After merging the
three lanes run it once more on main; `docs/generated/API-V1.json` did not change (kernel API stays 1.5).

## 4. `engine/kernel/world/draw/draw.gd:244` (world draw layer), only if a rig is ever mirrored
The mirror path copies the instance parameter `build` to the mirrored instance. A toon mesh is never mirrored (it carries
`tl_plot`), so `tl_body` needs no copy today. If that path ever takes toon geometry, copy `tl_body` beside `build`.
