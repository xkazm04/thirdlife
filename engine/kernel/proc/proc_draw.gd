extends "res://kernel/runner/worker.gd"
## P8 spike, process D: the picture. It builds the pack's scene once by running the pack's own `_pack_setup` and
## `_pack_start` in a window (the "same build calls" candidate at its coarsest grain: the build list is the pack's
## setup), then never ticks it: no `_pack_tick`, no bot, no physics step, every node of the pack switched off. From
## then on it only follows what process S sends (transforms, visibility, HUD text, bone poses, camera lens, sounds
## and effects as events) and sends its input samples back, one per physics tick.
##
##   --port=<n>          S's port on 127.0.0.1
##   --out=<png>         one capture of the window when S's frame reaches --shot (default 600), or at the end
##   --latency=<n> --key=right,left --watch=Paddle_player   the key-to-picture measurement (n presses)
##   --survive=<frames>  how long to go on drawing after S is lost before ending (default 180)
##
## D survives S: a tick that does not come leaves the last picture standing and the window answering.

const Wire: GDScript = preload("res://kernel/proc/proc_wire.gd")

var link: RefCounted = null
var _connect_until: int = 0
var _by_key: Dictionary = {}          # key -> node, D's own tree
var _node: Dictionary = {}            # S's id -> D's node
var _standins: Dictionary = {}        # S's id -> true for nodes D had to make up
var _fx_holder: Node3D = null
var _banner: Label = null
var _sent_at: Dictionary = {}         # input seq -> usec
var _seq: int = 0
var _echo_seen: int = -1
var _s_frame: int = -1
var _ticks: int = 0
var _table_rows: int = 0
var _matched: int = 0
var _unmatched_first: int = 0
var _runtime_added: int = 0
var _runtime_no_picture: int = 0
var _removed_count: int = 0
var _events: int = 0
var _vfx: int = 0
var _apply_us: Array = []
var _period_us: Array = []
var _rtt_us: Array = []
var _gap_max_ms: float = 0.0
var _last_tick_usec: int = 0
var _last_process_usec: int = 0
var _bye: Dictionary = {}
var _lost_at_frame: int = -1
var _frames_after_loss: int = 0
var _shot_done: bool = false
var _quitting: bool = false
var _cpu0: float = -1.0
var _frames0: int = 0
var _pending_fx: Array = []
var _busy: bool = false
var _ready_ms: int = 0              # engine start to "scene built", in this process
var _d_nodes0: int = 0
var _moved_count: int = 0
var _added_names: Dictionary = {}
var _s_only: Array = []
var _nodelay: bool = false
# the key-to-picture measurement
var _lat_n: int = 0
var _lat_keys: PackedStringArray = PackedStringArray()
var _lat_watch: Node3D = null
var _lat_clock: int = 0
var _lat_armed: bool = false
var _lat_key_frame: int = 0
var _lat_key_usec: int = 0
var _lat_p0: Vector3 = Vector3.ZERO
var _lat_frames: Array = []
var _lat_ms: Array = []
var _lat_held: String = ""


func start(options: Dictionary) -> void:
	options["mode"] = "play"
	super.start(options)
	if not loaded:
		return
	entry.call("_pack_start")
	pack_node.process_mode = Node.PROCESS_MODE_DISABLED       # the pack is a picture here: nothing of it runs
	ctx.cameras.process_mode = Node.PROCESS_MODE_DISABLED
	PhysicsServer3D.set_active(false)
	_index(self, "")
	_d_nodes0 = _by_key.size()
	_fx_holder = Node3D.new()
	_fx_holder.name = "ProcFx"
	add_child(_fx_holder)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	layer.name = "ProcBanner"
	add_child(layer)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_banner.position += Vector2(24, 96)
	layer.add_child(_banner)
	_lat_n = int(options.get("latency", 0))
	_lat_keys = str(options.get("key", "right,left")).split(",")
	if _lat_n > 0:
		_lat_watch = pack_node.find_child(str(options.get("watch", "Paddle_player")), true, false) as Node3D
		ctx.input.accept_devices = false
	link = Wire.new()
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	tcp.connect_to_host("127.0.0.1", int(options.get("port", 47800)))
	link.set("tcp", tcp)
	_connect_until = Time.get_ticks_msec() + 180000
	set_process(true)
	_ready_ms = Time.get_ticks_msec()
	print("[proc] D ready: pack=%s nodes=%d" % [ctx.pack_id, _by_key.size()])


func _index(n: Node, key: String) -> void:
	var segs: Dictionary = Wire.call("segments", n)
	for c: Node in n.get_children():
		var k: String = key + "/" + str(segs[c.get_instance_id()])
		_by_key[k] = c
		_index(c, k)


