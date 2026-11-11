# P4: patches to files outside my scope

None of these was applied. P4 works without any of them (the lift of a plot already comes from the walk's plot `origin`
y through view.gd's existing lift, and the visitor finds the world through the landscape node), but each one removes a
duplication or a limit that the builder met.

## 1. `kernel/world/draw/view.gd`: let the walk state a pad height once, and a bend width once

Today a plot's height is written twice in a walk: as the plot's `origin` y and in `landscape.pad_h` (the landscape
needs the pad's height and does not know the pack's rim, which view.gd measures). The landscape cannot place plots
itself because view.gd lifts them before the landscape is built.

```gdscript
# view.gd, start(), where `plots` are made from the walk (tour branch), before the lifts:
-			plots.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0)))), d.get("origin", Vector3.ZERO)))
+			var o: Vector3 = d.get("origin", Vector3.ZERO)
+			var pads: Array = (walk.get("landscape", {}) as Dictionary).get("pad_h", [])
+			if i < pads.size():
+				o.y = float(pads[i])
+			plots.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(d.get("yaw", 0.0)))), o))
```

and `draw.set("rim_band", float(opts.get("band", str(walk.get("rim_band", 9.0)))))`, so that a walk can widen the
bend (the drive seed's hollow is 7.6 m deep and is bent to the rim over 9 m: 40 to 60 degrees at its steepest, which
the visitor's body cannot walk down; 18 m would make it about 25 to 35 degrees). The landscape reads the same number
from `landscape.rim_band` for the visitor's collider (default 9, equal to the draw layer's default): the two must be
kept equal until this patch lets one key serve both.

## 2. `kernel/world/draw/view.gd`: print the worst frame

The tour line has the median of the frame times (`frame_ms_p50_all`) and no maximum. P4's visitor prints
`frame_ms_p50`, `frame_ms_p99` and `frame_ms_max` of the frames it saw in his own `tl.view/1` line of kind `visitor` instead.

```gdscript
# in _on_world_ended, the tour line:
+ "frame_ms_max_all": snappedf(float(_frame_usec.max() if _frame_usec.size() > 0 else 0) / 1000.0, 0.001),
```

## 3. `kernel/world/world.gd`: one place for the world's physics space

The visitor's space is owned by the landscape node (meta `tl_space`) and freed when the landscape leaves the tree.
If the world host should own it (so that a headless world can also have a visitor, and `world.gd`'s `_end` frees it
with the packs' spaces), the landscape's `WorldSpace` creation would move to `world.gd`:

```gdscript
+const WorldSpace: GDScript = preload("res://kernel/world/terrain/world_space.gd")
+var visitor_space: RefCounted = null          # P4: the visitor's physics space (terrain, fences, trees; copies of every pack's statics)
+# in _end(), after the packs' spaces are released:
+if visitor_space != null:
+	visitor_space.call("free_all")
```

Not needed today: the tour's visitor exists only in a window, and the proof (`world.sh tour tour --headless`) has none.

## 4. `engine/seeds/seed_drive` and the kit's terrain: a way down into a dipped plot

A visitor cannot walk into the drive seed's hollow: its own ground is a 7.6 m bowl, bent over 9 m at the plot edge.
Either the pack declares an entry ramp in `pack.json` (`footprint.entry`: a gate direction and a ramp width, that the
kit's terrain flattens, as it does for a road corridor) or the world widens the band per plot (patch 1). Not done: it is
the pack's ground.
