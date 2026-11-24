class_name TLSound
extends RefCounted
## Sound from files (kernel 1.27; capability `audio`). `TLAudio` plays synthesised presets by name; this plays the
## sound files a game core owns (`res://cores/<id>/audio/**`, .ogg or .wav): one-shots, loops whose volume and pitch the
## game sets, and five channels with a volume each (`sfx`, `crowd`, `music`, `voice`, `ambience`). A pack has no sound
## files of its own: it reaches a core's sounds through that core's part (`ctx.cores.part`).
##
##   TLSound.play("res://cores/rink/audio/sfx/goal_v0_s100_t0.ogg", {"channel": "sfx", "db": -3.0})
##   TLSound.play(path, {"position": Vector3(4, 0, 2)})                # at a place: fades with distance
##   TLSound.loop(&"music", "res://cores/rink/audio/music/MUS_MatchLoop_01.ogg", {"channel": "music", "db": -9.1})
##   TLSound.set_loop(&"music", {"db": -4.4, "ramp_frames": 30})       # volume and pitch, reached over frames
##   TLSound.stop_loop(&"music", 30)
##   TLSound.say(path, {"duck_music_db": -6.9})                        # the voice channel: one line at a time
##   TLSound.stop_voice(9)                                             # the line being said fades out over 9 frames
##   TLSound.channel_db("music", -6.0)
##
## Time is physics frames: a ramp, a fade and a delay are counted in frames by the pack's own sound node, never on the
## wall clock. Every call is recorded in `TLAudio.events` (`{frame, clip, channel, db, kind}`, kind play / loop / say /
## stop), also headless, where nothing is loaded or played: a bot can check what sounded and when.
## Unknown option keys are errors (the call does nothing). Sound is never state: nothing here feeds the simulation.

const CHANNELS: PackedStringArray = ["sfx", "crowd", "music", "voice", "ambience"]
const PLAY_KEYS: PackedStringArray = ["channel", "db", "pitch", "position", "delay_frames", "unit_size"]
const LOOP_KEYS: PackedStringArray = ["channel", "db", "pitch"]
const SET_KEYS: PackedStringArray = ["db", "pitch", "ramp_frames"]
const SAY_KEYS: PackedStringArray = ["db", "duck_music_db", "duck_frames"]
const SILENT_DB: float = -80.0
const NODE_NAME: String = "TLSound"
const BUS_PREFIX: String = "TL_"

static var _streams: Dictionary = {}     # path -> AudioStream (shared, read-only once loaded)


## Plays a file once. Options: `channel` ("sfx"), `db` (0), `pitch` (1), `position` (a Vector3 in the pack's space:
## the sound fades with distance; absent = everywhere), `unit_size` (metres at which a placed sound is at its level, 10),
## `delay_frames` (0: it starts that many frames from now).
static func play(path: String, opt: Dictionary = {}) -> void:
	TLContext.require("audio", "TLSound")
	if not _ok(path, opt, PLAY_KEYS, "play"):
		return
	var ctx: TLContext = TLContext.current
	var channel: String = str(opt.get("channel", "sfx"))
	var db: float = float(opt.get("db", 0.0))
	_record(ctx, path, channel, db, "play", opt.get("position"))
	var node: TLSoundNode = _node(ctx)
	if node != null:
		node.play(_stream(path), channel, db, float(opt.get("pitch", 1.0)), opt.get("position"), int(opt.get("delay_frames", 0)), float(opt.get("unit_size", 10.0)))


## Starts the loop `name` (a loop of that name that is already running is replaced). Options: `channel` ("sfx"),
## `db` (0), `pitch` (1). The file loops whatever its own loop flag says.
static func loop(name: StringName, path: String, opt: Dictionary = {}) -> void:
	TLContext.require("audio", "TLSound")
	if not _ok(path, opt, LOOP_KEYS, "loop"):
		return
	var ctx: TLContext = TLContext.current
	var channel: String = str(opt.get("channel", "sfx"))
	_record(ctx, path, channel, float(opt.get("db", 0.0)), "loop", null)
	var node: TLSoundNode = _node(ctx)
	if node != null:
		node.loop(name, _stream(path, true), channel, float(opt.get("db", 0.0)), float(opt.get("pitch", 1.0)))


