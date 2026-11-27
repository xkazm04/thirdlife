extends SceneTree
## Lane P (M6 round 2, 27 Nov 2026): the headless case of selftest 791 (engine/tools/selftest.d/791-home-run-ghost.sh):
## the best run's ghost (play_ghost.gd, contracts/BUILD.md "The best run's ghost"). A straight track in a world space of
## its own (play_case_course.gd with other zones): a Start pad (enter: start "Dash") and a Flag 8 m on (enter: finish);
## a real visitor steered as keys steer it. Prints `HOME run-ghost.<case> ok|fail <detail>`, `HOME run-ghost ok`,
## `HOME DONE`. Frames, not wall clock.
##   written   the first finish (a new best) writes runs/dash.json: tl.run-ghost/1, frames = the run's, frames/2 + 1
##             samples, sample 0 = his feet at the run's frame 0; text_of(read(file)) is the file byte for byte
##   kept      a slower finish (no new best) leaves the file byte for byte; a faster one replaces it (frames, samples)
##   follows   on a restart the ghost node stands on the kept track at every frame of the run (sample k at frame 2k,
##             between samples interpolated) and is gone after the track's end; G hides it, G again shows it
##   refused   a file with an unknown key, a short track, a wrong schema: read refuses with a reason; with the bad file
##             a restart shows no ghost; in a Home with no file: no ghost ("none")

const Course := preload("res://kernel/world/build/play_case_course.gd")
const PlayGhost := preload("res://kernel/world/build/play_ghost.gd")
const PlayLooks := preload("res://kernel/world/build/play_looks.gd")
const CaseUtil := preload("res://kernel/world/build/case_util.gd")
const TMP := "user://tl_run_ghost_case"

var ok_all := true
var c: RefCounted
var g_now := [false]


func _initialize() -> void:
	call_deferred("run")


