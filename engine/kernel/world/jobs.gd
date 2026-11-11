extends RefCounted
## P5. The build queue of a scheduled world (kernel/world/world.gd owns one; TIERS.md "Loading" has the model and
## the measured numbers). Loading is not simulation: a pack that is still being built is `unbuilt` for the scheduler,
## and the tick boundary it arrives on is an event (`built`) in the world log, so a replay does the same.
##
## A pack is built in two parts:
##   PREPARE  on this queue's worker thread: every script of the pack is loaded (parsed and compiled) and every
##            `tl.layout/1` file under its data/ is built ahead by the kit (TLKit.build_layout_ahead: the venue's
##            meshes, bodies and rigs, off the scene tree). This is 95 to 99 % of a seed's loading time.
##   ATTACH   on the main thread, at a tick boundary: the holder is made, `_pack_setup` runs (its `build_layout`
##            calls find the layouts built ahead and only attach them), the laws are applied. The pack's first tick
##            is the next one (the one-tick rest of N7).
## Order: the tier first (stage, sideline, backdrop), then the distance to the player. A plot in `ledger` is not built.
##
## Modes (tiers.json `load.mode`; the walk or `--load=` may override):
##   queue  attach what is ready, at least one pack per tick, more while this tick's attaches used less than
##          `load.budget_ms`. The arrival tick depends on the machine: for a world somebody looks at.
##   step   one pack per world tick in queue order, built whole on the main thread (the worker is not used: it would
##          only be waited for): the arrival tick is a pure function of the walk (time is physics frames). For
##          scripted runs without a window.
##   wait   as step, but prepared on the worker and waited for: the worker's path with arrival ticks that do not
##          depend on the machine (the selftest case world.queue; a window-less run is over before a worker is done).
##   auto   `queue` in a window, `step` without one. `block` (no queue at all: every pack before the first tick,
##          as before P5) is handled by world.gd: it makes no queue.
## No global class name is used here.

const PackScript: GDScript = preload("res://kernel/world/pack.gd")
const PlotFile: GDScript = preload("res://kernel/world/plotfile.gd")

var world: Node
var mode: String = "queue"
var budget_us: int = 4000
var scenery: String = "plot"
var edits: Array = []                   # the walk's `edits`: [[tick, file, replacement file]], a scripted "the designer saved a value"
var built: Array = []                   # [[plot id, world tick, ms since the world started, prepare ms, attach ms]]
var forced: Array = []                  # P12: [[plot id, world tick, ms the main thread blocked, "stage" | "end"]]
var _jobs: Dictionary = {}              # plot index -> job
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _sem: Semaphore = Semaphore.new()
var _quit: bool = false
var _t0: int = 0
var _waited_ms: float = 0.0             # main thread time spent waiting for the worker (step mode, replays)
var _early: Array = []                  # plots built by `now` before the first tick: their `built` event is logged on it
var _spent_usec: int = 0                # step mode and replays: what this tick spent on loading (the wait and the attach)
var _step_usec: int = 0                 # the same, summed over the run: it is loading time (`load_ms`), not tick time


func setup(world_node: Node, load_cfg: Dictionary, resolved_mode: String, scenery_: String, edit_list: Variant) -> void:
	world = world_node
	mode = resolved_mode
	budget_us = int(float(load_cfg.get("budget_ms", 4.0)) * 1000.0)
	scenery = scenery_
	_t0 = Time.get_ticks_usec()
	if typeof(edit_list) == TYPE_ARRAY:
		for e: Variant in edit_list:
			if typeof(e) == TYPE_ARRAY and (e as Array).size() == 3:
				edits.append([int((e as Array)[0]), str((e as Array)[1]), str((e as Array)[2])])
	_thread = Thread.new()
	_thread.start(_run)


