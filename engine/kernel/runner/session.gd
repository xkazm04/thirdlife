extends RefCounted
## P7. A session's input as a file, `tl.input/1` (worker.gd and host.gd may not grow, so this lives here):
##
##   {"schema": "tl.input/1", "pack": "<pack id>", "seed": 1, "mode": "bot", "max_frames": 36000,
##    "length": 1894, "end": "tick", "frames": [[frame, "action", value], ...]}
##
## `frames` holds every sample of `ctx.input` that was not zero, in frame order: an action that is held for a second is
## sixty entries, a frame in which nothing is pressed has none. A value is a multiple of 0.001 (the latch rounds). `length` is the number of frames the session ticked and
## `end` says where it stopped: "step" (after the physics step of its last frame: play, smoke) or "tick" (inside its
## last frame, before the step: a bot that said it was done). `mode` and `max_frames` are what `ctx` told the pack.
## A replay gives the pack exactly these samples and nothing else: no bot is loaded, no device is read.
##
## Worker side: `begin` (options --record, --input, --devices), `attach` (after ctx.input exists), `pre_sample`,
## `ends_now`, `finish`. Supervisor side (static): `read`, `replay` (the verb), `extra`, `record_check`, `intify`.
## No global class name is used here: the supervisor loads this before the class cache is known to exist.

const SCHEMA: String = "tl.input/1"
const KEYS: Array = ["schema", "pack", "seed", "mode", "max_frames", "length", "end", "frames"]
const MODES: Array = ["smoke", "bot", "capture", "play"]

var record_path: String = ""       # --record: where this run's input is written
var replaying: Dictionary = {}     # --input: the record this run is fed from
var problem: String = ""
var cut_frame: int = -1            # a replay of a record that ended inside its last frame stops there too
var devices: Array = []            # --devices: [frame, kind, a, b] raw device events of a scripted interactive run (tests)
var _dev_at: int = 0
var _rec: Variant = null
var _ctx: Object = null
var _w: Node = null


# ------------------------------------------------------------------------------------------------------ the file
## Returns {ok, record, error}. Unknown keys are errors; every entry is [whole frame, action name, number], in frame order.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "input record not found: %s" % path}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "%s line %d: not valid JSON: %s" % [path.get_file(), json.get_error_line() + 1, json.get_error_message()]}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "%s: an input record is an object" % path.get_file()}
	var r: Dictionary = json.data
	var bad: Callable = func(text: String) -> Dictionary:
		return {"ok": false, "error": "%s: %s (%s)" % [path.get_file(), text, SCHEMA]}
	for k: Variant in r.keys():
		if not KEYS.has(k):
			return bad.call("unknown key '%s' (unknown keys are errors)" % str(k))
	for k: String in KEYS:
		if not r.has(k) or r[k] == null:
			return bad.call("missing key '%s'" % k)
	if str(r["schema"]) != SCHEMA:
		return bad.call("schema is '%s'" % str(r["schema"]))
	for k: String in ["seed", "max_frames", "length"]:
		if not _is_num(r[k]) or float(r[k]) != floorf(float(r[k])) or (k != "seed" and float(r[k]) < 0.0):
			return bad.call("'%s' must be a whole number" % k)
		r[k] = int(r[k])
	if typeof(r["pack"]) != TYPE_STRING or typeof(r["mode"]) != TYPE_STRING or not MODES.has(r["mode"]):
		return bad.call("'pack' is a pack id and 'mode' one of %s" % ", ".join(PackedStringArray(MODES)))
	if str(r["end"]) != "step" and str(r["end"]) != "tick":
		return bad.call("'end' is \"step\" or \"tick\"")
	if typeof(r["frames"]) != TYPE_ARRAY:
		return bad.call("'frames' is a list of [frame, action, value]")
	var last: int = 0
	for i: int in (r["frames"] as Array).size():
		var e: Variant = r["frames"][i]
		if typeof(e) != TYPE_ARRAY or (e as Array).size() != 3 or not _is_num(e[0]) or typeof(e[1]) != TYPE_STRING \
				or not _is_num(e[2]) or float(e[0]) != floorf(float(e[0])) or float(e[0]) < 0.0:
			return bad.call("frames[%d] must be [frame, \"action\", value]" % i)
		if int(e[0]) < last or int(e[0]) >= int(r["length"]):
			return bad.call("frames[%d]: frame %d is out of order or not below 'length' (%d)" % [i, int(e[0]), int(r["length"])])
		last = int(e[0])
	return {"ok": true, "record": r}


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


## A sample as text: a multiple of 0.001 (TLInput.STEP) with at most three decimals.
static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else String.num(v, 3)


