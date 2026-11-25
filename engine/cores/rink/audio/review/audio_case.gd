extends SceneTree
## Headless checks of thirdjam's sound as the core carries it (selftest block 841, lane K6):
##   godot --headless --path engine --script res://cores/rink/audio/review/audio_case.gd
## Prints one line a case, `AUDIO <case> ok=true|false <detail>`:
##   table    audio.json names only files that exist; every Variant has every Strength step; sizes under the limit
##   kernel   TLSound records a play, a loop, a say and a stop headless and refuses a bad option, channel and path
##   match    a whole match of the bare core (seed 1, pro, an idle hand): every event that sounds in thirdjam has its
##            row at its frame with the Variant an independent copy of thirdjam's table gives, silent events have
##            none, two runs give the same rows; writes the event / frame / clip table when TL_AUDIO_TABLE names a file
##   tj       thirdjam's own event log of a played match (review/tj_events_regular_pro.json) through the same rules:
##            every event thirdjam broadcast gets a sound or is silent by thirdjam's rule; a goal's Variant is the one
##            thirdjam's binder logged
##   loops    the music's level by phase and the skate loop's numbers at Speed 0, 0.5 and 1 (MS_skate_loop's own)
## TL_AUDIO_EXPECT_SILENT overrides the list of silent events (to show `match` red).

const Sound := preload("res://cores/rink/audio/rink_audio.gd")
const DIR := "res://cores/rink/audio/"
const SIZE_LIMIT: int = 60000000
# thirdjam's events that play nothing: UJamEffectsBinder::IsSilentEvent (EffectsBinder.cpp:276-280)
const SILENT: PackedStringArray = ["period", "carry"]


func _init() -> void:
	_table()
	_kernel()
	_match()
	_tj()
	_loops()
	quit(0)


func _say(name: String, bad: PackedStringArray, detail: String) -> void:
	print("AUDIO %s ok=%s %s%s" % [name, str(bad.is_empty()), detail, "" if bad.is_empty() else " " + "; ".join(bad.slice(0, 6))])


func _table() -> void:
	var bad: PackedStringArray = []
	var s := Sound.new()
	var t: Dictionary = s.table
	var files: Dictionary = {}
	var steps_want: Array = t.get("strength_steps", [])
	for ev: String in t.get("events", {}):
		var vs: Dictionary = t["events"][ev]["variants"]
		for v: String in vs:
			var steps: Dictionary = vs[v]["steps"]
			var takes: int = -1
			for st: String in steps:
				var list: Array = steps[st]
				if takes >= 0 and list.size() != takes:
					bad.append("%s v%s: %d takes at %s, %d elsewhere" % [ev, v, list.size(), st, takes])
				takes = list.size()
				for k: Dictionary in list:
					if str(k["file"]) != "":
						files[str(k["file"])] = true
			if steps.size() != steps_want.size() and steps.size() != 1:
				bad.append("%s v%s has %d Strength steps" % [ev, v, steps.size()])
	for l: String in t.get("loops", {}):
		for k: String in ["file", "stride", "carve", "noise"]:
			if (t["loops"][l] as Dictionary).has(k):
				files[str(t["loops"][l][k])] = true
	var bytes: int = 0
	for f: String in files:
		if not FileAccess.file_exists(DIR + f):
			bad.append("%s is named and not there" % f)
		else:
			bytes += FileAccess.get_file_as_bytes(DIR + f).size()
	if bytes > SIZE_LIMIT:
		bad.append("%d bytes of sound, the limit is %d" % [bytes, SIZE_LIMIT])
	if (t.get("events", {}) as Dictionary).size() < 40:
		bad.append("%d events in the table" % (t.get("events", {}) as Dictionary).size())
	_say("table", bad, "events=%d files=%d mb=%.1f" % [(t.get("events", {}) as Dictionary).size(), files.size(), float(bytes) / 1e6])