## Plot `i` must be in memory. `again`: also when it is (a next round, a reload): the pack there stays until the new
## one is attached. `rec`: {ticks, data} of the plot (its record in the ledger, or what the old pack leaves).
func want(i: int, again: bool = false, rec: Dictionary = {}) -> void:
	var p: Node = (world.get("packs") as Array)[i]
	var def: Dictionary = (world.get("plot_defs") as Array)[i]
	if (world.get("_dead") as PackedStringArray).has(str(i)) or (p.get("manifest") as Dictionary).is_empty():
		return
	_mutex.lock()
	var job: Variant = _jobs.get(i, null)
	if job != null:
		(job as Dictionary)["cancelled"] = false
		if again:
			(job as Dictionary)["rec"] = rec
		_mutex.unlock()
		return
	_mutex.unlock()
	if bool(p.get("loaded")) and not bool(p.get("ledgered")) and not again:
		return
	if rec.is_empty():
		var kept: Dictionary = (world.get("ledger") as Dictionary).get(i, {})
		rec = {"ticks": int(kept.get("ticks", def.get("ticks_before", 0))), "data": kept.get("data", def.get("data", null))}
	var j: Dictionary = {"i": i, "dir": str(p.get("pack_dir")), "manifest": p.get("manifest"), "state": "queued", "keys": [],
		"prio": 0.0, "rec": rec, "cancelled": false, "prep_ms": 0.0, "asked_usec": Time.get_ticks_usec()}
	_mutex.lock()
	_jobs[i] = j
	_mutex.unlock()
	if mode != "step":
		_sem.post()                         # step mode builds on the main thread, one pack per tick: the worker would only be waited for


## Plot `i` went to the ledger before it arrived.
func cancel(i: int) -> void:
	_mutex.lock()
	if _jobs.has(i):
		(_jobs[i] as Dictionary)["cancelled"] = true
	_mutex.unlock()


func pending() -> int:
	return _jobs.size()


func _prioritise() -> void:
	var sched: RefCounted = world.get("sched")
	var plots: Array = sched.get("plots")
	var pos: Vector3 = world.get("player_pos")
	_mutex.lock()
	for i: int in _jobs:
		var pl: Dictionary = plots[i]
		var rank: int = maxi(0, (["stage", "sideline", "backdrop"] as Array).find(str(pl["tier"])))
		(_jobs[i] as Dictionary)["prio"] = float(rank) * 100000.0 + float(sched.call("distance", pl, pos))
	_mutex.unlock()


func _best(states: Array) -> Dictionary:
	var best: Dictionary = {}
	_mutex.lock()
	for i: int in _jobs:
		var j: Dictionary = _jobs[i]
		if states.has(str(j["state"])) and not bool(j["cancelled"]) and (best.is_empty() or float(j["prio"]) < float(best["prio"])):
			best = j
	_mutex.unlock()
	return best


## Once per world tick of a live run, after the scheduler's decisions: attaches what the mode allows. Each arrival is
## the event `built` (world.gd then calls `attach`).
func pump(tick: int) -> void:
	for e: Array in edits:
		if int(e[0]) == tick:
			DirAccess.copy_absolute(str(e[2]), str(e[1]))
	for i: int in _early.duplicate():
		world.call("_on_event", (world.get("sched") as RefCounted).call("mark_built", tick, i))
	if _jobs.is_empty():
		return
	_prioritise()
	_sweep()
	var sched: RefCounted = world.get("sched")
	if mode == "queue":
		_force_needed(tick, sched)
	var used: int = 0
	while used < budget_us:
		var job: Dictionary = _best(["ready"] if mode == "queue" else ["ready", "queued", "preparing"])
		if job.is_empty():
			break
		var t: int = Time.get_ticks_usec()
		world.call("_on_event", sched.call("mark_built", tick, int(job["i"])))
		used += Time.get_ticks_usec() - t
		if mode != "queue":
			break


