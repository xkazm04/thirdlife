extends Node
## A contact bot: starts one drill of data/drills.json (both fighters placed, the rival scripted), presses the player's
## keys of the drill through ctx.input, and passes when the drill's contact happened with BOTH fighters' states changed
## (DUEL-PLAYBOOK 6.3 acceptance) and no contact of the run left a fighter unchanged.
var ctx
var drill_id: String = ""
var drill: Dictionary = {}
var t0: int = 4
var seen: Dictionary = {}
var done: bool = false
var frames_after: int = 0


func _bot_setup(c) -> void:
	ctx = c
	for d: Dictionary in ctx.read_json("drills.json")["drills"]:
		if str(d["id"]) == drill_id:
			drill = d


func _bot_tick(frame: int) -> void:
	if drill.is_empty():
		done = true
		return
	if frame == t0:
		ctx.input.tap(StringName("drill_" + drill_id))
	var k: int = frame - t0
	for p: Array in drill["input"]:
		if k == int(p[0]):
			ctx.input.press(StringName(p[1]))
		elif k == int(p[0]) + int(p[2]):
			ctx.input.release(StringName(p[1]))
	var s: Dictionary = ctx.pack_state()
	for e: Dictionary in s["log"]:
		if str(e["type"]) == str(drill["expect"]) and seen.is_empty():
			seen = e
	if not seen.is_empty():
		frames_after += 1
	done = frames_after > int(drill.get("tail", 100)) or k > 600                 # 100 frames after the contact: the reactions play out (and a clip shows them)


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var s: Dictionary = ctx.pack_state()
	var ok: bool = not seen.is_empty() and bool(seen.get("both", false)) and int(s["failures"]) == 0
	var line: String = "%s: attacker %s -> %s>%s, defender %s -> %s>%s" % [seen.get("type", "?"), seen.get("a", ["?", "?", "?"])[0], seen.get("a", ["?", "?", "?"])[1],
		seen.get("a", ["?", "?", "?"])[2], seen.get("d", ["?", "?", "?"])[0], seen.get("d", ["?", "?", "?"])[1], seen.get("d", ["?", "?", "?"])[2]] if not seen.is_empty() else "no %s contact (kinds %s)" % [drill.get("expect", "?"), str(s["kinds"])]
	return {"ok": ok, "summary": "drill %s: %s; failures %d" % [drill_id, line, int(s["failures"])], "contact": seen,
		"kinds": s["kinds"], "you": s["you"]["st"], "rival": s["rival"]["st"]}
