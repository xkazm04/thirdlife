# PATCHES-P12: what round 3's arrivals package (P12) needs from files it does not own

Entries are numbered. "Applied" means the change is in this worktree although the file is not in P12's scope list;
the Director decides whether it stays.

## 1. `engine/kits/tl_mesh.gd` (APPLIED, line-neutral: 660 lines before and after)

The cause of "the queue hangs on the frame rate". `TLMesh.merge` (called once per layout by
`tl_kit_layout_build.gd` line 113, for the venue's merged `Static` mesh) read every source mesh back with
`ArrayMesh.surface_get_arrays`. On a worker thread that call is a value-returning call into the rendering server:
it waits for the main thread's next frame. A seed's layout merges about twenty meshes, so its preparation took about
twenty frames: 0.5 s with free frames, 4.5 to 5.0 s with 250 ms frames (`kernel/world/jobs_probe.gd`, before the
change: seed_paddle 620 / 4517 ms, seed_wall 744 / 5034 ms, at frame 0 / 250 ms).

The change: `_add_surface`, when it runs off the main thread, keeps the arrays it hands to the renderer in the mesh's
meta `tl_arrays`; `merge` reads them from there when they exist and asks the renderer otherwise. On the main thread
nothing changed. After it: seed_paddle 549 / 507 ms, seed_wall 547 / 478 ms, seed_drive 532 / 541 ms (frame 0 / 250).
The merged mesh's vertices are the generator's own arrays instead of the renderer's copy of them (whose normals went
through the renderer's octahedral compression and back): a difference below what the next compression keeps; no state
hash reads a render mesh. Other calls that wait for the main thread on a worker (measured with 100 ms frames):
`Mesh.create_trimesh_shape`, `create_convex_shape`, `ArrayMesh.get_faces`, `ArrayMesh.surface_get_arrays`. No kit,
rig or style code calls them on the build-ahead path today; a new one would bring the frame-rate dependence back
(the selftest case `world.prepare_capped` catches it for the seeds).

## 2. `engine/kits/tl_kit_layout_build.gd`: nothing needed

Listed because the merge call is there. It does not have to change.

## 3. `engine/kernel/runner/worker.gd` (P11's runner): a changed script

A pack alone (`tl.sh smoke`, `bot`) still loads its entry script with `load()`. Only a world reloads packs, so it
does not matter today. For one rule everywhere, `worker.gd` would call `TLContext._load_fresh(full)` where it calls
`load(full)` for the pack's entry and test scripts.

## 4. `engine/tools/world.sh`: frame cap and window position for measurements

`world.sh` hands its own `--fixed-fps 60` to the engine, and the host starts the world as a child process with its
own arguments (host.gd line 441), so `--max-fps` given to the console never reaches the world. P12 measured the
frame-rate dependence with its own probe (`kernel/world/jobs_probe.gd`) instead. For a windowed figure several runs
must not share a screen spot: `TL_WINDOW_POS` exists; a lock (one windowed measurement at a time) belongs in
`world.sh` `window_mode`, around the engine start:

```bash
  local lock="${TMPDIR:-/tmp}/tl_window.lock"
  while ! mkdir "$lock" 2>/dev/null; do sleep 2; done
  trap 'rmdir "$lock" 2>/dev/null' EXIT
```

## 5. Documentation of the build queue's new fields (WORLD.md is P12's; contracts are the Director's)

tl.world/1, world line `load` (queue mode only): `forced` (games built at once because they were needed),
`forced_ms` (main-thread milliseconds spent on them), `forced_list` as `[plot, world tick, ms, "stage" | "end"]`.

## 6. `kernel/world/draw/view.gd` `_on_plot_event("rebuilt")`, `draw/draw.gd` `set_tier` (P13 / P11): what is left of an arrival in a window

After P12 the pack's own part of an arrival is 2 to 30 ms on the main thread (TIERS.md, section P12; 19 to 30 ms for
the layout seeds in a 960x540 window with `arrival_probe.gd`). In the windowed `walk30` (17:10, another project's
window open on the machine) the queue's `attach_ms` was 5 to 20 ms for most games but 118 to 150 ms for the seven
arrivals of the layout seeds (seed_paddle and seed_wall copies), and those are the slow frames (120 to 145 ms; the
worst, 295 ms, is two arrivals in one frame at ticks 1163 and 1164). `attach_ms` includes what the view does on the
`rebuilt` event, synchronously: `world_space.add_pack` (copies the pack's static colliders into the visitor's space:
`ConcavePolygonShape3D.get_faces` and new shapes) and `draw.set_tier` for a plot whose tier is `backdrop`, which
builds the plot's stand-in at once; the tour line reports stand-ins of these packs with `build_ms` 89 to 136 (35,000
source triangles). Not split further by P12 (both files are not P12's). Proposed:
- `draw.gd`: build the stand-in of a pack that arrives far on a worker thread (the pack's meshes are in the tree
  then: read their arrays from the generator's meta `tl_arrays` when the pack was built ahead, see entry 1, or copy
  them on the main thread and merge on the worker), and show the plot's pad until it is ready; or keep stand-ins in
  `user://tl_cache/standin_<pack directory hash>.res` (PATCHES-P5 entry 4).
- `view.gd`: call `add_pack` for a plot whose tier is `backdrop` or `ledger` later (the visitor cannot reach it),
  one plot per frame.