## P12. A game that is needed is there: in queue mode a plot on `stage` (the visitor entered it, a walk event put it
## there) that is not built yet jumps the queue and is built now, and on the walk's last tick every game still
## wanted is built (it arrives with no tick of its own, which the proof accepts). The main thread blocks for it:
## counted in `forced` and `forced_ms`. Each is an ordinary `built` event, so a replay does the same.
func _force_needed(tick: int, sched: RefCounted) -> void:
	var last: bool = tick >= int(world.get("walk_ticks")) - 1
	var plots: Array = sched.get("plots")
	var need: Array = []
	_mutex.lock()
	for i: int in _jobs:
		var j: Dictionary = _jobs[i]
		if not bool(j["cancelled"]) and (last or str((plots[i] as Dictionary)["tier"]) == "stage"):
			need.append(i)
	_mutex.unlock()
	need.sort()
	for i: int in need:
		var t: int = Time.get_ticks_usec()
		world.call("_on_event", sched.call("mark_built", tick, i))
		forced.append([str(((world.get("plot_defs") as Array)[i] as Dictionary)["id"]), tick, snappedf(float(Time.get_ticks_usec() - t) / 1000.0, 0.1), "end" if last else "stage"])


## Jobs that were cancelled and are not on the worker any more: what was built ahead for them is freed.
func _sweep() -> void:
	var gone: Array = []
	_mutex.lock()
	for i: int in _jobs:
		var j: Dictionary = _jobs[i]
		if bool(j["cancelled"]) and str(j["state"]) != "preparing":
			gone.append(j)
	for j: Dictionary in gone:
		_jobs.erase(int(j["i"]))
	_mutex.unlock()
	for j: Dictionary in gone:
		for k: String in j["keys"]:
			drop_ahead(k)


## The main-thread half, at the tick boundary of the `built` event: waits for the worker when it is not done (a
## replay, step mode), then builds the holder. What was built ahead and not asked for by the pack is freed.
func attach(i: int, tick: int) -> void:
	if _early.has(i):
		_early.erase(i)                     # it is there already (`now`): this is only its event
		return
	if not _jobs.has(i):
		want(i, true)                       # a log says it arrives here: build it whatever this run thinks of it
	if not _jobs.has(i):
		return
	var job: Dictionary = _jobs[i]
	var w0: int = Time.get_ticks_usec()
	while true:
		_mutex.lock()
		var st: String = str(job["state"])
		job["cancelled"] = false
		if st == "queued" and mode == "wait":
			job["prio"] = -1.0              # the worker takes it next
		elif st == "queued":
			job["state"] = "ready"          # the worker has not begun it: it is built here, whole, as before P5
			st = "ready"
		_mutex.unlock()
		if st == "ready":
			break
		# The worker's calls into the rendering and physics servers that return a value wait for THIS thread to run
		# them (the servers' command queues): a main thread that only sleeps here would wait for ever.
		RenderingServer.force_sync()
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)
		OS.delay_usec(200)
	_waited_ms += float(Time.get_ticks_usec() - w0) / 1000.0
	var t: int = Time.get_ticks_usec()
	var def: Dictionary = (world.get("plot_defs") as Array)[i]
	def["go"] = true
	TLRigs._record_rigs(true)
	TLKit._record_parts(true)
	world.call("_rebuild", i, job["rec"])
	remember_rigs(str(job["dir"]), TLRigs._record_rigs(false), TLKit._record_parts(false))
	def.erase("go")
	var left: int = 0
	for k: String in job["keys"]:
		if drop_ahead(k):
			left += 1
	_mutex.lock()
	_jobs.erase(i)
	_mutex.unlock()
	var now: int = Time.get_ticks_usec()
	if mode != "queue" or bool(world.get("is_replay")):
		_spent_usec += now - w0
		_step_usec += now - w0
	built.append([str(def["id"]), tick, snappedf(float(now - _t0) / 1000.0, 0.1), job["prep_ms"], snappedf(float(now - t) / 1000.0, 0.01), left])


