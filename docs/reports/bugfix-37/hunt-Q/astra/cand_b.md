# Terrain and walker physics candidates

## Unloading a pack removes collision from its copied platform

`engine/kernel/world/terrain/world_space.gd:317` · **High severity.** A visitor can fall through a previously solid platform after a pack unloads.

Both the immediate copy at line 317 and the sliced copy at line 263 attach the source shape’s RID to a new physics body. Neither path retains the `Shape3D` resource. The repro copies a 6 × 1 × 6 m box, frees the source holder, waits two physics frames, and repeats the same downward ray. Both copies lose the surface at y = 0.50 m.

`world_space.gd:31` describes the ownership requirement as “Shape3D resources that must outlive their bodies”. The sliced-copy comment at line 193 explicitly allows “the pack's nodes may move or go later”. The source holder disappearing should therefore leave the world’s static copy usable.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_ledger_collider.gd"
```

```text
REPRO ledger_collider immediate: FAIL before=0.50 expected_after=0.50 actual_after=nan
REPRO ledger_collider sliced: FAIL before=0.50 expected_after=0.50 actual_after=nan
```

## A closed terrain hole still lets the visitor fall through the visible pad

`engine/kernel/world/landscape.gd:522` · **High severity.** A stationary visitor falls 11.80 m in one second while the pad is visible.

For a plot with a known rim, an unarrived pack and no cached picture, `shut_holes` sets the material’s hole radius to zero. Landscape construction has already removed the collider triangles inside the radius. At the centre of the pad the ground ray finds nothing, and gravity takes the visitor through it.

`landscape.gd:517` describes the collider as “the terrain (left open where a plot's own ground carries him)”. `view_seam.gd:104` says the pad shows “until it has something to show”. During this interval the pack supplies no ground to carry the visitor.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_unloaded_pad.gd"
```

```text
REPRO unloaded_pad: FAIL hole_radius=0.0 visible_pad_y=0.00 support_y=nan feet_y_after_60=-11.80
```

## A road ending near a river aborts landscape construction

`engine/kernel/world/landscape.gd:289` · **High severity.** A valid road and river layout leaves the landscape build incomplete.

A straight 30 m road ends 16 m from a river with a 6 m half-width. Only the road’s final sample qualifies for the bridge. The bridge probe reads the sample after its midpoint, which here means index 16 of a 16-point path. `build()` exits before recording the terrain or installing its collider triangles.