func _linked() -> bool:
	var tcp: StreamPeerTCP = link.get("tcp")
	if tcp == null:
		return false
	tcp.poll()
	return tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED


# ---------------------------------------------------------------------------------------------------- input out
func _physics_process(_delta: float) -> void:
	if _quitting or link == null or _ticks == 0 or _lost_at_frame >= 0 or not _linked():
		return
	if _lat_n > 0 and _lat_watch != null:
		_lat_clock += 1
		var phase: int = _lat_clock % 90
		if phase == 30 and _lat_frames.size() < _lat_n and not _lat_armed:
			_lat_held = _lat_keys[_lat_frames.size() % _lat_keys.size()]
			ctx.input.press(StringName(_lat_held))
			_lat_armed = true
			_lat_key_frame = Engine.get_process_frames()
			_lat_key_usec = Time.get_ticks_usec()
			_lat_p0 = _lat_watch.position
		elif phase == 50 and not _lat_held.is_empty():
			ctx.input.release(StringName(_lat_held))
			_lat_held = ""
	ctx.input._sample()
	var names: PackedStringArray = ctx.input.declared()
	var values: PackedFloat32Array = PackedFloat32Array()
	for a: String in names:
		values.append(ctx.input.strength(StringName(a)))
	_seq += 1
	_sent_at[_seq] = Time.get_ticks_usec()
	link.call("send", ["i", _seq, names, values])


# ---------------------------------------------------------------------------------------------------- picture in
func _process(_delta: float) -> void:
	if _quitting or link == null or _busy:
		return
	var now: int = Time.get_ticks_usec()
	if _last_process_usec > 0 and _ticks > 0:
		_period_us.append(now - _last_process_usec)
	_last_process_usec = now
	if _ticks == 0 and _bye.is_empty() and not _linked():
		var tcp: StreamPeerTCP = link.get("tcp")
		if tcp.get_status() == StreamPeerTCP.STATUS_ERROR or tcp.get_status() == StreamPeerTCP.STATUS_NONE:
			tcp.disconnect_from_host()
			tcp.connect_to_host("127.0.0.1", int(opts.get("port", 47800)))     # S is not listening yet: try again
		if Time.get_ticks_msec() > _connect_until:
			print("[proc] D: no simulation process to connect to")
			_proc_quit(2)
		return
	if not _nodelay:
		_nodelay = true
		(link.get("tcp") as StreamPeerTCP).set_no_delay(true)
	link.call("flush")
	var got: int = 0
	for m: Variant in link.call("recv"):
		if typeof(m) != TYPE_ARRAY or (m as Array).is_empty():
			continue
		if str((m as Array)[0]) == "t":
			_apply(m)
			got += 1
		elif str((m as Array)[0]) == "bye":
			_bye = (m as Array)[1]
	if got > 0:
		_apply_us.append(Time.get_ticks_usec() - now)
		if _last_tick_usec > 0:
			_gap_max_ms = maxf(_gap_max_ms, float(now - _last_tick_usec) / 1000.0)
		_last_tick_usec = now
		if _cpu0 < 0.0:
			cpu.call("wait_settled")
			_cpu0 = float(cpu.call("_read"))
			_frames0 = Engine.get_process_frames()
	if _lat_armed and _lat_watch != null and _lat_watch.position.distance_to(_lat_p0) > 0.0001:
		_lat_armed = false
		_lat_frames.append(Engine.get_process_frames() - _lat_key_frame)
		_lat_ms.append(float(Time.get_ticks_usec() - _lat_key_usec) / 1000.0)
	var quiet_ms: float = float(now - _last_tick_usec) / 1000.0 if _last_tick_usec > 0 else 0.0
	var state: String = "live"
	if not _bye.is_empty():
		state = "ended"
	elif _ticks > 0 and not _linked():
		state = "LOST (the simulation process is gone); the picture stands"
		if _lost_at_frame < 0:
			_lost_at_frame = Engine.get_process_frames()
	elif quiet_ms > 250.0:
		state = "NOT ANSWERING for %d ms; the picture stands" % int(quiet_ms)
	_banner.text = "P8 spike: drawn by process %d, simulated by another (tick %d, %d B/tick)   simulation: %s" % [
		OS.get_process_id(), _s_frame, int(Wire.call("mean", _tick_sizes())), state]
	if not _shot_done and opts.has("out") and (_s_frame >= int(opts.get("shot", 600)) or not _bye.is_empty()):
		_shot_done = true
		_busy = true
		await _shoot(str(opts["out"]))
		_busy = false
	if not _bye.is_empty():
		_proc_quit(0)
	elif _lost_at_frame >= 0:
		_frames_after_loss = Engine.get_process_frames() - _lost_at_frame
		if _frames_after_loss >= int(opts.get("survive", 180)):
			if opts.has("out"):
				_busy = true
				await _shoot(str(opts["out"]).get_basename() + ".lost.png")
				_busy = false
			_proc_quit(0)
	elif _lat_n > 0 and _lat_frames.size() >= _lat_n and _lat_held.is_empty():
		_proc_quit(0)


