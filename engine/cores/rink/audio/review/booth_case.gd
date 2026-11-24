extends SceneTree
## Headless checks of the commentator's voice and the barks' sound (selftest block 842, lane K6 round 3):
##   godot --headless --fixed-fps 60 --path engine --script res://cores/rink/audio/review/booth_case.gd
## One line a case, `BOOTH <case> ok=true|false <detail>`:
##   voices   voice.json has a file for every line of the booth's bank (the caption picker's 415, lane K5's
##            commentary_lines.gd), each file there; the core's sound stays under 60 MB
##   match    a whole match of the bare core (seed 1, pro, an idle hand) through the pack's own HUD (lane K5's hud.gd, its
##            booth and bark lane: one picker): every line the caption starts is said on its frame, that line's file,
##            nothing else is said; every bark said plays MS_bark on its frame; a line the booth cuts without a new one
##            fades exactly where a bark at the human came 30 frames or more into it; two runs agree. Writes the
##            frame / line / clip table when TL_BOOTH_TABLE names a file
##   duck     TLSound's own node: a line ducks the music bus to 0.45 (-6.94 dB) over 12 frames in a straight line of gain,
##            stop_voice fades the line out in 9 frames, the music comes back over 12
##   pause    the tree paused under a pausable pack (the dungeon's pause): the music loop and the line hold their place for
##            60 frames and go on at resume (thirdjam: SetGamePaused pauses every non-UI sound, AudioDevice.cpp HandlePause)
## TL_BOOTH_SKIP_BARKS=1 drops the barks from the sound part's input (to show `match` red); TL_BOOTH_PAUSE_ALWAYS=1 makes
## the pack's node run through a pause (to show `pause` red).

const Sound := preload("res://cores/rink/audio/rink_audio.gd")
const Hud := preload("res://packs/hokej/scripts/hud/hud.gd")
const DIR := "res://cores/rink/audio/"
const CART := "res://packs/hokej/data/hockey.regular.cartridge.json"
const SIZE_LIMIT: int = 60000000

var step: int = 0
var run: Node
var node: Node
var music_bus: int = -1
var marks: Dictionary = {}
var bad_duck: PackedStringArray = []
var bad_pause: PackedStringArray = []


## A layer that keeps nothing (the HUD's drawing calls answered, as lane K5's bot_hud_rules.gd does).
class Rec:
	extends RefCounted
	func clear() -> void: pass
	func extent() -> Vector2: return Vector2(1920, 1080)
	func measure(s: String, pt: float, _face: String = "bold", _tr: int = 0) -> Vector2: return Vector2(s.length() * pt * 0.6, pt * 4.0 / 3.0 * 1.17)
	func box(_p: Vector2, _s: Vector2, _f: Color, _r: float = 0.0, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0) -> void: pass
	func text(p: Vector2, s: String, pt: float, _c: Color, _o: Dictionary = {}) -> Rect2: return Rect2(p, measure(s, pt))
	func ring(_r: Rect2, _c: Color, _b: float = 0.0, _e: float = 0.0, _ec: Color = Color()) -> void: pass
	func chevron(_p: Vector2, _s: float, _c: Color, _e: Color = Color(), _ew: float = 0.0, _a: float = 0.0, _al: Vector2 = Vector2()) -> void: pass
	func polygon(_p: PackedVector2Array, _c: Color) -> void: pass
	func line(_a: Vector2, _b: Vector2, _c: Color, _w: float = 1.0) -> void: pass
	func minimap(_p: Vector2, _s: Vector2, _f: Vector2, _d: Array) -> void: pass
	func project(w: Vector3) -> Vector3: return Vector3(960.0 + w.x * 20.0, 540.0 + w.z * 20.0, 30.0)
	func camera_local(w: Vector3) -> Vector3: return Vector3(w.x, w.z, -30.0)
	func eye() -> Vector3: return Vector3(0, 30, 0)
	func ground_ring(c: Vector3, r: float, _n: float = 0.5) -> Rect2: return Rect2(Vector2(960.0 + (c.x - r) * 20.0, 540.0 + (c.z - r) * 20.0), Vector2(r, r) * 40.0)


func _initialize() -> void:
	_voices()
	_match()
	run = Node.new()
	run.process_mode = Node.PROCESS_MODE_ALWAYS if OS.get_environment("TL_BOOTH_PAUSE_ALWAYS") == "1" else Node.PROCESS_MODE_PAUSABLE
	root.add_child(run)


