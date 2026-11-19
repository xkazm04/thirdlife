extends RefCounted
## S (engine-world-next, 17-18 Nov 2026). The construction site: a lot of the village that shows a Foreman job being
## built, from that job's own log, and on which the promoted game ARRIVES (vision layer L5, docs/FEASIBILITY.md).
## The world host (world.gd) owns one; the landscape (landscape.gd) draws it (site/draw.gd). WORLD.md "The
## construction site" has the model; contracts/JOB.md lists the events.
##
## Walk script, block `landscape`, per lot (all optional; absent = today's decorative lot):
##   "job": "<job directory>"                 relative to the repository root, or absolute
##   "replay": {"ticks_per_event": <int>}       the log is shown one event per that many world ticks (deterministic:
##                                              walks, stills, tests); without it the site is LIVE: it follows the
##                                              file as it grows (its size is looked at once every 60 ticks)
## The site reads ONLY `<job>/job.jsonl` and `<job>/promoted/` and writes nothing there (JOB.md, 2026-11-17).
## E2 (day of 19 Nov): a job made in the minigame editor carries the player's lot in `job_created.lot` (JOB.md, "Added
## 2026-11-19"): it moves this lot there (`job_lot`). A job without it falls back to the workbench's draft
## `<job>/../_editor/*.json` whose request is the job's sentence (`draft_lot`, E6); neither = the walk's lot.
## When the centre moves, the lot and its reserved plot take the natural ground height at that centre.
##
## Arrival. With a build queue (tiers `load.mode` queue, step, wait or auto) a site lot is a plot of the world from the
## start, appended after the walk's plots (id `site_<lot index>`, radius = the lot's, origin = the lot's `at` and `h`).
## Until the log's LAST `promoted` event names a pack under `promoted/`, that plot is HELD: its holder has no
## manifest (the queue never builds it, jobs.gd `want`) and the scheduler sees it out of reach (its size is negative:
## nobody stands in it and it is not entered). Then the holder takes the promoted pack's manifest, the plot gets its
## size back and the queue builds it like any other arrival (a `built` event in the world log; a replay does the
## same). A later promotion replaces the pack by a `reload` from the new directory.
## The site is presentation: it never enters a state hash. Its report is one line `[site] {json}` at the world's end.

const SiteLog: GDScript = preload("res://kernel/world/site/log.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")   # S5: the cache of measured extents
const VillageTerrain := preload("res://kernel/world/terrain/village_terrain.gd")
const Landscape := preload("res://kernel/world/landscape.gd")
const LOT_KEYS: Array = ["at", "radius", "h", "job", "replay"]
const LIVE_EVERY: int = 60                  # live mode: the log's size is looked at once in this many world ticks
const HELD_SIZE: Vector2 = Vector2(-1.0e7, -1.0e7)

var world: Node = null
var sites: Array = []                       # [{lot, job, dir, plot (index or -1), tpe (0 = live), log, n, view, arrived_dir, ...}]
var warnings: Array = []
var _held_applied: bool = false