func _tick_sizes() -> Array:
	return [float(int(link.get("bytes_in"))) / float(maxi(_ticks, 1))]


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) == OK:
		print("[proc] D capture: %s (%dx%d, simulation tick %d)" % [path, img.get_width(), img.get_height(), _s_frame])


func _apply(m: Array) -> void:
	_s_frame = int(m[1])
	_ticks += 1
	var first: bool = _ticks == 1
	for row: Array in (m[5] as Array):
		var id: int = int(row[0])
		var key: String = str(row[1])
		var kind: int = int(row[3])
		_table_rows += 1
		var mine: Node = _by_key.get(key) if first else null     # only what the build made can be matched by its place
		if mine != null and mine.get_class() == str(row[2]):
			_node[id] = mine
			_matched += 1
			continue
		if first:
			_unmatched_first += 1
			if _s_only.size() < 6:
				_s_only.append(key)
		else:
			_runtime_added += 1
			var what: String = str(row[2]) + " " + key.get_file().rstrip("0123456789@#")
			_added_names[what] = int(_added_names.get(what, 0)) + 1
		if not (kind & Wire.K_3D):
			continue
		var parent: Node = _node.get(int(row[4]))
		if parent != null and not is_instance_valid(parent):
			parent = null
		if kind & Wire.K_VFX:
			var holder: Node3D = Node3D.new()            # the effect itself is made below, once its place has arrived
			(parent if parent is Node3D else _fx_holder).add_child(holder)
			_node[id] = holder
			_standins[id] = true
			_pending_fx.append([holder, str(row[5])])
			continue
		var made: Node3D = Node3D.new()
		made.name = "S_" + str(id)
		if kind & Wire.K_BODY:
			var mi: MeshInstance3D = MeshInstance3D.new()    # a body S made after the build: D has no picture for it
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE * 0.3
			mi.mesh = box
			made.add_child(mi)
			_runtime_no_picture += 1
		(parent if parent != null else pack_node).add_child(made)
		_by_key[key] = made
		_node[id] = made
		_standins[id] = true
	var moved: PackedInt32Array = m[13]
	for i: int in range(0, moved.size(), 2):
		var who: Node = _node.get(moved[i])
		var to: Node = _node.get(moved[i + 1])
		if who != null and to != null and is_instance_valid(who) and is_instance_valid(to) and who.get_parent() != to:
			who.reparent(to, false)
			_moved_count += 1
	var ids: PackedInt32Array = m[2]
	var xf: PackedFloat32Array = m[3]
	for i: int in ids.size():
		var n: Node3D = _node.get(ids[i]) as Node3D
		if n != null and is_instance_valid(n):
			var o: int = i * 12
			n.transform = Transform3D(Vector3(xf[o], xf[o + 1], xf[o + 2]), Vector3(xf[o + 3], xf[o + 4], xf[o + 5]),
				Vector3(xf[o + 6], xf[o + 7], xf[o + 8]), Vector3(xf[o + 9], xf[o + 10], xf[o + 11]))
	for v: int in (m[4] as PackedInt32Array):
		var n: Node3D = _node.get(v >> 1) as Node3D
		if n != null and is_instance_valid(n) and not first:      # the first table is the build's own state: D keeps its own
			n.visible = (v & 1) == 1
	for id: int in (m[6] as PackedInt32Array):
		_removed_count += 1
		var n: Node = _node.get(id)
		if n != null and is_instance_valid(n):
			n.queue_free()
		_node.erase(id)
	var labels: Array = m[7]
	for i: int in range(0, labels.size(), 2):
		var l: Label = _node.get(int(labels[i])) as Label
		if l != null and is_instance_valid(l):
			l.text = str(labels[i + 1])
	var bones: Array = m[8]
	for i: int in range(0, bones.size(), 2):
		var sk: Skeleton3D = _node.get(int(bones[i])) as Skeleton3D
		var pose: PackedFloat32Array = bones[i + 1]
		if sk != null and is_instance_valid(sk) and pose.size() == sk.get_bone_count() * 10:
			for b: int in sk.get_bone_count():
				var o: int = b * 10
				sk.set_bone_pose_position(b, Vector3(pose[o], pose[o + 1], pose[o + 2]))
				sk.set_bone_pose_rotation(b, Quaternion(pose[o + 3], pose[o + 4], pose[o + 5], pose[o + 6]))
				sk.set_bone_pose_scale(b, Vector3(pose[o + 7], pose[o + 8], pose[o + 9]))
	var cams: PackedFloat32Array = m[9]
	for i: int in range(0, cams.size(), 4):
		var cam: Camera3D = _node.get(int(cams[i])) as Camera3D
		if cam != null and is_instance_valid(cam):
			cam.fov = cams[i + 1]
			cam.h_offset = cams[i + 2]
			cam.v_offset = cams[i + 3]
	for e: Array in (m[10] as Array):
		_events += 1
		if not first and _ticks > 2:
			TLAudio.play(StringName(str(e[0])), e[1])
	if int(m[11]) >= 0:
		var active: Camera3D = _node.get(int(m[11])) as Camera3D
		if active != null and is_instance_valid(active):
			active.current = true
	for fx: Array in _pending_fx:
		_vfx += 1
		if is_instance_valid(fx[0]):
			TLVfx.burst(StringName(str(fx[1])), (fx[0] as Node3D).global_position, _fx_holder)
	_pending_fx.clear()
	var echo: int = int(m[12])
	if echo > _echo_seen and _sent_at.has(echo):
		_rtt_us.append(Time.get_ticks_usec() - int(_sent_at[echo]))
		for s: int in range(_echo_seen + 1, echo + 1):
			_sent_at.erase(s)
		_echo_seen = echo


