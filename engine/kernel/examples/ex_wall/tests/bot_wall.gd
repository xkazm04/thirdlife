extends Node
## Bot: checks that the light ball left the wall intact, that the heavy ball broke it, and that the pieces settled.

var ctx
var state: Dictionary = {}
var intact_after_light: bool = false
var impulse_light: float = 0.0
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	state = ctx.pack_state()
	if frame == 170:
		intact_after_light = state["wall"] == "intact" and int(state["light_bounces"]) >= 1
		impulse_light = float(state["strongest_impulse"])
	done = state["wall"] == "settled"


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and intact_after_light and int(state["pieces"]) == 18 and int(state["awake"]) == 0 \
		and impulse_light < float(state["threshold"]) and float(state["strongest_impulse"]) > float(state["threshold"])
	return {"ok": ok, "summary": "light ball %.1f N*s left the wall intact (threshold %.0f N*s); heavy ball %.0f N*s broke it at frame %d; %d pieces settled after %d frames" % [
			impulse_light, float(state["threshold"]), float(state["strongest_impulse"]), int(state["broke_frame"]), int(state["pieces"]), int(state["settled_after"])],
		"impulse_light": impulse_light, "impulse_heavy": float(state["strongest_impulse"]), "threshold": float(state["threshold"]),
		"pieces": int(state["pieces"]), "settled_after_frames": int(state["settled_after"]), "light_mass_kg": float(state["light_mass"]), "heavy_mass_kg": float(state["heavy_mass"])}
