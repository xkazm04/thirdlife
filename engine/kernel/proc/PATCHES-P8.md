# P8: patches outside my scope (not applied)

The spike runs without any of them: it has its own scene (`kernel/proc/proc.tscn`) and tool (`tools/proc.sh`) and
extends the unchanged worker. These are what MOVING a game across the boundary would need, each small, each with
the measurement or the reading that asks for it. Numbering is the order I would apply them in.

## 1. `engine/kernel/api/tl_input.gd`: a door for input that comes from another process
Why: the only way in today is `press()`, the door a bot uses. A bot and a remote player on the same door overwrite
each other; the spike feeds D's samples through `press()` only when no bot runs.
Add the field to every action's record (two places: `declare`, line 23):
```
	_actions[action] = {"keys": keys.duplicate(), "injected": 0.0, "hold": -1, "now": 0.0, "prev": 0.0, "remote": 0.0}
```
Add after `release_all()`:
```
## Kernel side: the strength the drawing process sampled for this action (devices live there, not here).
func _feed(action: StringName, value: float) -> void:
	if _actions.has(action):
		(_actions[action] as Dictionary)["remote"] = clampf(value, 0.0, 1.0)
```
In `_sample()` replace `var v: float = float(a["injected"])` by:
```
		var v: float = maxf(float(a["injected"]), float(a.get("remote", 0.0)))
```
And one more accessor, so the drawing process can be told which keys to poll without running the pack:
```
## Kernel side: action -> physical key codes, as the pack declared them.
func _bindings() -> Dictionary:
	var out: Dictionary = {}
	for name: StringName in _actions.keys():
		out[String(name)] = ((_actions[name] as Dictionary)["keys"] as Array).duplicate()
	return out
```

## 2. `engine/kernel/api/tl_audio.gd`: the record of a sound must hold everything needed to play it elsewhere
Why: `volume_db` is played and not recorded, so a sound that crosses as an event loses it. In `_play`, after
`e["position"] = position`:
```
	if volume_db != 0.0:
		e["volume_db"] = volume_db
```

## 3. `engine/kernel/api/tl_vfx.gd`: an effect must remember how it was asked for
Why: in a process without a window `_make` builds a `TLVfxNode` with no particles and throws `opts` away; the
spike can only tell D the preset. In `_make`, after `fx.one_shot = one_shot`:
```
	if not opts.is_empty():
		fx.set_meta(&"tl_fx_opts", opts.duplicate())
```
`TLVfx.trail` returns nothing describable in a headless process (the style draws nothing and no record is kept):
give it the same treatment (a `TLVfxNode` with `preset = &"trail"` and the options in the meta) when moving.

## 4. `engine/kits/tl_kit_layout_build.gd` (`run`): the layout's root says what it was built from
Why: `TLKit.build` and `TLRigs.build` tag their result with `tl_kind` and `tl_params`, which is exactly a build
record: another process can make the same part from two values. `run` tags its root with the layout's NAME only
(`tl_layout`), and its products (terrain, scatter, the merged static mesh, the `Parts`/`Actors`/`Nature` holders)
are the largest group of nodes with no record: 23 nodes of the 266 at the start of seed_wall have none, and they
are these, the three HUD labels and the pack's own root; everything else is a kit part, a kernel class or a
kernel body. After line 26 (`root.set_meta("tl_layout", ...)`):
```
	root.set_meta("tl_kind", "layout")
	root.set_meta("tl_params", L)
```

## 5. `engine/kernel/runner/worker.gd` (`_on_node_added`): a number for every node of a pack
Why: the two processes cannot agree on a node by its path. The engine names an unnamed node `@Node3D@41`, and the
number is a counter of the process. The spike falls back to "class and ordinal among unnamed siblings", which is
right only while both trees are built by the same code in the same order. One line, in the hook the worker already
has (before the `if`):
```
	if pack_node != null and pack_node.is_ancestor_of(n) and not n.has_meta(&"tl_n"):
		_node_serial += 1
		n.set_meta(&"tl_n", _node_serial)
```
with `var _node_serial: int = 0` among the fields. The number is the order of entering the tree, which is the same
in every process that runs the same pack with the same seed (it is what determinism already promises). Note:
`worker.gd` "may not grow" (statehash.gd says so): this is three lines and would go with the move, not before.

## 6. `engine/kernel/host/host.gd`, `engine/kernel/runner/verbs.json`: only if the experiment is kept as a mode
Not needed now. If `proc` should be reachable through the host like `world-view`, add to `MODE_OPTIONS`:
```
	"proc": ["role", "pack", "test", "seed", "frames", "port", "out", "shot", "latency", "key", "watch", "stall-at", "stall-ms", "die-at", "survive", "wait", "result", "mode", "tag"],
```
and the same list under `"modes"` in `verbs.json`. I would not: it is a measurement, and it should stay off the path.

## 7. `CLAUDE.md`, the table "Where things are" (one row, for whoever looks for it)
```
| One game in a second process (spike, measurements) | `engine/kernel/proc/PROCESS.md`, `engine/tools/proc.sh` |
```
