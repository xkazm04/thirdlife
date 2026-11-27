extends SceneTree
## Lane F3 (27 Nov 2026): what play shows a newcomer of the rules (the playtest's "nothing says E", "a hazard is an
## invisible box", "1 coins", "lamps at night, and you cannot have them"), headless. Prints `HOME play-shows.<case>
## ok|fail <detail>`, `HOME play-shows ok|fail`, `HOME DONE`; selftest 803 reads them. Frames, not wall clock.
##   prompt   rules_play.gd `use_prompt`: in the Switch zone of play_case_course.gd's walk the prompt is "open Door" and
##            the HUD shows it (lines.prompt, the box visible); a toggle reads "close" once open; out of every use zone ""
##   looks    play_looks.gd: `roles` names a respawning zone `hazard` and an opened one `door`; a hazard of look none is
##            red and white stripes on its floor (both palette keys, its node at the floor centre); a door's frame goes
##            round its blocks (a 3-deep preset zone: the wall's slice) and outside them, on the wall's two faces
##   counters play_hud.gd: no chip and no text at 0; "1 coin", "2 coins"; "1 hop"; "glass" kept
##   lamps    unlocks.json: the street lamp is open with no trophies; the light mast and plaster still wait for play

const Course := preload("res://kernel/world/build/play_case_course.gd")
const PlayLooks := preload("res://kernel/world/build/play_looks.gd")
const PlayHud := preload("res://kernel/world/build/play_hud.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const TMP := "user://tl_play_shows_case"

var ok_all := true


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME play-shows.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP)
	await prompt_case()
	looks_case()
	await counters_case()
	lamps_case()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	PlayLooks._meshes.clear()
	print("HOME play-shows %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func prompt_case() -> void:
	var c: RefCounted = Course.new(self)
	var why: String = c.call("make", root, TMP)
	if why != "":
		say("prompt", false, why)
		return
	var v: Node3D = c.get("v")
	var p: RefCounted = c.get("p")
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)
	var away := str(p.get("prompt"))
	v.call("put", Vector3(0.0, 0.0, 3.5), float(v.get("look_yaw")), false)          # the Switch pad (zone 4)
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)
	var on := str(p.get("prompt"))
	var hud: Node = p.get("hud")
	var shown := str((hud.get("lines") as Dictionary).get("prompt", "")) if hud != null else ""
	var box: Variant = hud.get("_prompt_box") if hud != null else null
	var vis := box is Control and (box as Control).visible
	# a toggle: the same zone's rule made `toggle` reads "close Door" while the door is open
	var rules: Dictionary = p.get("run").get("layer").get("rules")
	(rules[3].do as Array)[0] = {"do": "toggle", "zone": 3}
	p.get("run").get("layer").set("revision", int(p.get("run").get("layer").get("revision")) + 1)
	await c.call("frame", Vector3.ZERO, true)
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)                                   # (a frame's tick is read in the next frame)
	var after := str(p.get("prompt")) + ("" if bool(p.get("run").call("is_open", 3)) else " (not open)")
	v.call("put", Vector3(0.0, 0.0, 9.5), float(v.get("look_yaw")), false)
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)
	var gone := str(p.get("prompt"))
	var shown_gone := str((hud.get("lines") as Dictionary).get("prompt", "x")) if hud != null else "x"
	say("prompt", away == "" and on == "open Door" and shown == on and vis and after == "close Door" and gone == "" and shown_gone == "",
		"away '%s'; on the Switch '%s' (HUD '%s', shown %s); a toggle, E: '%s'; on the Start '%s' (HUD '%s')" % [away, on, shown, vis, after, gone, shown_gone])
	c.call("free_all")
	await wait(3)