func _say(name: String, bad: PackedStringArray, detail: String) -> void:
	print("BOOTH %s ok=%s %s%s" % [name, str(bad.is_empty()), detail, "" if bad.is_empty() else " " + "; ".join(bad.slice(0, 6))])


func _voices() -> void:
	var bad: PackedStringArray = []
	var s := Sound.new()
	var lines: Dictionary = s.voice_table.get("lines", {})
	var bank: Array = load("res://packs/hokej/scripts/hud/commentary_lines.gd").LINES
	for row: Array in bank:
		var id: String = row[0]
		if not lines.has(id):
			bad.append("no voice for %s" % id)
		elif not FileAccess.file_exists(DIR + str(lines[id])):
			bad.append("%s is named and not there" % lines[id])
	var bytes: int = _bytes(DIR)
	if bytes > SIZE_LIMIT:
		bad.append("%d bytes of sound, the limit is %d" % [bytes, SIZE_LIMIT])
	_say("voices", bad, "bank=%d voices=%d audio_mb=%.1f" % [bank.size(), lines.size(), float(bytes) / 1e6])


static func _bytes(dir: String) -> int:
	var n: int = 0
	var d := DirAccess.open(dir)
	if d == null:
		return 0
	for f: String in d.get_files():
		if f.ends_with(".ogg") or f.ends_with(".json") or f.ends_with(".wav"):
			n += FileAccess.get_file_as_bytes(dir + f).size()
	for sub: String in d.get_directories():
		n += _bytes(dir + sub + "/")
	return n