## Reads the walk's site lots; reserves a plot for each lot whose log is there (when the world has a build queue).
## Sets `world.refused` for a site lot that breaks its schema (unknown keys are errors). Called once, before the
## world builds its plots.
func setup(world_node: Node, walk: Dictionary) -> void:
	world = world_node
	var land: Variant = walk.get("landscape", {})
	var lots: Array = (land as Dictionary).get("lots", []) if typeof(land) == TYPE_DICTIONARY and typeof((land as Dictionary).get("lots")) == TYPE_ARRAY else []
	var plots: Array = walk.get("plots", []) if typeof(walk.get("plots")) == TYPE_ARRAY else []
	var reserved: Dictionary = {}           # a replayed world log carries the plots it reserved: lot index -> plot index
	var moved := {}                         # lot index -> site whose centre changed
	for i: int in plots.size():
		if typeof(plots[i]) == TYPE_DICTIONARY and (plots[i] as Dictionary).has("site_lot"):
			reserved[int((plots[i] as Dictionary)["site_lot"])] = i
	for k: int in lots.size():
		if typeof(lots[k]) != TYPE_DICTIONARY or not (lots[k] as Dictionary).has("job"):
			continue
		var lot: Dictionary = lots[k]
		var why: String = _check_lot(lot)
		if not why.is_empty():
			world.set("refused", "walk script, landscape.lots[%d]: %s" % [k, why])
			return
		var dir: String = job_dir(str(lot["job"]))
		var s: Dictionary = {"lot": k, "job": str(lot["job"]), "dir": dir, "plot": -1, "tpe": int((lot.get("replay", {}) as Dictionary).get("ticks_per_event", 0)),
			"log": SiteLog.new(), "n": 0, "view": SiteLog.fold([], 0), "arrived_dir": "", "size_seen": -1, "reads": 0, "read_us": 0, "stage_ticks": {},
			"at": [float((lot["at"] as Array)[0]), float(lot.get("h", 0.0)), float((lot["at"] as Array)[1])], "radius": float(lot.get("radius", 20.0))}
		if not dir.is_empty() and FileAccess.file_exists(dir + "/job.jsonl"):
			# The gate still faces the road, independent of the player's yaw.
			var placement := job_lot(dir)
			var source := "job log"
			if placement.is_empty():
				placement = draft_lot(dir)
				if placement.has("file"):
					source = "workbench draft " + str(placement.file)
			if not placement.is_empty():
				if lot.at != placement.at:
					moved[k] = s
				lot["at"] = placement.at
				lot["radius"] = placement.radius
				s["at"] = [placement.at[0], float(lot.get("h", 0.0)), placement.at[1]]
				s["radius"] = placement.radius
				s["lot_from"] = source
				print("[site] lot %d: at %s, radius %s m, from the %s" % [k, str(lot.at), str(lot.radius), source])
		if dir.is_empty() or not FileAccess.file_exists(dir + "/job.jsonl"):
			_warn("lot %d: no job log at '%s' (%s): the lot stays a plain building site" % [k, str(lot["job"]), dir + "/job.jsonl" if not dir.is_empty() else "not found"])
			continue
		if world.get("jobs") == null:
			_warn("lot %d: the world has no build queue (tiers load.mode block): the job is shown, its game cannot arrive" % k)
		elif reserved.has(k):
			s["plot"] = reserved[k]
			s["radius"] = float((plots[reserved[k]] as Dictionary).get("radius", s["radius"]))
			if moved.has(k):
				plots[reserved[k]].origin = s.at
		else:
			s["plot"] = plots.size()
			var fit: Array = fit_radius(dir, float(s["radius"]))
			var fr: float = float(fit[0])               # the scheduler's footprint: from the files only, so a run's ticks never depend on a cache
			var seen: Array = remembered_radius(dir, float(s["radius"]))
			s["sched_r"] = fr                         # hunt2 B2: the scheduler gets this back on arrival, never the cached radius
			s["radius"] = fr if seen.is_empty() else float(seen[0])
			s["fit"] = str(fit[1]) if seen.is_empty() else str(seen[1])
			var r: float = float(s["radius"])
			plots.append({"id": "site_%d" % k, "origin": s["at"], "radius": r, "footprint": {"size_m": [fr * 2.0, fr * 2.0]}, "seed": 1, "site_lot": k})
		sites.append(s)
	walk["plots"] = plots
	# Every placement must be known before sampling: any lot can move the terrain's bounds and centre.
	if not moved.is_empty():
		var terr := _base_terrain(walk, world._resolve)
		var pads: Array = land.get("pad_h", [])
		for k: int in moved:
			var s: Dictionary = moved[k]
			var lot: Dictionary = lots[k]
			var centre := Vector2(lot.at[0], lot.at[1])
			var h := terr.base_h(centre.x, centre.y)
			print("[site] lot %d: pad h %s -> %.2f m (the land at the new centre)" % [k, str(lot.get("h", "auto")), h])
			lot.h = h
			s.at[1] = h                  # the reserved plot's origin shares this array
			s.pad_h = h
			if s.plot >= 0 and s.plot < pads.size():
				pads[s.plot] = h
	if not sites.is_empty():
		world.connect("ended", _on_ended)


## Mirrors landscape.gd build(), lines 74-135: the same plot and lot bounds, road, river, grid and base height.
## Site plots already represent their lots. No heightfield or rendered world is needed for this sample.
static func _base_terrain(walk: Dictionary, resolve_pack: Callable) -> VillageTerrain:
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