func looks_case() -> void:
	var bad := []
	var rules := {1: {"id": 1, "when": {"on": "enter", "zone": 1}, "do": [{"do": "respawn"}]},
		2: {"id": 2, "when": {"on": "use", "zone": 2}, "do": [{"do": "open", "zone": 3}]},
		3: {"id": 3, "when": {"on": "enter", "zone": 4}, "do": [{"do": "start", "run": "R"}]},
		4: {"id": 4, "when": {"on": "leave", "zone": 5}, "do": [{"do": "respawn"}]}}
	var role: Dictionary = PlayLooks.roles(rules)
	if str(role) != str({1: "hazard", 3: "door", 4: "start"}):
		bad.append("roles %s" % str(role))
	var hz: Node3D = PlayLooks.look_of({"id": 1, "box": [[4, 1, 0], [7, 1, 4]], "look": "none"}, "hazard")
	var keys := []
	if hz != null:
		var m: ArrayMesh = (hz.get_child(0) as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var mat: Material = m.surface_get_material(i)
			keys.append(str(mat.resource_name) if mat != null else "?")
	if hz == null or hz.position != Vector3(6.0, 1.0, 2.5) or hz.get_child_count() != 2 or str(hz.get_meta(&"tl_look", "")) != "hazard":
		bad.append("hazard look %s" % (str(hz.position) if hz != null else "null"))
	var plain: Variant = PlayLooks.look_of({"id": 6, "box": [[0, 0, 0], [0, 0, 0]], "look": "none"})
	if plain != null:
		bad.append("a zone of look none with no role has a look")
	# a door preset's zone: 1 wide, 2 high, grown to 3 deep along z; the wall runs along x at z 10
	var wall := {}
	for x in range(-3, 4):
		for y in range(1, 3):
			wall[Vector3i(x, y, 10)] = true
	var solid := func(c: Vector3i) -> bool: return wall.has(c)
	var box := [[0, 1, 9], [0, 2, 11]]
	var op: Dictionary = PlayLooks.door_opening(box, solid)
	var dz: Node3D = PlayLooks.look_of({"id": 3, "box": box, "look": "none", "opening": op}, "door")
	var aabb := AABB()
	if dz != null:
		aabb = ((dz.get_child(0) as MeshInstance3D).mesh as ArrayMesh).get_aabb()
		aabb.position += dz.position
	var want_op := {"lo": Vector3i(0, 1, 10), "hi": Vector3i(0, 2, 10), "faces_z": true}
	if str(op) != str(want_op) or dz == null or aabb.position.z > 9.99 or aabb.end.z < 11.01 or aabb.position.x > -0.05 or aabb.end.x < 1.05 \
			or aabb.end.y < 3.05 or aabb.position.z < 9.8 or aabb.end.z > 11.2:
		bad.append("door opening %s, frame %s" % [str(op), str(aabb)])
	for n: Variant in [hz, dz]:
		if n is Node:
			(n as Node).free()
	say("looks", bad.is_empty(), "roles hazard/door; hazard stripes at the floor centre (%s) with a shimmer; door frame round the wall's slice %s, frame box %s%s" % [
		"%d surfaces" % keys.size(), str(op), str(aabb), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])


func counters_case() -> void:
	var hud: CanvasLayer = PlayHud.new()
	root.add_child(hud)
	await wait(1)
	var st := {"running": true, "run": "R", "frames": 10, "counters": {}}
	var got := []
	for n: int in [0, 1, 2]:
		st.counters = {"coins": n} if n > 0 else {}
		hud.call("tick", n, st, ["coins"])
		var chips: Control = hud.get("_counters")
		got.append([str(hud.get("lines").counters), chips.visible])
	var words := [PlayHud.count_text("hops", 1), PlayHud.count_text("glass", 1), PlayHud.count_text("door_a", 2)]
	var ok := str(got) == str([["", false], ["1 coin", true], ["2 coins", true]]) and str(words) == str(["1 hop", "1 glass", "2 door a"])
	say("counters", ok, "coins 0, 1, 2: %s; %s" % [str(got), str(words)])
	hud.queue_free()
	await wait(1)


func lamps_case() -> void:
	var u: RefCounted = Unlocks.new("")
	var got := {"parts:street_lamp": u.locked("parts", "street_lamp"), "parts:light_mast": u.locked("parts", "light_mast"),
		"mats:12": u.locked("mats", 12), "parts:bench": u.locked("parts", "bench")}
	var ok: bool = got["parts:street_lamp"] == "" and got["parts:light_mast"] != "" and got["mats:12"] != "" and got["parts:bench"] != "" \
		and (u.get("errors") as Array).is_empty()
	say("lamps", ok, "no trophies: %s" % str(got))
