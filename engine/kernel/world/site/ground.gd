extends RefCounted
## The land's height under a site lot, from files only (kernel/world/site.gd setup): moved out of site.gd for its
## 600-line ratchet (day of 19 Nov, round 4). Read-only use of the terrain code.

const VillageTerrain := preload("res://kernel/world/terrain/village_terrain.gd")
const Landscape := preload("res://kernel/world/landscape.gd")


## Mirrors landscape.gd build(), lines 74-135: the same plot and lot bounds, road, river, grid and base height.
## Site plots already represent their lots. No heightfield or rendered world is needed for this sample.
static func base_terrain(walk: Dictionary, resolve_pack: Callable) -> VillageTerrain:
	var cfg: Dictionary = walk.landscape
	var tiers: Dictionary = walk.tiers if walk.get("tiers") is Dictionary else {}
	var default_size: Array = tiers.get("default_footprint_m", [40, 40])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var scatter := Vector2.ONE * Landscape.SCATTER_MARGIN
	var reserved := {}
	for plot: Dictionary in walk.get("plots", []):
		if plot.has("site_lot"):
			reserved[int(plot.site_lot)] = true
		var fp: Dictionary = plot.get("footprint", {})
		if not plot.has("footprint") and plot.has("pack"):
			var path := str(resolve_pack.call(plot.pack)).path_join("pack.json")
			if FileAccess.file_exists(path):
				var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if manifest is Dictionary:
					fp = manifest.get("footprint", {})
		var size: Array = fp.get("size_m", default_size)
		var extent := Vector2(size[0], size[1]) * 0.5
		var r := float(plot.get("radius", minf(extent.x, extent.y)))
		var axis := Vector2.from_angle(-deg_to_rad(float(plot.get("yaw", 0.0))))
		var bounds := (axis.abs() * extent.x + axis.orthogonal().abs() * extent.y).max(Vector2.ONE * r)
		var origin: Array = plot.get("origin", [0, 0, 0])
		var c := Vector2(origin[0], origin[2])
		lo = lo.min(c - bounds - scatter)
		hi = hi.max(c + bounds + scatter)
	var lots: Array = cfg.get("lots", [])
	for k: int in lots.size():
		if reserved.has(k):
			continue
		var c := Vector2(lots[k].at[0], lots[k].at[1])
		var bounds := Vector2.ONE * (float(lots[k].get("radius", 20.0)) + Landscape.SCATTER_MARGIN)
		lo = lo.min(c - bounds)
		hi = hi.max(c + bounds)
	for p: Array in cfg.get("road", walk.get("road", [])):
		lo = lo.min(Vector2(p[0], p[1]))
		hi = hi.max(Vector2(p[0], p[1]))
	var river: Dictionary = cfg.river if cfg.get("river") is Dictionary else {}
	for p: Array in river.get("path", []):
		lo = lo.min(Vector2(p[0], p[1]) - Vector2.ONE * 40.0)
		hi = hi.max(Vector2(p[0], p[1]) + Vector2.ONE * 40.0)
	var cell := float(cfg.get("cell_m", 3.0))
	var margin := Vector2.ONE * float(cfg.get("margin_m", 110.0))
	var start := ((lo - margin) / cell).floor() * cell
	var end := ((hi + margin) / cell).ceil() * cell
	var terr := VillageTerrain.new(int(cfg.get("seed", 7)), Rect2(start, end - start), cell)
	terr.centre = (lo + hi) * 0.5
	terr.relief = float(cfg.get("relief", 1.0))
	return terr
