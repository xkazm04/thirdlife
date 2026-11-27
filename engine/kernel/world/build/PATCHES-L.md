# PATCHES-L: what lane L (land look + plants, M5) needs in files it does not own

Written 27 Nov 2026 by lane L. The Director makes these (LANES.md "Landing").

## L1 (seam_v3.gd, frozen): free the ghost nodes of `skipped`

`seam_v3.gd` `m5()` line 266 calls `b.preview_nodes(r, ["blocks"])` and keeps only the metas: the nodes are never freed.
With a built layer that draws a ghost (plants here; water and paths in their lanes) the orphan node and its mesh and
material leaked at exit, and 754 failed on every case ("ERROR: 1 RID allocations ... leaked at exit", "1 resources
still in use"). Measured on this branch before the stopgap. Patch:

```gdscript
	var skipped_nodes: Array = b.preview_nodes(r, ["blocks"])
	var skipped: Array = skipped_nodes.map(func(n: Node3D) -> String: return str(n.get_meta(&"tl_layer", "")))
	for n: Node3D in skipped_nodes:
		n.free()
```

Stopgap in lane L's own file (no frozen file touched): `land_ghost.gd` builds its meshes only when it enters the tree,
and a ghost that nobody added to the tree by the end of the frame it was made in frees itself (`_orphan_check`). The
command tool adds every ghost at once (command_tool.gd:307), so this changes nothing in play. Once L1 is in, the
orphan check can go.

## L2 (LANES.md): the shader's path

LANES.md names `engine/style/dio/toon_cel.gdshader`; the file is `engine/style/shaders/toon_cel.gdshader` (the one lane
L edited, only its growth-density terms).

## L3 (contracts/BUILD.md, a question, not an edit)

"Flood, path and plant are refused in the protected areas, with a reason, like land and paint." Lane L refuses `plant`
where paint is refused EXCEPT where the visitor stands ("too close"): growth moves nothing, and the refusal only cut a
hole under his feet in every stroke near him. If the contract means the visitor too, it is one line in
`land_protect.gd rule`.
