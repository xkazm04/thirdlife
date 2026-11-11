# N6: patches the kernel needs before the panel can live inside a running game

None of these is applied. N6 touched nothing outside `ui/` and `tools/ui.sh`; tonight the panel runs in its own host
scene (`ui/host.tscn`). Each patch below is exact text against this engine copy (`site/_work/n6/engine`, the kernel
as of 2026-11-11 01:25). **None of them has been run.**

## 1. Keys typed into a field must not reach the game

**Why.** `kernel/api/tl_input.gd` does not use input events: `_sample()` polls the keyboard with
`Input.is_physical_key_pressed()` every physics frame (line 120). A `LineEdit` that consumes a key event changes
nothing about that poll, so typing "wasd" or a space into "Describe a game..." would steer and shoot in the game
behind the panel.

**Patch, `kernel/api/tl_input.gd`**, in `_sample()`:

```gdscript
# before
func _sample() -> void:
	for name: StringName in _actions.keys():
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if accept_devices:

# after
func _sample() -> void:
	var devices: bool = accept_devices and not keys_taken()
	for name: StringName in _actions.keys():
		var a: Dictionary = _actions[name]
		var v: float = float(a["injected"])
		if devices:
```

and one new function in the "kernel side" part of the same file:

```gdscript
## True while a text field has the keyboard (the designer panel's fields): the game sees no key then.
func keys_taken() -> bool:
	var vp: Viewport = get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	return f is LineEdit or f is TextEdit
```

Injected input (bots) is not touched, so no verify verb changes.

## 2. Esc must not end the game while the panel is open

**Why.** `kernel/runner/worker.gd` line 247 ends a `play` run when Esc is down, again by polling. With the panel open,
Esc should give the keyboard back to the game (or close the enlarged picture), not quit.

**Patch, `kernel/runner/worker.gd`**, in `_physics_process()`:

```gdscript
# before
	if mode == "play" and Input.is_physical_key_pressed(KEY_ESCAPE):
# after
	if mode == "play" and Input.is_physical_key_pressed(KEY_ESCAPE) and not _designer_open():
```

with

```gdscript
func _designer_open() -> bool:
	var layer: Node = get_node_or_null("TLDesigner")
	return layer != null and (layer as CanvasLayer).visible
```

## 3. Show the panel over a running pack

**Why.** There is no place in the kernel where a 2D layer of the game's own interface is mounted, and no key for it.
The panel is a plain `Control` (`ui/panel.gd`) that needs a jobs root and a door (`ui/foreman_door.gd`).

**Patch, `kernel/runner/worker.gd`**, at the end of the scene set-up in `start()` (after `TLStandin.install_look`):

```gdscript
	if mode == "play" and not ctx.headless and opts.has("jobs"):
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "TLDesigner"
		layer.layer = 50
		layer.visible = false
		add_child(layer)
		var door: RefCounted = (load("res://ui/foreman_door.gd") as GDScript).new()
		var flags: Variant = (load("res://ui/job_model.gd") as GDScript).call("read_json", str(opts.get("foreman-flags", "")))
		door.call("setup", str(opts["jobs"]), {"flags": (flags as Dictionary).get("flags", {}) if flags is Dictionary else {},
			"flags_name": str((flags as Dictionary).get("name", "")) if flags is Dictionary else ""})
		var panel: Control = (load("res://ui/panel.gd") as GDScript).new()
		panel.call("setup", str(opts["jobs"]), door, {})
		layer.add_child(panel)
```

and the key that shows and hides it (Tab), in the same file:

```gdscript
func _unhandled_key_input(event: InputEvent) -> void:
	if mode == "play" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		var layer: CanvasLayer = get_node_or_null("TLDesigner") as CanvasLayer
		if layer != null:
			layer.visible = not layer.visible
			if not layer.visible and get_viewport().gui_get_focus_owner() != null:
				get_viewport().gui_get_focus_owner().release_focus()
```

`tools/tl.sh play` then needs two options passed through to the worker: `--jobs=<dir>` and `--foreman-flags=<json>`
(the worker already takes every `--name=value` into `opts`; `fix_arg` in `tl.sh` must also treat `--jobs=` and
`--foreman-flags=` as paths). Two things to check when this is tried: the worker runs with
`process_mode = PROCESS_MODE_ALWAYS`, so the panel's one-second poll keeps running when the game is paused; and
`tl_orbit_cam.gd` reads the mouse in `_unhandled_input`, so clicks and the wheel on the panel do not reach it (the
panel's two boxes stop the mouse), while a drag that starts on the game and crosses the panel still orbits.

## 4. Tune: a value takes effect at the next start, because nothing can restart a pack

**Why.** A slider writes the number into the promoted pack's data file (through a temporary file, then a rename).
Packs read their data once, in `_pack_setup`; the kernel has no call that loads a pack a second time in the same
process, so the sheet says "A change takes effect at the next start of the game" and that is true.

**Proposal (not exact text, it needs a kernel builder's judgement):** a `restart_pack()` in `worker.gd` that frees
`pack_node`, clears `ctx.input`'s declared actions and the cameras, and runs `_load_pack()` and the `_pack_setup` /
`_pack_start` sequence again with the same seed; the panel would call it 300 ms after the last slider movement. I
did not find a cleaner live path: a per-value "set" hook would need every pack to implement it.

## 5. Which pack does the game play?

Not a patch, a gap: the panel tunes `<job>/promoted/<pack id>[@version]/`, the directory the last `promoted` event
names. When the Foreman promotes into the engine (`--promote-to engine`, `dest: packs/<id>`), the panel shows "no
promoted pack" for that job, because it does not know the engine directory the Foreman used. The door should then be
told the engine directory (the same `TL_ENGINE_DIR`), and `job_model.gd read_job()` should resolve `packs/<id>`
against it.