## Sets a running loop's `db` and / or `pitch`, reached in a straight line over `ramp_frames` (0 = at once).
## Not recorded (a game sets these every frame). A name that is not running: nothing.
static func set_loop(name: StringName, opt: Dictionary) -> void:
	TLContext.require("audio", "TLSound")
	for k: String in opt:
		if not SET_KEYS.has(k):
			push_error("TLSound.set_loop: unknown option '%s' (known: %s)" % [k, ", ".join(SET_KEYS)])
			return
	var node: TLSoundNode = _node(TLContext.current)
	if node != null:
		node.set_loop(name, opt)


## Stops the loop `name`, fading it out over `fade_frames`.
static func stop_loop(name: StringName, fade_frames: int = 0) -> void:
	TLContext.require("audio", "TLSound")
	var ctx: TLContext = TLContext.current
	_record(ctx, String(name), "", 0.0, "stop", null)
	var node: TLSoundNode = _node(ctx)
	if node != null:
		node.stop_loop(name, fade_frames)


## Says a line on the voice channel: the line being said, if any, is cut. Options: `db` (0), `duck_music_db` (0: the
## music channel is lowered by this much while the line plays), `duck_frames` (12: the frames the duck takes each way,
## a straight line in gain, as a sound mix fades).
static func say(path: String, opt: Dictionary = {}) -> void:
	TLContext.require("audio", "TLSound")
	if not _ok(path, opt, SAY_KEYS, "say"):
		return
	var ctx: TLContext = TLContext.current
	_record(ctx, path, "voice", float(opt.get("db", 0.0)), "say", null)
	var node: TLSoundNode = _node(ctx)
	if node != null:
		node.say(_stream(path), float(opt.get("db", 0.0)), float(opt.get("duck_music_db", 0.0)), int(opt.get("duck_frames", 12)))


## Fades the line being said out over `fade_frames` (0: at once) and ends it; the duck comes back as the line ends.
## Nothing is said: nothing happens (recorded all the same, as `stop` of the clip "voice").
static func stop_voice(fade_frames: int = 0) -> void:
	TLContext.require("audio", "TLSound")
	var ctx: TLContext = TLContext.current
	_record(ctx, "voice", "", 0.0, "stop", null)
	var node: TLSoundNode = _node(ctx)
	if node != null:
		node.stop_voice(fade_frames)


## True while a line said with `say` is still playing (always false headless).
static func saying() -> bool:
	var node: TLSoundNode = _node(TLContext.current)
	return node != null and node.saying()


## A channel's volume (dB) for this pack; every sound and loop on it follows.
static func channel_db(channel: String, db: float) -> void:
	TLContext.require("audio", "TLSound")
	if not CHANNELS.has(channel):
		push_error("TLSound.channel_db: unknown channel '%s' (channels: %s)" % [channel, ", ".join(CHANNELS)])
		return
	var node: TLSoundNode = _node(TLContext.current)
	if node != null:
		node.channel_db(channel, db)


## How many times a file was played, looped or said so far in this run (the last TLAudio.MAX_EVENTS calls).
static func count(path: String) -> int:
	var n: int = 0
	for e: Dictionary in TLAudio.events:
		if e.get("clip", "") == path:
			n += 1
	return n


static func _ok(path: String, opt: Dictionary, keys: PackedStringArray, what: String) -> bool:
	for k: String in opt:
		if not keys.has(k):
			push_error("TLSound.%s: unknown option '%s' (known: %s)" % [what, k, ", ".join(keys)])
			return false
	if opt.has("channel") and not CHANNELS.has(str(opt["channel"])):
		push_error("TLSound.%s: unknown channel '%s' (channels: %s)" % [what, opt["channel"], ", ".join(CHANNELS)])
		return false
	var p: String = path.replace("\\", "/")
	if not p.begins_with("res://cores/") or not p.contains("/audio/") or p.contains(".."):
		push_error("TLSound.%s: '%s' is not a core's sound file (res://cores/<id>/audio/...)" % [what, path])
		return false
	return true


