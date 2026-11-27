extends RefCounted
## Lane P (M6 round 2, 27 Nov 2026): the best run's ghost (contracts/BUILD.md "The best run's ghost"). While a run
## goes, the figure's feet and facing are kept every STEP frames from frame 0 and each change of its animation clip;
## when a finish is a new best the path is written to `<home>/runs/<slug of the run name>.json` as `tl.run-ghost/1`
## (temp, read back, rename: build_file.gd `_write_whole`), replacing the earlier best's file. When that run starts
## again, a ghost of the figure (the biped rig in the holo look, no collider, no shadow) walks the kept track from
## frame 0 beside the visitor, its clips played at their frames, and vanishes at the track's end. It is drawn only in
## the visitor's view (a child of the Home's root, never a pack's space or hash). `shown` (rules_play.gd: the G key)
## hides or shows it for the rest of the visit; every visit starts with it shown. Time is the run's frames.
##
##   PlayGhost.path_of(home_dir, run) / PlayGhost.read(path) -> {"ghost"?, "error"} / PlayGhost.write(home_dir, doc)
##   g.record_start(); g.record(frame_in_run, feet, yaw, clip); g.doc_of(run, frames) -> the tl.run-ghost/1 document
##   g.play_start(holder, doc); g.play_tick(); g.play_stop(); g.pose_at(frame) -> [Vector3 feet, yaw] (interpolated)

const BuildFile := preload("res://kernel/world/build/build_file.gd")
const StampFile := preload("res://kernel/world/build/stamp_file.gd")
const SCHEMA := "tl.run-ghost/1"
const KEYS := ["schema", "run", "frames", "step", "track", "clips"]
const STEP := 2
const MAX_FRAMES := 216000               # an hour of run: a longer one is not kept (a file of at most ~1.7 MB)

var shown := true                        # the G key, for the rest of the visit
var track := PackedFloat32Array()        # x, y, z, yaw per sample (recording)
var clips := []                          # [frame, clip] (recording)
var _last_clip := "\u0000"
var recording := false
var ghost: Dictionary = {}               # the document being played
var samples := PackedFloat32Array()
var node: Node3D = null                  # the ghost figure
var rig: Node3D = null
var t := -1                              # the frame of the ghost's track it shows (-1: none)
var _clip_i := 0


static func path_of(home_dir: String, run_name: String) -> String:
	return home_dir.path_join("runs").path_join(StampFile.slug_of(run_name) + ".json")


## The document as written: the contract's key order, compact, one line.
static func text_of(doc: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in KEYS:
		if doc.has(k):
			parts.append("%s:%s" % [JSON.stringify(k), JSON.stringify(doc[k], "", false)])
	return "{%s}\n" % ",".join(parts)


## Writes `doc` as `<home_dir>/runs/<slug>.json` (replacing the earlier best's). "" or why not.
static func write(home_dir: String, doc: Dictionary) -> String:
	if home_dir == "":
		return "no Home folder"
	var why := check(doc)
	if why != "":
		return why
	var d := home_dir.path_join("runs")
	var err := DirAccess.make_dir_recursive_absolute(d)
	if err != OK and not DirAccess.dir_exists_absolute(d):
		return "cannot make %s (error %d)" % [d, err]
	return BuildFile._write_whole(path_of(home_dir, str(doc.run)), text_of(doc))


## {"ghost": doc} or {"error": why} (no file: "none").
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "none"}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary):
		return {"error": "not a JSON object"}
	var why := check(v)
	if why != "":
		return {"error": why}
	var d: Dictionary = v
	d.frames = int(d.frames)                     # JSON numbers are floats: the integers back, so text_of gives the file again
	d.step = int(d.step)
	for c: Array in d.clips:
		c[0] = int(c[0])
	return {"ghost": d}


