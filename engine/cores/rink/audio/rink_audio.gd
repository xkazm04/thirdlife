extends RefCounted
## thirdjam's sound for a match on the rink core (K6, hockey port): what UJamEffectsBinder and UJamCommentarySystem do
## with sound, from the core's snapshot. The files and their table are baked from thirdjam's own audio
## (audio.json; engine/tools/arena: export_audio.py, audio_digest.py, audio_jobs.py, render_audio.py, audio_bake.py):
## an event's sound is Unreal's render of that event's MetaSound at a Variant and a Strength.
##
##   var sound = ctx.cores.part("rink", "audio").new()
##   sound.begin(cart)                 # _pack_setup: the music, the crowd bed, the skate loop
##   sound.frame(snap)                 # once per simulated frame, after the core's step
##
## The rules, each with its thirdjam source:
##   an event plays MS_<event> (EffectsBinder.cpp:146-149, 474-489) unless it is silent (period, carry: cpp:276-280) or
##     quiet (an ability granted, not used: cpp:243-246); thirdjam's MetaSounds carry no attenuation settings, so a
##     sound is not placed: it is heard the same everywhere;
##   its Variant: VariantFor's table (cpp:178-238), a stumbling check 4 (cpp:240-244), a goal 0 for the human's team
##     and 1 against (the team whose score grew, cpp:407-424), a shot 1 over 30 m/s or as a one-timer (cpp:446-452,
##     EffectsBinder.h:56-57);
##   the music: Level 0.6 from the start, 0.35 while the puck is in play, reached over 0.5 s (CommentarySystem.cpp:913-921,
##     938-943; MS_music_match);
##   the crowd bed: started with the music and left alone (cpp:922-930; MS_crowd_bed at Level 0.5, Excite 0);
##   the skate loop on the human's skater: Speed = |velocity| / game.skater.speed every frame, Turn when the yaw rate
##     passes 3 rad/s above 1 m/s, at most once in 15 frames (cpp:945-968; MS_skate_loop).
## Sound is never state. A take is chosen from the frame and the event, not from the simulation's random numbers.

const DIR: String = "res://cores/rink/audio/"
const SILENT_EVENTS: PackedStringArray = ["period", "carry"]
const SHOT_CRACK_MPS: float = 30.0
const MAX_ROWS: int = 20000

var table: Dictionary = {}
var rows: Array = []              ## what sounded: [frame, event, variant, strength, file, db] (the event-to-sound table)
var _cart: Dictionary = {}
var _last_frame: int = -1
var _score: Array = [0, 0]
var _turn_cooldown: int = 0
var _music_level: float = -1.0
var _begun: bool = false
var _stereo: float = 1.0          # what Unreal's output does to a stereo and to a mono 2D sound (audio.json "out_gain", measured)
var _mono: float = 1.0


func _init() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "audio.json"))
	if d is Dictionary:
		table = d
	else:
		push_error("rink audio: %saudio.json does not read" % DIR)


## Starts the held sounds. `cart`: the cartridge the core runs (game.skater.speed and game.puck.max_speed are read).
func begin(cart: Dictionary) -> void:
	_cart = cart
	_last_frame = -1
	_score = [0, 0]
	_turn_cooldown = 0
	rows.clear()
	if table.is_empty():
		return
	var loops: Dictionary = table["loops"]
	var m: Dictionary = loops["music"]
	_stereo = float(table["out_gain"]["stereo"])
	_mono = float(table["out_gain"]["mono"])
	_music_level = float(m["level_pause"])
	TLSound.loop(&"rink_music", DIR + str(m["file"]), {"channel": "music", "db": linear_to_db(_music_level * _stereo)})
	var bed: Dictionary = loops["crowd_bed"]
	TLSound.loop(&"rink_crowd_bed", DIR + str(bed["file"]), {"channel": "crowd", "db": linear_to_db(float(bed["gain"]) * _stereo)})
	var sk: Dictionary = loops["skate"]
	TLSound.loop(&"rink_skate_stride", DIR + str(sk["stride"]), {"channel": "sfx", "db": TLSound.SILENT_DB})
	TLSound.loop(&"rink_skate_noise", DIR + str(sk["noise"]), {"channel": "sfx", "db": TLSound.SILENT_DB})
	_begun = true