static func _record(ctx: TLContext, clip: String, channel: String, db: float, kind: String, position: Variant) -> void:
	var e: Dictionary = {"frame": ctx.frame if ctx != null else 0, "clip": clip, "kind": kind}
	if channel != "":
		e["channel"] = channel
		e["db"] = db
	if position != null:
		e["position"] = position
	var record: Array = ctx.audio_events if ctx != null else TLAudio._loose_events
	record.append(e)
	if record.size() > TLAudio.MAX_EVENTS:
		record.pop_front()


## The pack's sound node (made on first use under the pack's root), or null headless.
static func _node(ctx: TLContext) -> TLSoundNode:
	if ctx == null or ctx.headless or ctx.root == null:
		return null
	var n: TLSoundNode = ctx.root.get_node_or_null(NODE_NAME) as TLSoundNode
	if n == null:
		n = TLSoundNode.new()
		n.name = NODE_NAME
		ctx.root.add_child(n)
	return n


static func _stream(path: String, looping: bool = false) -> AudioStream:
	var key: String = path + ("|loop" if looping else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = load(path) as AudioStream
	if s == null:
		if TLContext.first_time("sound|" + path):
			push_error("TLSound: '%s' does not load as a sound (is the project imported?)" % path)
		return null
	if looping:
		s = s.duplicate() as AudioStream          # the loop flag is this use's, not the file's
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
	_streams[key] = s
	return s


## The node that holds a pack's players and counts their frames. Made by TLSound; a pack never touches it.
class TLSoundNode extends Node:
	var _loops: Dictionary = {}      # name -> {player, db, pitch, db_to, pitch_to, frames, stop}
	var _delayed: Array = []         # [frames left, player]
	var _voice: AudioStreamPlayer = null
	var _voice_fade: Array = [0, 0, 0.0]     # [frames left, frames, the line's db]: a line fading out
	var _duck: Dictionary = {"db": 0.0, "g": 1.0, "to": 1.0, "step": 0.0, "amount": 1.0}   # the music's duck, as a gain
	var _channel_db: Dictionary = {}

	func _ready() -> void:
		process_physics_priority = 90

	func _bus(channel: String) -> StringName:
		var bname: String = TLSound.BUS_PREFIX + channel
		if AudioServer.get_bus_index(bname) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bname)
			AudioServer.set_bus_send(i, &"Master")
		return StringName(bname)

	func _apply_channel(channel: String) -> void:
		var db: float = float(_channel_db.get(channel, 0.0)) + (float(_duck["db"]) if channel == "music" else 0.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(_bus(channel)), db)

	func channel_db(channel: String, db: float) -> void:
		_channel_db[channel] = db
		_apply_channel(channel)

	func play(stream: AudioStream, channel: String, db: float, pitch: float, position: Variant, delay_frames: int, unit_size: float) -> void:
		if stream == null:
			return
		var p: Node
		if position == null:
			var p2 := AudioStreamPlayer.new()
			p2.stream = stream
			p2.volume_db = db
			p2.pitch_scale = maxf(pitch, 0.01)
			p2.bus = _bus(channel)
			p2.finished.connect(p2.queue_free)
			p = p2
		else:
			var p3 := AudioStreamPlayer3D.new()
			p3.stream = stream
			p3.volume_db = db
			p3.pitch_scale = maxf(pitch, 0.01)
			p3.unit_size = unit_size
			p3.bus = _bus(channel)
			p3.finished.connect(p3.queue_free)
			p = p3
		add_child(p)
		if p is AudioStreamPlayer3D:
			(p as AudioStreamPlayer3D).position = position
		if delay_frames > 0:
			_delayed.append([delay_frames, p])
		else:
			p.call(&"play")

	func loop(lname: StringName, stream: AudioStream, channel: String, db: float, pitch: float) -> void:
		if _loops.has(lname):
			(_loops[lname]["player"] as AudioStreamPlayer).queue_free()
			_loops.erase(lname)
		if stream == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = maxf(db, TLSound.SILENT_DB)
		p.pitch_scale = maxf(pitch, 0.01)
		p.bus = _bus(channel)
		add_child(p)
		p.play()
		_loops[lname] = {"player": p, "db": db, "pitch": pitch, "db_to": db, "pitch_to": pitch, "frames": 0, "stop": false}

	func set_loop(lname: StringName, opt: Dictionary) -> void:
		if not _loops.has(lname):
			return
		var l: Dictionary = _loops[lname]
		if bool(l["stop"]):
			return
		l["db_to"] = float(opt.get("db", l["db_to"]))
		l["pitch_to"] = float(opt.get("pitch", l["pitch_to"]))
		l["frames"] = int(opt.get("ramp_frames", 0))
		if int(l["frames"]) <= 0:
			_tune(l, float(l["db_to"]), float(l["pitch_to"]))

	func stop_loop(lname: StringName, fade_frames: int) -> void:
		if not _loops.has(lname):
			return
		var l: Dictionary = _loops[lname]
		if fade_frames <= 0:
			(l["player"] as AudioStreamPlayer).queue_free()
			_loops.erase(lname)
			return
		l["db_to"] = TLSound.SILENT_DB
		l["frames"] = fade_frames
		l["stop"] = true

	func say(stream: AudioStream, db: float, duck_db: float, duck_frames: int) -> void:
		if _voice != null and is_instance_valid(_voice):
			_voice.queue_free()
		_voice = null
		if stream == null:
			return
		_voice_fade = [0, 0, db]
		_voice = AudioStreamPlayer.new()
		_voice.stream = stream
		_voice.volume_db = db
		_voice.bus = _bus("voice")
		add_child(_voice)
		_voice.play()
		_duck["amount"] = db_to_linear(duck_db)
		_duck["to"] = _duck["amount"]
		_duck["step"] = absf(1.0 - float(_duck["amount"])) / float(maxi(duck_frames, 1))

	func stop_voice(fade_frames: int) -> void:
		if not saying():
			return
		if fade_frames <= 0:
			_voice.queue_free()
			_voice = null
			return
		_voice_fade = [fade_frames, fade_frames, _voice.volume_db]

	func saying() -> bool:
		return _voice != null and is_instance_valid(_voice) and _voice.playing

	func _tune(l: Dictionary, db: float, pitch: float) -> void:
		l["db"] = db
		l["pitch"] = pitch
		var p: AudioStreamPlayer = l["player"]
		p.volume_db = maxf(db, TLSound.SILENT_DB)
		p.pitch_scale = maxf(pitch, 0.01)

	func _physics_process(_dt: float) -> void:
		for i: int in range(_delayed.size() - 1, -1, -1):
			_delayed[i][0] = int(_delayed[i][0]) - 1
			if int(_delayed[i][0]) <= 0:
				var p: Node = _delayed[i][1]
				if is_instance_valid(p):
					p.call(&"play")
				_delayed.remove_at(i)
		for lname: StringName in _loops.keys():
			var l: Dictionary = _loops[lname]
			var n: int = int(l["frames"])
			if n > 0:
				# a volume ramps in linear gain (a fade is heard as even), a pitch in its ratio
				var g: float = lerpf(db_to_linear(float(l["db"])), db_to_linear(float(l["db_to"])), 1.0 / float(n))
				_tune(l, linear_to_db(maxf(g, 1e-4)), lerpf(float(l["pitch"]), float(l["pitch_to"]), 1.0 / float(n)))
				l["frames"] = n - 1
				if n - 1 == 0 and bool(l["stop"]):
					(l["player"] as AudioStreamPlayer).queue_free()
					_loops.erase(lname)
		# a line fading out (stop_voice): its gain falls in a straight line, then it ends
		if int(_voice_fade[0]) > 0 and _voice != null and is_instance_valid(_voice):
			_voice_fade[0] = int(_voice_fade[0]) - 1
			if int(_voice_fade[0]) <= 0:
				_voice.queue_free()
				_voice = null
			else:
				_voice.volume_db = linear_to_db(maxf(db_to_linear(float(_voice_fade[2])) * float(_voice_fade[0]) / float(_voice_fade[1]), 1e-4))
		# the duck under a voice line: down while it plays, back when it ends (a straight line in gain)
		if not saying():
			_duck["to"] = 1.0
		if not is_equal_approx(float(_duck["g"]), float(_duck["to"])):
			_duck["g"] = move_toward(float(_duck["g"]), float(_duck["to"]), maxf(float(_duck["step"]), 1e-4))
			_duck["db"] = linear_to_db(maxf(float(_duck["g"]), 1e-4))
			_apply_channel("music")
