extends "res://kernel/runner/worker.gd"
## P8 spike, process S: the simulation. It is the unchanged sim worker (one pack, its bot, the same frame order, the
## same state hash) with a tap after every tick: what the picture needs goes to process D over a loopback TCP
## connection, and D's input samples come back. The pack is not touched and does not know.
##
##   --port=<n>            listen on 127.0.0.1:<n> (loopback only)
##   --wait=<seconds>      how long to wait for D before giving up (default 180: a window can take 40 s to start on a busy machine)
##   --stall-at=<f> --stall-ms=<ms>   sleep at frame f (the "S is slow" experiment)
##   --die-at=<f>          end this process without a word at frame f (the "S dies" experiment)
##   every option of the worker: --mode --pack --test --seed --frames --result
##
## Tap order inside frame f: D's input is read -> the worker's tick f (bot, input latch, _pack_tick) -> the tap reads
## the tree (transforms as the step of f-1 left them plus what scripts set in tick f: what a window would draw).

const Wire: GDScript = preload("res://kernel/proc/proc_wire.gd")

var link: RefCounted = null
var _server: TCPServer = null
var _wait_until: int = 0
var _had_draw: bool = false
var _dirty: bool = true
var _next_id: int = 0
var _ids: Dictionary = {}            # instance id -> id
var _keys: Array = []                # id -> key
var _last_xf: Array = []             # id -> Transform3D
var _last_vis: PackedByteArray = PackedByteArray()
var _last_misc: Array = []           # id -> label text / bone poses / camera lens
var _n3: Array = []                  # the Node3D nodes in the tree now
var _n3_id: PackedInt32Array = PackedInt32Array()
var _special: Array = []             # [node, id, kind] of labels, skeletons, cameras
var _removed: PackedInt32Array = PackedInt32Array()
var _last_event: Variant = null
var _active_sent: int = -2
var _echo: int = -1
var _inputs_in: int = 0
var _tap_us: Array = []
var _tick_bytes: Array = []
var _moved: Array = []
var _first_bytes: int = 0
var _cpu0: float = -1.0
var _t0_usec: int = 0
var _stall_at: int = -1
var _die_at: int = -1
var _remote: Dictionary = {}         # action -> strength, as D last sent it
var _ended: bool = false
var _ready_ms: int = 0              # loading the pack, in this process
var _accepted_ms: int = 0
var _tapped: bool = false
var _left: Dictionary = {}           # instance id -> true: left the tree since the last tap
var _parent_of: Array = []           # id -> the parent's id as D was told
var _covered: Dictionary = {}        # instance id -> true: the node is a kit part or inside one
var _how: Dictionary = {}            # "start.kit_root" ... -> count
var _by_hand: Dictionary = {}        # a sample of what the pack made by hand


func start(options: Dictionary) -> void:
	_stall_at = int(options.get("stall-at", -1))
	_die_at = int(options.get("die-at", -1))
	_server = TCPServer.new()
	var err: Error = _server.listen(int(options.get("port", 47800)), "127.0.0.1")
	if err != OK:
		print("[proc] S could not listen on 127.0.0.1:%s (error %d)" % [str(options.get("port", 47800)), err])
		get_tree().quit(2)
		return
	# D is waited for HERE, before the pack is loaded: the engine's loop must not turn (and the physics must not step)
	# between the pack's setup and its tick 0, or the run is no longer the run one process makes.
	_wait_until = Time.get_ticks_msec() + int(float(options.get("wait", 180)) * 1000.0)
	while not _server.is_connection_available() and Time.get_ticks_msec() < _wait_until:
		OS.delay_msec(5)
	if not _server.is_connection_available():
		print("[proc] S: no drawing process connected in time")
		_server.stop()
		get_tree().quit(2)
		return
	link = Wire.new()
	link.call("attach", _server.take_connection())
	_had_draw = true
	_accepted_ms = Time.get_ticks_msec()
	super.start(options)
	if loaded:
		get_tree().node_added.connect(func(_n: Node) -> void: _dirty = true)
		get_tree().node_removed.connect(_on_removed)
		_ready_ms = Time.get_ticks_msec() - _accepted_ms
		print("[proc] S ready: pack=%s mode=%s port=%s" % [ctx.pack_id, mode, str(options.get("port", 47800))])


