extends Node
## Bot (H13): a face-off is won, not given. The match's opening face-off on the default rink: the centre men start 3.0 m
## from the centre, the puck drops up to 0.4 m off it, the reach is 1.45 m: nobody can own it at the drop.
## `skate` false: the human does nothing; true: he skates straight at the puck from the first frame (perfect keys).
## Reads, from the state: who owns the puck at the first live frame (must be nobody), and who takes it first (within 600
## frames). ok: nobody owns it at the first live frame, and (doing nothing) the human is not the first to take it.
## Who wins the draw when he skates is a number (`won`); test files bot_faceoff_<x>.gd set the level and `skate`.

var level: String = "rookie"
var skate: bool = true
var ctx
var s: Dictionary = {}
var first_live: int = -1
var owner_at_drop: String = ""
var first_taker: String = ""
var taken_at: int = -1
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if frame == 0:
		ctx.input.tap(StringName("level_" + level))       # pins the level (the default is rookie)
		return
	if done:
		ctx.input.set_axis(&"left", &"right", 0.0)
		ctx.input.set_axis(&"up", &"down", 0.0)
		return
	if first_live < 0 and str(s["state"]) == "running":
		first_live = frame
		owner_at_drop = str(s["puck"].get("holder", ""))
	var h: String = str(s["puck"].get("holder", ""))
	if first_live >= 0 and h != "" and first_taker == "":
		first_taker = h
		taken_at = frame - first_live
		done = true
	if skate:
		var me: Vector2 = Vector2.ZERO
		for k: Dictionary in s["skaters"]:
			if k["id"] == "b0":
				me = _v(k["pos"])
		var to: Vector2 = _v(s["puck"]["pos"]) - me
		var d: Vector2 = to.normalized() if to.length() > 0.05 else Vector2.ZERO
		ctx.input.set_axis(&"left", &"right", d.x)
		ctx.input.set_axis(&"up", &"down", d.y)
	if frame > 600:
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and first_live >= 0 and owner_at_drop == "" and (skate or first_taker != "b0")
	return {"ok": ok, "summary": "level %s, he %s: at the first live frame the puck is %s; first taken by %s after %d frames" % [level,
		"skates at it" if skate else "does nothing", "nobody's" if owner_at_drop == "" else owner_at_drop + "'s", first_taker if first_taker != "" else "nobody", taken_at],
		"won": first_taker == "b0", "frames": ctx.frame, "owner_at_drop": owner_at_drop, "first_taker": first_taker}