# ---------------------------------------------------------------------------------------------------- the end
func _proc_quit(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	var frames_drawn: int = Engine.get_process_frames() - _frames0
	var fig: Dictionary = {"proc": 1, "role": "draw", "mem_peak_mb": snappedf(float(OS.get_static_memory_peak_usage()) / 1048576.0, 0.1), "ready_ms": _ready_ms, "pack": ctx.pack_id, "ticks_received": _ticks, "last_tick": _s_frame,
		"frames_drawn": frames_drawn, "d_nodes": _d_nodes0, "s_nodes_at_start": _matched + _unmatched_first,
		"matched": _matched, "s_only_at_start": _unmatched_first, "s_only_sample": _s_only, "d_only": _d_nodes0 - _matched, "added_kinds": _added_names,
		"added_after_start": _runtime_added, "bodies_without_picture": _runtime_no_picture, "removed": _removed_count, "moved_to_another_parent": _moved_count,
		"sound_events": _events, "effects": _vfx, "bytes_in": int(link.get("bytes_in")), "inputs_sent": _seq,
		"apply_ms": {"mean": Wire.call("r3", float(Wire.call("mean", _apply_us)) / 1000.0), "p50": float(Wire.call("pct", _apply_us, 0.5)) / 1000.0,
			"p99": float(Wire.call("pct", _apply_us, 0.99)) / 1000.0},
		"frame_period_ms": {"p50": float(Wire.call("pct", _period_us, 0.5)) / 1000.0, "p99": float(Wire.call("pct", _period_us, 0.99)) / 1000.0,
			"max": float(Wire.call("pct", _period_us, 1.0)) / 1000.0},
		"input_round_trip_ms": {"p50": float(Wire.call("pct", _rtt_us, 0.5)) / 1000.0, "p99": float(Wire.call("pct", _rtt_us, 0.99)) / 1000.0,
			"mean": Wire.call("r3", float(Wire.call("mean", _rtt_us)) / 1000.0)},
		"tick_gap_max_ms": Wire.call("r3", _gap_max_ms), "s_lost": _lost_at_frame >= 0, "frames_drawn_after_loss": _frames_after_loss,
		"s_said_goodbye": not _bye.is_empty()}
	if _cpu0 >= 0.0 and frames_drawn > 0:
		fig["cpu_ms_per_frame"] = Wire.call("r3", (float(cpu.call("_read")) - _cpu0) / float(frames_drawn))
	if not _bye.is_empty():
		fig["s_state_hash"] = str(_bye.get("state_hash", ""))
	if _lat_n > 0:
		fig["key_to_picture"] = {"samples": _lat_frames.size(), "frames": _lat_frames, "frames_mean": Wire.call("r3", Wire.call("mean", _lat_frames)),
			"ms_mean": Wire.call("r3", Wire.call("mean", _lat_ms)), "ms_max": Wire.call("pct", _lat_ms, 1.0), "watch_found": _lat_watch != null}
	print(JSON.stringify(fig, "", false))
	link.call("close")
	_wd_mutex.lock()
	_wd_stop = true
	_wd_mutex.unlock()
	_wd_thread.wait_to_finish()
	cpu.call("stop")
	get_tree().quit(code)
