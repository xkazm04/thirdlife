extends RefCounted
## The worker's state hash trace (moved out of runner/worker.gd), and the located re-run's half of it (host/diverge.gd
## is the supervisor's half). After the pack's calls of frame f, before its physics step, the worker hands the frame here.
##
## A normal run: every HASH_TRACE_EVERY frames, [f, the first 16 hex of the state hash] into the result's `hash_trace`.
## Three internal worker options, set only by host/diverge.gd after two runs of one seed hashed differently:
##   --trace_every=<n>       sample every n frames (diverge: 1)
##   --stop_against=<file>   another run's trace ([[f, hash], ...] as JSON): at the first sampled frame whose hash differs
##                           from that run's, keep {frame, parts} (statehash.gd parts()) and end the run there
##   --parts_at=<f>          keep {frame, parts} at frame f and end the run there
## What is kept goes into the result file as `diverge` (the result file only; the tl.verify/1 report reads its text).

const StateHash: GDScript = preload("res://kernel/host/statehash.gd")

const HASH_TRACE_EVERY: int = 300

var every: int = HASH_TRACE_EVERY
var against: Dictionary = {}            # frame -> the other run's hash at that frame (stop_against)
var parts_at: int = -1
var found: Dictionary = {}              # {frame, parts}: where this run stopped for the locator


func _init(opts: Dictionary = {}) -> void:
	every = maxi(1, int(opts.get("trace_every", HASH_TRACE_EVERY)))
	parts_at = int(opts.get("parts_at", -1))
	var path: String = str(opts.get("stop_against", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_ARRAY:
			for e: Variant in parsed:
				if typeof(e) == TYPE_ARRAY and (e as Array).size() == 2:
					against[int((e as Array)[0])] = str((e as Array)[1])


## The frame `f` of the pack `life` (runner/pack_life.gd): samples it into `trace`. False: the locator has what it came
## for and the run ends here.
func sample(f: int, life: RefCounted, trace: Array) -> bool:
	if f == parts_at:
		_keep(f, life)
		return false
	if f % every != 0:
		return true
	var h: String = str(life.call("state_hash")).substr(0, 16)
	trace.append([f, h])
	if against.has(f) and str(against[f]) != h:
		_keep(f, life)
		return false
	return true


func _keep(f: int, life: RefCounted) -> void:
	var entry: Node = life.get("entry")
	var ctx: TLContext = life.get("ctx")
	var has_state: bool = entry != null and entry.has_method("_pack_state")
	var state: Variant = entry.call("_pack_state") if has_state else null
	found = {"frame": f, "parts": StateHash.call("parts", life.get("pack_node"), state, has_state, ctx.rng, ctx.input, ctx.origin)}