## A node that left the tree is either gone or on its way to another parent (TLFracture moves its pieces): the tap
## decides which, so a moved node keeps its number and D moves the picture it already has.
func _on_removed(n: Node) -> void:
	var iid: int = n.get_instance_id()
	if _ids.has(iid):
		_left[iid] = true
		_dirty = true


func _physics_process(delta: float) -> void:
	if finished:
		return
	for m: Variant in link.call("recv"):
		if typeof(m) == TYPE_ARRAY and (m as Array).size() >= 4 and str((m as Array)[0]) == "i":
			_echo = int((m as Array)[1])
			_inputs_in += 1
			var names: PackedStringArray = (m as Array)[2]
			var values: PackedFloat32Array = (m as Array)[3]
			for i: int in names.size():
				_remote[names[i]] = values[i]
	if not bool(link.call("connected")):
		print("[proc] S: the drawing process is gone; ending the run")
		_end_run()
		return
	if bot == null:          # a player in D: its samples are this pack's input (a bot run only counts them)
		for a: String in _remote.keys():
			if ctx.input._actions.has(StringName(a)):
				ctx.input.press(StringName(a), float(_remote[a]))
	if frame == _stall_at:
		_stall_at = -1
		OS.delay_msec(int(opts.get("stall-ms", 1000)))
	if frame == _die_at:
		cpu.call("stop")
		OS.kill(OS.get_process_id())
		return
	if _cpu0 < 0.0 and frame == 0:
		cpu.call("wait_settled")
		_cpu0 = float(cpu.call("_read"))
		_t0_usec = Time.get_ticks_usec()
	var f: int = frame
	super._physics_process(delta)
	if finished:
		return
	_tap(f)


# ---------------------------------------------------------------------------------------------------- the tap
func _scan(n: Node, key: String, added: Array, pid: int, moved: PackedInt32Array) -> void:
	var segs: Dictionary = {}
	for c: Node in n.get_children():
		var iid: int = c.get_instance_id()
		var id: int = int(_ids.get(iid, -1))
		var kind: int = Wire.call("kind_of", c)
		if id >= 0 and _parent_of[id] != pid:
			_parent_of[id] = pid
			moved.append(id)
			moved.append(pid)
		if id < 0:
			if segs.is_empty():
				segs = Wire.call("segments", n)
			id = _next_id
			_next_id += 1
			_ids[iid] = id
			_keys.append(key + "/" + str(segs[iid]))
			_last_xf.append(null)
			_last_vis.append(2)
			_last_misc.append(null)
			_parent_of.append(pid)
			var row: Array = [id, _keys[id], c.get_class(), kind, pid, String(c.get("preset")) if kind & Wire.K_VFX else ""]
			_census_kit(c, n)
			added.append(row)
		if kind & Wire.K_3D:
			_n3.append(c)
			_n3_id.append(id)
		if kind & (Wire.K_LABEL | Wire.K_SKELETON | Wire.K_CAMERA):
			_special.append([c, id, kind])
		_scan(c, _keys[id], added, id, moved)