## Read only the complete creation event, even when the rest of a live log is large or still being written.
static func _job_created(dir: String) -> Dictionary:
	var file := FileAccess.open(dir.path_join("job.jsonl"), FileAccess.READ)
	if file == null:
		return {}
	var line := file.get_line()
	if file.eof_reached():
		return {}
	var parsed := JSON.new()
	if not SiteLog.check_line(line, parsed).is_empty() or parsed.data.type != "job_created" or parsed.data.seq != 1:
		return {}
	return parsed.data


## E2. `job_created.lot` ({at: [x, z], yaw_deg, radius}) or {}. The first line is checked against the job schema
## (site/event_schema.gd: radius >= 12, at two numbers); a line that fails gives {} and the draft is tried instead.
## The yaw is not taken: the gate faces the road by the landscape rule.
static func job_lot(dir: String) -> Dictionary:
	return _job_created(dir).get("lot", {})


## E6. The lot the player chose in the workbench for this job: the draft (`tl.editor-draft/1`, written by
## engine/ui/editor/workbench.gd on Build it) under `<the job's parent>/_editor/` whose `request` is the job's
## `job_created.sentence` (the Foreman's command line turns " into '). Returns {at: [x, z], radius, file} or {} when
## there is none or it is malformed (then the walk's lot stands as before). Read from files only: the same files give
## the same lot, so a run's ticks and hashes stay a function of its inputs.
static func draft_lot(dir: String) -> Dictionary:
	var sentence := str(_job_created(dir).get("sentence", "")).replace("\"", "'").strip_edges()
	var ed: String = dir.get_base_dir() + "/_editor"
	if sentence.is_empty() or not DirAccess.dir_exists_absolute(ed):
		return {}
	var files: PackedStringArray = DirAccess.get_files_at(ed)
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ed + "/" + f))
		if typeof(d) != TYPE_DICTIONARY or str((d as Dictionary).get("schema", "")) != "tl.editor-draft/1":
			continue
		if str((d as Dictionary).get("request", "")).replace("\"", "'").strip_edges() != sentence:
			continue
		var lot: Variant = (d as Dictionary).get("lot", null)
		if typeof(lot) != TYPE_DICTIONARY or typeof((lot as Dictionary).get("at")) != TYPE_ARRAY or ((lot as Dictionary)["at"] as Array).size() != 2:
			return {}
		var at: Array = lot.at
		for n: Variant in [at[0], at[1], lot.get("radius")]:
			if not (n is float or n is int) or not is_finite(n):
				return {}
		if lot.radius < FIT_MIN:
			return {}
		return {"at": [float(at[0]), float(at[1])], "radius": float(lot.radius), "file": f}
	return {}


## S3. The lot fits its game. When the job's log already names a promoted game under `promoted/` (its last
## `promoted` event: a finished job, a replay), the lot is sized to that game: the half-diagonal of the `footprint` its
## pack.json declares plus FIT_MARGIN metres, at least FIT_MIN, never more than the walk's radius. A pack without a
## footprint keeps the walk's radius (what its scripts build cannot be known before it is built). A job that has
## promoted nothing yet keeps the walk's radius too. Returns [radius, what decided it].
const FIT_MARGIN: float = 4.0
const FIT_MIN: float = 12.0
static func fit_radius(dir: String, lot_r: float) -> Array:
	var lg: RefCounted = SiteLog.new()
	lg.call("feed", FileAccess.get_file_as_string(dir + "/job.jsonl"))
	var pr: Dictionary = SiteLog.fold(lg.get("events"))["promoted"]
	var dest: String = str(pr.get("dest", "")).trim_suffix("/")
	if not dest.begins_with("promoted/") or not FileAccess.file_exists(dir + "/" + dest + "/pack.json"):
		return [lot_r, "walk radius: nothing promoted yet"]
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + dest + "/pack.json"))
	var fp: Variant = (m as Dictionary).get("footprint", null) if typeof(m) == TYPE_DICTIONARY else null
	if typeof(fp) != TYPE_DICTIONARY or typeof((fp as Dictionary).get("size_m")) != TYPE_ARRAY or ((fp as Dictionary)["size_m"] as Array).size() != 2:
		return [lot_r, "walk radius: %s declares no footprint" % dest.get_file()]
	var sz: Array = (fp as Dictionary)["size_m"]
	var half: float = Vector2(float(sz[0]), float(sz[1])).length() * 0.5
	var r: float = clampf(ceilf(half + FIT_MARGIN), FIT_MIN, lot_r)
	return [r, "footprint %s x %s m of %s: half-diagonal %.1f m + %.0f" % [str(sz[0]), str(sz[1]), dest.get_file(), half, FIT_MARGIN]]