## Stops the held sounds (the pack leaves, or a new match is built).
func end() -> void:
	if not _begun:
		return
	for n: StringName in [&"rink_music", &"rink_crowd_bed", &"rink_skate_stride", &"rink_skate_noise"]:
		TLSound.stop_loop(n, 12)
	_begun = false


## One simulated frame: its events, then the held sounds. A snapshot whose frame was already heard does nothing (a
## match that is over keeps its last frame's events).
func frame(snap: Dictionary) -> void:
	if table.is_empty() or not _begun:
		return
	var f: int = int(snap.get("Frame", 0))
	if f == _last_frame:
		return
	if f < _last_frame:                         # the core restarted (a new match on the same seed)
		_score = [0, 0]
		_turn_cooldown = 0
	_last_frame = f
	var score: Array = snap.get("Score", [0, 0])
	for e: Dictionary in snap.get("Events", []):
		_event(e, snap, score)
	_score = [int(score[0]), int(score[1])]
	_loops(snap)


## The Variant thirdjam sends for an event (the binder's whole rule for sound).
func variant_of(e: Dictionary, snap: Dictionary, score: Array) -> int:
	var ev: String = str(e.get("Name", ""))
	var kind: String = str(e.get("Kind", ""))
	match ev:
		"poke", "lift":
			return 1 if kind == "miss" else 0
		"faceoff":
			return 1 if kind == "won" else (2 if kind == "lost" else 0)
		"foul":
			return 1 if kind == "foul_no_puck" else 0
		"signal":
			return ["defend", "space", "pass", "praise"].find(kind) if ["space", "pass", "praise"].has(kind) else 0
		"check":
			if str(e.get("Outcome", "")) == "stumble":
				return 4
			return 1 if kind == "side_l" else (2 if kind == "side_r" else (3 if kind == "behind" else 0))
		"board":
			return 1 if kind == "skater" else 0
		"ability":
			return 1 if kind == "hip_check" else (2 if kind == "shield" else (3 if kind == "slow_puck" else 0))
		"clock":
			return 1 if kind == "sudden_death" else 0
		"possess":
			return 1 if kind == "body" else 0
		"shot_blocked":
			return 1 if kind == "skater" else 0
		"goal":
			# ResolveScoringTeam: the team whose score grew since the last goal heard; else the team of Who; else unknown
			var scorer: int = -1
			if int(score[0]) > int(_score[0]) and int(score[1]) <= int(_score[1]):
				scorer = 0
			elif int(score[1]) > int(_score[1]) and int(score[0]) <= int(_score[0]):
				scorer = 1
			else:
				scorer = _team_of(snap, int(e.get("Who", -1)))
			var human: int = _team_of(snap, int(snap.get("HumanIndex", -1)))
			return 0 if scorer >= 0 and scorer == human else 1
		"shot":
			var max_speed: float = float(((_cart.get("game", {}) as Dictionary).get("puck", {}) as Dictionary).get("max_speed", 0.0))
			var exit_mps: float = float(e.get("Strength", 0.0)) * max_speed      # PuckCapScale is 1 without a shot-speed effect (JamSim.h:922)
			return 1 if (kind == "one_timer" or exit_mps > SHOT_CRACK_MPS) else 0
	return 0


## The file and gain of an event's sound at a Variant and a Strength: {"file": "" (nothing sounds) or a path, "db"}.
func sound_of(ev: String, variant: int, strength: float, frame_no: int, who: int) -> Dictionary:
	var e: Dictionary = (table["events"] as Dictionary).get(ev, {})
	if e.is_empty():
		return {"file": "", "db": 0.0, "known": false}
	var vs: Dictionary = e["variants"]
	var v: Dictionary = vs.get(str(variant), vs.get("0", {}))
	var steps: Dictionary = v.get("steps", {})
	if steps.is_empty():
		return {"file": "", "db": 0.0, "known": true}
	var keys: Array = steps.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(a) < float(b))
	var s: float = clampf(strength, float(keys[0]), float(keys[-1]))
	var lo: String = keys[0]
	var hi: String = keys[-1]
	for k: String in keys:
		if float(k) <= s + 1e-6:
			lo = k
	for i: int in range(keys.size() - 1, -1, -1):
		if float(keys[i]) >= s - 1e-6:
			hi = keys[i]
	var takes: Array = steps[lo]
	var take: int = posmod(hash([frame_no, ev, who]), takes.size())
	var t: Dictionary = takes[take]
	var gain: float = float(t["gain"])
	if str(v.get("law", "steps")) == "gain" and hi != lo and gain > 0.0:
		# the sound only scales with Strength: a straight line between the two steps' gains on the one file. A silent
		# lower step is a gate, not a slope: it stays silent up to the next step.
		var th: Dictionary = (steps[hi] as Array)[posmod(take, (steps[hi] as Array).size())]
		if str(th["file"]) == str(t["file"]):
			gain = lerpf(gain, float(th["gain"]), (s - float(lo)) / (float(hi) - float(lo)))
	if str(t["file"]) == "" or gain <= 0.0:
		return {"file": "", "db": 0.0, "known": true}
	return {"file": DIR + str(t["file"]), "db": linear_to_db(gain), "known": true}


