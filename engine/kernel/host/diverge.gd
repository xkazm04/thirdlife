extends RefCounted
## The determinism locator: where two runs of one pack with one seed first differ, and in what. Called by invariants.gd
## only after two runs hashed differently, so a passing pack never pays for it (and these runs never count toward a
## frame budget). It runs the pack three more times, the way the failing check ran it (same verb, seed and frames):
##   A  traced every frame (runner/trace.gd, --trace_every=1)
##   B  traced every frame against A's trace (--stop_against): it stops at the first frame F whose hash differs from A's
##      and keeps the parts of its state there (statehash.gd parts())
##   C  to frame F (--parts_at=F) for the same parts of the run that agreed with A
## The parts of B and C are compared in hash order: bodies in tree order, `_pack_state` keys, the generator, the input.
## A frame's hash is taken after the pack's calls of that frame and before its physics step, so frame F is the frame
## in which the pack's own code (or the step before it) made the difference. If B never differs from A, the located
## re-run did not reproduce the difference: the text says so and keeps the sampled window of the two runs.
## No global class name is used (the supervisor works before the class cache exists).

const SHOWN: int = 3                    # parts named in the text; the rest are counted


## The sampled window from two runs' `hash_trace` (every 300 frames): what the report said before the locator.
static func window(a: Dictionary, b: Dictionary) -> String:
	var ta: Array = a.get("hash_trace", [])
	var tb: Array = b.get("hash_trace", [])
	for i: int in mini(ta.size(), tb.size()):
		if str((ta[i] as Array)[1]) != str((tb[i] as Array)[1]):
			return "at or before frame %d" % int((ta[i] as Array)[0])
	return "after the last sampled frame"


## "at frame F: body World/Crate (and 2 more)", or the window with "(not reproduced in the located re-run)".
## `h`: the supervisor (host.gd); `mode` and `opts`: the worker runs of the failing check; `a`, `b`: their results.
static func locate(h: Node, mode: String, opts: Dictionary, a: Dictionary, b: Dictionary) -> String:
	var coarse: String = window(a, b)
	var base: Dictionary = opts.duplicate()
	base.erase("series")
	var oa: Dictionary = base.duplicate()
	oa["trace_every"] = 1
	var ra: Dictionary = await h.call("_run_worker", mode, oa, "")
	var ta: Array = (ra.get("result", {}) as Dictionary).get("hash_trace", [])
	if ta.is_empty():
		return coarse + " (the located re-run could not run)"
	var trace_path: String = str(h.call("_tmp_base")) + ".diverge.json"
	var f: FileAccess = FileAccess.open(trace_path, FileAccess.WRITE)
	if f == null:
		return coarse + " (the located re-run could not write its trace)"
	f.store_string(JSON.stringify(ta, "", false))
	f.close()
	var ob: Dictionary = base.duplicate()
	ob["trace_every"] = 1
	ob["stop_against"] = trace_path
	var rb: Dictionary = await h.call("_run_worker", mode, ob, "")
	h.call("_remove", trace_path)
	var db: Dictionary = (rb.get("result", {}) as Dictionary).get("diverge", {})
	if db.is_empty():
		return coarse + " (not reproduced in the located re-run)"
	var at: int = int(db.get("frame", 0))
	var oc: Dictionary = base.duplicate()
	oc["parts_at"] = at
	var rc: Dictionary = await h.call("_run_worker", mode, oc, "")
	var dc: Dictionary = (rc.get("result", {}) as Dictionary).get("diverge", {})
	var names: PackedStringArray = differing(dc.get("parts", []), db.get("parts", []))
	if dc.is_empty() or int(dc.get("frame", -1)) != at or names.is_empty():
		return "at frame %d (the part that differs was not found)" % at
	var text: String = "at frame %d: %s" % [at, ", ".join(names.slice(0, SHOWN))]
	if names.size() > SHOWN:
		text += " (and %d more)" % (names.size() - SHOWN)
	return text


## The parts that differ between two parts lists ([[name, digest], ...]), in the order of `pa`, then those only in `pb`.
static func differing(pa: Array, pb: Array) -> PackedStringArray:
	var by_b: Dictionary = {}
	for e: Variant in pb:
		by_b[str((e as Array)[0])] = str((e as Array)[1])
	var seen: Dictionary = {}
	var out: PackedStringArray = PackedStringArray()
	for e: Variant in pa:
		var name: String = str((e as Array)[0])
		seen[name] = true
		if not by_b.has(name) or str(by_b[name]) != str((e as Array)[1]):
			out.append(name)
	for e: Variant in pb:
		if not seen.has(str((e as Array)[0])):
			out.append(str((e as Array)[0]))
	return out
