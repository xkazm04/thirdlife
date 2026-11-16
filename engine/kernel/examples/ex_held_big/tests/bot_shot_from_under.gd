extends Node
## Bot: watches. The skater never moves of his own will; passes when, after the puck was shot from under his 0.66 m body,
## his speed stayed under 1 m/s and he is still within 1 m of where he stood.

var ctx
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()


func _bot_done() -> bool:
	return int(state.get("ticks", 0)) >= 240


func _bot_result() -> Dictionary:
	var moved: float = Vector2(float(state["skater_x"]), float(state["skater_z"])).length()
	var ok: bool = int(state["released_at"]) == 90 and float(state["top_speed_after"]) < 1.0 and moved < 1.0 \
		and float(state["puck_peak"]) > 20.0 and absf(float(state["body_radius"]) - 0.66) < 0.001
	return {"ok": ok, "summary": "body radius %.2f m; puck shot from under him at tick %d (puck up to %.1f m/s); his top speed after %.2f m/s (limit 1.0), before %.2f; he ended %.2f m from where he stood (limit 1.0)" % [
			float(state["body_radius"]), int(state["released_at"]), float(state["puck_peak"]), float(state["top_speed_after"]), float(state["top_speed"]), moved],
		"top_speed_after": snappedf(float(state["top_speed_after"]), 0.01), "moved": snappedf(moved, 0.01), "puck_peak": snappedf(float(state["puck_peak"]), 0.1)}
