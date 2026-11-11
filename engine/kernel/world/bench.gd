extends Node
## N2. The measurements of `tools/world.sh bench`: tests 1 to 9 of the layering report's table, as far as a headless
## run can take them. Every figure comes from a fresh `world` process (the same command `tools/world.sh run` makes);
## this node only starts them, compares their lines and writes kernel/world/BENCH.md and kernel/world/bench.json.
##
##   world.sh bench [--only=<part of a test name>] [--quick] [--out-dir=<dir>]
##
## Times are wall-clock medians of one whole loop iteration (the kernel's calls into every pack, the scene tree's
## tick of their nodes, the step of every active physics space; headless, so no drawing). Timed runs are taken twice
## and the lower median is kept, because other processes use this machine.

const SEEDS: Array = ["seed_wall", "seed_drive", "seed_paddle"]
const BUDGET_PHYSICS_MS: float = 2.0       # the project's physics budget (a target, not a measured capacity)
const BUDGET_FRAME_MS: float = 16.7        # one 60 Hz frame
const BUDGET_VERIFY_MS: float = 8.0        # the V3 frame budget of one pack (host.gd BUDGET_FRAME_MS_P99)

var opts: Dictionary = {}
var engine_dir: String = ""
var out_dir: String = ""
var quick: bool = false
var md: PackedStringArray = PackedStringArray()
var data: Dictionary = {"schema": "tl.world.bench/1", "tests": {}}
var runs: int = 0
var total_leaks: int = 0
var total_wrong: int = 0
var total_limit_warnings: int = 0
var total_errors: int = 0
var warning_texts: Array = []
var probe_calls: int = 0
var probe_ticks: int = 0
var empty_ms: float = 0.0


func start(options: Dictionary) -> void:
	opts = options
	quick = opts.has("quick")
	engine_dir = ProjectSettings.globalize_path("res://").trim_suffix("/")
	out_dir = str(opts.get("out-dir", engine_dir + "/kernel/world"))
	call_deferred("_run_all")


# ------------------------------------------------------------------------------------------------------ running
func _dir(pack: String) -> String:
	for base: String in ["seeds", "kernel/examples", "kernel/world/packs", "packs"]:
		if DirAccess.dir_exists_absolute(engine_dir + "/" + base + "/" + pack):
			return engine_dir + "/" + base + "/" + pack
	return pack


