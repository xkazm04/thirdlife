# Lane T round 2: patches for files that are not mine

## To lane L: engine/style/shaders/toon.gdshader, `vertex()`, the plot cut (two lines)

Why: an instance whose origin lies outside the plot is dropped whole (`VERTEX = vec3(0.0)`), which is right for a
tree of a pack's forest and wrong for a long slab placed by its middle: ex_car's course (asphalt 60 x 190 m, origin
65 m out of its 40 m plot) is not drawn at all in a world. The draw layer (draw_base.gd `reaches_in`, landed in my
worktree) now adds 2 to `tl_clip.w` for such an instance (w: 0 = thing, 1 = terrain sheet, 2 = slab reaching in,
3 = sheet reaching in). Until this patch, w >= 2 is dropped as before and w = 3 is a sheet as w = 1 was.

```diff
 	if (tl_clip.x > 0.0) {
 		vec3 org = MODEL_MATRIX[3].xyz;
 		float ro = length(org.xz);
-		if (ro > tl_clip.x) {
+		if (ro > tl_clip.x && tl_clip.w < 1.5) {   // w >= 2: a slab that reaches into the plot is cut in fragment(), not dropped
 			VERTEX = vec3(0.0);   // every vertex on one point: nothing is drawn
 		} else if (tl_clip.z > 0.0) {
-			bool sheet = tl_clip.w > 0.5;
+			bool sheet = tl_clip.w > 0.5 && (tl_clip.w < 1.5 || tl_clip.w > 2.5);
```
(The existing `fragment()` cut `length(wpos.xz) > tl_clip.x + 3.0` then trims it to the plot.)
Proof: a scratch copy of the wf-ground2 tree with exactly this change, `world.sh tour` crane views:
stills2/R2_car_asphalt_before_after_shaderpatch.png (asphalt drawn and cut at the plot) and
R2_hockey_with_shaderpatch.png (nothing else changes). My fix of the stand bend does NOT depend on it.

## Still open from round 1 (T-PATCHES.md): L1 ink breakup, L2 near canopies, M3 visit.gd `_close_stage_record`.