## Writes a record (temporary file, read back and compared, rename). Returns "" or what went wrong.
static func write(path: String, r: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var texts: Dictionary = {}
	var at: int = -1
	for e: Array in r["frames"]:
		if not texts.has(e[2]):
			texts[e[2]] = _num(float(e[2]))
		parts.append("%s[%d,%s,%s]" % ["\n" if int(e[0]) != at else "", int(e[0]), JSON.stringify(str(e[1])), texts[e[2]]])
		at = int(e[0])
	var text: String = "{\"schema\":\"%s\",\"pack\":%s,\"seed\":%d,\"mode\":\"%s\",\"max_frames\":%d,\"length\":%d,\"end\":\"%s\",\"frames\":[%s\n]}\n" % [
		SCHEMA, JSON.stringify(str(r["pack"])), int(r["seed"]), str(r["mode"]), int(r["max_frames"]), int(r["length"]), str(r["end"]), ",".join(parts)]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return "could not write %s (error %d)" % [path, FileAccess.get_open_error()]
	f.store_string(text)
	f.close()
	var back: Dictionary = read(path + ".tmp")
	var same: bool = bool(back["ok"]) and ((back["record"] as Dictionary)["frames"] as Array).size() == (r["frames"] as Array).size()
	if same:
		for i: int in (r["frames"] as Array).size():
			if roundf(float(back["record"]["frames"][i][2]) * 1000.0) != roundf(float(r["frames"][i][2]) * 1000.0) or int(back["record"]["frames"][i][0]) != int(r["frames"][i][0]):
				same = false
				break
	if not same:
		DirAccess.remove_absolute(path + ".tmp")
		return "the record did not read back as it was written: %s" % str(back.get("error", "a value changed"))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return "could not move the record to %s" % path
	return ""


# ------------------------------------------------------------------------------------------------------ worker side
## Reads the options of a run. A replay takes its seed, its length and its mode from the record.
func begin(w: Node) -> void:
	_w = w
	var opts: Dictionary = w.get("opts")
	record_path = str(opts.get("record", ""))
	if str(opts.get("mode", "")) == "replay":
		var rr: Dictionary = read(str(opts.get("input", "")))
		if not rr["ok"]:
			problem = str(rr["error"])
			return
		replaying = rr["record"]
		opts["seed"] = int(replaying["seed"])
		w.set("frames_target", int(replaying["length"]))
		if str(replaying["end"]) == "tick":
			cut_frame = int(replaying["length"]) - 1
	if opts.has("devices"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["devices"]))) if FileAccess.file_exists(str(opts["devices"])) else null
		if typeof(parsed) != TYPE_ARRAY:
			problem = "--devices: %s is not a JSON list of [frame, kind, a, b]" % str(opts["devices"])
			return
		devices = parsed


## After the pack's `ctx.input` exists and before any pack code runs. False (and a load error) when the run cannot start.
func attach(ctx: Object) -> bool:
	_ctx = ctx
	if problem.is_empty() and not replaying.is_empty() and str(replaying["pack"]) != str(ctx.get("pack_id")):
		problem = "the input record is of pack '%s', this pack is '%s'" % [str(replaying["pack"]), str(ctx.get("pack_id"))]
	if not problem.is_empty():
		(_w.get("load_errors") as Array).append({"kind": "load", "file": str((_w.get("opts") as Dictionary).get("input", "")).get_file(), "message": problem})
		return false
	var input: Object = ctx.get("input")
	if not replaying.is_empty():
		ctx.set("mode", str(replaying["mode"]))
		ctx.set("max_frames", int(replaying["max_frames"]))
		input.call("_feed", replaying["frames"])
	if not record_path.is_empty():
		_rec = input.call("_record")
	return true


## Before the input is sampled for `frame`: the scripted device events of a test (`--devices`), through the engine's
## own input path. Kinds: key (name, 1 or 0), drag (dx, dy with the right button), wheel (1 out, -1 in),
## field (1: a text field takes the keyboard, 0: gives it back), panel (1: the designer panel is open, 0: closed),
## close (the window's close button).
func pre_sample(frame: int) -> void:
	var any: bool = false
	while _dev_at < devices.size() and int(devices[_dev_at][0]) <= frame:
		var e: Array = devices[_dev_at]
		_dev_at += 1
		any = true
		var a: Variant = e[2] if e.size() > 2 else 0
		var b: float = float(e[3]) if e.size() > 3 else 0.0
		match str(e[1]):
			"key":
				var k: InputEventKey = InputEventKey.new()
				k.physical_keycode = OS.find_keycode_from_string(str(a))
				k.keycode = k.physical_keycode
				k.pressed = b != 0.0
				Input.parse_input_event(k)
			"drag":
				var m: InputEventMouseMotion = InputEventMouseMotion.new()
				m.relative = Vector2(float(a), b)
				m.button_mask = MOUSE_BUTTON_MASK_RIGHT
				_pointer_event(m)
			"wheel":
				var wb: InputEventMouseButton = InputEventMouseButton.new()
				wb.button_index = MOUSE_BUTTON_WHEEL_DOWN if float(a) > 0.0 else MOUSE_BUTTON_WHEEL_UP
				wb.pressed = true
				_pointer_event(wb)
			"field":
				var field: Control = _w.get_node_or_null("TLTestField") as Control
				if float(a) != 0.0 and field == null:
					field = LineEdit.new()
					field.name = "TLTestField"
					_w.add_child(field)
					field.grab_focus()
				elif float(a) == 0.0 and field != null:
					field.release_focus()
					_w.remove_child(field)
					field.free()
			"panel":
				var layer: CanvasLayer = _w.get_node_or_null("TLDesigner") as CanvasLayer
				if layer == null:
					layer = CanvasLayer.new()
					layer.name = "TLDesigner"
					_w.add_child(layer)
				layer.visible = float(a) != 0.0
			"close":
				_w.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
				return
			_:
				push_error("--devices: unknown kind '%s' (key, drag, wheel, field, panel, close)" % str(e[1]))
	if any:
		Input.flush_buffered_events()