`WORLD.md:81` defines a road as “control points of the main road”. `WORLD.md:135` specifies a bridge “where the main road is within 17 m of the river”. The endpoint satisfies that distance, and the documented path format permits a two-point road.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_bridge_endpoint.gd"
```

```text
SCRIPT ERROR: Out of bounds get index '16' (on base: 'PackedVector2Array')
   at: build (res://kernel/world/landscape.gd:289)
REPRO bridge_endpoint: FAIL road_end=(0,0) river_x=16 build_completed=false
```

## Omitting the optional pad height moves the terrain and collider below the pack rim

`engine/kernel/world/landscape.gd:103` · **High severity.** The example produces a 5 m seam and a walking surface 4.68 m below the visible floor near its edge.

The walk places a plot at y = 0. Its pack has a flat floor at local y = 5, so the viewer applies a −5 m lift to bring the drawn floor to zero. Without `pad_h`, line 103 uses that already-lifted transform as the pad height. Line 543 also derives the collider’s bend target from it. Supplying the same authored height explicitly restores both surfaces.

`landscape.gd:7` identifies the intended value as “the walk's plot origin y”. `draw_base.gd:180` explains the lift is applied “so the rim of the pack's ground meets the world's ground”. Both versions of this fixture have the same authored plot origin.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_pad_lift.gd"
```

```text
REPRO pad_lift: control explicit_pad=true pack_rim_y=0.00 pad_y=0.00 collider_y_at_r39=0.00
REPRO pad_lift: FAIL explicit_pad=false pack_rim_y=0.00 pad_y=-5.00 collider_y_at_r39=-4.68
```

## Rotating a narrow deck opens a terrain hole under uncovered ground

`engine/kernel/world/draw/draw_base.gd:222` · **Medium severity.** A 42.5 m radius hole opens although the only deck covers one third of the sampled rim.

A 40 × 90 m rectangular deck sits at the centre of a 40 m radius plot. Rotating it by 45° leaves its actual coverage at 48 of 144 samples. The coverage test uses the axis-aligned bounds of the rotated mesh. Those bounds enclose all 144 samples, so `edge_height` accepts the deck and the ground material opens the hole.

`draw_base.gd:206` defines the measurement as “the share of the plot's rim that the pack's own wide meshes really cover”. The declared minimum at line 213 is 0.95. The repro calculates actual coverage in the rectangular deck’s local coordinates.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_rotated_ground.gd"
```

```text
REPRO rotated_ground: control yaw=0 physical_coverage=48/144 reported=0.333 hole_radius=0.0
REPRO rotated_ground: FAIL yaw=45 physical_coverage=48/144 reported=1.000 hole_radius=42.5
```

## A plot-covering floor disappears from both distant pictures

`engine/kernel/world/draw/draw_pictures.gd:401` · **Medium severity.** Changing distance can remove an entire floor from the venue’s picture.

A centred 100 × 100 m plane covers a 40 m radius plot. Its two triangles cross the plot, but all four corners lie beyond the cut radius. The picture builder rejects both triangles. Subdividing the same plane without moving its surface leaves 30 triangles in each picture.

`draw_pictures.gd:396` describes the rejection rule as “a triangle wholly outside the plot is not part of the stand-in”. Both source triangles cover part of the plot interior.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_crossing_faces.gd"
```

```text
REPRO crossing_faces: FAIL subdivisions=0 source_covers_plot=true mid_triangles=0 far_triangles=0
REPRO crossing_faces: control subdivisions=3 source_covers_plot=true mid_triangles=30 far_triangles=30
```

## A visitor placed on a 65° bank stays grounded indefinitely while idle

`engine/kernel/world/terrain/world_body.gd:183` · **Medium severity.** A spawn or teleport can leave the visitor standing on a slope above the 55° limit.

The repro places the feet using the real ground ray, calls `rest()`, and drives the body for 120 ticks without input. The idle ground branch checks whether the downward probe hit anything and ignores its surface normal. Every tick reports grounded at the original position.

`world_body.gd:10` specifies “ground steeper than `max_slope_deg`: he slides down it”. The stationary exception at line 6 applies to “standing still on walkable ground”. The fixture exceeds the configured limit by 10°.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_steep_rest.gd"
```

```text
REPRO steep_rest: FAIL slope=65 limit=55 grounded_ticks=120/120 downhill_metres=0.000
```

## A distant road changes the grade across a wider road

`engine/kernel/world/terrain/village_terrain.gd:133` · **Medium severity.** Reordering two disjoint roads changes the height inside one road by 12.79 m.

A road with 9 m half-width has a 20 m profile. The sample is 8 m from its centre line and 68 m from a narrow road. `build_grid()` uses `roads[0].half` to blend every road. With the wide road first the sample is at the intended 19.98 m grade, including the code’s 2 cm surface offset. Putting the narrow road first lowers the same point to 7.19 m.

`village_terrain.gd:28` gives each road its own `{pts: PackedVector2Array, ys: PackedFloat32Array, half: float}`. `WORLD.md:133` says “the ground is graded flat across the road”. The sample lies inside the wide road in both runs.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_road_width.gd"
```

```text
REPRO road_width: FAIL expected_y=19.98 wide_first=19.98 narrow_first=7.19
```

## Walking off a ledge reports the end of an already completed run slide

`engine/kernel/world/terrain/world_body.gd:207` · **Low severity.** The movement event stream reports two slide endings for one slide.

The visitor performs one run slide, stops on flat ground, then runs off a ledge. The slide has already ended below the speed threshold, but `_slide_t` remains positive. The ground-to-air branch sees the old counter and emits another `end_slide` on tick 258.

`world_body.gd:15` specifies that a run slide “ends below SLIDE_END or after SLIDE_MAX ticks”. Lines 126–128 document `events` as part of the tick result. The later ledge departure starts in `ground` mode and has no active slide to end.

```powershell
timeout 120 "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/b_stale_slide.gd"
```

```text
REPRO stale_slide: FAIL tick=258 transition=ground->air events=["end_slide"] slide_starts=1 slide_ends=2
```

## Suspicions (not reproduced)

None.
