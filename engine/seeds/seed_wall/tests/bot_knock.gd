extends Node
## Bot: plays seed.wall to the end through the player's actions (left, right, forward, back, throw).
##
## How it plays: it picks the block still standing that is nearest in x (when none stands, the rubble of the nearest
## one), lines up with it between 5 and 9.5 m in front of the wall, creeps toward the wall so that the walker faces
## it, and throws whenever it holds a ball and faces the wall. Too close, it walks back out and comes in again.
## How it decides it won: the rules say over with reason "score" (the pieces-down target was reached before the
## clock ran out), the HUD says so, and blocks really broke. Reason "time" is a failure.

const NEAR: float = 5.0               # metres in front of the wall: closer than this, walk back out
const FAR: float = 9.5

var ctx
var s: Dictionary = {}
var done: bool = false
var retreating: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	s = ctx.pack_state()
	done = s["state"] == "over"
	if done:
		ctx.input.release_all()
		return
	var me: Dictionary = s["player"]
	var target: Dictionary = _pick_block(float(me["x"]))
	var dx: float = float(target["x"]) - float(me["x"])
	var ahead: float = float(me["z"]) - float(target["z"])            # metres in front of the wall
	if ahead < NEAR:
		retreating = true
	elif ahead > FAR - 1.0:
		retreating = false
	ctx.input.set_axis(&"left", &"right", clampf(dx * 2.0, -1.0, 1.0))
	if retreating:
		ctx.input.set_axis(&"forward", &"back", 1.0)
	else:
		ctx.input.set_axis(&"forward", &"back", -1.0 if ahead > FAR else -0.15)      # creep: it also turns the walker to the wall
	var aimed: bool = absf(dx) < 0.3 and float(me["fz"]) < -0.97 and ahead <= FAR + 0.5 and not retreating
	if aimed and bool(me["holding"]):
		ctx.input.tap(&"throw")


## The standing block nearest in x; when all are broken, the nearest heap of rubble (more pieces to push).
func _pick_block(x: float) -> Dictionary:
	var best: Dictionary = {}
	for want_intact: bool in [true, false]:
		for b: Dictionary in s["blocks"]:
			if (b["state"] == "intact") == want_intact and (best.is_empty() or absf(float(b["x"]) - x) < absf(float(best["x"]) - x)):
				best = b
		if not best.is_empty():
			break
	return best


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var broken: int = (s["blocks"] as Array).filter(func(b: Dictionary) -> bool: return b["state"] != "intact").size()
	var ok: bool = done and s["reason"] == "score" and s["winner"] == "player" and broken >= 1 \
		and int(s["sounds"]["break"]) == broken and int(s["sounds"]["horn"]) == 1 and str(s["hud"]["hint"]) == "THE WALL IS DOWN"
	return {"ok": ok, "summary": "%d pieces down in %.1f s (limit 60 s), ended by %s; %d of %d blocks broken with %d throws (%d hard hits); %d pieces loose" % [
			int(s["pieces_down"]), ctx.seconds(int(s["total_frames"])), str(s["reason"]), broken, (s["blocks"] as Array).size(),
			int(s["throws"]), int(s["hits"]), int(s["pieces_loose"])],
		"pieces_down": int(s["pieces_down"]), "seconds": ctx.seconds(int(s["total_frames"])), "blocks_broken": broken,
		"throws": int(s["throws"]), "hits": int(s["hits"]), "pieces_loose": int(s["pieces_loose"])}
