extends RefCounted

var ctx = null
var cfg: Dictionary = {}
var _last_board: int = -1000
var _last_spray: int = -1000
var _frame: int = 0


func setup(c, _env) -> void:
	ctx = c
	var d = c.read_json("fx.json")
	if d is Dictionary:
		cfg = d


func _f(key: String, dflt: float) -> float:
	return float(cfg.get(key, dflt))


func _play(preset: String, pos = null) -> void:
	TLAudio.play(preset, pos, _f("volume_db", 0.0))


func on_event(name: String, pos: Vector3, _team: String) -> void:
	match name:
		"shot":
			_play("hit_ice", pos)
			_play("skate", pos)
			TLVfx.burst("ice_spray", pos, ctx.root)
		"board":
			if _frame - _last_board >= int(_f("min_gap_frames", 12)):
				_last_board = _frame
				_play("hit_wood", pos)
		"goal":
			_play("horn")
			_play("cheer")
			TLVfx.burst("goal_flash", pos, ctx.root)
			TLVfx.burst("confetti", pos + Vector3(0, 2, 0), ctx.root)
		"faceoff":
			_play("whistle")
		"win":
			_play("cheer")
			TLVfx.burst("confetti", pos + Vector3(0, 2, 0), ctx.root)
		"lose":
			_play("beep")


func tick(frame: int, env) -> void:
	_frame = frame
	if env.get("frozen", false):
		return
	var fastest: float = 0.0
	var fast_pos := Vector3.ZERO
	for id in env["skaters"]:
		var sk = env["skaters"][id]
		var s: float = sk.speed()
		if s > fastest:
			fastest = s
			fast_pos = sk.global_position
	var every: int = maxi(1, int(_f("scrape_every_frames", 20)))
	if frame % every == 0 and fastest > _f("scrape_speed", 5.0):
		_play("skate", fast_pos)
	if fastest > _f("spray_speed", 6.0) and frame - _last_spray >= int(_f("spray_every_frames", 30)):
		_last_spray = frame
		TLVfx.burst("ice_spray", fast_pos, ctx.root)
