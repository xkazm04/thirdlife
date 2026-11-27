extends SceneTree
## Lane DN (day of 27 Nov 2026): day and night in the Home, headless (engine/tools/selftest.d/776-home-daynight.sh).
## Two runs of this script: `--mode=headless` (TLStyle headless, as every headless run) and `--mode=look` (TLStyle told
## it draws, so the kit builds its lights: the lamps' sockets and their choice exist; the renderer is still the dummy).
## Prints `HOME daynight.<case> ok|fail <detail>` lines and `HOME DONE`. Frames, not wall clock.
## headless:
##   clock     the cycle opened on a folder advances one frame of the day per physics frame; held, it stands; a cycle
##             no folder opened stands at noon (it is off)
##   keys      in build mode N steps noon -> dusk -> night -> dawn -> noon and H holds and runs again (each a save);
##             outside build mode, and while the command tool has the keyboard, N and H do nothing; neither is a key
##             build mode or a tool polls
##   settings  the file is tl.home-settings/1 with exactly schema, day.frame, day.cycle; a second cycle reads it back;
##             unknown keys, a wrong schema, a frame out of range are refused and that file is not written over;
##             build mode's build.json carries no day key
##   off       headless, 600 frames of a running cycle write no look (style_day.gd apply_day returns 0) and change no style data
##   stage     a game on stage: the clock holds and the look eases to noon's in EASE frames (lamps out); off the stage
##             the clock runs again and the look comes back to the clock's
##   noon      Day.day_look(0.5) is the style's own values key for key, and the globals it writes are those
##             TLStyle._register_globals writes (same formulas from the file: sun, shade, ambient, bounce, rims, haze, sun
##             direction), byte for byte; the light at 0.5 is the style's sun (elev, azim)
##   timeline  lamps 0 all day (0.375..0.625), > 0.9 all night; the light never below 4 degrees; at both blue hours the
##             lit band is the shade's colour (the sun-moon swap is not seen); dawn and dusk differ from noon
## window (`--mode=window`, run in a window, not part of 776: a real renderer answers global_shader_parameter_get):
##   window    after TLStyle.install, apply_day(day_look(0.5)) leaves every global, the sun's rotation and colour, the
##             environment's fog, ambient and exposure and every sky parameter as install set them (byte for byte); after
##             night and back to noon the same again
## look:
##   sockets   60 street lamps and 6 houses placed: one socket per kit light (60 + 18), none by day
##   cap       at night the CAP (48) nearest the camera are live, each a drawn light node, and every one that is not
##             live is at least as far as the farthest live one; by day none is drawn
##   follow    the camera moved 120 m: the live set follows it (nearest again) within CHOOSE_EVERY frames
##   dusk      at the dusk's strength some lamps are on and fewer than at night (they come on one by one)
##   lift      the lamps of lifted pieces go: their sockets are gone and no live light stands there
##   cost      the lamps' update per physics frame (microseconds, p50 and max over 600 frames, 78 sockets)

const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const HomeBuild := preload("res://kernel/world/build/home_build.gd")
const Cycle := preload("res://kernel/world/home/day_cycle.gd")
const Lamps := preload("res://kernel/world/home/day_lamps.gd")
const Day := preload("res://style/day/style_day.gd")
const TMP := "user://tl_day_case"