## S5. One ring per site. A game measured once (`_measure`) is remembered in the world's cache (PlotFile.cache_dir()
## `/site_extent.json`: the promoted pack's content hash -> metres, as the far pictures and rims are kept), so the
## next world starts the lot, its pad, bank and worn ring at the measured size, not at the size the footprint guessed.
## Returns [radius, what decided it], or [] when the promoted game of the log was never measured on this machine (or
## in the build's shipped cache). Drawing only: the scheduler's footprint stays the one `fit_radius` reads from files.
const EXTENT_FILE: String = "site_extent.json"
static func remembered_radius(dir: String, lot_r: float) -> Array:
	var pd: String = promoted_dir(dir)
	if pd.is_empty():
		return []
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(PlotFile.call("cache_dir")) + "/" + EXTENT_FILE)) if FileAccess.file_exists(str(PlotFile.call("cache_dir")) + "/" + EXTENT_FILE) else null
	var key: String = str(PlotFile.call("dir_hash", pd))
	if typeof(c) != TYPE_DICTIONARY or not (c as Dictionary).has(key):
		return []
	var far: float = float((c as Dictionary)[key])
	return [clampf(ceilf(far), FIT_MIN, lot_r), "measured %.1f m before (cache, %s)" % [far, pd.get_file()]]


static func remember_extent(pack_dir: String, far: float) -> void:
	var path: String = str(PlotFile.call("cache_dir")) + "/" + EXTENT_FILE
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var d: Dictionary = c if typeof(c) == TYPE_DICTIONARY else {}
	d[str(PlotFile.call("dir_hash", pack_dir))] = snappedf(far, 0.1)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "", true) + "\n")
		f.close()


## The directory of the game the log's last `promoted` event names, or "".
static func promoted_dir(dir: String) -> String:
	var lg: RefCounted = SiteLog.new()
	lg.call("feed", FileAccess.get_file_as_string(dir + "/job.jsonl"))
	var dest: String = str((SiteLog.fold(lg.get("events"))["promoted"] as Dictionary).get("dest", "")).trim_suffix("/")
	return dir + "/" + dest if dest.begins_with("promoted/") and FileAccess.file_exists(dir + "/" + dest + "/pack.json") else ""


static func _check_lot(lot: Dictionary) -> String:
	for key: Variant in lot.keys():
		if not LOT_KEYS.has(str(key)):
			return "unknown key '%s'" % str(key)
	if typeof(lot.get("at")) != TYPE_ARRAY or (lot["at"] as Array).size() != 2:
		return "'at' must be [x, z]"
	if typeof(lot["job"]) != TYPE_STRING or str(lot["job"]).is_empty():
		return "'job' must be a job directory (text)"
	if lot.has("replay"):
		if typeof(lot["replay"]) != TYPE_DICTIONARY:
			return "'replay' must be an object"
		for key: Variant in (lot["replay"] as Dictionary).keys():
			if str(key) != "ticks_per_event":
				return "unknown key 'replay.%s'" % str(key)
		var tpe: Variant = (lot["replay"] as Dictionary).get("ticks_per_event")
		if not (typeof(tpe) == TYPE_INT or typeof(tpe) == TYPE_FLOAT) or int(tpe) < 1 or float(tpe) != float(int(tpe)):
			return "'replay.ticks_per_event' must be a whole number of at least 1"
	return ""


## A job directory: absolute, or relative to the repository root (the folder above the engine). In a worktree a
## job that is not there is looked for in the main checkout too (job output under `site/` is not tracked).
static func job_dir(job: String) -> String:
	var p: String = job.replace("\\", "/").trim_suffix("/")
	if p.is_absolute_path():
		return p if DirAccess.dir_exists_absolute(p) else ""
	var root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").get_base_dir()
	if DirAccess.dir_exists_absolute(root + "/" + p):
		return root + "/" + p
	var wt: int = root.find("/.claude/worktrees/")
	if wt >= 0 and DirAccess.dir_exists_absolute(root.substr(0, wt) + "/" + p):
		return root.substr(0, wt) + "/" + p
	return ""


## The plot index `i` is a site's plot that is still held (no game arrived on it).
func holds(i: int) -> bool:
	for s: Dictionary in sites:
		if int(s["plot"]) == i and str(s["arrived_dir"]).is_empty():
			return true
	return false


