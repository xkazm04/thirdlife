extends Node
## Bot: drives seed.drive to the end through the player's actions (left, right, gas, brake, nitro).
##
## How it drives: the game state carries two points on the centre line. `ahead` is a few metres in front of the
## car: the bot steers its nose toward it. `far` is where the car will be in a second and a half: the more that
## point is off to one side, the tighter the bend that is coming, and the bot slows from FAST toward SLOW in time.
## When the pad has filled the tank and the road ahead is straight, it holds nitro until the tank is empty.
## How it decides it won: the rules say over, winner "car", reason "laps", three laps counted, and the pad and the
## nitro were really used. A run that ends by the clock (reason "time") is a failure.

const FAST: float = 19.0
const SLOW: float = 10.0
const BOOST: float = 30.0              # speed allowed while the nitro burns

var ctx
var s: Dictionary = {}
var done: bool = false
var worst_off_line: float = 0.0
var boosting: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	done = s["state"] == "over"
	if done:
		ctx.input.release_all()
		return
	var car: Dictionary = s["car"]
	ctx.input.set_axis(&"left", &"right", clampf(_side(car, s["ahead"]) * 2.5, -1.0, 1.0))
	var bend: float = absf(_side(car, s["far"]))               # 0 = straight road ahead, 1 = a right angle
	if float(car["nitro_charge"]) >= 1.0 and bend < 0.05:
		boosting = true
	elif float(car["nitro_charge"]) <= 0.0 or bend > 0.2:
		boosting = false
	ctx.input.press(&"nitro", 1.0 if boosting else 0.0)
	var limit: float = BOOST if boosting else lerpf(FAST, SLOW, clampf(bend * 4.0, 0.0, 1.0))
	var speed: float = float(car["forward_speed"])
	ctx.input.press(&"gas", 1.0 if speed < limit else 0.0)
	ctx.input.press(&"brake", 1.0 if speed > limit + 1.5 else 0.0)
	worst_off_line = maxf(worst_off_line, absf(float(s["off_line"])))


## How far to the side of the car's nose a point [x, z] is: -1 = hard left, 0 = dead ahead, +1 = hard right.
func _side(car: Dictionary, point: Array) -> float:
	var dx: float = float(point[0]) - float(car["x"])
	var dz: float = float(point[1]) - float(car["z"])
	return (float(car["fx"]) * dz - float(car["fz"]) * dx) / maxf(0.001, sqrt(dx * dx + dz * dz))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var rounds: int = int((s.get("laps", {}) as Dictionary).get("car", 0))
	var ok: bool = done and s["winner"] == "car" and s["reason"] == "laps" and rounds == 3 \
		and int(s["pad_visits"]) >= 3 and int(s["nitro_starts"]) >= 1 and int(s["cones"]["spawned"]) >= 8
	return {"ok": ok, "summary": "%d laps in %.1f s (limit 90 s), ended by %s; top speed %.1f m/s; nitro pad %d times, %d nitro bursts; %d cone hits, %d cones spawned; at most %.1f m off the centre line" % [
			rounds, ctx.seconds(int(s["total_frames"])), str(s["reason"]), float(s["top_speed"]), int(s["pad_visits"]), int(s["nitro_starts"]),
			int(s["cone_hits"]), int(s["cones"]["spawned"]), worst_off_line],
		"laps": rounds, "seconds": ctx.seconds(int(s["total_frames"])), "top_speed": float(s["top_speed"]), "pad_visits": int(s["pad_visits"]),
		"nitro_starts": int(s["nitro_starts"]), "cone_hits": int(s["cone_hits"]), "cones_spawned": int(s["cones"]["spawned"]),
		"worst_off_line_m": worst_off_line}
