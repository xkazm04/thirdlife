extends Node3D
## The move lab (lane L2 fight-clips, 21 Nov 2026): the biped's fight clips at game scale, to judge by eye. Not part
## of any pack; it counts frames, never a clock. Run windowed (it renders), e.g. with the crisp look:
##   godot --path engine --resolution 1280x720 res://rigs/review/move_lab.tscn -- --mode=sheet --set=fight --cam=game \
##         --style=res://style/style_crisp.json --out=<sheet.png>
## Args after `--`:
##   --mode=sheet   a stills sheet: one row per clip, one tile per key frame (TLRigBipedFight.TIMING), cropped round the
##                  figure from the full frame, so a tile shows the figure at the size the camera gives it
##   --mode=clip    every clip of the set replayed side by side (write it with --write-movie); --frames=N
##   --set=fight    strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt (walking figure)
##   --set=hockey   a skater with a stick: cross_check, body_check, and stick_yaw at -1.2 .. 1.2, each beside an opponent
##   --cam=game     a third-person arena camera (11 m away, 6 m up, fov 50); close = 4.5 m; hockey = the hockey pack's
##                  broadcast camera (100.7 m up, fov 20); chase = the hockey chase camera (11 m back, 13 m up, fov 50)
##   --only=a,b     only these clips (fight set)
##   --style=<file> the look; --tile=px the crop (default by camera); --zoom=k scales each tile up (nearest) for viewing

const F := preload("res://rigs/biped/tl_rig_biped_fight.gd")
const FIGHT: Array = ["strike", "strike_heavy", "block", "roll", "dodge", "body_check", "cross_check", "taunt"]
const BLUE: Dictionary = {"top": "car_blue", "trim": "car_white", "legs": "bot_dark", "boots": "black"}
const RED: Dictionary = {"top": "car_red", "trim": "car_white", "legs": "bot_dark", "boots": "black"}

var args: Dictionary = {}
var cam: Camera3D
var label: Label
var frame: int = 0
var actors: Array = []      # [{rig, clip, base: Vector3, start}] in clip mode


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("style"):
		for note: String in TLStyle.load_style(String(args["style"])):
			print("[move_lab] style: " + note)
	TLStyle.install(self, {})
	var hockey: bool = String(args.get("set", "fight")) == "hockey"
	var fl: Node3D = TLKit.build("ground_patch", {"size_x": 120.0, "size_z": 120.0, "surface": "ice" if hockey else "dirt", "thickness": 0.3})
	add_child(fl)
	cam = Camera3D.new()
	cam.far = 1000.0
	add_child(cam)
	cam.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	if String(args.get("mode", "sheet")) == "sheet":
		_sheet.call_deferred(hockey)
	else:
		_setup_clip(hockey)


# ------------------------------------------------------------------ cameras
func _cam_at(target: Vector3, which: String) -> void:
	match which:
		"hockey":
			cam.fov = 20.0
			cam.look_at_from_position(target + Vector3(0, 100.7, 8.8), target + Vector3(0, 0, 0), Vector3.UP)
		"chase":
			cam.fov = 50.0
			cam.look_at_from_position(target + Vector3(0, 13.0, 11.0), target, Vector3.UP)
		"side":
			cam.fov = 40.0
			cam.look_at_from_position(target + Vector3(4.4, 1.6, 0.0), target + Vector3(0, 0.9, 0), Vector3.UP)
		"close":
			cam.fov = 40.0
			cam.look_at_from_position(target + Vector3(2.6, 2.2, -3.5), target + Vector3(0, 0.9, 0), Vector3.UP)
		_:
			cam.fov = 50.0
			cam.look_at_from_position(target + Vector3(6.2, 6.0, -8.9), target + Vector3(0, 0.9, 0), Vector3.UP)


static func _tile_px(which: String) -> int:
	return {"hockey": 110, "chase": 220, "close": 420, "side": 420}.get(which, 300)


# ------------------------------------------------------------------ the stills sheet
## Key frames of a clip: the start, the end of the wind-up, the middle and end of the active part, half-way through the
## recovery, the last frame (holds: 20 frames into the hold).
static func keyframes(clip: String) -> Array:
	var tm: Dictionary = F.TIMING[clip]
	var a: int = int(tm["anticipation"])
	var b: int = int(tm["active"])
	var n: int = int(tm["frames"])
	if clip == "taunt":
		return [1, 12, 35, 50, 65, 89]
	var out: Array = [1, maxi(1, a), (a + b + 1) / 2, b, (b + n) / 2, n if String(tm["end"]) == "returns" else n + 20]
	var uniq: Array = []
	for f: int in out:
		if not uniq.has(f):
			uniq.append(f)
	return uniq