## world.gd `_spawn_plot` with a build queue: a held site plot gets an empty holder (no manifest: the queue never
## builds it; in the ledger: it is not a pack that failed to load); any other plot its stub as before.
func stub(p: Node, i: int, dir: String) -> Node:
	if not holds(i):
		return p.call("stub", dir)
	p.set("pack_dir", dir.path_join("(arriving)"))
	p.set("ledgered", true)
	p.set("finished", true)
	p.set("running", false)
	return p


## Once per world tick, before the scheduler decides: the logs move on, a promotion releases its plot.
func tick(t: int) -> void:
	if sites.is_empty():
		return
	var sched: RefCounted = world.get("sched")
	if not _held_applied and sched != null:
		_held_applied = true
		for s: Dictionary in sites:
			if int(s["plot"]) >= 0:
				((sched.get("plots") as Array)[int(s["plot"])] as Dictionary)["size"] = HELD_SIZE
	for s: Dictionary in sites:
		_read(s, t)
		var n: int = (s["log"] as RefCounted).get("events").size()
		if int(s["tpe"]) > 0:
			n = mini(n, 1 + t / int(s["tpe"]))
		if n != int(s["n"]):
			s["n"] = n
			s["view"] = SiteLog.fold((s["log"] as RefCounted).get("events"), n)
			var st: String = str((s["view"] as Dictionary)["stage"])
			if not (s["stage_ticks"] as Dictionary).has(st):
				(s["stage_ticks"] as Dictionary)[st] = t
		var pr: Dictionary = (s["view"] as Dictionary)["promoted"]
		if int(s["plot"]) >= 0 and not pr.is_empty():
			_arrive(s, pr, t)
			_measure(s, t)


## S4. The game that arrived is measured once it is built: the farthest point (from the plot's centre, across the
## ground) of every mesh it put in the world after its setup. That is what stands on the lot, so it decides the lot's
## radius from then on (site/draw.gd moves its entrance there): ceil(extent), at least FIT_MIN, at most the plot's
## radius (the draw layer cuts a pack at that circle and the landscape's pad is that big). Before the game is built
## only its declared `footprint` is known (`fit_radius`, at the world's start). Main thread, one pass over the nodes,
## once per arrived directory; the time is in the report (`measure_ms`).
func _measure(s: Dictionary, t: int) -> void:
	var p: Node = (world.get("packs") as Array)[int(s["plot"])]
	if not bool(p.get("loaded")) or str(s.get("measured_dir", "")) == str(s["arrived_dir"]):
		return
	if str(p.get("pack_dir")).simplify_path() != str(s["arrived_dir"]).simplify_path():
		return                                  # the game of an earlier promotion is still there: wait for the new one
	if not s.has("measure_task"):
		# the main thread lists the meshes (one pass over the nodes); a worker reads their vertices (hockey: 10.7 ms
		# when it was done in the frame)
		var t0: int = Time.get_ticks_usec()
		var box: Dictionary = {"items": meshes_of(p)}
		s["measure_ms"] = snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.01)
		s["measure_task"] = [WorkerThreadPool.add_task(func() -> void: box["far"] = extent_from(box["items"])), box]
		return
	var task: Array = s["measure_task"]
	if not WorkerThreadPool.is_task_completed(int(task[0])) and not bool(world.get("_ended")) and t < int(world.get("walk_ticks")) - 1:
		return
	WorkerThreadPool.wait_for_task_completion(int(task[0]))
	s.erase("measure_task")
	var far: float = float((task[1] as Dictionary).get("far", 0.0))
	s["measured_dir"] = s["arrived_dir"]
	s["measured_m"] = snappedf(far, 0.1)
	remember_extent(str(s["arrived_dir"]), far)         # S5: the next world starts the lot at this size
	var plot_r: float = float(((world.get("walk") as Dictionary)["plots"] as Array)[int(s["plot"])].get("radius", s["radius"]))
	var r: float = clampf(ceilf(far), FIT_MIN, plot_r)
	if not s.has("radius_before"):
		s["radius_before"] = float(s["radius"])
	s["radius"] = r
	s["fit"] = "measured %.1f m (what the game built, at tick %d)%s" % [far, t, "; declared: " + str(s["fit"]) if s.has("fit") else ""]
	print("[site] lot %d: the game measures %.1f m from the plot's centre: the lot is %.0f m (was %.0f)" % [int(s["lot"]), far, r, float(s["radius_before"])])


