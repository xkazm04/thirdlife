extends SceneTree
## P12. Does a pack's preparation on the build queue's worker hang on the frame rate? Prepares one pack exactly as
## jobs.gd does (`prepare`) on a worker thread while the main thread holds frames of a fixed length (OS.delay_msec
## inside the frame, as a throttled window or vertical sync holds it). Before P12 every value-returning call of the
## worker into the renderer waited for the main thread's next frame, so preparation took about 20 frames.
##   <godot> --headless --path engine -s res://kernel/world/jobs_probe.gd -- <abs pack dir> <frame ms>
## Prints `PROBE dir=<name> frame_ms=<n> prepare_ms=<ms> frames=<n>`.

const Jobs: GDScript = preload("res://kernel/world/jobs.gd")
const Manifest: GDScript = preload("res://kernel/runner/manifest.gd")

var _th: Thread
var _frames: int = 0
var _frame_ms: int = 0
var _done: bool = false
var _prep_ms: float = 0.0
var _dir: String = ""


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() < 2:
		print("PROBE usage: -- <abs pack dir> <frame ms>")
		quit(2)
		return
	_dir = Manifest.resolve_dir(a[0])
	_frame_ms = int(a[1])
	var mres: Dictionary = Manifest.read(_dir)
	if _dir.is_empty() or not bool(mres["ok"]):
		print("PROBE no pack at " + a[0])
		quit(2)
		return
	var m: Dictionary = mres["manifest"]
	_th = Thread.new()
	_th.start(func() -> void:
		var t: int = Time.get_ticks_usec()
		var keys: Array = Jobs.prepare(_dir, m, "plot")
		_prep_ms = float(Time.get_ticks_usec() - t) / 1000.0
		for k: String in keys:
			Jobs.drop_ahead(k)
		_done = true)


func _process(_d: float) -> bool:
	if _th == null:
		return true
	_frames += 1
	if _done:
		_th.wait_to_finish()
		print("PROBE dir=%s frame_ms=%d prepare_ms=%.1f frames=%d" % [_dir.get_file(), _frame_ms, _prep_ms, _frames])
		return true
	if _frames > 2000:
		print("PROBE dir=%s frame_ms=%d TIMEOUT frames=%d" % [_dir.get_file(), _frame_ms, _frames])
		return true
	OS.delay_msec(_frame_ms)
	return false