func _rows(hockey: bool) -> Array:
	# [title, clip, params, extra]: extra {"yaw": radians} for the stick turn
	if not hockey:
		var r: Array = []
		for c: String in FIGHT:
			if not args.has("only") or String(args["only"]).split(",").has(c):
				r.append([c, c, {"colors": BLUE}, {}])
		return r
	var sk: Dictionary = {"mode": "skate", "stick": true, "colors": BLUE}
	return [["cross_check (skate, stick)", "cross_check", sk, {}], ["body_check (skate, stick)", "body_check", sk, {}],
		["stick_yaw -1.2 .. +2.0 (glide)", "", sk, {"yaws": [-1.2, -0.6, 0.0, 0.6, 1.2, 2.0]}]]


func _sheet(hockey: bool) -> void:
	var which: String = String(args.get("cam", "hockey" if hockey else "game"))
	var px: int = int(args.get("tile", str(_tile_px(which))))
	var zoom: int = int(args.get("zoom", "1"))
	var rows: Array = _rows(hockey)
	var cols: int = 6
	var tile: int = px * zoom
	var sheet: Image = Image.create(cols * tile, rows.size() * tile, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	_cam_at(Vector3.ZERO, which)
	for k: int in 3:
		await RenderingServer.frame_post_draw
	for ri: int in rows.size():
		var row: Array = rows[ri]
		var cells: Array = []
		if (row[3] as Dictionary).has("yaws"):
			for y: float in row[3]["yaws"]:
				cells.append([0, y])
		else:
			for f: int in keyframes(String(row[1])):
				cells.append([f, 0.0])
		for ci: int in mini(cells.size(), cols):
			var f: int = int(cells[ci][0])
			var rig: Node3D = TLRigs.build("biped", row[2])
			add_child(rig)
			var opp: Node3D = null
			if hockey and not (row[3] as Dictionary).has("yaws"):
				opp = TLRigs.build("biped", {"mode": "skate", "stick": true, "colors": RED})
				opp.position = Vector3(0, 0, -1.6)
				opp.rotation.y = PI
				add_child(opp)
				opp.call("set_locomotion", Vector3.ZERO, true)
				opp.call("tick", 1)
			if (row[3] as Dictionary).has("yaws"):
				rig.call("set_param", &"stick_yaw", float(cells[ci][1]))
				for k: int in 30:
					rig.call("set_locomotion", Vector3.ZERO, true)
					rig.call("tick", k + 1)
			else:
				_pose_at(rig, String(row[1]), f)
			_cam_at(Vector3.ZERO, which)
			var c2: Vector2 = cam.unproject_position(Vector3(0, 0.9, 0))
			var vp: Vector2 = get_viewport().get_visible_rect().size
			var r0: Vector2i = Vector2i(clampi(int(c2.x) - px / 2, 0, int(vp.x) - px), clampi(int(c2.y) - px / 2, 0, int(vp.y) - px))
			label.position = Vector2(r0) + Vector2(4, 2)
			label.text = ("%s  yaw %+.1f" % [row[0], float(cells[ci][1])]) if (row[3] as Dictionary).has("yaws") else ("%s  f%d" % [row[0], f] if ci > 0 or px < 200 else "%s\nf%d" % [row[0], f])
			if px < 150:
				label.text = "%s f%d" % [String(row[1]).replace("_check", ""), f] if not (row[3] as Dictionary).has("yaws") else "yaw %+.1f" % float(cells[ci][1])
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var crop: Image = img.get_region(Rect2i(r0, Vector2i(px, px)))
			if zoom > 1:
				crop.resize(tile, tile, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(crop, Rect2i(0, 0, tile, tile), Vector2i(ci * tile, ri * tile))
			rig.queue_free()
			if opp != null:
				opp.queue_free()
			await get_tree().process_frame
	var out: String = String(args.get("out", "user://move_lab_sheet.png"))
	sheet.save_png(out)
	print("[move_lab] sheet %s (%d x %d tiles of %d px, cam %s)" % [out, cols, rows.size(), tile, which])
	get_tree().quit()


## Plays `clip` from rest and ticks it to frame `f` (f ticks after the play, as a pack's frame loop does). A dodge is
## seen moving to its right (velocity_local.x = +3 m/s on its first tick).
static func _pose_at(rig: Node3D, clip: String, f: int) -> void:
	rig.call("set_locomotion", Vector3.ZERO, true)
	rig.call("tick", 0)
	rig.call("play", StringName(clip), 0.0)
	for k: int in f:
		rig.call("set_locomotion", Vector3(3.0 if clip == "dodge" and k < 4 else 0.0, 0, 0), true)
		rig.call("tick", k + 1)


# ------------------------------------------------------------------ the clip: everything replayed side by side
const CYCLE: int = 100


func _setup_clip(hockey: bool) -> void:
	var lineup: Array = []
	if hockey:
		var sk: Dictionary = {"mode": "skate", "stick": true, "colors": BLUE}
		lineup = [["cross_check", sk], ["body_check", sk], ["stick_yaw", sk]]
	else:
		for c: String in ["strike", "strike_heavy", "block", "taunt", "roll", "dodge", "body_check", "cross_check"]:
			lineup.append([c, {"colors": BLUE}])
	var per_row: int = 4 if not hockey else 3
	for i: int in lineup.size():
		var rig: Node3D = TLRigs.build("biped", lineup[i][1])
		var base: Vector3 = Vector3((float(per_row - 1) * 0.5 - float(i % per_row)) * 3.2, 0, float(i / per_row) * 5.6 - 2.8 * float((lineup.size() - 1) / per_row))
		rig.position = base
		add_child(rig)
		var tag: Label3D = Label3D.new()
		tag.text = String(lineup[i][0])
		tag.font_size = 56
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = base + Vector3(0, 2.35, 0)
		tag.outline_size = 10
		add_child(tag)
		var opp: Node3D = null
		if hockey:
			opp = TLRigs.build("biped", {"mode": "skate", "stick": true, "colors": RED})
			opp.position = base + Vector3(0, 0, -1.7)
			opp.rotation.y = PI
			add_child(opp)
		actors.append({"rig": rig, "clip": String(lineup[i][0]), "base": base, "opp": opp})
	var which: String = String(args.get("cam", "chase" if hockey else "game"))
	if which == "game":
		cam.fov = 50.0
		cam.look_at_from_position(Vector3(2.4, 7.0, -11.4), Vector3(0, 0.3, 0.6), Vector3.UP)
	else:
		_cam_at(Vector3(0, 0, -0.8), which)
	label.position = Vector2(12, 8)


func _physics_process(_dt: float) -> void:
	if actors.is_empty():
		return
	frame += 1
	var k: int = (frame - 1) % CYCLE
	label.text = "fight clips at game scale (%s), frame %d of a %d-frame cycle" % [String(args.get("style", "style.json")).get_file(), k, CYCLE]
	for a: Dictionary in actors:
		var rig: Node3D = a["rig"]
		var clip: String = a["clip"]
		var tm: Dictionary = F.TIMING.get(clip, {})
		var v: Vector3 = Vector3.ZERO
		var off: Vector3 = Vector3.ZERO
		if clip == "stick_yaw":
			rig.call("set_param", &"stick_yaw", 1.2 * sin(TAU * float(frame) / 120.0))
		elif k == 20:
			rig.call("play", StringName(clip), 0.15)
		elif k == 20 + int(tm["frames"]) + 30 and String(tm["end"]) == "holds":
			rig.call("play", &"", 0.15)
		var c: int = k - 20
		# the pack moves the body: a roll travels 2.6 m, a dodge 1.3 m to the right, a check lunges 0.9 m
		if clip == "roll":
			off = Vector3(0, 0, -2.6 * smoothstep(0.0, 24.0, float(c)))
			v = Vector3(0, 0, -6.5) if c >= 0 and c < 24 else Vector3.ZERO
		elif clip == "dodge":
			off = Vector3(1.3 * smoothstep(0.0, 10.0, float(c)), 0, 0)
			v = Vector3(4.0, 0, 0) if c >= 0 and c < 10 else Vector3.ZERO
		elif clip == "body_check":
			off = Vector3(0, 0, -0.9 * smoothstep(4.0, 16.0, float(c)))
		elif clip == "cross_check":
			off = Vector3(0, 0, -0.4 * smoothstep(6.0, 12.0, float(c)))
		rig.position = (a["base"] as Vector3) + off
		rig.call("set_locomotion", v, true)
		rig.call("tick", frame)
		if a["opp"] != null:
			(a["opp"] as Node3D).call("set_locomotion", Vector3.ZERO, true)
			(a["opp"] as Node3D).call("tick", frame)
	if args.has("frames") and frame >= int(args["frames"]):
		get_tree().quit()