func _kernel() -> void:
	var bad: PackedStringArray = []
	var ev: Array = TLAudio.events
	var n0: int = ev.size()
	var p: String = DIR + "music/MUS_MatchLoop_01.ogg"
	TLSound.play(p, {"channel": "sfx", "db": -3.0})
	TLSound.loop(&"case_loop", p, {"channel": "music"})
	TLSound.set_loop(&"case_loop", {"db": -6.0, "ramp_frames": 30})
	TLSound.say(p, {"duck_music_db": -6.9})
	TLSound.stop_loop(&"case_loop", 10)
	var kinds: PackedStringArray = []
	for i: int in range(n0, TLAudio.events.size()):
		kinds.append(str(TLAudio.events[i]["kind"]))
	if ",".join(kinds) != "play,loop,say,stop":
		bad.append("recorded %s" % ",".join(kinds))
	if TLSound.count(p) < 3:
		bad.append("count %d" % TLSound.count(p))
	var n1: int = TLAudio.events.size()
	# three refusals (each prints an engine error line on purpose)
	TLSound.play(p, {"volume": 1.0})
	TLSound.play(p, {"channel": "radio"})
	TLSound.play("res://packs/hokej/data/x.ogg")
	if TLAudio.events.size() != n1:
		bad.append("a refused call was recorded")
	_say("kernel", bad, "recorded=%s refused=3" % ",".join(kinds))


## thirdjam's Variant table, typed again from EffectsBinder.cpp:178-244 (not read from rink_audio.gd).
func _variant(name: String, kind: String, outcome: String) -> int:
	if name == "poke" or name == "lift":
		return 1 if kind == "miss" else 0
	if name == "faceoff":
		return {"won": 1, "lost": 2}.get(kind, 0)
	if name == "foul":
		return 1 if kind == "foul_no_puck" else 0
	if name == "signal":
		return {"space": 1, "pass": 2, "praise": 3}.get(kind, 0)
	if name == "check":
		return 4 if outcome == "stumble" else {"side_l": 1, "side_r": 2, "behind": 3}.get(kind, 0)
	if name == "board":
		return 1 if kind == "skater" else 0
	if name == "possess":
		return 1 if kind == "body" else 0
	if name == "shot_blocked":
		return 1 if kind == "skater" else 0
	if name == "clock":
		return 1 if kind == "sudden_death" else 0
	return -1          # goal and shot: checked by their own rules below


func _run_match(frames: int) -> Dictionary:
	var core: Object = ClassDB.instantiate("RinkCore")
	var text: String = FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json")
	core.call("load_cartridge", text)
	core.call("set_difficulty", "pro")
	core.call("reset", 1)
	var s := Sound.new()
	s.begin(JSON.parse_string(text))
	var events: Array = []
	var last: Dictionary = {}
	for i: int in frames:
		if not bool(core.call("step")):
			break
		var snap: Dictionary = core.call("snapshot")
		for e: Dictionary in snap["Events"]:
			events.append([int(snap["Frame"]), e, (snap["Score"] as Array).duplicate()])
		s.frame(snap)
		last = snap
	return {"rows": s.rows, "events": events, "sound": s, "last": last}