func _pointer_event(e: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		_w.get_viewport().push_input(e)      # no window system hands events on in a headless run
	else:
		Input.parse_input_event(e)


## engine/ui/PATCHES.md entry 2: Esc ends an interactive run, but not while the designer panel is open.
func ends_now() -> bool:
	if not Input.is_physical_key_pressed(KEY_ESCAPE):
		return false
	var layer: CanvasLayer = _w.get_node_or_null("TLDesigner") as CanvasLayer
	return layer == null or not layer.visible


## When the run ends: writes the record of `--record`. Returns what the result file says about it ({} when none was asked).
func finish(frames_run: int, inside_tick: bool) -> Dictionary:
	if _rec == null or _ctx == null:
		return {}
	var err: String = write(record_path, {"pack": str(_ctx.get("pack_id")), "seed": int(_ctx.get("seed")), "mode": str(_ctx.get("mode")),
		"max_frames": int(_ctx.get("max_frames")), "length": frames_run, "end": "tick" if inside_tick else "step", "frames": _rec})
	var out: Dictionary = {"file": record_path, "samples": (_rec as Array).size(), "length": frames_run}
	if not err.is_empty():
		out["error"] = err
	return out


# ------------------------------------------------------------------------------------------------------ supervisor side
## The `replay` verb (contracts/RUNNER.md): one worker run fed from --input; the V2 checks, `replay.complete`, the hash.
static func replay(h: Node, manifest: Dictionary) -> void:
	var opts: Dictionary = h.get("opts")
	var rr: Dictionary = read(str(opts["input"])) if opts.has("input") else {"ok": false, "error": "--input=<file> is required: a tl.input/1 record written by `play --record` or `bot --record`"}
	var rec: Dictionary = rr.get("record", {})
	if rr["ok"] and str(rec["pack"]) != str(manifest.get("id", "")):
		rr = {"ok": false, "error": "the input record is of pack '%s', this pack is '%s'" % [str(rec["pack"]), str(manifest.get("id", ""))]}
	if not rr["ok"]:
		h.call("_not_run", "load" if opts.has("input") else "engine", str(rr["error"]))
		return
	var report: Dictionary = h.get("report")
	report["seed"] = int(rec["seed"])
	report["frames"] = int(rec["length"])
	var run: Dictionary = await h.call("_run_worker", "replay", extra(opts, {"input": str(opts["input"])}), "")
	if h.call("_smoke_checks", run, int(rec["length"])):
		report["metrics"] = h.call("_metrics", run)
		var ran: int = int((run["result"] as Dictionary).get("frames_run", 0))
		h.call("_check", "replay.complete", ran == int(rec["length"]), "%d of the record's %d frames, %d samples fed (the record's mode: %s, end: %s)" % [
			ran, int(rec["length"]), (rec["frames"] as Array).size(), str(rec["mode"]), str(rec["end"])])
		record_check(h, run)
	h.call("_finish_by_checks")


## The worker options of a run, with --record handed on when the caller gave it.
static func extra(opts: Dictionary, base: Dictionary) -> Dictionary:
	if opts.has("record"):
		base["record"] = str(opts["record"])
	return base


## Adds the check `record.written` when the run was asked for a record.
static func record_check(h: Node, run: Dictionary) -> void:
	if not (h.get("opts") as Dictionary).has("record"):
		return
	var info: Dictionary = (run.get("result", {}) as Dictionary).get("record", {})
	var ok: bool = not info.is_empty() and not info.has("error") and FileAccess.file_exists(str(info.get("file", "")))
	h.call("_check", "record.written", ok, "%d samples of %d frames -> %s" % [int(info.get("samples", 0)), int(info.get("length", 0)), str(info.get("file", ""))] if ok
		else "no record was written: %s" % str(info.get("error", "the run did not get that far")))


## JSON has one number type; whole numbers read back from the worker become ints again.
static func intify(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(v) == floor(float(v)) and absf(float(v)) < 9.0e15 else v
		TYPE_DICTIONARY:
			for k: Variant in (v as Dictionary).keys():
				(v as Dictionary)[k] = intify((v as Dictionary)[k])
		TYPE_ARRAY:
			for i: int in (v as Array).size():
				(v as Array)[i] = intify((v as Array)[i])
	return v
