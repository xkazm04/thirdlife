extends SceneTree
## M5 lane L (spark world-sandbox): the scene of the land-look captures, made headless with the real tools as a person
## drives them (B, T, the keys, the pointer, LMB held for frames), then saved as a Home build file that a windowed run
## loads (TL_HOME_BUILD_DIR) for its picture. The same pointer path and frames before and after a change to the
## brush, the mesh or the shader give before/after pictures from the same camera. Not a selftest: a capture helper.
##   godot --headless --fixed-fps 60 --path engine --script res://kernel/world/build/land_shots.gd -- --out=<abs dir>
## Prints `SHOT <name> at x,z look x2,z2` (the TL_EXE_START of its picture) and `SHOTS DONE`.
##   hill     raise (1), brush 6 (18 m), 120 frames still
##   terrace  flatten (3) on a slope, brush 5, 60 frames still
##   paint    dirt (4), brush 2, an arc of 40 frames
##   meadow   (plants, when the plant tool is built) meadow, flowers and tall grass side by side (brush 2, 14 m apart)
##   river    lower (2) 80 m from the river line, below the river's level, brush 5, 90 frames (the river-band check;
##            refused where the land layer refuses it)

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const CAM_H := 40.0

var node: Node3D
var b: RefCounted
var bm: Node
var land: RefCounted
var cam: Camera3D
var out := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	call_deferred("run")


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	if out == "":
		print("SHOTS fail: --out=<abs dir> is missing")
		quit(1)
		return
	node = CaseUtil.landscape(root, CaseUtil.walk())
	b = node.get_meta(&"tl_build")
	bm = node.get_meta(&"tl_build_mode")
	land = b.layer("land")
	var tmp := ProjectSettings.globalize_path("user://tl_land_shots")
	CaseUtil.remove_dir(tmp)
	bm.call("open", tmp)
	var far := Vector3(2000.0, 0.0, 2000.0)
	bm.set("feet_at", func() -> Vector3: return far)
	b.protect.visitor_at = func() -> Vector3: return far
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	bm.set("cam", cam)
	root.size = Vector2i(1280, 720)
	var home: RefCounted = node.get_meta(&"tl_home")
	var hill := free_site(Vector2(480, -480), 30.0, 0.0)
	var terrace := free_site(hill + Vector2(150, 0), 24.0, 0.18)
	var paint := free_site(hill + Vector2(0, 110), 18.0, 0.0)
	var meadow := free_site(hill + Vector2(-110, 40), 24.0, 0.0)
	for p: Vector2 in [hill, terrace, paint, meadow]:
		home.ensure(p)
	await wait(3)
	await tap(KEY_B)
	await to_tool("sculpt")
	# hill: raise, brush 6
	await set_radius(6)
	await tap(KEY_1)
	await stroke(hill, 120)
	shot("hill", hill, 48.0)
	# terrace: flatten on the slope, brush 5
	await set_radius(5)
	await tap(KEY_3)
	await stroke(terrace, 60)
	shot("terrace", terrace, 28.0)
	# paint: dirt along an arc, brush 2
	await to_tool("paint")
	await set_radius(2)
	await tap(KEY_4)
	var arc := []
	for k: int in 41:
		var a := -0.9 + 1.8 * k / 40.0
		arc.append(paint + Vector2(sin(a), cos(a) - 1.0) * 16.0)
	await stroke_path(arc)
	shot("paint", paint, 30.0)
	# meadow and flowers (the plant tool, once built)
	if await to_tool("plant") and not (bm.call("tool").slots() as Array).is_empty():
		await set_radius(2)
		for k: int in 3:
			await tap([KEY_1, KEY_2, KEY_3][k])
			await stroke(meadow + Vector2(-14.0 + 14.0 * k, -4.0), 4)
			await stroke(meadow + Vector2(-14.0 + 14.0 * k, 4.0), 4)
		shot("meadow", meadow, 22.0)
	# the river band: a hollow 80 m east of the river line, below the river's level
	var v: RefCounted = home.ground.land
	var rz := 420.0
	var river := Vector2(float(v.river_x(rz)) + 80.0, rz)
	home.ensure(river)
	await wait(2)
	print("SHOT river_ground at %s (%.1f m from the line) %.2f m, river level %.2f m, why '%s'" % [str(river), river.x - float(v.river_x(rz)), land.height_at(river.x, river.y), float(v.level(rz)), land.refusal(vtx(river), "land")])
	await to_tool("sculpt")
	await set_radius(5)
	await tap(KEY_2)
	for k: int in 5:
		await stroke(river, 90)
	print("SHOT river_after %.2f m (reason '%s')" % [land.height_at(river.x, river.y), str(bm.call("tool").get("reason"))])
	var east := river + Vector2(40.0, 0.0)
	print("SHOT river start %.1f,%.1f,%.1f,%.1f ground %.2f" % [east.x + 30.0, east.y, east.x, east.y, land.height_at(river.x, river.y)])
	await tap(KEY_B)
	b.flush()
	var why: String = b.save(out)
	print("SHOTS saved %s '%s' (%d land, %d paint)" % [out, why, land.store.heights.size(), land.store.paints.size()])
	CaseUtil.remove_dir(tmp)
	print("SHOTS DONE")
	quit(0)


