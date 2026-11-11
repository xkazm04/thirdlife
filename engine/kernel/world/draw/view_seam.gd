extends RefCounted
## P14. The viewer's (view.gd) work at the seam between a world that builds packs while it is drawn and the visitor:
## the rim cache read before the first frame, and the copy of an arrived pack's colliders into the visitor's space in
## slices. Static functions on the viewer's own fields (the size rule of `tl arch` keeps view.gd under 600 lines).

const DrawScript: GDScript = preload("res://kernel/world/draw/draw.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")
const COPY_US: int = 2000               # what the copy may take of a frame
const COPY_NEAR_M: float = 10.0         # a plot whose edge is nearer than this to the visitor is copied whole at once

static var _hashes: Dictionary = {}     # pack directory -> content hash, once per process (PATCHES-P13 entry 4)


## P5. The rim of plot `i` (draw.gd `edge_height`). A plot whose pack is not built yet takes it from the rim cache, a
## file in the user directory keyed by the pack directory's content, the radius and the scenery; when it is not there
## the pack is built now, before the first frame, and the cache learns it (the first visit of a world on a machine).
## P14: a directory's content is hashed once per process, not once per plot (thirty plots of walk30 share nine).
static func rim_of(v: Node, i: int, r: float) -> float:
	var world: Node = v.get("world")
	var h: Node = (world.get("packs") as Array)[i]
	if bool(h.get("loaded")) or world.get("jobs") == null or (h.get("manifest") as Dictionary).is_empty():
		return float(DrawScript.call("edge_height", h, r))
	var rims: Dictionary = v.get("_rims")
	if rims.is_empty() and FileAccess.file_exists(rims_path()):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(rims_path()))
		if typeof(j) == TYPE_DICTIONARY:
			rims.merge(j)
	var dir: String = str(h.get("pack_dir"))
	if not _hashes.has(dir):
		_hashes[dir] = str(PlotFile.call("dir_hash", dir))
	var opts: Dictionary = v.get("opts")
	var key: String = "%s|%s|%s" % [str(_hashes[dir]), str(r), str(opts.get("scenery", (world.get("walk") as Dictionary).get("scenery", "plot")))]
	if not rims.has(key) or OS.get_environment("TL_RIM_CACHE") == "off":
		(world.get("jobs") as RefCounted).call("now", i)
		var e: float = float(DrawScript.call("edge_height", (world.get("packs") as Array)[i], r))
		rims[key] = "none" if is_nan(e) else e
		v.set("_rims_new", int(v.get("_rims_new")) + 1)
	return NAN if typeof(rims[key]) == TYPE_STRING else float(rims[key])


static func rims_path() -> String:
	return str(PlotFile.call("cache_dir")) + "/rims.json"          # P14: TL_CACHE_DIR or the user directory


static func save_rims(v: Node) -> void:
	if int(v.get("_rims_new")) == 0:
		return
	DirAccess.make_dir_recursive_absolute(rims_path().get_base_dir())
	var f: FileAccess = FileAccess.open(rims_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(v.get("_rims"), "", true))
		f.close()


## The rule: before the visitor takes a step, every plot whose edge is within COPY_NEAR_M of him has all its
## colliders (copied whole now if it must); of the rest the nearest is copied for COPY_US a frame. Running (9 m/s) he
## covers 10 m in 66 ticks; a seed's copy (5 ms whole) takes three slices. Returns the microseconds it took.
static func copy_colliders(copies: Array, ws: Object, plots: Array, radii: Array, at: Vector3) -> int:
	var tc: int = Time.get_ticks_usec()
	var best: int = -1
	var best_d: float = INF
	for k: int in range(copies.size() - 1, -1, -1):
		var i: int = int((copies[k] as Dictionary)["i"])
		var o: Vector3 = (plots[i] as Transform3D).origin
		var d: float = Vector2(at.x - o.x, at.z - o.z).length() - float(radii[i])
		if d < COPY_NEAR_M:
			ws.call("step_pack", (copies[k] as Dictionary)["job"], 1 << 30)
			copies.remove_at(k)
			if best > k:
				best -= 1
		elif d < best_d:
			best_d = d
			best = k
	if best >= 0 and Time.get_ticks_usec() - tc < COPY_US:
		if bool(ws.call("step_pack", (copies[best] as Dictionary)["job"], COPY_US - (Time.get_ticks_usec() - tc))):
			copies.remove_at(best)
	return Time.get_ticks_usec() - tc
