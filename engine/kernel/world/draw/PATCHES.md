# N5b: patches to files outside my scope

**N7 (11 November, main tree): patches 1 to 4 are applied.** 1: `ctx.on_stage` is set in `pack.gd` `load_pack` from
the option `on_stage`, and `world.gd` passes it (false for every plot of a walk: tier events set it). 2: as written.
3: `world.gd` has `signal ended(bad)`, `quit_on_end` and `exit_code`; `ended` is emitted before the packs are freed.
4: host mode `world-view` in `host.gd` and `verbs.json`; `view.gd` takes `start(options)`; `tools/view.sh` starts the
host. 5 (`ctx.plot`) and 7 (lint) are still open; 6 is half done: the world reads `footprint`, no pack declares it.

None of these files was edited in the copy `site/_work/n5b/engine`. The viewer (`kernel/world/draw/view.gd`) works
with `kernel/world/world.gd`, `kernel/world/pack.gd` and the kernel API exactly as they are; each patch below removes
a workaround the viewer carries today.

## 1. `kernel/world/pack.gd`, `load_pack`: a pack is told whether it is on stage BEFORE its scripts load

```gdscript
 	ctx.origin = options.get("at", Vector3.ZERO)
+	ctx.on_stage = bool(options.get("on_stage", true))
```

and in `kernel/world/world.gd`, `start`, in the options of `load_pack`:

```gdscript
-			"trace": int(opts.get("trace", "0")), "own_space": str(opts.get("space", "own")) != "shared"})
+			"trace": int(opts.get("trace", "0")), "own_space": str(opts.get("space", "own")) != "shared",
+			"on_stage": i == int(opts.get("stage", "0"))})
```

Reason: `on_stage` defaults to true, so while a world loads, every pack's first view takes the viewport's camera
(`TLCameras.activate`), and the last pack loaded holds it. The viewer sets `on_stage` on every context after the
load and makes the stage pack's view (or its own crane camera) current again. It works, because only the state at
the first drawn frame counts, but for the length of the load the wrong pack owns the camera.

## 2. `kernel/api/tl_hud.gd`, `create`: a HUD of a pack that is not on stage starts hidden

```gdscript
 	if TLContext.current != null:
 		TLContext.current.huds.append(h)
+		h.visible = TLContext.current.on_stage
```

Reason: a viewport shows every `CanvasLayer`, whichever pack made it. The draw layer hides the HUDs of the non-stage
packs when the stage is set (`draw.gd`, `set_stage`), and the viewer polls every frame for a HUD that a pack made
later (`view.gd`, `_process`). With the patch the poll can go; `set_stage` still has to switch them when the player
walks to another pack.

## 3. `kernel/world/world.gd`: the host of a world decides when the process ends

```gdscript
+signal ended(bad: bool)
+var quit_on_end: bool = true
 ...
 func _end() -> void:
 ...
-	get_tree().quit(1 if bad else 0)
+	ended.emit(bad)
+	if quit_on_end:
+		get_tree().quit(1 if bad else 0)
```

Reason: `_end()` frees every pack and quits the tree. The viewer uses that as it is (`--until=end` lets the world
run to its own end; a plain `shot` calls `world._end()` itself after the last picture, which prints the world's
lines with empty hashes for the packs it cut short). A world with a player in it must outlive the bots of its packs,
and the draw layer wants to free its mirror instances before the nodes go (today it does so in `_exit_tree` and by
checking `is_instance_valid` on every node it follows).

## 4. `kernel/host/host.gd` and `kernel/runner/verbs.json`: the viewer as a host mode

```gdscript
 const MODE_OPTIONS: Dictionary = {
 	"world": [...],
 	"world-bench": ["only", "quick", "out-dir"],
+	"world-view": ["packs", "at", "yaw", "spacing", "radius", "lift", "band", "stage", "cam", "crane", "frame", "out",
+		"also", "settle", "until", "mech", "cull", "standins", "far", "mode", "frames", "seeds", "ground", "ground-key",
+		"hud", "measure", "tag"],
 }
```

plus the same list under `modes` in `verbs.json`, and in `_start_mode` the script `res://kernel/world/draw/view.gd`
for `world-view` (the script then has to take its options from a `start(options)` call instead of reading the
command line in `_ready`).

Reason: `host.gd` is not mine, so the viewer is its own main scene (`kernel/world/draw/view.tscn`). Two things the
host does for every verb had to be repeated in `tools/view.sh`: building the class cache when `.godot/` is missing
(without it the scene loads with parse errors and an idle window stays open: this cost three runs tonight), and
starting again when the window dies before its first line.

## 5. `kernel/world/pack.gd`: the option `at` and `ctx.origin` (proposal, no exact patch)

The viewer never passes `--at` to the world host: a pack is simulated at its own origin (N2, BENCH.md test 5) and its
plot is a property of the picture, held by the draw layer (`draw.gd`, `entries[i]["plot"]`, a `Transform3D`).
`pack.gd` still has `position = ctx.origin` and the shifted hash path for way (a). Proposal: keep `at` for the bench
only, and add `ctx.plot: Transform3D` (read-only for the pack; where the pack stands in the world, for a pack that
wants to draw a sign pointing at a neighbour) set by whoever owns the draw layer.

## 6. `kernel/runner/manifest.gd` and `pack.json`: a pack declares its footprint (proposal, no exact patch)

`"footprint": {"radius": 64}` (metres around the pack's origin that the pack needs drawn). Reason: tonight the plot
radius of every pack is a number I chose by looking (`--radius=64,40,38,40,30`). Nothing in a pack says how much of
its scene is the venue and how much is scenery of its own; the drive seed's circuit alone is 114 m long, so the
brief's 80 m between plots cannot hold for it. API.md section 19 already lists `footprint` under "not in a world yet".

## 7. `kernel/runner/lint.gd` (proposal, no exact patch)

Count, as a composability finding, geometry whose material is not a style material (`StandardMaterial3D`, a
`ShaderMaterial` with a shader of the pack's own). It is drawn at the right place in a world (the draw layer mirrors
it, see DRAW.md), but it is not cut to the plot, it is not in the far stand-in, and each such instance costs one
comparison per frame.