func say(case_name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("HOME run-ghost.%s %s %s" % [case_name, "ok" if ok else "fail", detail])


static func track_ops() -> Array:
	return [Course.zone(1, [-1, 0, 8], [1, 1, 9], "pad", "Start"), Course.zone(2, [-1, 0, 0], [1, 1, 0], "flag", "Flag"),
		Course.rule(1, {"on": "enter", "zone": 1}, [{"do": "start", "run": "Dash"}]),
		Course.rule(2, {"on": "enter", "zone": 2}, [{"do": "finish"}])]


func run() -> void:
	TLStyle.set_headless(false)
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	DirAccess.make_dir_recursive_absolute(TMP + "/home")
	DirAccess.make_dir_recursive_absolute(TMP + "/empty")
	var why := ""
	c = Course.new(self)
	why = c.call("make", root, TMP + "/home", track_ops())
	if why != "":
		say("written", false, why)
	else:
		(c.get("p") as RefCounted).set("ghost_key", func() -> bool: return g_now[0])
		await cases()
	c.call("free_all")
	c = null
	await _wait(3)
	# no file: a fresh Home's run shows no ghost
	var c2: RefCounted = Course.new(self)
	var why2: String = c2.call("make", root, TMP + "/empty", track_ops())
	var none_ok := false
	var none_txt := why2
	if why2 == "":
		c = c2
		await dash(4.5, 13.0)
		var p: RefCounted = c2.get("p")
		none_ok = not bool(p.get("ghost").call("playing")) or false
		none_txt = "a Home with no runs/ file: the first run had no ghost (error '%s')" % str(p.get("ghost_error"))
		none_ok = none_ok and str(p.get("ghost_error")) == "none" and not _seen_ghost
	say("none", none_ok, none_txt)
	c2.call("free_all")
	c = null
	c2 = null
	await _wait(3)
	PlayLooks._meshes.clear()
	CaseUtil.remove_dir(ProjectSettings.globalize_path(TMP))
	print("HOME run-ghost %s" % ("ok" if ok_all else "fail"))
	print("HOME DONE")
	quit(0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


var _feet_at := {}                       # run frame -> his feet (the last dash)
var _ghost_at := {}                      # run frame -> the ghost node's position (the last dash), absent: no ghost
var _seen_ghost := false


## Puts him behind the Start (z `from_z`) and walks -z at `speed` m/s until the run is finished; keeps his feet and
## the ghost's place per run frame. Returns the finish's frames, or -1.
func dash(speed: float, from_z: float) -> int:
	var v: Node3D = c.get("v")
	var p: RefCounted = c.get("p")
	var run: RefCounted = p.get("run")
	v.call("put", Vector3(0.5, 0, from_z), 0.0, false)
	await c.call("frame", Vector3.ZERO)
	await c.call("frame", Vector3.ZERO)
	_feet_at.clear()
	_ghost_at.clear()
	_seen_ghost = false
	var started := false
	var g: RefCounted = p.get("ghost")
	for i: int in 900:
		var was: Vector3 = v.feet                         # the feet the frame before ticked the rules with
		await c.call("frame", Vector3(0, 0, -speed))
		# what the frame before did (build mode ticks after this): run frame n's feet and ghost
		var st: Dictionary = run.call("state")
		if bool(st.running):
			started = true
			_feet_at[int(st.frames)] = was
		if g.call("playing"):
			_seen_ghost = true
			_ghost_at[int(g.get("t"))] = (g.get("node") as Node3D).position
		if started and not bool(st.running):
			break
	for i: int in 3:
		await c.call("frame", Vector3.ZERO)
	return int((run.get("last_finish") as Dictionary).get("frames", -1)) if started else -1


func cases() -> void:
	var p: RefCounted = c.get("p")
	var path := PlayGhost.path_of(TMP + "/home", "Dash")
	# written
	var f1 := await dash(4.5, 13.0)
	var feet1 := _feet_at.duplicate()
	var text1 := FileAccess.get_file_as_string(path)
	var r1: Dictionary = PlayGhost.read(path)
	var bad := []
	var doc1: Dictionary = r1.get("ghost", {})
	var s1 := Marshalls.base64_to_raw(str(doc1.get("track", ""))).to_float32_array()
	var s0 := Vector3(s1[0], s1[1], s1[2]) if s1.size() >= 4 else Vector3.INF
	if f1 < 0 or doc1.is_empty() or int(doc1.frames) != f1 or s1.size() / 4 != f1 / 2 + 1 or PlayGhost.text_of(doc1) != text1 \
			or not feet1.has(0) or s0.distance_to(feet1[0]) > 1e-4 or not path.ends_with("runs/dash.json"):
		bad.append("finish %d, read %s, samples %d, round trip %s, sample 0 %s vs feet %s" % [f1, str(r1.get("error", "")), s1.size() / 4,
			PlayGhost.text_of(doc1) == text1, str(s0), str(feet1.get(0, "-"))])
	say("written", bad.is_empty(), "first finish %d frames: %s, %d samples (step 2), %d clip lines, sample 0 = his feet at frame 0, re-written text equal%s" % [
		f1, path.get_file(), s1.size() / 4, (doc1.get("clips", []) as Array).size(), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	# follows (on the slower run: the ghost of run 1 walks beside him) + kept (slower: no change)
	bad = []
	g_now[0] = false
	var f2 := await dash(2.5, 13.0)
	var ghost2 := _ghost_at.duplicate()
	var seen2 := _seen_ghost
	var text2 := FileAccess.get_file_as_string(path)
	var worst := 0.0
	var checked := 0
	for k: int in ghost2:
		if k > f1:
			continue
		var want: Vector3 = Vector3(s1[(k / 2) * 4], s1[(k / 2) * 4 + 1], s1[(k / 2) * 4 + 2]) if k % 2 == 0 else Vector3.INF
		if want != Vector3.INF:
			worst = maxf(worst, (ghost2[k] as Vector3).distance_to(want))
			checked += 1
	var past := 0
	for k: int in ghost2:
		if k > f1:
			past += 1
	if not seen2 or checked < f1 / 2 or worst > 1e-4 or past != 0:
		bad.append("ghost seen %s, %d even frames checked (want >= %d), worst %.5f m, frames past the end %d" % [seen2, checked, f1 / 2, worst, past])
	var kept_ok := f2 > f1 and text2 == text1
	if not kept_ok:
		bad.append("slower finish %d (first %d): file %s" % [f2, f1, "kept" if text2 == text1 else "CHANGED"])
	# faster: replaced
	var f3 := await dash(9.0, 13.0)
	var r3: Dictionary = PlayGhost.read(path)
	var doc3: Dictionary = r3.get("ghost", {})
	var s3 := Marshalls.base64_to_raw(str(doc3.get("track", ""))).to_float32_array()
	if f3 < 0 or f3 >= f1 or doc3.is_empty() or int(doc3.frames) != f3 or s3.size() / 4 != f3 / 2 + 1:
		bad.append("faster finish %d: file frames %s, samples %d" % [f3, str(doc3.get("frames", "-")), s3.size() / 4])
	say("kept", kept_ok and f3 >= 0 and f3 < f1 and int(doc3.get("frames", -1)) == f3, "slower %d frames: file byte for byte; faster %d frames: replaced (%d samples)" % [f2, f3, s3.size() / 4])
	say("follows", bad.is_empty() or (seen2 and worst <= 1e-4 and past == 0), "the ghost of the %d-frame run beside the %d-frame one: on the track at %d even frames (worst %.6f m), gone after frame %d%s" % [
		f1, f2, checked, worst, f1, "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
	# G: hidden, shown again (same visit), while the ghost walks
	var g: RefCounted = p.get("ghost")
	var v: Node3D = c.get("v")
	v.call("put", Vector3(0.5, 0, 13.0), 0.0, false)
	var vis := []
	for i: int in 120:
		g_now[0] = i == 60 or i == 80
		await c.call("frame", Vector3(0, 0, -4.5))
		if i in [59, 63, 83] and g.call("playing"):
			vis.append(bool((g.get("node") as Node3D).visible))
	g_now[0] = false
	say("key", vis == [true, false, true], "G (play key, not E/N/H/B/F/C/Space/Shift/WASD) on a walking ghost: visible %s (want [true, false, true])" % str(vis))
	# refused
	bad = []
	var good: Dictionary = doc3.duplicate(true)
	var rows := []
	for t: Array in [["unknown key", "colour", "red"], ["short track", "track", Marshalls.raw_to_base64(PackedFloat32Array([0, 0, 0, 0]).to_byte_array())],
			["schema", "schema", "tl.run-ghost/0"], ["frames", "frames", -3]]:
		var d := good.duplicate(true)
		d[t[1]] = t[2]
		var why := PlayGhost.check(d)
		rows.append("%s: '%s'" % [t[0], why])
		if why == "":
			bad.append("%s accepted" % t[0])
	var d2 := good.duplicate(true)
	d2.erase("clips")
	if PlayGhost.check(d2) == "":
		bad.append("a missing key accepted")
	var odd := good.duplicate(true)
	odd["colour"] = "red"
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(odd))
	fa.close()
	await dash(4.5, 13.0)
	if _seen_ghost or not str(p.get("ghost_error")).begins_with("unknown key"):
		bad.append("with an unknown key in the file: ghost seen %s, error '%s'" % [_seen_ghost, str(p.get("ghost_error"))])
	say("refused", bad.is_empty(), "; ".join(rows) + "; missing clips refused; a restart with the bad file: no ghost ('%s')%s" % [
		str(p.get("ghost_error")), "" if bad.is_empty() else "; BAD " + "; ".join(bad)])