func _match() -> void:
	var bad: PackedStringArray = []
	if not ClassDB.class_exists("RinkCore"):
		_say("match", ["the rink core is not built"], "")
		return
	var silent: PackedStringArray = SILENT
	if OS.get_environment("TL_AUDIO_EXPECT_SILENT") != "":
		silent = OS.get_environment("TL_AUDIO_EXPECT_SILENT").split(",")
	var a: Dictionary = _run_match(12000)
	var b: Dictionary = _run_match(12000)
	if JSON.stringify(a["rows"]) != JSON.stringify(b["rows"]):
		bad.append("two runs differ")
	var s: Object = a["sound"]
	var known: Dictionary = s.table["events"]
	var cart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json"))
	var max_speed: float = float(cart["game"]["puck"]["max_speed"])
	var rows: Array = (a["rows"] as Array).filter(func(r: Array) -> bool: return str(r[1]) != "skate_turn")
	var ri: int = 0
	var sounding: int = 0
	var with_file: int = 0
	var by_name: Dictionary = {}
	for row: Array in a["events"]:
		var e: Dictionary = row[1]
		var name: String = str(e["Name"])
		if silent.has(name) or not known.has(name):
			continue
		sounding += 1
		if ri >= rows.size():
			bad.append("no row for %s at frame %d" % [name, row[0]])
			break
		var r: Array = rows[ri]
		ri += 1
		if int(r[0]) != int(row[0]) or str(r[1]) != name:
			bad.append("row %d is %s at %d, the event is %s at %d" % [ri, r[1], r[0], name, row[0]])
			break
		var want: int = _variant(name, str(e["Kind"]), str(e.get("Outcome", "")))
		if want >= 0 and int(r[2]) != want:
			bad.append("%s at %d has Variant %d, thirdjam's table says %d" % [name, row[0], r[2], want])
		if name == "shot":
			var mps: float = float(e["Strength"]) * max_speed      # Strength = speed / game.puck.max_speed (JamSim.cpp:2885)
			var want_shot: int = 1 if (str(e["Kind"]) == "one_timer" or mps > 30.0) else 0
			if int(r[2]) != want_shot:
				bad.append("shot at %d (%.1f m/s, %s) has Variant %d" % [row[0], mps, e["Kind"], r[2]])
		if str(r[4]) != "":
			with_file += 1
			if not FileAccess.file_exists(DIR + str(r[4])):
				bad.append("%s is not there" % r[4])
		by_name[name] = int(by_name.get(name, 0)) + 1
	if ri != rows.size():
		bad.append("%d rows for %d sounding events" % [rows.size(), sounding])
	# the goals: Variant 0 when the human's team (team 0) scored, by the score
	var prev: Array = [0, 0]
	for row: Array in a["events"]:
		var e2: Dictionary = row[1]
		if str(e2["Name"]) == "goal":
			var sc: Array = row[2]
			var scorer: int = 0 if int(sc[0]) > int(prev[0]) else 1
			var found: bool = false
			for r2: Array in rows:
				if str(r2[1]) == "goal" and int(r2[0]) == int(row[0]):
					found = true
					if int(r2[2]) != (0 if scorer == 0 else 1):
						bad.append("goal at %d by team %d has Variant %d" % [row[0], scorer, r2[2]])
			if not found:
				bad.append("no goal row at %d" % row[0])
			prev = sc
	var out: String = OS.get_environment("TL_AUDIO_TABLE")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"columns": ["frame", "event", "variant", "strength", "clip", "db"], "rows": a["rows"],
			"frames": int((a["last"] as Dictionary).get("Frame", 0)), "score": (a["last"] as Dictionary).get("Score", [])}))
		f.close()
	_say("match", bad, "frames=%d events=%d sounding=%d rows=%d with_file=%d turns=%d names=%d" % [int((a["last"] as Dictionary).get("Frame", 0)),
		(a["events"] as Array).size(), sounding, rows.size(), with_file, (a["rows"] as Array).size() - rows.size(), by_name.size()])


