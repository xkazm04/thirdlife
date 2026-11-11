extends RefCounted
## P1. The V3 checks of `invariants` (moved out of host.gd, which may not grow): determinism, below ground, the frame budgets
## (stage p99, one of many p50), entity budget, and the bot replay. `h` is the host (the supervisor), `report` its report.
## No global class name is used (the supervisor works before the class cache exists).

## P1 (measured: docs/PERF.md section 3, 11 packs, quiet machine). The 8 ms per pack budget was set for a world of one and
## lets one game eat half a frame; the heaviest real pack today (hockey) is 1.3 ms at p99 and 0.75 ms at p50.
##   stage game (alone in the world): p99 of the frame, scripts + physics step, at most 4 ms (a quarter of a 60 Hz frame; the world's
##     front budget is 6 ms for stage and sidelines together)
##   one of many: p50 at most 1.0 ms (six such games fill the front budget); TARGET_MANY is the figure below which a pack is cheap
const BUDGET_FRAME_MS_P99: float = 4.0
const BUDGET_MANY_MS_P50: float = 1.0
const TARGET_MANY_MS_P50: float = 0.5
const BUDGET_EXTRA_RUNS: int = 2        # idle runs added when the frame budget is not met by the first two
const BUDGET_NODES: int = 5000
const BUDGET_BODIES: int = 600

var h: Node
var report: Dictionary = {}


func _check(id: String, ok: bool, detail: String) -> void:
	h.call("_check", id, ok, detail)


func _error(kind: String, file: String, message: String) -> void:
	h.call("_error", kind, file, message)


func _add_starved(metrics: Dictionary) -> void:
	h.call("_add_starved", metrics)


## P1. The frame time of a pack, as a figure that does not move with the load on the machine. Runs of one pack with one
## seed do the same work in frame i, so the best time any run took for frame i is the cost of that frame; a stall the
## machine causes lands on different frames in different runs and drops out, a spike the pack causes is in every run.
## Returns {p99, p50, runs}. Without per-frame series (an older worker) the better of the runs' own p99 is used.
func robust_frame_p99(runs: Array) -> Dictionary:
	var series: Array = []
	for r: Dictionary in runs:
		if r.has("frame_us") and (r["frame_us"] as Array).size() > 10:
			series.append(r["frame_us"])
	if series.size() < runs.size() or series.is_empty():
		var best: float = INF
		for r: Dictionary in runs:
			best = minf(best, float((r.get("metrics", {}) as Dictionary).get("frame_ms_p99", 0.0)))
		return {"p99": best if best != INF else 0.0, "p50": float((runs[0].get("metrics", {}) as Dictionary).get("frame_ms_p50", 0.0)), "runs": runs.size(), "per_frame": false}
	var n: int = 1 << 30
	for sr: Array in series:
		n = mini(n, sr.size())
	var best_us: PackedInt64Array = PackedInt64Array()
	best_us.resize(n)
	for i: int in n:
		var m: int = int((series[0] as Array)[i])
		for k: int in range(1, series.size()):
			m = mini(m, int((series[k] as Array)[i]))
		best_us[i] = m
	best_us.sort()
	var p99i: int = clampi(int(ceil(0.99 * float(n))) - 1, 0, n - 1)
	return {"p99": snappedf(float(best_us[p99i]) / 1000.0, 0.001), "p50": snappedf(float(best_us[n / 2]) / 1000.0, 0.001), "runs": series.size(), "per_frame": true}