## The farthest ground distance from a holder's origin to anything it drew: the vertices of every MeshInstance3D
## whose box reaches farther than what was found so far, the box of every MultiMeshInstance3D; in the holder's own
## frame (a pack is simulated at its own origin).
static func extent_of(holder: Node) -> float:
	return extent_from(meshes_of(holder))


## The meshes a holder drew: [[Mesh or null (a MultiMesh: its box only), its transform in the holder's frame, its AABB]].
static func meshes_of(holder: Node) -> Array:
	var out: Array = []
	var inv: Transform3D = (holder as Node3D).global_transform.affine_inverse()
	var stack: Array = [holder]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			var gi: GeometryInstance3D = n as GeometryInstance3D
			if gi.get_aabb().size != Vector3.ZERO:
				out.append([(n as MeshInstance3D).mesh if n is MeshInstance3D else null, inv * gi.global_transform, gi.get_aabb()])
	return out


static func extent_from(items: Array) -> float:
	var far: float = 0.0
	for it: Array in items:
		var bb: AABB = it[2]
		var xf: Transform3D = it[1]
		var box: float = 0.0
		for k: int in 8:
			var c: Vector3 = xf * bb.get_endpoint(k)
			box = maxf(box, Vector2(c.x, c.z).length())
		if box <= far:
			continue
		# a box's corner overstates a merged mesh (a rink's stands make a rectangle whose corners are empty): the
		# vertices of a plain mesh decide; a MultiMesh keeps its box
		var mesh: Mesh = it[0]
		if mesh == null:
			far = box
			continue
		for si: int in mesh.get_surface_count():
			var vs: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vs:
				var c: Vector3 = xf * v
				far = maxf(far, Vector2(c.x, c.z).length())
	return far


## Reads what is new in the log: a replay reads the whole file once; live mode looks at the size every LIVE_EVERY ticks.
func _read(s: Dictionary, t: int) -> void:
	if int(s["tpe"]) > 0 and int(s["reads"]) > 0:
		return
	if int(s["tpe"]) == 0 and int(s["reads"]) > 0 and t % LIVE_EVERY != 0:
		return
	var t0: int = Time.get_ticks_usec()
	var path: String = str(s["dir"]) + "/job.jsonl"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	s["reads"] = int(s["reads"]) + 1
	if f == null:
		return
	var size: int = f.get_length()
	if size != int(s["size_seen"]):
		s["size_seen"] = size
		var lg: RefCounted = s["log"]
		lg.call("feed", f.get_as_text())
		if not str(lg.get("error")).is_empty() and not bool(s.get("said", false)):
			s["said"] = true
			_warn("lot %d: %s; the site shows the log up to there" % [int(s["lot"]), str(lg.get("error"))])
	f.close()
	s["read_us"] = int(s["read_us"]) + Time.get_ticks_usec() - t0


func _arrive(s: Dictionary, pr: Dictionary, t: int) -> void:
	var dest: String = str(pr["dest"]).trim_suffix("/")
	if not dest.begins_with("promoted/"):
		if not bool(s.get("said_dest", false)):
			s["said_dest"] = true
			_warn("lot %d: the game was promoted into the engine (%s), not under the job's promoted/: it does not arrive here" % [int(s["lot"]), dest])
		return
	var dir: String = str(s["dir"]) + "/" + dest
	if dir == str(s["arrived_dir"]):
		return
	var was_missing := dir == str(s.get("missing", ""))
	if was_missing and (int(s["tpe"]) > 0 or t % LIVE_EVERY != 0):
		return
	if not FileAccess.file_exists(dir + "/pack.json"):
		if not was_missing:
			s["missing"] = dir
			_warn("lot %d: the promoted game %s has no pack.json" % [int(s["lot"]), dest])
		return
	s.erase("missing")
	var i: int = int(s["plot"])
	var p: Node = (world.get("packs") as Array)[i]
	var def: Dictionary = (world.get("plot_defs") as Array)[i]
	var sched: RefCounted = world.get("sched")
	var pl: Dictionary = (sched.get("plots") as Array)[i]
	var first: bool = str(s["arrived_dir"]).is_empty()
	s["arrived_dir"] = dir
	s["arrived_at"] = t
	def["dir"] = dir
	if first:
		p.call("stub", dir)                     # the manifest: from now on the queue builds it when the scheduler wants it
		var sr: float = float(s.get("sched_r", s["radius"]))
		pl["size"] = Vector2(sr * 2.0, sr * 2.0)
	else:
		p.set("pack_dir", dir)                  # a later promotion: the pack is replaced by a reload from the new directory
		var mres: Dictionary = (load("res://kernel/runner/manifest.gd") as GDScript).call("read", dir)
		if bool(mres.get("ok", false)):
			p.set("manifest", mres["manifest"])
	var m: Dictionary = p.get("manifest")
	pl["pack"] = str(m.get("id", ""))
	var has_bot: bool = typeof(m.get("tests")) == TYPE_ARRAY and not (m["tests"] as Array).is_empty()
	pl["on_leave"] = "bot" if has_bot else "pause"
	def["on_leave"] = pl["on_leave"]
	if first and not bool(world.get("is_replay")) and not ["", "ledger"].has(str(pl["tier"])):
		(world.get("jobs") as RefCounted).call("want", i)     # already near: no tier event will ask for it
	if not first and not bool(world.get("is_replay")):
		var ev: Dictionary = {"t": t, "e": "reload", "plot": str(pl["id"])}
		(sched.get("log") as Array).append(ev)  # in the world log: a replay applies it at the same tick
		world.call("_on_event", ev)
	print("[site] lot %d: %s %s arrives on plot %s at world tick %d" % [int(s["lot"]), str(pr["packId"]), str(pr["version"]), str(pl["id"]), t])