func _tj() -> void:
	var bad: PackedStringArray = []
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "review/tj_events_regular_pro.json"))
	var s := Sound.new()
	s.begin(JSON.parse_string(FileAccess.get_file_as_string("res://packs/hokej/data/hockey.regular.cartridge.json")))
	var known: Dictionary = s.table["events"]
	var skaters: Array = []
	for i: int in 10:
		skaters.append({"Team": 0 if i < 5 else 1, "Vel": Vector2.ZERO, "YawRate": 0.0})
	var score: Array = [0, 0]
	var goals: Array = d["goals"]
	var gi: int = 0
	var frame_events: Dictionary = {}
	var order: Array = []
	for r: Array in d["events"]:
		if not frame_events.has(int(r[0])):
			frame_events[int(r[0])] = []
			order.append(int(r[0]))
		(frame_events[int(r[0])] as Array).append({"Name": r[1], "Who": int(r[2]), "Strength": float(r[3]), "Kind": r[4], "Outcome": r[5]})
	var unknown: Dictionary = {}
	var sounding: int = 0
	for f: int in order:
		for e: Dictionary in frame_events[f]:
			if str(e["Name"]) == "goal" and gi < goals.size():
				score[int(goals[gi][1])] = int(score[int(goals[gi][1])]) + 1
			if not SILENT.has(str(e["Name"])):
				if known.has(str(e["Name"])):
					sounding += 1
				else:
					unknown[str(e["Name"])] = true
		var n0: int = s.rows.size()
		s.frame({"Frame": f, "Phase": 0, "Score": score.duplicate(), "HumanIndex": 0, "Skaters": skaters, "Events": frame_events[f]})
		for i: int in range(n0, s.rows.size()):
			if str(s.rows[i][1]) == "goal":
				if gi < goals.size() and int(s.rows[i][2]) != int(goals[gi][3]):
					bad.append("goal at %d: Variant %d, thirdjam's binder logged %d" % [f, s.rows[i][2], goals[gi][3]])
				gi += 1
	if not unknown.is_empty():
		bad.append("thirdjam broadcast events with no sound here: %s" % ", ".join(PackedStringArray(unknown.keys())))
	if s.rows.size() != sounding:
		bad.append("%d rows for %d sounding events" % [s.rows.size(), sounding])
	if gi != goals.size():
		bad.append("%d goals heard of %d" % [gi, goals.size()])
	_say("tj", bad, "events=%d sounding=%d rows=%d goals=%d" % [(d["events"] as Array).size(), sounding, s.rows.size(), gi])


func _loops() -> void:
	var bad: PackedStringArray = []
	var s := Sound.new()
	var l: Dictionary = s.table["loops"]
	# MS_music_match and CommentarySystem.h:46-47
	if not (is_equal_approx(float(l["music"]["level_play"]), 0.35) and is_equal_approx(float(l["music"]["level_pause"]), 0.6) and is_equal_approx(float(l["music"]["interp_s"]), 0.5)):
		bad.append("music levels %s" % str(l["music"]))
	# MS_crowd_bed at its resting inputs: Level 0.5 x 2 x (Excite 0 + 1) = 1, low-pass 3000 Hz
	if not (is_equal_approx(float(l["crowd_bed"]["gain"]), 1.0) and is_equal_approx(float(l["crowd_bed"]["lowpass_hz"]), 3000.0)):
		bad.append("crowd bed %s" % str(l["crowd_bed"]))
	# MS_skate_loop's literals, typed again: stride 1.4 x Speed at 4 x Speed - 2 semitones; noise 0.25 x 3 x Speed at 1200 + 2500 x Speed Hz; x FxTrim 0.7
	var sk: Dictionary = l["skate"]
	for sp: float in [0.0, 0.5, 1.0]:
		var stride: float = float(sk["stride_gain"]) * sp * float(sk["fx_trim"])
		var semis: float = float(sk["stride_semitones"][0]) * sp + float(sk["stride_semitones"][1])
		var noise: float = float(sk["noise_gain"][0]) * float(sk["noise_gain"][1]) * float(sk["noise_gain"][2]) * sp * float(sk["fx_trim"])
		var hz: float = float(sk["noise_hz"][0]) + float(sk["noise_hz"][1]) * sp
		if not (is_equal_approx(stride, 1.4 * sp * 0.7) and is_equal_approx(semis, 4.0 * sp - 2.0) and is_equal_approx(noise, 0.25 * 3.0 * sp * 0.7) and is_equal_approx(hz, 1200.0 + 2500.0 * sp)):
			bad.append("skate loop at Speed %.1f: stride %.3f at %.1f semitones, noise %.3f at %.0f Hz" % [sp, stride, semis, noise, hz])
	if not (is_equal_approx(float(sk["turn_rad_s"]), 3.0) and int(sk["turn_gap_frames"]) == 15 and is_equal_approx(float(sk["carve_gain"]), 0.8)):
		bad.append("turn %s" % str(sk))
	_say("loops", bad, "music=%.2f/%.2f bed=%.1f@%dHz skate_ref=%dHz" % [float(l["music"]["level_play"]), float(l["music"]["level_pause"]),
		float(l["crowd_bed"]["gain"]), int(l["crowd_bed"]["lowpass_hz"]), int(sk["noise_ref_hz"])])