## A spot near `want` whose ground within `r` m nothing protects, with at least `slope` of gradient.
func free_site(want: Vector2, r: float, slope: float) -> Vector2:
	for ring: int in 40:
		for k: int in maxi(1, ring * 6):
			var p := want + Vector2.from_angle(TAU * k / maxi(1, ring * 6)) * ring * 12.0
			var g := Vector2(land.height_at(p.x + 3, p.y) - land.height_at(p.x - 3, p.y), land.height_at(p.x, p.y + 3) - land.height_at(p.x, p.y - 3)) / 6.0
			if g.length() < slope:
				continue
			var ok := true
			for j: int in range(-ceili(r / 3), ceili(r / 3) + 1):
				for i: int in range(-ceili(r / 3), ceili(r / 3) + 1):
					ok = ok and land.refusal(vtx(p) + Vector2i(i, j), "land") == ""
			if ok:
				return p
	return want


## The TL_EXE_START of a picture of `p` from `dist` m to its south-east, looking at it (boot.gd walks the visitor
## from the first point to the second at frame 61: he ends at the second, facing along the line).
func shot(name: String, p: Vector2, dist: float) -> void:
	var d := Vector2(0.55, 0.83).normalized()
	var a := p + d * (dist + 20.0)
	var b := p + d * dist
	print("SHOT %s start %.1f,%.1f,%.1f,%.1f ground %.2f" % [name, a.x, a.y, b.x, b.y, land.height_at(p.x, p.y)])


func vtx(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


func to_tool(id: String) -> bool:
	for i in (bm.get("tools") as Array).size():
		if str(bm.call("tool").get("id")) == id:
			return true
		await tap(KEY_T)
	return str(bm.call("tool").get("id")) == id


func set_radius(r: int) -> void:
	for i in 10:
		await tap(KEY_BRACKETLEFT)
	for i in r - 1:
		await tap(KEY_BRACKETRIGHT)


func tap(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


func button(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = bm.get("pointer")
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func point(p: Vector2) -> void:
	cam.look_at_from_position(Vector3(p.x, land.height_at(p.x, p.y) + CAM_H, p.y + 0.01), Vector3(p.x, land.height_at(p.x, p.y), p.y), Vector3.FORWARD)
	cam.reset_physics_interpolation()
	var q := p + Vector2(0.23, 0.31)
	bm.set("pointer", cam.unproject_position(Vector3(q.x, land.height_at(q.x, q.y), q.y)))


func stroke(at: Vector2, frames: int) -> void:
	point(at)
	await wait(2)
	button(true)
	await wait(frames)
	button(false)
	await wait(3)
	b.flush()


func stroke_path(pts: Array) -> void:
	point(pts[0])
	await wait(2)
	button(true)
	for p: Vector2 in pts:
		point(p)
		await wait(1)
	button(false)
	await wait(3)
	b.flush()
