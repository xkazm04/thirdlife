extends Node
## Rule: the team signals 1-4 (SignalSystem.cpp:46-48 keys One..Four, 264-325 Issue; SignalIntent.h; GAMEMODE.md row 13: the
## core's glue): a press gives the team an intent the brain reads (snapshot Controls.IntentKind: 1 defend, 2 space, 3 pass,
## 4 praise), only while Playing, and a second signal within 60 frames of the last is ignored (RepeatCooldownFrames).
##   during the opening faceoff: One -> no intent; at Playing + 10: Two -> 2; 20 frames later: Four -> still 2 (cooldown);
##   80 frames after Two: Three -> 3.

var ctx
var t0: int = -1
var seen: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	var s: Dictionary = ctx.pack_state()
	for k: StringName in [&"k_1", &"k_2", &"k_3", &"k_4"]:
		ctx.input.release(k)
	if int(s["phase"]) == 3 and frame == 5:
		ctx.input.press(&"k_1")
	if frame == 7:
		seen["faceoff"] = int(s["intent"])
	if t0 < 0 and int(s["phase"]) == 0:
		t0 = frame
	if t0 < 0:
		return
	var d: int = frame - t0
	if d == 10:
		ctx.input.press(&"k_2")
	elif d == 12:
		seen["two"] = int(s["intent"])
	elif d == 30:
		ctx.input.press(&"k_4")
	elif d == 32:
		seen["four_in_cooldown"] = int(s["intent"])
	elif d == 90:
		ctx.input.press(&"k_3")
	elif d == 92:
		seen["three"] = int(s["intent"])
		done = true


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and int(seen.get("faceoff", -1)) == 0 and int(seen.get("two", -1)) == 2 and int(seen.get("four_in_cooldown", -1)) == 2 and int(seen.get("three", -1)) == 3
	return {"ok": ok, "summary": "intent: in the faceoff %s, after Two %s, Four inside 60 frames %s, Three after %s (want 0, 2, 2, 3)" % [str(seen.get("faceoff")), str(seen.get("two")), str(seen.get("four_in_cooldown")), str(seen.get("three"))], "frames": ctx.frame}
