# Lane M round 2: changes wanted outside lane M's files (walker-feel, 18 Nov 2026)

## 1. `engine/kernel/world/draw/draw.gd` line 116 (`set_stage`): a freed holder is cast
Seen (11:40, before and after alike, so not caused by lane M): walk `wf_kit_rec` (lane M's walks folder) + device file
`wf_kit_rec.devices.json` + `--record=<f> --cost=model --load=block`: `SCRIPT ERROR: Trying to cast a freed object.
at: set_stage (res://kernel/world/draw/draw.gd:116)` <- view.gd `_set_stage` 392 <- `_on_plot_event` 349 <- world.gd
`_on_event` 370, at E (tick 520). One entry's holder was rebuilt and freed when the stage changes.
Change:
```gdscript
		var hn: Variant = e["holder"]
		var ctx: TLContext = (hn as Node).get("ctx") if is_instance_valid(hn) else null
```
in place of `var ctx: TLContext = (e["holder"] as Node).get("ctx")`.

## 2. `engine/boot/boot.gd` (TL_EXE_KEYS, lane T): scripted keys survive a focus loss
The same fix as visit.gd's `sample()` (T-PATCHES M4): keep the keys TL_EXE_KEYS holds (`+W` adds, `-W` removes) and,
once per frame before applying the frame's keys, press again any that `Input.is_physical_key_pressed()` says the
engine let go of. In visit.gd (proof in M2.md): with a window of mine taking the focus for 2 s the scripted walk
stopped at tick ~430 before and walks on after.

## 3. World lock: a fresh worktree's first window run hangs with the lock held
Seen twice (09:36 round 1, 11:12 round 2): the first window run in a worktree without `engine/.godot` prints
`[tl] class cache refreshed (--import)`, then parse errors (`Could not find type "TLContext"`), then the window stays
open and the lock is held until TL_VIEW_TIMEOUT (600 s) or a kill. A `godot --headless --path <engine> --import`
before the first window avoids it (world.sh `window_mode` could do it when `.godot` is missing). Likely part of
T-PATCHES D1.