## The view of the site of lot `k` (site/draw.gd asks every frame): the log's fold plus where the site stands.
func view_of(k: int) -> Dictionary:
	for s: Dictionary in sites:
		if int(s["lot"]) == k:
			var v: Dictionary = (s["view"] as Dictionary).duplicate()
			v["arrived"] = not str(s["arrived_dir"]).is_empty()
			v["plot"] = int(s["plot"])
			v["radius"] = float(s["radius"])            # S4: the lot as it is now (refitted when the game is measured)
			return v
	return {}


## The lot `k` is a construction site (its log was found): the landscape draws it as a site, not as a plain lot.
func is_site(k: int) -> bool:
	for s: Dictionary in sites:
		if int(s["lot"]) == k:
			return true
	return false


func report() -> Array:
	var out: Array = []
	for s: Dictionary in sites:
		var v: Dictionary = s["view"]
		var pk: Array = []
		for b: Dictionary in v["packages"]:
			pk.append("%s:%s%s" % [str(b["id"]), str(b["state"]), "+merged" if bool(b["merged"]) else ""])
		var r: Dictionary = {"lot": int(s["lot"]), "job": str(s["job"]), "mode": "replay" if int(s["tpe"]) > 0 else "live",
			"events": int(s["n"]), "events_in_file": (s["log"] as RefCounted).get("events").size(), "stage": str(v["stage"]),
			"title": str(v["title"]), "built": int(v["built"]), "total": int(v["total"]), "job_state": str(v["job_state"]),
			"packages": pk, "stage_ticks": s["stage_ticks"], "radius": float(s["radius"]), "reads": int(s["reads"]), "read_ms": snappedf(float(int(s["read_us"])) / 1000.0, 0.01)}
		if int(s["plot"]) >= 0:
			r["plot"] = str(((world.get("plot_defs") as Array)[int(s["plot"])] as Dictionary)["id"])
		if s.has("fit"):
			r["fit"] = str(s["fit"])
		if s.has("lot_from"):
			r["lot_from"] = str(s["lot_from"])
		if s.has("pad_h"):
			r["pad_h"] = s.pad_h
		r["at"] = [float((s["at"] as Array)[0]), float((s["at"] as Array)[2])]
		for key: String in ["radius_before", "measured_m", "measure_ms", "refit_ms"]:
			if s.has(key):
				r[key] = s[key]
		if not str(s["arrived_dir"]).is_empty():
			r["arrived"] = str(s["arrived_dir"]).get_file()
			r["arrived_at"] = int(s["arrived_at"])
		if not str((s["log"] as RefCounted).get("error")).is_empty():
			r["log_error"] = str((s["log"] as RefCounted).get("error"))
		out.append(r)
	return out


func _warn(text: String) -> void:
	warnings.append(text)
	print("[site] warning: " + text)


func _on_ended(_bad: bool) -> void:
	print("[site] " + JSON.stringify({"sites": report(), "warnings": warnings}, "", false))