## Why `doc` is not a tl.run-ghost/1 document ("" = it is): unknown keys are errors, every key is required.
static func check(doc: Variant) -> String:
	if not (doc is Dictionary):
		return "not an object"
	var d: Dictionary = doc
	for k: Variant in d:
		if not (str(k) in KEYS):
			return "unknown key '%s'" % str(k)
	for k: String in KEYS:
		if not d.has(k):
			return "%s is missing" % k
	if str(d.schema) != SCHEMA:
		return "schema must be %s" % SCHEMA
	if typeof(d.run) != TYPE_STRING or str(d.run) == "":
		return "run must be a name"
	for k: String in ["frames", "step"]:
		if typeof(d[k]) not in [TYPE_INT, TYPE_FLOAT] or float(d[k]) != floorf(float(d[k])):
			return "%s must be an integer" % k
	if int(d.frames) < 0 or int(d.frames) > MAX_FRAMES or int(d.step) < 1:
		return "frames 0..%d, step >= 1" % MAX_FRAMES
	if typeof(d.track) != TYPE_STRING:
		return "track must be base64 text"
	var raw := Marshalls.base64_to_raw(str(d.track))
	if raw.is_empty() or raw.size() % 16 != 0 or raw.size() / 16 != int(d.frames) / int(d.step) + 1:
		return "track holds %d bytes, want %d samples of 16" % [raw.size(), int(d.frames) / int(d.step) + 1]
	if typeof(d.clips) != TYPE_ARRAY:
		return "clips must be a list"
	for c: Variant in d.clips:
		if not (c is Array) or (c as Array).size() != 2 or typeof(c[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(c[1]) != TYPE_STRING:
			return "a clip is [frame, \"clip\"]"
	return ""


# ------------------------------------------------------------------ recording
func record_start() -> void:
	track = PackedFloat32Array()
	clips = []
	_last_clip = "\u0000"
	recording = true


## Frame `f` of the run (0 at its start): a sample every STEP frames, a clip line when the clip changed.
func record(f: int, feet: Vector3, yaw: float, clip: String) -> void:
	if not recording or f > MAX_FRAMES:
		return
	if clip != _last_clip:
		_last_clip = clip
		clips.append([f, clip])
	if f % STEP == 0 and track.size() / 4 == f / STEP:
		track.append_array(PackedFloat32Array([feet.x, feet.y, feet.z, yaw]))


## The run finished in `frames`: the document of this run's path (samples 0..frames/STEP; the last is held when the
## finish frame fell between samples), or {} when nothing was recorded.
func doc_of(run_name: String, frames: int) -> Dictionary:
	recording = false
	var want := frames / STEP + 1
	if track.size() < 4 or frames > MAX_FRAMES:
		return {}
	while track.size() / 4 < want:
		track.append_array(track.slice(track.size() - 4))
	if track.size() / 4 > want:
		track = track.slice(0, want * 4)
	var cl := []
	for c: Array in clips:
		if int(c[0]) <= frames:
			cl.append([int(c[0]), str(c[1])])
	return {"schema": SCHEMA, "run": run_name, "frames": frames, "step": STEP,
		"track": Marshalls.raw_to_base64(track.to_byte_array()), "clips": cl}


# ------------------------------------------------------------------ the ghost
## Shows `doc`'s ghost from its frame 0 under `holder` (the Home's root: cell coordinates are world metres there).
func play_start(holder: Node3D, doc: Dictionary) -> void:
	play_stop()
	if holder == null or doc.is_empty():
		return
	ghost = doc
	samples = Marshalls.base64_to_raw(str(doc.track)).to_float32_array()
	node = Node3D.new()
	node.name = "RunGhost"
	rig = TLRigs.build("biped", {"backpack": false})
	if rig != null:
		node.add_child(rig)
		_holo(rig)
	holder.add_child(node)
	t = 0
	_clip_i = 0
	_place(0)
	node.visible = shown


## The figure in the holo look: every mesh drawn in TLStyle's holo material, no shadow (it has no collider at all).
static func _holo(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = TLStyle.material("holo")
	for c: Node in n.get_children():
		_holo(c)


## One physics frame: the next frame of the track; at its end the ghost goes.
func play_tick() -> void:
	if node == null:
		return
	t += 1
	if t > int(ghost.frames):
		play_stop()
		return
	_place(t)
	node.visible = shown


func _place(f: int) -> void:
	var p: Array = pose_at(f)
	var q: Array = pose_at(f + 1)
	node.position = p[0]
	node.rotation.y = float(p[1])
	if rig == null:
		return
	var v: Vector3 = ((q[0] as Vector3) - (p[0] as Vector3)) * 60.0
	rig.call("set_locomotion", v.rotated(Vector3.UP, -float(p[1])), absf(v.y) < 0.6)
	var cl: Array = ghost.clips
	while _clip_i < cl.size() and int(cl[_clip_i][0]) <= f:
		var c := str(cl[_clip_i][1])
		if c == "" or (rig.call("clips") as PackedStringArray).has(c):
			rig.call("play", StringName(c))
		_clip_i += 1
	rig.call("tick", f)


## [feet, yaw] of the kept track at run frame `f` (between samples: interpolated; past the end: the last).
func pose_at(f: int) -> Array:
	var n := samples.size() / 4
	if n == 0:
		return [Vector3.ZERO, 0.0]
	var step := int(ghost.get("step", STEP))
	var i := clampi(f / step, 0, n - 1)
	var j := mini(i + 1, n - 1)
	var k := clampf(float(f - i * step) / float(step), 0.0, 1.0) if j != i else 0.0
	var a := Vector3(samples[i * 4], samples[i * 4 + 1], samples[i * 4 + 2])
	var b := Vector3(samples[j * 4], samples[j * 4 + 1], samples[j * 4 + 2])
	return [a.lerp(b, k), lerp_angle(samples[i * 4 + 3], samples[j * 4 + 3], k)]


func set_shown(on: bool) -> void:
	shown = on
	if node != null:
		node.visible = on


func play_stop() -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	node = null
	rig = null
	ghost = {}
	samples = PackedFloat32Array()
	t = -1


func playing() -> bool:
	return node != null