func _copies(pack: String, n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(pack)
	return out


## One world process. `packs` are bare names; `args` the other options. Returns {packs: [...], world: {...}, cmd}.
func _world(packs: Array, args: Dictionary) -> Dictionary:
	var dirs: PackedStringArray = PackedStringArray()
	for p: Variant in packs:
		dirs.append(_dir(str(p)))
	var argv: PackedStringArray = PackedStringArray(["--headless", "--fixed-fps", "60", "--path", engine_dir,
		"res://kernel/host/host.tscn", "--", "world", "--packs=" + ",".join(dirs)])
	var shown: String = ",".join(PackedStringArray(packs))
	if packs.size() > 12:                # too long to print: say what the list is (the names, comma-separated)
		var kinds: Dictionary = {}
		for p: Variant in packs:
			kinds[str(p)] = int(kinds.get(str(p), 0)) + 1
		var parts: PackedStringArray = PackedStringArray()
		for k: String in kinds.keys():
			parts.append("%d x %s" % [int(kinds[k]), k] if int(kinds[k]) > 1 else k)
		shown = "<" + ", ".join(parts) + ">"
	var cmd: String = "bash tools/world.sh run --packs=" + shown
	for k: String in args.keys():
		argv.append("--%s=%s" % [k, str(args[k])])
		cmd += " '--%s=%s'" % [k, str(args[k])] if str(args[k]).contains(";") else " --%s=%s" % [k, str(args[k])]
	var out: Array = []
	OS.execute(OS.get_executable_path(), argv, out, false)
	runs += 1
	var res: Dictionary = {"packs": [], "world": {}, "cmd": cmd}
	for line: String in str(out[0] if not out.is_empty() else "").split("\n"):
		var t: String = line.strip_edges()
		if not t.begins_with("{\"schema\":\"tl.world/1\""):
			continue
		var parsed: Variant = JSON.parse_string(t)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if str((parsed as Dictionary).get("kind", "")) == "pack":
			(res["packs"] as Array).append(parsed)
		else:
			res["world"] = parsed
	var w: Dictionary = res["world"]
	total_leaks += int(w.get("gate_leaks", 0))
	total_wrong += int(w.get("wrong_pack_calls", 0))
	total_limit_warnings += int(w.get("contact_or_body_limit_warnings", 0))
	total_errors += int(w.get("script_errors", 0)) + int(w.get("engine_errors", 0))
	for t: Variant in w.get("warning_texts", []):
		if not warning_texts.has(str(t)) and warning_texts.size() < 12:
			warning_texts.append(str(t))
	for p: Dictionary in res["packs"]:
		probe_calls += int(p.get("probe_physics_calls", 0))
		probe_ticks += int(p.get("frames", 0))
	print("[bench] run %d: %s" % [runs, cmd])
	return res


func _hashes(run: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in run["packs"]:
		out.append(str(p.get("state_hash", "")).substr(0, 16))
	return out


func _ms(run: Dictionary, key: String) -> float:
	return float((run["world"] as Dictionary).get(key, 0.0))


## The lower of two runs' medians (other processes use this machine).
func _timed(packs: Array, args: Dictionary, key: String) -> Array:
	var a: Dictionary = _world(packs, args)
	if quick:
		return [_ms(a, key), a]
	var b: Dictionary = _world(packs, args)
	return [minf(_ms(a, key), _ms(b, key)), a if _ms(a, key) <= _ms(b, key) else b, maxf(_ms(a, key), _ms(b, key))]


func _want(test: String) -> bool:
	return not opts.has("only") or test.contains(str(opts["only"]))


func _f(v: float, digits: int = 3) -> String:
	return ("%." + str(digits) + "f") % v


func _row(cells: Array) -> void:
	var texts: PackedStringArray = PackedStringArray()
	for c: Variant in cells:
		texts.append(str(c))
	md.append("| " + " | ".join(texts) + " |")


func _head(cells: Array) -> void:
	_row(cells)
	var dashes: Array = []
	for c: Variant in cells:
		dashes.append("---")
	_row(dashes)


func _cmd(run: Dictionary) -> void:
	md.append("")
	md.append("`" + str(run["cmd"]) + "`")
	md.append("")


# ------------------------------------------------------------------------------------------------------ tests
func _run_all() -> void:
	var t0: int = Time.get_ticks_msec()
	md.append("# N2 bench: several packs in one process")
	md.append("")
	md.append("Written by `bash tools/world.sh bench` (kernel/world/bench.gd) on %s. Godot %s, Jolt, 60 Hz, headless, %s." % [
		Time.get_datetime_string_from_system(false, true), Engine.get_version_info()["string"], OS.get_processor_name()])
	md.append("Every figure is from a fresh process started with the command printed under its table; nothing here is")
	md.append("estimated. Times are medians of one whole loop iteration (kernel calls into the packs, the scene tree's tick")
	md.append("of their nodes, the step of every active physics space); timed runs are taken twice and the lower median")
	md.append("is kept (the higher one is shown as \"worst\"), because other processes were using this machine.")
	md.append("")
	var empty: Dictionary = _world([], {"hold": 600})
	empty_ms = _ms(empty, "hold_iter_ms_p50")
	data["empty_loop_ms"] = empty_ms
	md.append("An empty world (no pack) costs %s ms per iteration; it is subtracted where a per-pack cost is given." % _f(empty_ms, 4))
	md.append("")
	if _want("cost"):
		_t_cost()
	if _want("bodies"):
		_t_bodies()
	if _want("asleep"):
		_t_asleep()
	if _want("neighbours"):
		_t_neighbours()
	if _want("offset"):
		_t_offset()
	if _want("pause"):
		_t_pause()
	if _want("slice"):
		_t_slice()
	_t_gating()
	data["runs"] = runs
	data["wall_s"] = float(Time.get_ticks_msec() - t0) / 1000.0
	md.append("")
	md.append("%d world processes, %s s." % [runs, _f(float(data["wall_s"]), 0)])
	var suffix: String = "" if not opts.has("only") else "_" + str(opts["only"])
	_store(out_dir + "/BENCH%s.md" % suffix, "\n".join(md) + "\n")
	_store(out_dir + "/bench%s.json" % suffix, JSON.stringify(data, "  ", false) + "\n")
	print("[bench] wrote %s/BENCH%s.md and bench%s.json" % [out_dir, suffix, suffix])
	get_tree().quit(0 if total_leaks == 0 and total_limit_warnings == 0 else 1)


func _store(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


## Cost per pack per tick at 1, 5, 10, 20 packs (the seeds, each played by its bot, every pack ticked every tick).
func _t_cost() -> void:
	md.append("## Cost per pack per tick (every pack ticked on every world tick)")
	md.append("")
	md.append("Each seed is played by its own bot for 400 ticks; k copies run in one process, each in its own space.")
	md.append("")
	_head(["packs", "what", "iteration ms (median)", "worst of two", "ms per pack", "packs inside %s ms" % _f(BUDGET_PHYSICS_MS, 0),
		"packs inside %s ms" % _f(BUDGET_FRAME_MS, 1)])
	var rows: Array = []
	var last: Dictionary = {}
	var counts: Array = [1, 5, 10, 20] if not quick else [1, 10]
	for name: String in SEEDS:
		for k: int in counts:
			var r: Array = _timed(_copies(name, k), {"mode": "bot", "frames": 400}, "iter_ms_p50_all_ticked")
			var per: float = maxf(0.0001, (float(r[0]) - empty_ms) / float(k))
			_row([k, name, _f(float(r[0])), _f(float(r[2])) if r.size() > 2 else "", _f(per), int(floor(BUDGET_PHYSICS_MS / per)), int(floor(BUDGET_FRAME_MS / per))])
			rows.append({"packs": k, "pack": name, "iter_ms_p50": r[0], "ms_per_pack": per})
			last = r[1]
	var mix: Array = []
	for i: int in 20:
		mix.append(SEEDS[i % 3])
	var rm: Array = _timed(mix, {"mode": "bot", "frames": 400}, "iter_ms_p50_all_ticked")
	var per_mix: float = maxf(0.0001, (float(rm[0]) - empty_ms) / 20.0)
	_row([20, "7 wall + 7 drive + 6 paddle", _f(float(rm[0])), _f(float(rm[2])) if rm.size() > 2 else "", _f(per_mix),
		int(floor(BUDGET_PHYSICS_MS / per_mix)), int(floor(BUDGET_FRAME_MS / per_mix))])
	rows.append({"packs": 20, "pack": "mix", "iter_ms_p50": rm[0], "ms_per_pack": per_mix})
	(data["tests"] as Dictionary)["cost_per_pack"] = rows
	data["mix_ms_per_pack"] = per_mix
	_cmd(rm[1])
	md.append("The last two columns divide a budget by the per-pack cost: how many such packs can be ticked on every world")
	md.append("tick. %s ms is the project's physics target, %s ms a whole 60 Hz frame with nothing drawn (headless)." % [_f(BUDGET_PHYSICS_MS, 0), _f(BUDGET_FRAME_MS, 1)])
	md.append("")


## Test 1: active bodies in one space.
func _t_bodies() -> void:
	md.append("## Test 1: active bodies in one space")
	md.append("")
	md.append("The bench pack `w_pile` (kernel/world/packs/w_pile; the seed is the body count) keeps N wooden boxes awake by")
	md.append("throwing some of them every fourth tick. Every box comes from `TLBodies.make`, so each carries the kernel's")
	md.append("contact tracker (a GDScript `_physics_process` with a ray query), like every dynamic body of a real pack.")
	md.append("")
	_head(["bodies", "awake at end", "iteration ms (median)", "worst of two", "kernel calls ms", "inside the %s ms target" % _f(BUDGET_PHYSICS_MS, 0),
		"inside the %s ms V3 budget" % _f(BUDGET_VERIFY_MS, 0)])
	var rows: Array = []
	var last: Dictionary = {}
	for n: int in ([50, 150, 300, 600] if not quick else [50, 600]):
		var r: Array = _timed(["w_pile"], {"seeds": n, "frames": 400}, "iter_ms_p50_all_ticked")
		var p: Dictionary = ((r[1] as Dictionary)["packs"] as Array)[0]
		_row([n, int(p.get("awake_bodies_at_end", 0)), _f(float(r[0])), _f(float(r[2])) if r.size() > 2 else "", _f(_ms(r[1], "kernel_ms_p50")),
			"yes" if float(r[0]) <= BUDGET_PHYSICS_MS else "NO", "yes" if float(r[0]) <= BUDGET_VERIFY_MS else "NO"])
		rows.append({"bodies": n, "awake": int(p.get("awake_bodies_at_end", 0)), "iter_ms_p50": r[0]})
		last = r[1]
	(data["tests"] as Dictionary)["active_bodies"] = rows
	_cmd(last)
	md.append("One or several worker threads was not varied (the project setting was left as it is).")
	md.append("")


## Tests 2 and 3: asleep packs in active spaces, then the same packs switched off.
func _t_asleep() -> void:
	md.append("## Tests 2 and 3: packs asleep, and packs switched off")
	md.append("")
	md.append("k copies of `w_pile` with seed 10030: 30 boxes that are left alone, settle and fall asleep. 900 ticks with")
	md.append("every space active and every pack ticked (the figure is the median of the last third, when all are asleep),")
	md.append("then 300 world ticks with every pack switched off (holder disabled, space inactive).")
	md.append("")
	_head(["packs", "bodies in all", "awake at end", "asleep, ticked: iteration ms", "per pack ms", "switched off: iteration ms",
		"per pack ms", "static memory per pack (kB)"])
	var rows: Array = []
	var last: Dictionary = {}
	for k: int in ([10, 30, 60] if not quick else [10]):
		var r: Dictionary = _world(_copies("w_pile", k), {"seeds": 10030, "frames": 900, "hold": 300})
		var awake: int = 0
		var bodies: int = 0
		for p: Dictionary in r["packs"]:
			awake += int(p.get("awake_bodies_at_end", 0))
			bodies += int(p.get("bodies_max", 0))
		var asleep_ms: float = _ms(r, "iter_ms_p50_last_third")
		var off_ms: float = _ms(r, "hold_iter_ms_p50")
		_row([k, bodies, awake, _f(asleep_ms), _f((asleep_ms - empty_ms) / float(k), 4), _f(off_ms, 4), _f(maxf(0.0, off_ms - empty_ms) / float(k), 5),
			int((r["world"] as Dictionary).get("static_mem_per_pack_kb", 0))])
		rows.append({"packs": k, "bodies": bodies, "awake_at_end": awake, "asleep_iter_ms": asleep_ms, "off_iter_ms": off_ms,
			"static_mem_per_pack_kb": int((r["world"] as Dictionary).get("static_mem_per_pack_kb", 0))})
		last = r
	(data["tests"] as Dictionary)["asleep_and_off"] = rows
	_cmd(last)
	md.append("Static memory is Godot's own allocator (`OS.get_static_memory_usage`) after loading, divided by the packs; it")
	md.append("does not include what Jolt allocates for a space, and the OS working set was not read. `max_bodies` was left")
	md.append("at the project default.")
	md.append("")


## Test 4: hash stability against neighbours.
func _t_neighbours() -> void:
	md.append("## Test 4: a pack's hash against its neighbours")
	md.append("")
	var rows: Array = []
	var alone: Dictionary = {}
	for name: String in SEEDS:
		alone[name] = _hashes(_world([name], {"mode": "bot", "frames": 36000}))[0]
	_head(["run", "packs in the process (each in its own space, all at the origin)", "seed_wall", "seed_drive", "seed_paddle", "verdict"])
	_row(["alone", "one process each", alone["seed_wall"], alone["seed_drive"], alone["seed_paddle"], "the reference"])
	var all_same: bool = true
	var orders: Array = [["seed_wall", "seed_drive", "seed_paddle"], ["seed_paddle", "seed_drive", "seed_wall"],
		["seed_drive", "seed_wall", "seed_wall", "seed_paddle", "seed_wall"]]
	var last: Dictionary = {}
	for rep: int in (3 if not quick else 1):
		for order: Array in orders:
			var r: Dictionary = _world(order, {"mode": "bot", "frames": 36000})
			var h: PackedStringArray = _hashes(r)
			var same: bool = h.size() == order.size()
			var seen: Dictionary = {}
			for i: int in h.size():
				same = same and h[i] == str(alone[order[i]])
				seen[order[i]] = h[i] if not seen.has(order[i]) or str(seen[order[i]]) == h[i] else "MIXED"
			all_same = all_same and same
			_row([rep + 1, ", ".join(PackedStringArray(order)), seen.get("seed_wall", ""), seen.get("seed_drive", ""), seen.get("seed_paddle", ""),
				"same" if same else "DIFFERENT"])
			rows.append({"order": order, "hashes": h, "same": same})
			last = r
	_cmd(last)
	md.append("Bot runs to the end of each bot (wall 1221 ticks, drive 3516, paddle 6776). %s" % (
		"Every hash equals the solo hash in every run: a pack in its own space does not feel its neighbours, whatever the order they were added in."
		if all_same else "NOT every hash equals the solo hash: see the rows marked DIFFERENT."))
	md.append("The table's 20 runs and the varied job-thread count were not done: %d runs per order here." % (3 if not quick else 1))
	md.append("")
	# the control the report asks for: the same pack with a neighbour in the SAME space
	var a0: String = _hashes(_world(["ex_bounce"], {"frames": 1800}))[0]
	var s0: String = _hashes(_world(["ex_bounce"], {"frames": 1800, "space": "shared"}))[0]
	var s1: Dictionary = _world(["ex_bounce", "seed_wall"], {"frames": 1800, "space": "shared", "at": "0:0:0,300:0:0", "mode": "bot"})
	var s2: Dictionary = _world(["seed_wall", "ex_bounce"], {"frames": 1800, "space": "shared", "at": "300:0:0,0:0:0", "mode": "bot"})
	var o0: String = _hashes(_world(["ex_bounce"], {"frames": 1800, "mode": "bot"}))[0]
	_head(["ex_bounce at the origin", "state hash", "against its own-space run"])
	_row(["alone, own space, idle", a0, "the reference (idle)"])
	_row(["alone, the shared default space, idle", s0, "same" if s0 == a0 else "DIFFERENT"])
	_row(["alone, own space, bot", o0, "the reference (bot)"])
	_row(["shared space, seed_wall (bot) 300 m away, added after", _hashes(s1)[0], "same" if _hashes(s1)[0] == o0 else "DIFFERENT"])
	_row(["shared space, seed_wall (bot) 300 m away, added before", _hashes(s2)[1], "same" if _hashes(s2)[1] == o0 else "DIFFERENT"])
	_cmd(s2)
	(data["tests"] as Dictionary)["neighbours"] = {"all_same_in_own_spaces": all_same, "rows": rows,
		"same_space": {"alone_own": o0, "with_neighbour_after": _hashes(s1)[0], "with_neighbour_before": _hashes(s2)[1]}}
	md.append("")


func _first_difference(a: Dictionary, b: Dictionary) -> String:
	var ta: Array = a.get("hash_trace", [])
	var tb: Array = b.get("hash_trace", [])
	for i: int in mini(ta.size(), tb.size()):
		if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
			return "by tick %d" % int((ta[i] as Array)[0])
	if int(a.get("frames", 0)) != int(b.get("frames", 0)):
		return "the run has another length (%d against %d ticks)" % [int(b.get("frames", 0)), int(a.get("frames", 0))]
	return "after the last traced tick"


## Test 5: the same pack simulated away from the origin (way a: bodies at their world position in the pack's space).
func _t_offset() -> void:
	md.append("## Test 5: a pack away from the origin")
	md.append("")
	md.append("Way (a): the pack's holder stands at the offset, so its bodies are simulated at their world position inside")
	md.append("the pack's own space; the hash is taken relative to the holder. Way (b) is the row at 0, 0, 0: bodies at the")
	md.append("pack-local origin (in every other table of this file all packs stand at the origin of their own space, on top")
	md.append("of each other, and do not meet). Each cell: `same` when the hash equals the origin's, else where the hash trace")
	md.append("(every 60 ticks) first differs.")
	md.append("")
	md.append("`w_pile` has no world coordinate in its code (it places boxes with `position` and its state is three counts),")
	md.append("so its two columns show the arithmetic alone: 300 boxes kept awake, and 100 boxes left to fall asleep.")
	md.append("")
	var packs: Array = ["w_pile", "w_pile", "ex_bounce", "ex_wall", "ex_car", "ex_walker", "ex_slide", "seed_wall", "seed_drive", "seed_paddle"]
	var offsets: Array = ["0:0:0", "64:0:0", "1000:0:0", "2000:0:3000", "4000:0:4000", "10000:0:0"] if not quick else ["0:0:0", "1000:0:0"]
	var head: Array = ["offset (m)", "w_pile, 300 awake", "w_pile, 100 asleep"]
	head.append_array(packs.slice(2))
	_head(head)
	var base: Dictionary = {}
	var rows: Array = []
	var last: Dictionary = {}
	for off: String in offsets:
		var r: Dictionary = _world(packs, {"mode": "bot", "frames": 7200, "at": off, "trace": 60, "seeds": "300,10100,1"})
		if off == "0:0:0":
			base = r
		var cells: Array = [off.replace(":", ", ")]
		var rec: Dictionary = {"at": off}
		for i: int in (r["packs"] as Array).size():
			var p: Dictionary = (r["packs"] as Array)[i]
			var b: Dictionary = (base["packs"] as Array)[i]
			var bot_ok: bool = bool(((p.get("bot", {}) as Dictionary).get("result", {}) as Dictionary).get("ok", false))
			var text: String = str(p["state_hash"]).substr(0, 8) if off == "0:0:0" else (
				"same" if str(p["state_hash"]) == str(b["state_hash"]) else "differs " + _first_difference(b, p))
			if not bot_ok:
				text += "; BOT FAILS"
			cells.append(text)
			rec[str(head[i + 1])] = text
		_row(cells)
		rows.append(rec)
		last = r
	(data["tests"] as Dictionary)["offset"] = rows
	_cmd(last)
	md.append("Reading the table. The `w_pile` columns are rounding and nothing else: single-precision positions are coarser")
	md.append("away from the origin, a contact resolves a hair differently, and a pile of boxes amplifies it. \"By tick 0\" in")
	md.append("those columns means that even the starting positions no longer round to the same millimetre. The other")
	md.append("columns mix that with a second cause: the pack's own code reads world coordinates (`global_position` in")
	md.append("`_pack_state`, in its bot, or a literal position handed to a call that wants a world position). Where it says")
	md.append("BOT FAILS the game itself went wrong: the bot, which plays from `_pack_state`, could not finish.")
	md.append("")


## Test 6: pause and resume.
func _t_pause() -> void:
	md.append("## Test 6: pause and resume")
	md.append("")
	md.append("Each pack is played by its bot; at world tick 300 (bodies awake, mid-play) it is switched off for M world ticks")
	md.append("(holder `PROCESS_MODE_DISABLED`, `space_set_active(false)`), then switched on again and played to the end.")
	md.append("`w_pile` (seed 10100, 100 boxes left alone, 900 ticks, nobody playing) is switched off at tick 700, asleep.")
	md.append("")
	var packs: Array = ["seed_wall", "seed_drive", "seed_paddle", "ex_bounce", "ex_wall"]
	var base: Dictionary = _world(packs, {"mode": "bot", "frames": 36000})
	var pile0: Dictionary = _world(["w_pile"], {"seeds": 10100, "frames": 900})
	var head: Array = ["off for M world ticks"]
	head.append_array(packs)
	head.append("w_pile (asleep)")
	_head(head)
	var b: PackedStringArray = _hashes(base)
	var first: Array = ["0 (uninterrupted)"]
	for h: String in b:
		first.append(h)
	first.append(_hashes(pile0)[0])
	_row(first)
	var rows: Array = []
	var all_same: bool = true
	var last: Dictionary = {}
	for m: int in ([1, 60, 3600] if not quick else [60]):
		var pause: String = ""
		for i: int in packs.size():
			pause += "%s%d:300:%d" % ["" if i == 0 else ";", i, m]
		var r: Dictionary = _world(packs, {"mode": "bot", "frames": 36000, "pause": pause})
		var pr: Dictionary = _world(["w_pile"], {"seeds": 10100, "frames": 900, "pause": "0:700:%d" % m})
		var h: PackedStringArray = _hashes(r)
		var cells: Array = [m]
		for i: int in packs.size():
			var same: bool = i < h.size() and h[i] == b[i]
			all_same = all_same and same
			cells.append("same" if same else "DIFFERENT " + (h[i] if i < h.size() else ""))
		var pile_same: bool = _hashes(pr)[0] == _hashes(pile0)[0]
		all_same = all_same and pile_same
		cells.append("same" if pile_same else "DIFFERENT")
		_row(cells)
		rows.append({"off_ticks": m, "hashes": h, "pile": _hashes(pr)[0]})
		last = r
	(data["tests"] as Dictionary)["pause"] = {"all_same": all_same, "base": b, "rows": rows}
	_cmd(last)
	md.append("%s The variant that restores transforms and velocities by hand was not built." % (
		"Switching a pack off and on again is an exact pause here: every hash equals the uninterrupted run's." if all_same
		else "NOT every paused run equals the uninterrupted one."))
	md.append("")


## Test 7: a pack ticked on one world tick in N.
func _t_slice() -> void:
	md.append("## Test 7: a pack that gets one world tick in N")
	md.append("")
	md.append("The same packs and bots; every pack is ticked (and its space stepped) on one world tick in N and switched")
	md.append("off on the others, until it has had as many ticks of its own as the continuous run. `ex_bounce` has a")
	md.append("trigger (area signals), a spawner (bodies added while running) and rules; the bots read the HUD and audio.")
	md.append("")
	var packs: Array = ["seed_wall", "seed_drive", "seed_paddle", "ex_bounce", "ex_wall"]
	var base: Dictionary = _world(packs, {"mode": "bot", "frames": 36000})
	var b: PackedStringArray = _hashes(base)
	var head: Array = ["N"]
	head.append_array(packs)
	head.append("world ticks")
	head.append("iteration ms (median over all world ticks)")
	_head(head)
	var first: Array = ["1 (continuous)"]
	for h: String in b:
		first.append(h)
	first.append(int((base["world"] as Dictionary).get("world_ticks", 0)))
	first.append(_f(_ms(base, "iter_ms_p50")))
	_row(first)
	var rows: Array = []
	var all_same: bool = true
	var last: Dictionary = {}
	for n: int in ([2, 8, 30] if not quick else [8]):
		var r: Dictionary = _world(packs, {"mode": "bot", "frames": 36000, "every": n})
		var h: PackedStringArray = _hashes(r)
		var cells: Array = [n]
		for i: int in packs.size():
			var bp: Dictionary = (base["packs"] as Array)[i]
			var rp: Dictionary = (r["packs"] as Array)[i] if i < (r["packs"] as Array).size() else {}
			var same: bool = i < h.size() and h[i] == b[i] and int(rp.get("frames", -1)) == int(bp.get("frames", -2)) \
				and int(rp.get("audio_events", -1)) == int(bp.get("audio_events", -2))
			all_same = all_same and same
			cells.append("same" if same else "DIFFERENT")
		cells.append(int((r["world"] as Dictionary).get("world_ticks", 0)))
		cells.append(_f(_ms(r, "iter_ms_p50")))
		_row(cells)
		rows.append({"every": n, "hashes": h, "world_ticks": int((r["world"] as Dictionary).get("world_ticks", 0))})
		last = r
	(data["tests"] as Dictionary)["slice"] = {"all_same": all_same, "base": b, "rows": rows}
	_cmd(last)
	md.append("\"same\" means: the same state hash, the same number of pack ticks to the bot's end, and the same number of")
	md.append("recorded sounds. %s" % ("A pack given fewer world ticks runs the same game, later." if all_same
		else "NOT every sliced run equals the continuous one."))
	md.append("")


## Tests 8 and 9: script gating and the overflow guard, over every run above.
func _t_gating() -> void:
	md.append("## Tests 8 and 9: script gating and engine warnings, over all %d runs above" % runs)
	md.append("")
	md.append("Every pack holder carries a probe: a script node in the pack's subtree, ticked by the scene tree like any")
	md.append("script of the pack (`_physics_process` and `_process`). It counts a leak when it runs on a world tick its pack")
	md.append("did not get, and a wrong-pack call when `TLContext.current` is not its own pack while it runs.")
	md.append("")
	_head(["check", "result"])
	_row(["probe calls on a tick the pack did not get", total_leaks])
	_row(["probe calls with another pack as \"the pack being called\"", total_wrong])
	_row(["probe `_physics_process` calls / pack ticks", "%d / %d (a bot run ends inside its last tick, before the tree ticks: one less per bot run)" % [probe_calls, probe_ticks]])
	_row(["engine warnings about dropped contacts, body pairs or the body limit", total_limit_warnings])
	_row(["script and engine errors logged", total_errors])
	_row(["other engine warnings (distinct texts)", "none" if warning_texts.is_empty() else "; ".join(PackedStringArray(warning_texts))])
	(data["tests"] as Dictionary)["gating"] = {"gate_leaks": total_leaks, "wrong_pack_calls": total_wrong,
		"limit_warnings": total_limit_warnings, "errors": total_errors, "warning_texts": warning_texts}
	md.append("")
