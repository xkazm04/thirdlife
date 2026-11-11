# P11: patches for files that are not P11's

P11 (the world joins the contract, and a person can walk) touched only its own files, with the exceptions listed in
the report (lines of P7's selftest cases that the move to `kernelApi` 1.0 broke). What it found in files of other
owners is here as exact text. **None of these is applied, and none has been run**, unless the entry says so.

## 1. `engine/tools/item.sh` line 303: the patch-level case must follow the packs to 1.0 (needed at the merge)

`pack_min` (and every seed and example) now says `"kernelApi": "1.0"` (PATCHES-P7 section 6, applied by P11). The
case `manifest.kernel_api_patch_level` copies `pack_min` and rewrites `"0.1"` to `"0.2"`: its `sed` no longer matches,
the copy stays valid, lint exits 0 and the case (which wants 1) FAILS. `item.selftest` is skipped in a worktree (it
needs `site/`), so this was read in the code, not run. Patch:

```bash
  manifest_case kernel_api_patch_level 1 "kernelApi" 's#"kernelApi": "1.0"#"kernelApi": "2.0"#'
```

## 2. `engine/kernel/world/world.gd`: a person's walk runs none of the walk's scripted visits (PATCHES-P9 3b)

`view.gd` now empties the scheduler's list of scripted visits when a person walks:
`(world.get("sched") as RefCounted).set("_visits", [])` (P11, applied in `view.gd`, which is P11's). That reaches into
a private member of `tiers.gd`. The clean place is `world.gd` `start()`, where the walk's events are handed to the
scheduler (line 293 today):

```gdscript
	sched.call("setup", cfg, list, walk.get("tickets", []), [] if bool(opts.get("live", false)) else walk.get("events", []))
```

with `view.gd` passing `wopts["live"] = true`; then the line in `view.gd` goes.

## 3. `engine/kernel/world/world.gd`: the world line's `script_errors` misses errors with two packs

Measured (selftest case `p11.world_handler_off`, control run): a pack that pushes two errors in a world of one pack
gives `"script_errors":2` in the `kind:world` line; the same pack with `seed_wall` beside it gives `0` there and `0`
in its own pack line, while the engine printed both `ERROR:` lines. The case reads the engine's lines (TL_RAW) for that
reason. Not looked into further: the attribution of errors to packs in `world.gd` / `logger.gd`.

## 4. `engine/kernel/world/landscape.gd`: say where each gate is

`visit.gd` puts the visitor at a plot's gate after `Q`. The landscape knows the gate (`gates[i]`, the direction from
the plot's centre to the nearest point of the smoothed main road) and does not tell. `visit.gd` recomputes it from the
walk's `road` control points (nearest point of the polyline). For the drive plot both give (0, 1) (the picture
`03_after_leave.png` shows him between the gate's two flags); for a plot near a bend they can differ by a few degrees.
Patch, in `build()` after the loop that fills `gates`:

```gdscript
	parent.set_meta(&"tl_gates", gates)          # P11: per plot the direction its gate faces (Vector2), or null
```

and in `visit.gd` `_gate_dir` read `landscape.get_meta(&"tl_gates")[i]` first.

## 5. `engine/kernel/world/draw/draw.gd`: the env variable `TL_DRAW_PICTURE` can go (PATCHES-P6 entry 2)

`--picture=still|mid|far` is now an option of `world-view` (host.gd, verbs.json) and `view.gd` sets
`draw.force_picture` from it. `draw.gd` `setup()` still reads `TL_DRAW_PICTURE` into an empty value (lines 42-43);
`far_cost.sh` / `far_study.mjs` (in `draw/`) still set the variable. When they pass `--picture=` instead, delete:

```gdscript
	if force_picture.is_empty():              # the viewer may set it (PATCHES-P6 entry 2); until then the env variable
		force_picture = OS.get_environment("TL_DRAW_PICTURE")
```

## 6. A person's visit replays exactly only on a fixed schedule

Measured: a scripted visit recorded in a window and replayed in a window walks the same path every time, but the
packs' tick counts differed between runs (drive 1253 / 1221 / 1235 ticks) until `--cost=model --load=block`: with the
measured cost (the world's clock) and the build queue (a worker thread) the scheduler follows the wall clock. With both
set, record and two replays agree on the path and on all six hashes (`world.sh visit-proof`). For a person's real visit
(measured cost, queue) to replay to the same hashes, the replay also needs the world log of the visit (`--log`, the
scheduler's decisions, `tl.worldlog/1`) and `world-view` would have to accept `--replay=<log>` together with
`--input=<record>`. Proposal, not written: `host.gd` world-view options + `view.gd` passing `replay` to the world.

## 7. `engine/kernel/world/packs/w_pile`, `w_pile_x` `pack.json`: `"kernelApi": "0.1"` -> `"1.0"` (optional)

Not in P11's list of files (seeds and examples are). "0.1" is read as 1.0, so nothing breaks.

## 8. `engine/kernel/world/WORLD.md`: the person's keys

Line 27 `(WASD, E, Q / Esc)` and lines 271-272 ("No person has walked it ... is written and has never been run") are
stale. Text: "`world.sh visit tour` a person walks it: W S along the view, A D step aside, the mouse looks, Shift runs,
E enters, Q leaves, Esc quits (kernel/runner/visit.gd; scripted and replayed by `world.sh visit-test` / `visit-proof`)."

## 9. `kernel/api/tl_input.gd`: the pointer of a captured mouse

`TLInput` fills `LOOK_X` / `LOOK_Y` only from a right-button drag. The visitor's mouse look moves the mouse with no
button (captured), so `visit.gd` reads that motion itself, above the sampling line, and hands it in with
`press(TLInput.LOOK_X, dx)` before `_sample()`. If games on stage should get mouse look the same way, `TLInput` would
need a captured mode (a public member: API 1.1). Nothing is proposed for tonight.

## 10. PATCHES-P9 1, second half (`host.gd`): not done

`_ensure_import` returns at once outside the editor binary (applied). The worker and world-child command lines still
name `--path <engine_dir>`, which is empty in an export, so the host's verbs are still not usable in the exe.