func _run_match(frames: int) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(CART)
	var cart: Dictionary = JSON.parse_string(text)
	var core: Object = ClassDB.instantiate("RinkCore")
	core.call("load_cartridge", text)
	core.call("set_difficulty", "pro")
	core.call("reset", 1)
	var hud = Hud.new(Rec.new(), cart["game"], "pro", 1, (JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hud_barks.json")) as Dictionary)["lines"])
	var s := Sound.new()
	s.begin(cart)
	var ui: Dictionary = {"with_puck": false, "held": {}, "press": false, "saucer": false, "braced": false, "paused": false, "stamina01": 1.0}
	var started: Array = []          # [frame, id, dur, end]
	var barks: Array = []            # [frame, n, at_human]
	var skip_barks: bool = OS.get_environment("TL_BOOTH_SKIP_BARKS") == "1"
	var last: Dictionary = {}
	var snap: Dictionary = core.call("snapshot")
	for i: int in frames:
		hud.frame(snap, ui)
		var sh: Dictionary = hud.shown
		var f: int = int(snap["Frame"])
		if sh.has("line_started"):
			started.append([f, str(sh["line_started"]), int(hud.captions.last_pick.get("dur", 0)), int(hud.captions.last_end)])
		if sh.has("bark_said"):
			var at_h: bool = false
			for bk: Array in hud.barks.said:
				var sit: String = bk[1]
				at_h = at_h or (not (sit == "goal_against" or sit == "faceoff") and (sit != "goal_for" or int((snap["Skaters"][int(bk[0])] as Dictionary)["Team"]) == int((snap["Skaters"][int(snap["HumanIndex"])] as Dictionary)["Team"])))
			barks.append([f, (hud.barks.said as Array).size(), at_h])
		s.frame(snap)
		s.booth(f, {} if skip_barks and sh.has("bark_said") and not sh.has("line_started") else sh, int(hud.captions.last_end), [] if skip_barks else hud.barks.said)
		last = snap
		if not bool(core.call("step")):
			break
		snap = core.call("snapshot")
	return {"rows": s.rows, "started": started, "barks": barks, "sound": s, "last": last, "texts": _texts()}


static func _texts() -> Dictionary:
	var out: Dictionary = {}
	for row: Array in load("res://packs/hokej/scripts/hud/commentary_lines.gd").LINES:
		out[row[0]] = row[6]
	return out


func _match() -> void:
	var bad: PackedStringArray = []
	if not ClassDB.class_exists("RinkCore"):
		_say("match", ["the rink core is not built"], "")
		return
	var a: Dictionary = _run_match(7200)
	var b: Dictionary = _run_match(7200)
	var booth_rows: Callable = func(rows: Array) -> Array: return rows.filter(func(r: Array) -> bool: return str(r[1]) in ["voice", "voice_cut", "bark"])
	var ra: Array = booth_rows.call(a["rows"])
	if JSON.stringify(ra) != JSON.stringify(booth_rows.call(b["rows"])):
		bad.append("two runs differ")
	var s: Object = a["sound"]
	var lines: Dictionary = s.voice_table["lines"]
	var voices: Array = ra.filter(func(r: Array) -> bool: return str(r[1]) == "voice")
	var cuts: Array = ra.filter(func(r: Array) -> bool: return str(r[1]) == "voice_cut")
	var bark_rows: Array = ra.filter(func(r: Array) -> bool: return str(r[1]) == "bark")
	# one voice a line the caption started, on its frame, its own file; nothing else
	var started: Array = a["started"]
	if voices.size() != started.size():
		bad.append("%d lines started, %d said" % [started.size(), voices.size()])
	for i: int in mini(voices.size(), started.size()):
		var v: Array = voices[i]
		var st: Array = started[i]
		if int(v[0]) != int(st[0]) or str(v[2]) != str(st[1]):
			bad.append("line %d: said %s at %d, the caption started %s at %d" % [i, v[2], v[0], st[1], st[0]])
			break
		if str(v[4]) != str(lines[str(st[1])]) or str(v[4]) != "vo/VO_Commentator_%s.ogg" % str(st[1]).replace(".", "_"):
			bad.append("line %s plays %s" % [st[1], v[4]])
			break
	# a bark said: MS_bark on its frame, one a bark
	var want_barks: int = 0
	var bi: int = 0
	for bk: Array in a["barks"]:
		want_barks += int(bk[1])
		for k: int in int(bk[1]):
			if bi >= bark_rows.size() or int(bark_rows[bi][0]) != int(bk[0]):
				bad.append("the bark at %d has no MS_bark" % bk[0])
				break
			if not str(bark_rows[bi][4]).begins_with("sfx/bark_v0_"):
				bad.append("a bark plays %s" % bark_rows[bi][4])
			bi += 1
	if bark_rows.size() != want_barks:
		bad.append("%d barks said, %d MS_bark" % [want_barks, bark_rows.size()])
	# the cut: only where a bark at the human came 30 frames or more into a running line, and no new line started
	var want_cuts: Array = []
	var cur: Array = []
	var bark_at: Dictionary = {}
	for bk: Array in a["barks"]:
		if bool(bk[2]):
			bark_at[int(bk[0])] = true
	var si: int = 0
	var frames: int = int((a["last"] as Dictionary).get("Frame", 0))
	for f: int in frames + 1:
		var new_line: bool = si < started.size() and int(started[si][0]) == f
		if not new_line and not cur.is_empty() and bark_at.has(f) and f < int(cur[3]) and f - int(cur[0]) >= 30:
			want_cuts.append(f)
			cur = []
		if new_line:
			cur = started[si]
			si += 1
	var got_cuts: Array = cuts.map(func(r: Array) -> int: return int(r[0]))
	if JSON.stringify(got_cuts) != JSON.stringify(want_cuts):
		bad.append("cuts at %s, the bark rule says %s" % [str(got_cuts.slice(0, 6)), str(want_cuts.slice(0, 6))])
	# thirdjam's own booth in its played match (a scripted hand, another play): its rates beside ours
	var tj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "review/tj_booth_regular_pro.json"))
	var per_min: Callable = func(n: int, fr: int) -> float: return float(n) / maxf(float(fr) / 3600.0, 1e-6)
	var out: String = OS.get_environment("TL_BOOTH_TABLE")
	if out != "":
		var fo := FileAccess.open(out, FileAccess.WRITE)
		fo.store_string(JSON.stringify({"columns": ["frame", "what", "line", "strength", "clip", "db"], "rows": ra, "texts": a["texts"],
			"frames": frames, "score": (a["last"] as Dictionary).get("Score", []), "tj": tj}))
		fo.close()
	_say("match", bad, "frames=%d lines=%d said=%d barks=%d ms_bark=%d cuts=%d lines_per_min=%.1f barks_per_min=%.1f tj_lines_per_min=%.1f tj_barks_per_min=%.1f" % [frames,
		started.size(), voices.size(), want_barks, bark_rows.size(), cuts.size(), per_min.call(started.size(), frames), per_min.call(want_barks, frames),
		per_min.call((tj["lines"] as Array).size(), int(tj["frames"])), per_min.call((tj["barks"] as Array).size(), int(tj["frames"]))])