var ok_all := true
var mode := "headless"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME daynight.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	var tmp := ProjectSettings.globalize_path(TMP)
	CaseUtil.remove_dir(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	if mode == "look":
		TLStyle.set_headless(false)
		TLStyle.load_style(TLStyle._chosen_path())
		TLStyle.install(root)                          # the rig a window has (Sun, WorldEnvironment, ink, grade)
		var node := CaseUtil.landscape(root, CaseUtil.walk())
		var cyc: Node = node.get_meta(&"tl_home_day") if node.has_meta(&"tl_home_day") else null
		if cyc == null:
			say("mount", false, "no HomeDay on the Home's landscape")
		else:
			await off_case(cyc)
			await clock_case(cyc, tmp)
			await keys_case(node, cyc, tmp)
			settings_case(node, tmp)
			await stage_case(cyc)
		noon_case()
		timeline_case()
		await look_cases()
	elif mode == "window":
		await window_case()
	else:
		TLStyle.set_headless(true)
		await headless_case()
	CaseUtil.remove_dir(tmp)
	print("HOME daynight %s %s" % [mode, "ok" if ok_all else "fail"])
	print("HOME DONE")
	quit(0)


# ------------------------------------------------------------------ headless
func clock_case(cyc: Node, tmp: String) -> void:
	var off_before: int = cyc.frame_of_day
	var on_before: bool = cyc.on
	await wait(30)
	var off_after: int = cyc.frame_of_day
	cyc.open(tmp.path_join("clock"))
	var a: int = cyc.frame_of_day
	await wait(120)
	var b: int = cyc.frame_of_day
	cyc.running = false
	await wait(60)
	var c: int = cyc.frame_of_day
	cyc.running = true
	cyc.frame_of_day = Cycle.DAY_FRAMES - 10
	await wait(20)
	var wrap: int = cyc.frame_of_day
	var drew: int = cyc.writes
	say("clock", off_before == 43200 and off_after == 43200 and b - a == 120 and c == b and wrap == 10 and not on_before and cyc.on and drew > 0,
		"off: %d -> %d (noon, standing); on: +%d in 120 frames, held +%d in 60, wrapped to %d; %d looks written once on" % [off_before, off_after, b - a, c - b, wrap, drew])


func keys_case(node: Node3D, cyc: Node, tmp: String) -> void:
	var bm: Node = node.get_meta(&"tl_build_mode")
	var d := tmp.path_join("keys")
	cyc.dir = ""
	cyc.open(d)
	cyc.running = false
	cyc.frame_of_day = 43200
	var seen := []
	await press(KEY_N)                                   # build mode off: nothing
	var outside: int = cyc.frame_of_day
	await press(KEY_B)
	var entered: bool = bm.active
	for i in 4:
		await press(KEY_N)
		seen.append(cyc.phase_name() + "@" + str(cyc.frame_of_day))
	await press(KEY_H)
	var after_h: bool = cyc.running
	await wait(30)
	var ran: int = cyc.frame_of_day - 43200
	await press(KEY_H)
	var after_h2: bool = cyc.running
	var held_at: int = cyc.frame_of_day
	await wait(10)
	var still: bool = cyc.frame_of_day == held_at
	# the command tool has the keyboard: N does nothing
	bm.switch_tool(0, "command")
	await wait(2)
	var blocks: bool = bool(bm.tool().blocks_input())
	var before_cmd: int = cyc.frame_of_day
	await press(KEY_N)
	var cmd_ok: bool = (not blocks) or cyc.frame_of_day == before_cmd
	bm.switch_tool(0, "blocks")
	await press(KEY_B)
	var polled: Array = bm.get("_polled")
	var free_keys: bool = not polled.has(KEY_N) and not polled.has(KEY_H)
	var saved: bool = FileAccess.file_exists(d.path_join(Cycle.FILE))
	var want := ["dusk@64800", "night@0", "dawn@21600", "day@43200"]
	say("keys", entered and outside == 43200 and seen == want and after_h and ran >= 28 and ran <= 40 and not after_h2 and still and cmd_ok and free_keys and saved,
		"outside build mode N: %d; N x4: %s; H: run=%s, 30 frames ran %d, H: run=%s, stands=%s; command tool has the keyboard=%s, N then: %s; N,H polled by build mode: %s; saved: %s" % [
			outside, ",".join(seen), after_h, ran, after_h2, still, blocks, cmd_ok, not free_keys, saved])


func press(k: Key) -> void:
	CaseUtil.key(k, true)
	await wait(2)
	CaseUtil.key(k, false)
	await wait(2)


func settings_case(node: Node3D, tmp: String) -> void:
	var d := tmp.path_join("settings")
	var a: Node = Cycle.new()
	a.land = null
	a.open(d)
	a.frame_of_day = 12345
	a.running = false
	var e1: String = a.save("case")
	var text := FileAccess.get_file_as_string(d.path_join(Cycle.FILE))
	var doc: Variant = JSON.parse_string(text)
	var exact: bool = doc is Dictionary and (doc as Dictionary).keys() == ["schema", "day"] and str(doc.schema) == Cycle.SCHEMA \
		and (doc.day as Dictionary).keys() == ["frame", "cycle"] and int(doc.day.frame) == 12345 and str(doc.day.cycle) == "hold"
	var b: Node = Cycle.new()
	var r: String = b.open(d)
	var back: bool = r == "" and b.frame_of_day == 12345 and not b.running
	var bad := {}
	for k: String in ["unknown", "schema", "range", "cycle", "nested"]:
		var t: String = {"unknown": '{"schema":"tl.home-settings/1","day":{"frame":1,"cycle":"run"},"sun":1}',
			"schema": '{"schema":"tl.home-settings/2","day":{"frame":1,"cycle":"run"}}',
			"range": '{"schema":"tl.home-settings/1","day":{"frame":86400,"cycle":"run"}}',
			"cycle": '{"schema":"tl.home-settings/1","day":{"frame":1,"cycle":"stop"}}',
			"nested": '{"schema":"tl.home-settings/1","day":{"frame":1,"cycle":"run","speed":2}}'}[k]
		var bd := tmp.path_join("bad_" + k)
		DirAccess.make_dir_recursive_absolute(bd)
		var f := FileAccess.open(bd.path_join(Cycle.FILE), FileAccess.WRITE)
		f.store_string(t)
		f.close()
		var c: Node = Cycle.new()
		var why: String = c.open(bd)
		c.frame_of_day = 7
		c.save("case")
		var kept: bool = FileAccess.get_file_as_string(bd.path_join(Cycle.FILE)) == t
		bad[k] = why != "" and kept
		c.free()
	var all_bad := true
	for k: String in bad:
		all_bad = all_bad and bool(bad[k])
	# build mode's own file has no day key: save a build into its own folder and read it
	var bdir := tmp.path_join("build")
	var hb: RefCounted = node.get_meta(&"tl_build")
	var se: String = hb.call("save", bdir)
	var bj: Variant = JSON.parse_string(FileAccess.get_file_as_string(bdir.path_join("build.json")))
	var no_day: bool = bj is Dictionary and not (bj as Dictionary).has("day") and not (bj as Dictionary).has("settings")
	say("settings", se == "" and e1 == "" and exact and back and all_bad and no_day,
		"file %s; read back frame %d run=%s; refused and kept: %s; build.json keys %s" % [text.strip_edges().replace("\n", "").replace(" ", ""),
			b.frame_of_day, b.running, bad, (bj as Dictionary).keys() if bj is Dictionary else "unreadable"])
	a.free()
	b.free()


## Off until a folder is opened: 600 frames of the Home with no folder (a scripted run: build mode opened none) write
## no look and the clock stands at noon; the lamps stay out.
func stage_case(cyc: Node) -> void:
	var st := [-1]
	cyc.stage_at = func() -> int: return st[0]
	cyc.running = true
	cyc.frame_of_day = 0
	await wait(10)
	var night_lamps: float = float(cyc.last_look.get("lamps", 0.0))
	st[0] = 0
	await wait(5)
	var at: int = cyc.frame_of_day
	var mid: float = cyc.stage_w
	await wait(Cycle.EASE)
	var held: bool = cyc.frame_of_day == at
	var noon: Dictionary = Day.day_look(0.5)
	var eased: bool = cyc.stage_w == 1.0 and cyc.last_look["sun.color"] == noon["sun.color"] and float(cyc.last_look["lamps"]) == 0.0
	st[0] = -1
	await wait(Cycle.EASE + 5)
	var back: bool = cyc.frame_of_day > at and cyc.stage_w == 0.0 and float(cyc.last_look["lamps"]) > 0.9
	cyc.stage_at = Callable()
	say("stage", night_lamps > 0.9 and mid > 0.0 and mid < 1.0 and held and eased and back,
		"night lamps %.2f; on stage: ease %.2f after 5 frames, clock held %s, noon's look and lamps out after %d: %s; off stage: runs and night again: %s" % [
			night_lamps, mid, held, Cycle.EASE, eased, back])


func off_case(cyc: Node) -> void:
	var w0: int = cyc.writes
	await wait(600)
	var lamps: RefCounted = cyc.get("lamps")
	var gain: float = float(lamps.get("gain")) if lamps != null else 0.0
	say("off", cyc.writes == w0 and w0 == 0 and not cyc.on and cyc.frame_of_day == 43200 and gain == 0.0,
		"no folder opened: %d looks written in 600 frames, clock %s, lamp strength %.2f" % [cyc.writes - w0, cyc.clock(), gain])


## Headless (TLStyle.headless, as every headless run of the world and of a pack): the landscape grows no Home, so there
## is no clock (no HomeDay, no meta) and style_day.gd apply_day writes nothing for any look; the style's data stays as loaded.
func headless_case() -> void:
	TLStyle.ensure()
	var data_before: Dictionary = TLStyle.data
	var node := CaseUtil.landscape(root, CaseUtil.walk())
	await wait(60)
	var day_nodes := root.find_children("HomeDay", "", true, false).size()
	var wrote := 0
	for x: float in [0.0, 0.25, 0.5, 0.75]:
		wrote += Day.apply_day(node, Day.day_look(x))
	say("off_headless", day_nodes == 0 and not node.has_meta(&"tl_home_day") and wrote == 0 and is_same(TLStyle.data, data_before),
		"headless: %d HomeDay nodes, apply_day wrote %d values over four looks, style data the same object: %s" % [
			day_nodes, wrote, is_same(TLStyle.data, data_before)])


func noon_case() -> void:
	var d: Dictionary = TLStyle.data
	var lk: Dictionary = Day.day_look(0.5)
	var differ := []
	var n: Dictionary = Day.noon(d)
	for k: String in n:
		if lk.get(k) != n[k]:
			differ.append(k)
	for sec: String in Day.KEYS:
		for k: String in Day.KEYS[sec]:
			var raw: Variant = (d.get(sec, {}) as Dictionary).get(k)
			if raw == null:
				continue
			var want: Variant = Color(String(raw)) if raw is String else float(raw)
			if lk[sec + "." + k] != want:
				differ.append(sec + "." + k + " (file)")
	# the globals TLStyle._register_globals writes for these names, from the file, as it writes them
	var t: Dictionary = d["toon"]
	var sun: Dictionary = d["sun"]
	var sd: Vector3 = Basis.from_euler(Vector3(deg_to_rad(-float(sun["elev"])), deg_to_rad(180.0 - float(sun["azim"])), 0.0)).z
	var ref := {
		"g_sun": TLStyle._v4(TLStyle._lin(sun["color"]), float(sun["energy"])),
		"g_shade": TLStyle._v4(TLStyle._lin(t["shade"]), float(t["shade_k"])),
		"g_amb_sky": TLStyle._v4(TLStyle._lin(t["amb_sky"]), float(t["amb_energy"])),
		"g_amb_gnd": TLStyle._v4(TLStyle._lin(t["amb_ground"]), 1.0),
		"g_shade2": TLStyle._v4(TLStyle._lin(t.get("shade_ground", t["shade"])), float(t.get("shade_grad", 0.0))),
		"g_rim2": TLStyle._v4(TLStyle._lin(t.get("rim2", "#000000")), float(t.get("rim2_k", 0.0))),
		"g_bounce": TLStyle._v4(TLStyle._lin(t.get("bounce", "#000000")), float(t.get("bounce_k", 0.0))),
		"g_sun_dir": Vector4(sd.x, sd.y, sd.z, 0.0),
		"g_haze": TLStyle._v4(TLStyle._lin(d["fog"]["color"]), float(d["fog"]["density"])),
	}
	var g: Dictionary = Day.globals(d, lk)
	var gdiff := []
	for k: String in ref:
		if var_to_bytes(g.get(k)) != var_to_bytes(ref[k]):
			gdiff.append(k)
	var night_g: Dictionary = Day.globals(d, Day.day_look(0.0))
	var moved := 0
	for k: String in ref:
		if night_g[k] != ref[k]:
			moved += 1
	say("noon", differ.is_empty() and gdiff.is_empty() and g.size() == ref.size() and moved >= 7 and lk["sun.elev"] == float(sun["elev"]) and lk["sun.azim"] == float(sun["azim"]),
		"look keys differing from the file: %s; globals byte-different from install's: %s of %d; at night %d of them move; light %.1f/%.1f" % [
			differ, gdiff, ref.size(), moved, lk["sun.elev"], lk["sun.azim"]])


func timeline_case() -> void:
	var day_lamps := 0.0
	var night_min := 9.0
	var low := 90.0
	for i: int in 1001:
		var x := i / 1000.0
		var lk: Dictionary = Day.day_look(x)
		if x >= 0.375 and x <= 0.625:
			day_lamps = maxf(day_lamps, float(lk["lamps"]))
		if x <= 0.2 or x >= 0.8:
			night_min = minf(night_min, float(lk["lamps"]))
		low = minf(low, float(lk["sun.elev"]))
	var flat := true
	for x: float in [Day.BLUE_DAWN, Day.BLUE_DUSK]:
		var b: Dictionary = Day.day_look(x)
		flat = flat and b["sun.color"] == b["toon.shade"]
	var noon: Dictionary = Day.day_look(0.5)
	var dawn: Dictionary = Day.day_look(0.25)
	var dusk: Dictionary = Day.day_look(0.75)
	var differ: bool = dawn["sun.color"] != noon["sun.color"] and dusk["sky.horizon"] != noon["sky.horizon"]
	say("timeline", day_lamps == 0.0 and night_min > 0.9 and low >= 4.0 and flat and differ,
		"lamps by day max %.2f, by night min %.2f; lowest light %.1f deg; blue hours flat: %s; dawn and dusk differ from noon: %s" % [
			day_lamps, night_min, low, flat, differ])


# ------------------------------------------------------------------ look (the kit's lights exist)
func look_cases() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var b: RefCounted = HomeBuild.new(holder, null, {})
	var ops := []
	for i: int in 60:
		ops.append({"op": "put", "at": [(i % 10) * 12, 2, (i / 10) * 12], "part": "street_lamp", "rot": 0})
	for i: int in 6:
		ops.append({"op": "put", "at": [200 + i * 16, 2, 0], "part": "house", "rot": 0})
	var r: Dictionary = b.apply(ops)
	b.flush()
	var lamps: RefCounted = b.layer("pieces").get("draw").get("lamps")
	var cam := Vector3(0, 4, 0)
	lamps.update(0.0, cam)
	var f_day: Dictionary = lamps.figures()
	var socks: int = f_day.sockets
	say("sockets", int(r.applied) == 66 and socks == 60 + 18 and int(f_day.nodes) == 0,
		"%d pieces put, %d sockets (60 lamps + 6 houses x 3), %d light nodes drawn by day" % [int(r.applied), socks, int(f_day.nodes)])
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(1.0, cam)
	var f: Dictionary = lamps.figures()
	var nearest: bool = float(f.min_out_d) < 0.0 or float(f.max_live_d) <= float(f.min_out_d) + 0.001
	var on_nodes := _drawn(lamps)
	lamps.update(0.0, cam)
	var back_off: Dictionary = lamps.figures()
	say("cap", int(f.live) == Lamps.CAP and int(f.nodes) == Lamps.CAP and on_nodes == Lamps.CAP and nearest and int(back_off.nodes) == 0,
		"night: %d live of %d on (cap %d), %d light nodes drawn; farthest live %.1f m, nearest not live %.1f m; day again: %d drawn" % [
			int(f.live), int(f.on), Lamps.CAP, int(f.nodes), float(f.max_live_d), float(f.min_out_d), int(back_off.nodes)])
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(1.0, cam)
	var before := _live_ids(lamps)
	var cam2 := Vector3(320, 4, 0)
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(1.0, cam2)
	var f2: Dictionary = lamps.figures()
	var after := _live_ids(lamps)
	var houses_live := 0
	for id: String in after:
		if _socket_x(lamps, id) >= 190.0:
			houses_live += 1
	var near2: bool = float(f2.min_out_d) < 0.0 or float(f2.max_live_d) <= float(f2.min_out_d) + 0.001
	say("follow", after != before and houses_live == 18 and near2 and int(f2.live) == Lamps.CAP,
		"camera 320 m east: the 18 house lights all live (%d), farthest live %.1f m, nearest not live %.1f m, %d swaps so far" % [
			houses_live, float(f2.max_live_d), float(f2.min_out_d), int(f2.swaps)])
	var g_dusk: float = Day.day_look(0.66)["lamps"]
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(g_dusk, cam)
	var f3: Dictionary = lamps.figures()
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(1.0, cam)
	var f4: Dictionary = lamps.figures()
	say("dusk", int(f3.on) > 0 and int(f3.on) < int(f4.on),
		"at 15:50 (strength %.2f) %d lamps on; at night %d" % [g_dusk, int(f3.on), int(f4.on)])
	var lifts := []
	for i: int in 10:
		lifts.append({"op": "lift", "at": [(i % 10) * 12, 2, 0]})
	b.apply(lifts)
	b.flush()
	for i in Lamps.CHOOSE_EVERY:
		lamps.update(1.0, cam)
	var f5: Dictionary = lamps.figures()
	var stray := 0
	var socks_now: Dictionary = lamps.get("sockets")
	for sl: Dictionary in lamps.get("slots"):
		if str(sl.id) == "" or sl.node == null:
			continue
		var found := false
		for sct: Vector2i in socks_now:
			for sk: Array in socks_now[sct]:
				found = found or (sl.node as Node3D).transform.is_equal_approx(sk[2])
		if not found:
			stray += 1
	say("lift", int(f5.sockets) == socks - 10 and stray == 0,
		"10 lamps lifted: %d sockets, %d live lights left where they stood" % [int(f5.sockets), stray])
	var us := PackedInt64Array()
	for i in 600:
		var c := Vector3(float(i) * 0.5, 4, 30)
		var t0 := Time.get_ticks_usec()
		lamps.update(1.0, c)
		us.append(Time.get_ticks_usec() - t0)
	var order := us.duplicate()
	us.sort()
	var big := []
	for i: int in order.size():
		if order[i] > 2000:
			big.append("%d@%d" % [order[i], i])
	say("cost", true, "update per frame: p50 %d us, p99 %d us, max %d us (%d sockets, a choice every %d frames; over 2 ms: %s)" % [us[300], us[594], us[599], int(f5.sockets), Lamps.CHOOSE_EVERY, big])
	b.free_all()


func _drawn(lamps: RefCounted) -> int:
	var n := 0
	for sl: Dictionary in lamps.get("slots"):
		if sl.node != null and (sl.node as Light3D).visible and (sl.node as Light3D).light_energy > 0.0:
			n += 1
	return n


func _live_ids(lamps: RefCounted) -> Array:
	var out := []
	for sl: Dictionary in lamps.get("slots"):
		if str(sl.id) != "":
			out.append(str(sl.id))
	out.sort()
	return out


func _socket_x(lamps: RefCounted, id: String) -> float:
	var socks: Dictionary = lamps.get("sockets")
	for s: Vector2i in socks:
		for sk: Array in socks[s]:
			if str(sk[0]) == id:
				return (sk[2] as Transform3D).origin.x
	return -1.0


func _snapshot() -> Dictionary:
	var out := {}
	for g: String in ["g_sun", "g_shade", "g_amb_sky", "g_amb_gnd", "g_shade2", "g_rim2", "g_bounce", "g_sun_dir", "g_haze"]:
		out[g] = RenderingServer.global_shader_parameter_get(StringName(g))
	var rig: Node = root.find_child(TLStyle.RIG_NODE, true, false)
	var sun: DirectionalLight3D = rig.get_node("Sun")
	out["sun.rot"] = sun.rotation
	out["sun.color"] = sun.light_color
	out["sun.energy"] = sun.light_energy
	var key: Node = sun.get_node_or_null("OverheadKey")
	if key != null:
		out["key.normal"] = key.get("normal_pitch")
		out["key.over"] = key.get("overhead_pitch")
	var env: Environment = (rig.get_node("WorldEnvironment") as WorldEnvironment).environment
	for p: String in ["fog_light_color", "fog_density", "fog_height_density", "ambient_light_color", "tonemap_exposure"]:
		out["env." + p] = env.get(p)
	var sm: ShaderMaterial = env.sky.sky_material
	for k: String in Day.KEYS["sky"]:
		out["sky." + k] = sm.get_shader_parameter(k)
	var gm: ShaderMaterial = (rig.get_node("Grade/Rect") as CanvasItem).material
	for k: String in Day.KEYS["grade"]:
		out["grade." + k] = gm.get_shader_parameter(k)
	var wm: Variant = TLStyle._mats.get("water")
	if wm is ShaderMaterial:
		for k: String in Day.KEYS["water"]:
			out["water." + k] = (wm as ShaderMaterial).get_shader_parameter(k)
	return out


func _differ(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k: String in a:
		if var_to_bytes(a[k]) != var_to_bytes(b.get(k)):
			out.append("%s: %s -> %s" % [k, a[k], b.get(k)])
	return out


func window_case() -> void:
	TLStyle.load_style(TLStyle._chosen_path())
	TLStyle.material(&"water")
	TLStyle.install(root)
	await wait(3)
	var base := _snapshot()
	var n1: int = Day.apply_day(root, Day.day_look(0.5))
	await wait(2)
	var after := _snapshot()
	Day.apply_day(root, Day.day_look(0.0))
	await wait(2)
	var night := _snapshot()
	Day.apply_day(root, Day.day_look(0.5))
	await wait(2)
	var back := _snapshot()
	var d1 := _differ(base, after)
	var d2 := _differ(base, back)
	var moved := _differ(base, night).size()
	say("window", n1 > 0 and d1.is_empty() and d2.is_empty() and moved > 20 and not TLStyle.headless(),
		"%d values compared, %d written at noon; differing after noon: %s; after night and noon again: %s; %d of them move at night" % [
			base.size(), n1, d1, d2, moved])
