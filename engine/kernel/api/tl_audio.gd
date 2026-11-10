class_name TLAudio
extends RefCounted
## Sound presets by name, with stand-in implementations: short synthesised tones (no audio files exist yet).
## Every call is recorded in `events` (frame, preset, position), also in headless runs, where nothing is played;
## so a bot can check that the horn sounded. Capability: `audio`.
##
##   TLAudio.play(&"whistle")
##   TLAudio.play(&"hit_wood", crate.global_position, -6.0)
##
## Contact sounds are automatic: when a tracked body (TLContact) hits something, the kernel plays
## `hit_<sound set>` of the struck material (materials.json column `sound`), louder for a harder hit, if the pack
## declares `audio`.

## preset -> {freq (Hz), ms, decay (higher = shorter ring), noise (0..1 share of noise)}
const PRESETS: Dictionary = {
	&"whistle": {"freq": 2100.0, "ms": 500, "decay": 1.0, "noise": 0.05},
	&"horn": {"freq": 220.0, "ms": 900, "decay": 0.6, "noise": 0.1},
	&"beep": {"freq": 880.0, "ms": 120, "decay": 2.0, "noise": 0.0},
	&"cheer": {"freq": 500.0, "ms": 1200, "decay": 0.8, "noise": 0.9},
	&"engine": {"freq": 90.0, "ms": 400, "decay": 0.3, "noise": 0.3},
	&"nitro": {"freq": 160.0, "ms": 700, "decay": 0.8, "noise": 0.7},
	&"skate": {"freq": 3000.0, "ms": 180, "decay": 3.0, "noise": 0.9},
	&"score": {"freq": 660.0, "ms": 600, "decay": 1.2, "noise": 0.0},
	&"break": {"freq": 140.0, "ms": 500, "decay": 3.0, "noise": 0.8},
	&"hit_ice": {"freq": 1500.0, "ms": 90, "decay": 6.0, "noise": 0.4},
	&"hit_concrete": {"freq": 180.0, "ms": 110, "decay": 7.0, "noise": 0.6},
	&"hit_metal": {"freq": 950.0, "ms": 260, "decay": 3.0, "noise": 0.1},
	&"hit_wood": {"freq": 320.0, "ms": 120, "decay": 6.0, "noise": 0.3},
	&"hit_rubber": {"freq": 120.0, "ms": 90, "decay": 8.0, "noise": 0.2},
	&"hit_asphalt": {"freq": 160.0, "ms": 100, "decay": 8.0, "noise": 0.7},
	&"hit_grass": {"freq": 110.0, "ms": 80, "decay": 9.0, "noise": 0.8},
	&"hit_dirt": {"freq": 100.0, "ms": 90, "decay": 9.0, "noise": 0.8},
	&"hit_glass": {"freq": 2400.0, "ms": 200, "decay": 4.0, "noise": 0.2},
	&"hit_plastic": {"freq": 600.0, "ms": 80, "decay": 8.0, "noise": 0.2},
	&"hit_snow": {"freq": 90.0, "ms": 100, "decay": 10.0, "noise": 0.9},
	&"hit_water": {"freq": 300.0, "ms": 250, "decay": 4.0, "noise": 0.9},
	&"hit_stone": {"freq": 240.0, "ms": 110, "decay": 7.0, "noise": 0.5},
	&"hit_fabric": {"freq": 80.0, "ms": 70, "decay": 10.0, "noise": 0.7},
}
const MAX_EVENTS: int = 200

static var events: Array = []          ## [{frame, preset, position?}], the last MAX_EVENTS
static var _streams: Dictionary = {}
static var _warned: Dictionary = {}


static func presets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: StringName in PRESETS.keys():
		out.append(String(k))
	return out


## Plays a preset: at a world position (3D, fades with distance) or, with `position` null, everywhere.
static func play(preset: StringName, position: Variant = null, volume_db: float = 0.0) -> void:
	TLContext.require("audio", "TLAudio")
	_play(preset, position, volume_db)


## How many times a preset was played so far in this run (for bots and tests).
static func count(preset: StringName) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if e["preset"] == String(preset):
			n += 1
	return n


## Kernel door for contact sounds (called by TLContact). Silent when the pack does not declare `audio`.
static func contact(struck_material: String, impulse: float, position: Vector3) -> void:
	var ctx: TLContext = TLContext.current
	if ctx == null or not ctx.has_capability("audio") or struck_material.is_empty():
		return
	var set_name: String = str(TLLaws.material(struck_material).get("sound", "concrete"))
	_play(StringName("hit_" + set_name), position, clampf(linear_to_db(clampf(impulse / 200.0, 0.05, 1.0)), -26.0, 0.0))


static func _play(preset: StringName, position: Variant, volume_db: float) -> void:
	if not PRESETS.has(preset):
		if not _warned.has(preset):
			_warned[preset] = true
			push_error("TLAudio: unknown preset '%s' (presets: %s)" % [preset, ", ".join(presets())])
		return
	var ctx: TLContext = TLContext.current
	var e: Dictionary = {"frame": ctx.frame if ctx != null else 0, "preset": String(preset)}
	if position != null:
		e["position"] = position
	events.append(e)
	if events.size() > MAX_EVENTS:
		events.pop_front()
	if ctx == null or ctx.headless or ctx.root == null:
		return
	var stream: AudioStreamWAV = _stream(preset)
	if position == null:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		ctx.root.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	else:
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.unit_size = 8.0
		ctx.root.add_child(p3)
		p3.global_position = position
		p3.finished.connect(p3.queue_free)
		p3.play()


## The stand-in sound: a decaying tone with some noise, generated once per preset (noise from a fixed seed).
static func _stream(preset: StringName) -> AudioStreamWAV:
	if _streams.has(preset):
		return _streams[preset]
	var p: Dictionary = PRESETS[preset]
	var rate: int = 22050
	var n: int = int(float(rate) * float(p["ms"]) / 1000.0)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(preset))
	for i: int in n:
		var t: float = float(i) / float(rate)
		var env: float = exp(-float(p["decay"]) * t * 4.0) * minf(1.0, float(i) / 60.0)
		var tone: float = sin(TAU * float(p["freq"]) * t)
		var v: float = (tone * (1.0 - float(p["noise"])) + rng.randf_range(-1.0, 1.0) * float(p["noise"])) * env * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_streams[preset] = wav
	return wav
