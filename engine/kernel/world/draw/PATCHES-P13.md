# P13: patches for files that are not P13's

## 1. `engine/kernel/world/draw/view.gd` (P11's): APPLIED, the lines marked `# P13`

The brief allows P13 to change the place where the landscape is built and stepped. Five lines, all marked `# P13`:
- `start()`, where the landscape is built: the walk's `landscape` block is copied before keys are added to it
  (`.duplicate()`; before, `road` was written into the walk's own dictionary), and `lcfg["events"]` hands the walk's
  events to the landscape, which takes the crane shots from them so trees give way to fixed cameras
  (village_parts.gd `cameras`, `clear_views`).
- `_process()`: `Landscape.arrive(landscape)` while the landscape has parts made on a worker (`tl_land_rest`): the
  pad edges (worn ring, kerbs, fences, flags) arrive a few frames after the first one.
Nothing else in `view.gd` was touched. If P11 reshapes `_process`, the two lines move with the frame loop.

## 2. `engine/kernel/runner/manifest.gd` and the P7 selftest cases: NOT applied, the API version for `bind_scoreboard`

`TLKitSite.bind_scoreboard(board: Node3D, source: Object) -> MeshInstance3D` is a new public member of the kit
(item 7). `tl arch` rule `api-v1` fails on it ("an addition needs a new minor version: set KERNEL_API to 1.1"). This
is the one finding the gate shows on P13's tree; the Director settles the version at the merge.
P13 tried the bump and took it back: with `KERNEL_API = "1.1"` arch passes, but four kernel selftest cases of P7 fail,
because they hold the version as text (`p7.api_1_0_lint`, `p7.api_0_1_is_1_0` expect `"kernelApi":"1.0"` in the report;
`p7.api_2_0_refused` expects "offers API 1.0"; `p7.api_1_1_refused` expects a 1.1 pack to be refused). The bump is:
`manifest.gd` line 7 `"1.0"` -> `"1.1"`; in `tools/selftest.sh` those four cases' expected text to 1.1 (and the 1.1
case to a 1.2 pack); then `node devx/bin/tl.mjs arch --index` (it writes `docs/generated/API-V1.json` as 1.1).
`docs/generated/API-V1.json` in this tree is the 1.0 one (restored); `API-INDEX.md` is regenerated and fresh.

## 3. `engine/kernel/world/WORLD.md` (the walk's `landscape` block): two optional keys

`soft_patches` [150]: low patches of worn earth, darker grass and meadows with flowers (village_parts.gd
`soft_ground`; its own random generator, so nothing else moves). `edges_now` [false]: build the pad edges in the
frame instead of on a worker (to measure; `TL_LAND_NOW=1` does the same).
New walk: `walks/compact_village.json` (six games, a lot where the hockey arena goes; `far_study.mjs compact`).

## 4. `engine/kernel/world/draw/view.gd` `_rim_of` (P11's): the rim cache still hashes a directory in the frame

`PlotFile.dir_hash` reads every file of a pack directory: 60 to 100 ms for a seed (measured in P13 through the
picture cache's key). `_rim_of` calls it on the main thread for every plot whose pack is not built yet, before the
first frame. It was not seen as large in the tour and walk30 (seeds share directories; the hash is per plot), but a
village of thirty different games would pay it thirty times. Proposal: the draw layer now hashes every plot's
directory on workers from its `setup` (`_dir_hashes`); `_rim_of` could ask the draw layer, or the hash could be
cached by directory and modified time.

## 5. `engine/kernel/world/draw/view.gd` `_on_plot_event` (P11's): a far tier for a plot that has not arrived

P5 entry 4 asked the draw layer to refuse a holder that is not loaded. Done in `draw.gd` `_set_far`: an unloaded
holder is far only when it has a cached picture to show, and never builds one. `view.gd` still holds `set_tier` back
until a pack has arrived (`_arrived`); it may stop doing that, the draw layer is safe either way.
