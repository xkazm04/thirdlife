extends RefCounted
## WP2 + SEAM: build mode's test hook, moved out of build_mode.gd unchanged. TL_BUILD_DEVICES="<frame>:<kind>[:<args>];..."
## counts build mode's own physics frames, which are boot.gd's frames in the exe (both start on the same tick). Kinds:
##   px:x,y         the pointer at that pixel          at:x,y,z   the pointer at the pixel of that world point, followed
##   mouse          the real mouse again                          every frame
##   lmb|rmb|mmb:1|0  a button (held ones are pressed again after a focus loss, as boot does for keys)
##   key:<Key>:1|0  a key                              fill:x0,y0,z0,x1,y1,z1,shape,mat   one batch: a box of blocks
##   state          prints a `build_state` line
## While it runs, each edit prints a `build_edit` line (tools/blocks_tool.gd). TL_EXE_KEYS cannot click or set an
## absolute pointer, so this hook does that part.

var host: Node                          # build_mode.gd
var plan := {}                          # frame -> [[kind, args], ...]
var aim_at: Variant = null              # `at`: a world point the pointer follows
var held := {}                          # buttons the script holds down


func _init(h: Node, text: String) -> void:
	host = h
	for part: String in text.split(";", false):
		var f := part.strip_edges().split(":")
		if f.size() < 2 or not f[0].is_valid_int():
			print("[build] TL_BUILD_DEVICES: cannot read '%s'" % part)
			continue
		var t := int(f[0])
		if not plan.has(t):
			plan[t] = []
		(plan[t] as Array).append(f.slice(1))


func run(frame: int) -> void:
	for e: PackedStringArray in plan.get(frame, []):
		var a := e[1].split(",") if e.size() > 1 else PackedStringArray()
		match e[0]:
			"px":
				aim_at = null
				host.pointer = Vector2(float(a[0]), float(a[1]))
			"at":
				aim_at = Vector3(float(a[0]), float(a[1]), float(a[2]))
			"mouse":
				aim_at = null
				host.pointer = Vector2(-1.0, -1.0)
			"lmb", "rmb", "mmb":
				var bi: int = {"lmb": MOUSE_BUTTON_LEFT, "rmb": MOUSE_BUTTON_RIGHT, "mmb": MOUSE_BUTTON_MIDDLE}[e[0]]
				button(bi, a[0] == "1")
				if a[0] == "1": held[bi] = true
				else: held.erase(bi)
			"key":
				var k := InputEventKey.new()
				k.keycode = OS.find_keycode_from_string(e[1])
				k.physical_keycode = k.keycode
				k.pressed = e.size() > 2 and e[2] == "1"
				Input.parse_input_event(k)
				Input.flush_buffered_events()
			"fill":
				var v := a
				var ops := []
				for y: int in range(int(v[1]), int(v[4]) + 1):
					for z: int in range(int(v[2]), int(v[5]) + 1):
						for x: int in range(int(v[0]), int(v[3]) + 1):
							ops.append({"op": "place", "at": [x, y, z], "shape": int(v[6]), "mat": int(v[7]), "rot": 0})
				var r: Dictionary = host.build.apply(ops)
				print(JSON.stringify({"schema": "tl.view/1", "kind": "build_fill", "frame": frame, "ops": ops.size(),
					"applied": int(r.applied), "refused": (r.refused as Array).size(), "reason": str(r.reason)}, "", false))
			"state":
				var c: Camera3D = host._cam()
				var vis: Node3D = host._visitor()
				print(JSON.stringify({"schema": "tl.view/1", "kind": "build_state", "frame": frame, "active": host.active,
					"tool": str(host.tool().get("id")), "shape": host.shape, "mat": host.mat, "reason": host.reason,
					"pick": str((host.hit as Dictionary).get("place", "")), "pointer": str((host.pointer as Vector2).snapped(Vector2.ONE)),
					"stats": host.build.stats(), "cam": str(c.global_position.snapped(Vector3.ONE * 0.01)) if c != null else "",
					"feet": str(vis.get("feet")) if vis != null else ""}, "", false))
	# a button the script holds is pressed again when the engine let go of it (another window took the focus), as
	# boot.gd does for the keys of TL_EXE_KEYS
	for bi: int in held:
		if not Input.is_mouse_button_pressed(bi):
			button(bi, true)


func button(bi: int, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = bi as MouseButton
	mb.pressed = down
	mb.position = host.pointer
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
