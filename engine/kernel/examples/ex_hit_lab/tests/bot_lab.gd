extends Node
## Bot: the lab plays itself; this waits for the end (frame 750) and reports what every hit did. `ok` means the run
## completed as scripted (nine lab hits and the check, four downs, four get-ups); how the falls LOOK is not judged here
## (that is the clip, judged by eye). The away/toward figures are in metres of head travel, measured from the frame
## before the hit: a fall away from the blow has `lie_away` > 0 on a big hit.

var ctx
var state: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()
	done = bool(state.get("done", false))


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var hits: Array = state.get("hits", [])
	var lines: PackedStringArray = []
	var away_big: int = 0
	for h: Dictionary in hits:
		lines.append("%s %.1f: away %.2f toward %.2f head_y_min %.2f lie_away %.2f" % [h["side"], float(h["strength"]),
			float(h["away_max"]), float(h["toward_max"]), float(h["head_y_min"]), float(h["lie_away"])])
		if float(h["strength"]) >= 1.0 and float(h["lie_away"]) > 0.0:
			away_big += 1
	var check: Dictionary = state.get("check", {})
	var ok: bool = done and hits.size() == 10 and int(state.get("downed", 0)) == 4 and int(state.get("got_up", 0)) == 4 \
		and int(check.get("down_frames", 0)) > 0 and not bool(state.get("victim_down", true)) and not bool(state.get("skater_down", true))
	return {"ok": ok, "summary": "hits %d, downs %d, get-ups %d, big hits falling away from the blow %d of 4; check %s; %s" % [
			hits.size(), int(state.get("downed", 0)), int(state.get("got_up", 0)), away_big, str(check), "; ".join(lines)],
		"hits": hits, "check": check, "away_big": away_big, "pose_digest": int(state.get("pose_digest", 0))}