## Step mode and replays wait for a pack inside a tick: that time is loading, not simulation. The world takes it out
## of the tick's time and adds it to `load_ms`. In queue mode nothing is taken out: an arrival's frame is what it was.
func take_spent() -> int:
	var s: int = _spent_usec
	_spent_usec = 0
	return s


## Builds plot `i` at once, before the first tick: whoever draws the world needs the pack itself (view.gd, for a rim
## that is not in its cache). Its `built` event is logged on the first tick.
func now(i: int) -> void:
	want(i, true)
	if _jobs.has(i):
		attach(i, 0)
		_early.append(i)


func stop() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_quit = true
	_mutex.unlock()
	_sem.post()
	while _thread.is_alive():          # a worker in the middle of a build needs this thread to run its server calls (see `attach`)
		RenderingServer.force_sync()
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)
		OS.delay_usec(200)
	_thread.wait_to_finish()
	_thread = null
	for i: int in _jobs:
		for k: String in (_jobs[i] as Dictionary)["keys"]:
			drop_ahead(k)
	_jobs.clear()


## What the world line says about loading.
func report() -> Dictionary:
	var attach_ms: Array = []
	var prep_ms: Array = []
	for b: Array in built:
		prep_ms.append(float(b[3]))
		attach_ms.append(float(b[4]))
	attach_ms.sort()
	prep_ms.sort()
	var out: Dictionary = {"mode": mode, "budget_ms": float(budget_us) / 1000.0, "built": built.size(), "waited_ms": snappedf(_waited_ms, 0.1),
		"never_built": _jobs.size(), "in_ticks_ms": snappedf(float(_step_usec) / 1000.0, 0.1), "arrivals": built}
	if mode == "queue":
		var f_ms: float = 0.0
		for f: Array in forced:
			f_ms += float(f[2])
		out["forced"] = forced.size()
		out["forced_ms"] = snappedf(f_ms, 0.1)
		out["forced_list"] = forced
	if not built.is_empty():
		out["first_built_ms"] = (built[0] as Array)[2]
		out["six_built_ms"] = (built[mini(5, built.size() - 1)] as Array)[2]
		out["all_built_ms"] = (built[built.size() - 1] as Array)[2]
		out["attach_ms_p50"] = attach_ms[attach_ms.size() / 2]
		out["attach_ms_max"] = attach_ms[attach_ms.size() - 1]
		out["prepare_ms_p50"] = prep_ms[prep_ms.size() / 2]
		out["prepare_ms_max"] = prep_ms[prep_ms.size() - 1]
	return out


# ------------------------------------------------------------------------------------------------ the worker thread
func _run() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _quit:
			_mutex.unlock()
			return
		var job: Dictionary = {}
		for i: int in _jobs:
			var j: Dictionary = _jobs[i]
			if str(j["state"]) == "queued" and not bool(j["cancelled"]) and (job.is_empty() or float(j["prio"]) < float(job["prio"])):
				job = j
		if not job.is_empty():
			job["state"] = "preparing"
		_mutex.unlock()
		if job.is_empty():
			continue
		var t: int = Time.get_ticks_usec()
		var keys: Array = prepare(str(job["dir"]), job["manifest"], scenery)
		_mutex.lock()
		job["keys"] = keys
		job["prep_ms"] = snappedf(float(Time.get_ticks_usec() - t) / 1000.0, 0.1)
		job["state"] = "ready"
		_mutex.unlock()