## How a node could be rebuilt in another process from data alone: under a kit part or a rig (tl_kind + tl_params
## say how to build it), a kernel class (its factory's options would), or neither (the pack made it by hand).
func _census_kit(c: Node, parent: Node) -> void:
	var how: String = "by_hand"
	if c.has_meta(&"tl_kind"):
		how = "kit_root"
		_covered[c.get_instance_id()] = true
	elif _covered.has(parent.get_instance_id()):
		how = "in_kit_part"
		_covered[c.get_instance_id()] = true
	else:
		var sc: Script = c.get_script() as Script
		if sc != null and str(sc.get_global_name()).begins_with("TL"):
			how = "kernel_class"
		elif not pack_node.is_ancestor_of(c):
			how = "kernel_node"
		elif c is CollisionShape3D or c.has_meta(&"tl_material"):
			how = "kernel_body"
	var when: String = "start" if not _tapped else "later"
	_how[when + "." + how] = int(_how.get(when + "." + how, 0)) + 1
	if how == "by_hand" and _by_hand.size() < 12:
		_by_hand[c.get_class() + " " + String(c.name).rstrip("0123456789@")] = true


func _tap(f: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var added: Array = []
	var moved: PackedInt32Array = PackedInt32Array()
	if _dirty:
		_dirty = false
		_n3.clear()
		_n3_id.clear()
		_special.clear()
		for iid: int in _left.keys():
			var o: Object = instance_from_id(iid)
			if o == null or not is_instance_valid(o) or not (o as Node).is_inside_tree() or not is_ancestor_of(o as Node):
				_removed.append(int(_ids[iid]))
				_ids.erase(iid)
		_left.clear()
		_scan(self, "", added, -1, moved)
	var ids: PackedInt32Array = PackedInt32Array()
	var xf: PackedFloat32Array = PackedFloat32Array()
	var vis: PackedInt32Array = PackedInt32Array()
	for i: int in _n3.size():
		var n: Node3D = _n3[i]
		var id: int = _n3_id[i]
		var t: Transform3D = n.transform
		if _last_xf[id] == null or t != _last_xf[id]:
			_last_xf[id] = t
			ids.append(id)
			var b: Basis = t.basis
			xf.append_array([b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z])
		var v: int = 1 if n.visible else 0
		if _last_vis[id] != v:
			_last_vis[id] = v
			vis.append(id * 2 + v)
	var labels: Array = []
	var bones: Array = []
	var cams: PackedFloat32Array = PackedFloat32Array()
	for s: Array in _special:
		var id: int = s[1]
		var kind: int = s[2]
		if kind & Wire.K_LABEL:
			var text: String = (s[0] as Label).text
			if _last_misc[id] == null or text != _last_misc[id]:
				_last_misc[id] = text
				labels.append(id)
				labels.append(text)
		elif kind & Wire.K_SKELETON:
			var sk: Skeleton3D = s[0]
			var pose: PackedFloat32Array = PackedFloat32Array()
			for bi: int in sk.get_bone_count():
				var p: Vector3 = sk.get_bone_pose_position(bi)
				var q: Quaternion = sk.get_bone_pose_rotation(bi)
				var sc: Vector3 = sk.get_bone_pose_scale(bi)
				pose.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, sc.x, sc.y, sc.z])
			if _last_misc[id] == null or pose != _last_misc[id]:
				_last_misc[id] = pose
				bones.append(id)
				bones.append(pose)
		elif kind & Wire.K_CAMERA:
			var cam: Camera3D = s[0]
			var lens: Vector3 = Vector3(cam.fov, cam.h_offset, cam.v_offset)
			if _last_misc[id] == null or lens != _last_misc[id]:
				_last_misc[id] = lens
				cams.append_array([float(id), lens.x, lens.y, lens.z])
	var events: Array = []
	var record: Array = ctx.audio_events
	var k: int = record.size() - 1
	while k >= 0 and not is_same(record[k], _last_event):
		k -= 1
	for j: int in range(k + 1, record.size()):
		var e: Dictionary = record[j]
		events.append([str(e["preset"]), e.get("position")])
	if not record.is_empty():
		_last_event = record[record.size() - 1]
	var active: int = -1
	if ctx.cameras.active != null and _ids.has(ctx.cameras.active.get_instance_id()):
		active = int(_ids[ctx.cameras.active.get_instance_id()])
	var msg: Array = ["t", f, ids, xf, vis, added, _removed, labels, bones, cams, events, active if active != _active_sent else -2, _echo, moved]
	_active_sent = active
	var size: int = int(link.call("send", msg))
	_tapped = true
	_removed = PackedInt32Array()
	if _first_bytes == 0:
		_first_bytes = size
	else:
		_tick_bytes.append(size)
		_moved.append(ids.size())
		_tap_us.append(Time.get_ticks_usec() - t0)