func _invariant_checks(a: Dictionary, b: Dictionary, idle: Array = []) -> void:
	var ma: Dictionary = a.get("metrics", {})
	var mb: Dictionary = b.get("metrics", {})
	var ha: String = str(ma.get("state_hash", ""))
	var hb: String = str(mb.get("state_hash", ""))
	var same: bool = not ha.is_empty() and ha == hb
	var detail: String = "two runs, seed %d, %d frames: %s" % [int(report["seed"]), int(report["frames"]), ha.substr(0, 16)]
	if not same:
		var ta: Array = a.get("hash_trace", [])
		var tb: Array = b.get("hash_trace", [])
		var where: String = "after the last sampled frame"
		for i: int in mini(ta.size(), tb.size()):
			if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
				where = "at or before frame %d" % int((ta[i] as Array)[0])
				break
		detail = "state_hash differs between two runs with seed %d (%s vs %s); first difference %s" % [int(report["seed"]), ha.substr(0, 16), hb.substr(0, 16), where]
		_error("determinism", "", detail)
	_check("invariants.determinism", same, detail)
	var below: int = int(a.get("below_count", 0)) + int(b.get("below_count", 0))
	var bd: Dictionary = a.get("below", b.get("below", {}))
	var below_detail: String = "no physics body below y = -50"
	if below > 0:
		below_detail = "body '%s' at y = %s at frame %d" % [str(bd.get("node", "")), str(bd.get("y", "")), int(bd.get("frame", 0))]
		_error("budget", "", "a physics body fell below y = -50: " + below_detail)
	_check("invariants.below_ground", below == 0, below_detail)
	# frame time is the one budget that reads a clock (the contract's 8 ms); P1: judged on each frame's best time
	# over the idle runs, so that a stall the machine caused in one run cannot fail a healthy pack
	var fr: Dictionary = robust_frame_p99(idle if not idle.is_empty() else [a, b])
	var p99: float = float(fr["p99"])
	if p99 > BUDGET_FRAME_MS_P99:
		_error("budget", "", "frame p99 %.2f ms is over the %.0f ms budget" % [p99, BUDGET_FRAME_MS_P99])
	_check("invariants.frame_budget", p99 <= BUDGET_FRAME_MS_P99, "frame p99 %.3f ms (stage budget %.0f ms; scripts + physics step, headless, each frame's best of %d runs)" % [p99, BUDGET_FRAME_MS_P99, int(fr["runs"])])
	var p50: float = float(fr["p50"])
	if p50 > BUDGET_MANY_MS_P50:
		_error("budget", "", "frame p50 %.2f ms is over the %.1f ms budget of a pack in a world of many (about %d awake bodies cost this much)" % [p50, BUDGET_MANY_MS_P50, int(BUDGET_MANY_MS_P50 / 0.011)])
	_check("invariants.many_budget", p50 <= BUDGET_MANY_MS_P50, "frame p50 %.3f ms (budget %.1f ms for one of many; target %.1f ms%s)" % [p50, BUDGET_MANY_MS_P50, TARGET_MANY_MS_P50, ", above the target" if p50 > TARGET_MANY_MS_P50 else ""])
	var nodes: int = maxi(int(ma.get("entities_max", 0)), int(mb.get("entities_max", 0)))
	var bodies: int = maxi(int(ma.get("bodies_max", 0)), int(mb.get("bodies_max", 0)))
	var ent_ok: bool = nodes <= BUDGET_NODES and bodies <= BUDGET_BODIES
	if not ent_ok:
		_error("budget", "", "%d nodes (budget %d), %d physics bodies (budget %d)" % [nodes, BUDGET_NODES, bodies, BUDGET_BODIES])
	_check("invariants.entity_budget", ent_ok, "%d nodes (budget %d), %d physics bodies (budget %d)" % [nodes, BUDGET_NODES, bodies, BUDGET_BODIES])
	var metrics: Dictionary = {"state_hash": ha, "frame_ms_p50": fr["p50"], "frame_ms_p99": p99,
		"entities_max": nodes, "bodies_max": bodies}
	_add_starved(metrics)
	if not same:
		metrics["state_hash_b"] = hb
	report["metrics"] = metrics


## WP5: two bot runs of one test with one seed must end in the same state after the same number of frames.
func _bot_determinism_check(test: String, a: Dictionary, b: Dictionary) -> void:
	var ha: String = str((a.get("metrics", {}) as Dictionary).get("state_hash", ""))
	var hb: String = str((b.get("metrics", {}) as Dictionary).get("state_hash", ""))
	var fa: int = int(a.get("frames_run", 0))
	var fb: int = int(b.get("frames_run", 0))
	var same: bool = not ha.is_empty() and ha == hb and fa == fb
	var detail: String = "bot %s twice, seed %d: %s after %d frames" % [test, int(report["seed"]), ha.substr(0, 16), fa]
	if not same:
		var ta: Array = a.get("hash_trace", [])
		var tb: Array = b.get("hash_trace", [])
		var where: String = "after the last sampled frame"
		for i: int in mini(ta.size(), tb.size()):
			if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
				where = "at or before frame %d" % int((ta[i] as Array)[0])
				break
		detail = "two bot runs of %s with seed %d differ: %s after %d frames vs %s after %d frames; first difference %s" % [
			test, int(report["seed"]), ha.substr(0, 16), fa, hb.substr(0, 16), fb, where]
		_error("determinism", test, detail)
	_check("invariants.bot_deterministic", same, detail)
	var metrics: Dictionary = report.get("metrics", {})
	metrics["bot_state_hash"] = ha
	metrics["bot_frames"] = fa
	if not same:
		metrics["bot_state_hash_b"] = hb
	report["metrics"] = metrics