## Everything of a pack's build that needs no scene tree and no pack on the stack. Returns the keys of the layouts
## built ahead. Runs on the worker thread; static so that a measurement can call it anywhere.
static func prepare(dir: String, m: Dictionary, scenery_: String) -> Array:
	var files: PackedStringArray = PackedStringArray()
	PlotFile.call("list_files", dir, "", files)
	for rel: String in files:
		if rel.get_extension() == "gd":
			TLContext._load_fresh(dir + "/" + rel)   # compiled here; `_pack_setup` and `ctx.load_script` find it (P12: as it is on disk now)
	var keys: Array = []
	var probe: TLContext = TLContext.new()      # reads a data file exactly as the pack's own `ctx.read_json` will
	probe.pack_dir = dir
	probe.manifest = m
	probe.scenery = scenery_
	for rel: String in files:
		if not rel.begins_with("data/") or rel.get_extension() != "json":
			continue
		if not FileAccess.get_file_as_string(dir + "/" + rel).contains("\"tl.layout/"):
			continue
		var v: Variant = probe.read_json(rel)
		if typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("schema", "")).begins_with("tl.layout/"):
			var key: String = TLKit.build_layout_ahead(v)
			if not key.is_empty():
				keys.append(key)
	for rc: Array in rigs_of(dir):              # P12: the rigs and parts this pack built the last time it was built
		var part: bool = (rc as Array).size() == 3
		var rk: String = TLKit._part_ahead(str(rc[0]), rc[1]) if part else TLRigs._rig_ahead(str(rc[0]), rc[1])
		if not rk.is_empty():
			keys.append(("part:" if part else "rig:") + rk)
	return keys


# ------------------------------------------------------------------- P12: rigs built ahead from the pack's last build
## Which rigs a pack builds is known only by building it: each attach records its `TLRigs.build` calls, kept in this
## process and in `user://tl_cache/rigs/<md5 of the directory>.txt`, and the next preparation of the same directory
## builds them ahead on the worker. A recipe that no longer fits (the pack changed) only costs the worker time: a rig
## built ahead whose call does not come is freed after the attach. Static, so a measurement can call it anywhere.
const RIGS_DIR: String = "user://tl_cache/rigs"
static var _recipes: Dictionary = {}
static var _recipes_lock: Mutex = Mutex.new()


static func rigs_of(dir: String) -> Array:
	_recipes_lock.lock()
	var got: Variant = _recipes.get(dir, null)
	_recipes_lock.unlock()
	if got != null:
		return got
	var f: String = RIGS_DIR + "/" + dir.md5_text() + ".txt"
	if not FileAccess.file_exists(f):
		return []
	var v: Variant = str_to_var(FileAccess.get_file_as_string(f))
	var out: Array = []
	if typeof(v) == TYPE_ARRAY:
		for c: Variant in v:
			if typeof(c) == TYPE_ARRAY and (c as Array).size() in [2, 3] and typeof((c as Array)[1]) == TYPE_DICTIONARY:
				out.append(c)
	_recipes_lock.lock()
	_recipes[dir] = out
	_recipes_lock.unlock()
	return out


## `rigs`: TLRigs.record's [family, params] calls; `parts`: TLKit.record's [kind, params] calls (kept as [kind, params, "part"]).
static func remember_rigs(dir: String, rigs: Array, parts: Array = []) -> void:
	var calls: Array = rigs.duplicate()
	for pc: Array in parts:
		calls.append([pc[0], pc[1], "part"])
	_recipes_lock.lock()
	var same: bool = _recipes.has(dir) and var_to_str(_recipes[dir]) == var_to_str(calls)
	_recipes[dir] = calls
	_recipes_lock.unlock()
	if same:
		return
	DirAccess.make_dir_recursive_absolute(RIGS_DIR)
	var f: FileAccess = FileAccess.open(RIGS_DIR + "/" + dir.md5_text() + ".txt", FileAccess.WRITE)
	if f != null:
		f.store_string(var_to_str(calls))
		f.close()


## Frees one thing built ahead (a layout, a rig: key "rig:<key>", a part: "part:<key>"). Main thread. True when there was one.
static func drop_ahead(k: String) -> bool:
	if k.begins_with("rig:"):
		return TLRigs._drop_rig(k.substr(4))
	if k.begins_with("part:"):
		return TLKit._drop_part(k.substr(5))
	return TLKit.drop_layout_ahead(k)