# ------------------------------------------------------------------ duck and pause, frame by frame

func _physics_process(_dt: float) -> bool:
	step += 1
	if step == 1:
		node = TLSound.TLSoundNode.new()
		run.add_child(node)
		var music: AudioStream = TLSound._stream(DIR + "music/MUS_MatchLoop_01.ogg", true)
		node.loop(&"case_music", music, "music", -9.1, 1.0)
		music_bus = AudioServer.get_bus_index(&"TL_music")
	elif step == 10:
		node.say(TLSound._stream(DIR + "vo/VO_Commentator_goal_blue_01.ogg"), -6.02, linear_to_db(0.45), 12)
	elif step > 10 and step <= 22:
		# the duck: a straight line in gain from 1 to 0.45 over 12 frames (this script runs before the nodes each frame: the
		# node has stepped step - 10 times since the line began)
		var want: float = 1.0 - (1.0 - 0.45) * float(step - 10) / 12.0
		var got: float = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
		if absf(got - want) > 0.002:
			bad_duck.append("frame +%d: music x%.3f, want x%.3f" % [step - 10, got, want])
	elif step == 40:
		marks["db_ducked"] = AudioServer.get_bus_volume_db(music_bus)
		node.stop_voice(9)
	elif step == 49:
		if node.saying():
			bad_duck.append("the line still plays 9 frames after stop_voice")
	elif step == 48:
		if not node.saying():
			bad_duck.append("the line ended before its 9 frames")
	elif step == 62:
		marks["db_back"] = AudioServer.get_bus_volume_db(music_bus)
		if absf(float(marks["db_ducked"]) - linear_to_db(0.45)) > 0.02 or absf(float(marks["db_back"])) > 0.02:
			bad_duck.append("ducked %.2f dB, back %.2f dB" % [marks["db_ducked"], marks["db_back"]])
		_say("duck", bad_duck, "ducked_db=%.2f back_db=%.2f" % [marks["db_ducked"], marks["db_back"]])
		node.say(TLSound._stream(DIR + "vo/VO_Commentator_goal_blue_01.ogg"), -6.02, linear_to_db(0.45), 12)
	elif step == 75:
		paused = true
	elif step == 80:
		# five frames into the pause. The mixer runs on its own thread in real time (a --fixed-fps run races its frames),
		# so the players are given 300 ms of the wall clock paused, then 300 ms resumed
		OS.delay_msec(100)                           # the mixer's last buffer (about 10 ms) drains first
		marks["pos0"] = _positions()
		for c: Node in node.get_children():
			if c is AudioStreamPlayer and not (c as AudioStreamPlayer).stream_paused:
				bad_pause.append("a player on %s is not paused under the tree's pause" % (c as AudioStreamPlayer).bus)
		OS.delay_msec(300)
		var held: Array = _positions()
		if held != marks["pos0"] or held.size() != 2:
			bad_pause.append("moved under the pause: %s -> %s" % [str(marks["pos0"]), str(held)])
		marks["pos1"] = held
		paused = false
	elif step == 85:
		OS.delay_msec(300)
		var after: Array = _positions()
		if after.size() != 2 or float(after[0]) <= float(marks["pos1"][0]) or float(after[1]) <= float(marks["pos1"][1]):
			bad_pause.append("did not go on after the pause: %s -> %s" % [str(marks["pos1"]), str(after)])
		_say("pause", bad_pause, "music_at=%.3f line_at=%.3f held_300_ms then music_at=%.3f line_at=%.3f" % [float(marks["pos1"][0]) if marks["pos1"].size() > 0 else -1.0,
			float(marks["pos1"][1]) if marks["pos1"].size() > 1 else -1.0, float(after[0]) if after.size() > 0 else -1.0, float(after[1]) if after.size() > 1 else -1.0])
		return true
	return false


func _positions() -> Array:
	var out: Array = []
	for c: Node in node.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == &"TL_music":
			out.append(snappedf((c as AudioStreamPlayer).get_playback_position(), 0.0001))
	for c2: Node in node.get_children():
		if c2 is AudioStreamPlayer and (c2 as AudioStreamPlayer).bus == &"TL_voice":
			out.append(snappedf((c2 as AudioStreamPlayer).get_playback_position(), 0.0001))
	return out