# ---------------------------------------------------------------------------------------------------- the end
func _end_run() -> void:
	if _ended:
		return
	_ended = true
	var fig: Dictionary = {"proc": 1, "role": "sim", "mem_peak_mb": snappedf(float(OS.get_static_memory_peak_usage()) / 1048576.0, 0.1), "ready_ms": _ready_ms, "pack": ctx.pack_id if ctx != null else "", "mode": mode,
		"frames": frame, "had_draw": _had_draw}
	if loaded:
		var cpu1: float = float(cpu.call("_read")) if _cpu0 >= 0.0 else -1.0
		var wall_ms: float = float(Time.get_ticks_usec() - _t0_usec) / 1000.0
		fig["state_hash"] = _state_hash()
		fig["nodes"] = _next_id
		fig["nodes_3d"] = _n3.size()
		fig["first_message_bytes"] = _first_bytes
		fig["tick_bytes"] = {"mean": Wire.call("r3", Wire.call("mean", _tick_bytes)), "p50": Wire.call("pct", _tick_bytes, 0.5),
			"p99": Wire.call("pct", _tick_bytes, 0.99), "max": Wire.call("pct", _tick_bytes, 1.0)}
		fig["tap_ms"] = {"mean": Wire.call("r3", float(Wire.call("mean", _tap_us)) / 1000.0), "p50": float(Wire.call("pct", _tap_us, 0.5)) / 1000.0,
			"p99": float(Wire.call("pct", _tap_us, 0.99)) / 1000.0, "max": float(Wire.call("pct", _tap_us, 1.0)) / 1000.0}
		fig["moved_per_tick"] = {"mean": Wire.call("r3", Wire.call("mean", _moved)), "max": Wire.call("pct", _moved, 1.0)}
		fig["inputs_received"] = _inputs_in
		fig["rebuildable"] = _how
		fig["by_hand_sample"] = _by_hand.keys()
		var sorted: PackedInt64Array = frame_usec.duplicate()
		sorted.sort()
		fig["frame_ms"] = {"p50": _percentile(sorted, 0.5), "p99": _percentile(sorted, 0.99)}
		if cpu1 >= 0.0 and frame > 0:
			fig["cpu_ms_per_frame"] = Wire.call("r3", (cpu1 - _cpu0) / float(frame))
			fig["wall_ms_per_frame"] = Wire.call("r3", wall_ms / float(frame))
		if link != null:
			fig["bytes_out"] = int(link.get("bytes_out"))
			fig["backlog_max"] = int(link.get("backlog_max"))
			link.call("send", ["bye", fig])
			var until: int = Time.get_ticks_msec() + 15000       # let the last bytes leave before the process ends
			while int(link.call("backlog")) > 0 and Time.get_ticks_msec() < until and not bool(link.get("lost")):
				OS.delay_msec(2)
				link.call("flush")
	print(JSON.stringify(fig, "", false))
	if link != null:
		# A socket closed with unread input in it is RESET by Windows, and the reset throws away what D has not read
		# yet (the last ticks and the goodbye: seen once, when D's window was held up for 3 s). So S goes on reading
		# D's input until D, having read the goodbye, closes its end; five seconds at most.
		var gone_by: int = Time.get_ticks_msec() + 5000
		while bool(link.call("connected")) and Time.get_ticks_msec() < gone_by:
			link.call("recv")
			link.call("flush")
			OS.delay_msec(5)
	super._end_run()
	if link != null:
		link.call("close")
	if _server != null:
		_server.stop()
