extends Node
## Rule: R restarts the match in place (AHokejGameMode::RestartMatch, HokejGameMode.cpp:800-818; the key FJamBindings::Defaults
## R, InputMapping.cpp:118). The hand skates and shoots for 300 frames, taps R, then lets the match run 240 frames idle.
## After the tap the core's frame starts again from 0, the score is 0:0, the phase is the opening faceoff, and the
## state from there on is the fresh match's: the core hash 240 frames after R equals the hash of an untouched match at
## the same frame with the same (idle) input, which the bot reads first from frames 0-240 of its own run (idle too).

var ctx
var fresh: Dictionary = {}      # core frame -> hash in the first 240 idle frames
var after: Dictionary = {}      # core frame -> hash after R
var r_at: int = 540
var reset_seen: bool = false
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	var s: Dictionary = ctx.pack_state()
	var cf: int = int(s["rink"]["frame"])
	if frame <= 240:
		fresh[cf] = String(s["rink"]["hash"])
	elif frame > r_at and cf <= 240:
		after[cf] = String(s["rink"]["hash"])
		if cf <= 2 and int(s["rink"]["score"][0]) == 0 and int(s["rink"]["score"][1]) == 0:
			reset_seen = true
	ctx.input.release(&"k_w")
	ctx.input.release(&"m_left")
	ctx.input.release(&"k_r")
	if frame > 240 and frame < 540:                    # play: skate and shoot between the idle stretches
		ctx.input.press(&"k_w")
		if frame % 40 < 20:
			ctx.input.press(&"m_left")
	elif frame == r_at:
		ctx.input.press(&"k_r")
	done = frame >= r_at + 245


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var same: int = 0
	var differ: Array = []
	for f: int in after:
		if fresh.has(f):
			if fresh[f] == after[f]:
				same += 1
			else:
				differ.append(f)
	var ok: bool = done and reset_seen and same >= 200 and differ.is_empty()
	return {"ok": ok, "summary": "R at frame %d: restarted to frame 0 at 0:0 %s; %d core frames after R hash as the untouched match's, %d differ%s" % [r_at, str(reset_seen), same, differ.size(), "" if differ.is_empty() else " (first %d)" % int(differ[0])], "frames": ctx.frame}