func _event(e: Dictionary, snap: Dictionary, score: Array) -> void:
	var ev: String = str(e.get("Name", ""))
	if SILENT_EVENTS.has(ev):
		return
	var strength: float = float(e.get("Strength", 0.0))
	if ev == "ability" and strength < 0.5:
		return
	var variant: int = variant_of(e, snap, score)
	var s: Dictionary = sound_of(ev, variant, strength, int(snap.get("Frame", 0)), int(e.get("Who", -1)))
	if not bool(s["known"]):
		return                                  # thirdjam has no MS_<event>: its binder logs it once and plays nothing
	if rows.size() < MAX_ROWS:
		rows.append([int(snap.get("Frame", 0)), ev, variant, strength, str(s["file"]).trim_prefix(DIR), float(s["db"])])
	if str(s["file"]) != "":
		TLSound.play(str(s["file"]), {"channel": "sfx", "db": float(s["db"])})


func _loops(snap: Dictionary) -> void:
	var loops: Dictionary = table["loops"]
	var m: Dictionary = loops["music"]
	var target: float = float(m["level_play"]) if int(snap.get("Phase", 0)) == 0 else float(m["level_pause"])
	if not is_equal_approx(target, _music_level):
		_music_level = target
		TLSound.set_loop(&"rink_music", {"db": linear_to_db(target * _stereo), "ramp_frames": roundi(float(m["interp_s"]) * 60.0)})
	var skaters: Array = snap.get("Skaters", [])
	var hi: int = int(snap.get("HumanIndex", -1))
	if hi < 0 or hi >= skaters.size():
		return
	var sk: Dictionary = loops["skate"]
	var h: Dictionary = skaters[hi]
	var vel: Vector2 = h.get("Vel", Vector2.ZERO)
	var top: float = maxf(float(((_cart.get("game", {}) as Dictionary).get("skater", {}) as Dictionary).get("speed", 0.1)), 0.1)
	var speed: float = clampf(vel.length() / top, 0.0, 1.0)
	var fx: float = float(sk["fx_trim"]) * _mono
	var st: Array = sk["stride_semitones"]
	var ng: Array = sk["noise_gain"]
	var nh: Array = sk["noise_hz"]
	TLSound.set_loop(&"rink_skate_stride", {"db": _db(float(sk["stride_gain"]) * speed * fx), "pitch": pow(2.0, (float(st[0]) * speed + float(st[1])) / 12.0)})
	TLSound.set_loop(&"rink_skate_noise", {"db": _db(float(ng[0]) * float(ng[1]) * float(ng[2]) * speed * fx),
		"pitch": (float(nh[0]) + float(nh[1]) * speed) / float(sk["noise_ref_hz"])})
	if _turn_cooldown > 0:
		_turn_cooldown -= 1
	elif absf(float(h.get("YawRate", 0.0))) > float(sk["turn_rad_s"]) and vel.length() > float(sk["turn_min_speed"]):
		_turn_cooldown = int(sk["turn_gap_frames"])
		if rows.size() < MAX_ROWS:
			rows.append([int(snap.get("Frame", 0)), "skate_turn", 0, speed, str(sk["carve"]), _db(float(sk["carve_gain"]) * fx)])
		TLSound.play(DIR + str(sk["carve"]), {"channel": "sfx", "db": _db(float(sk["carve_gain"]) * fx)})


func _db(gain: float) -> float:
	return linear_to_db(gain) if gain > 1e-4 else TLSound.SILENT_DB


func _team_of(snap: Dictionary, index: int) -> int:
	var skaters: Array = snap.get("Skaters", [])
	return int((skaters[index] as Dictionary).get("Team", -1)) if index >= 0 and index < skaters.size() else -1
