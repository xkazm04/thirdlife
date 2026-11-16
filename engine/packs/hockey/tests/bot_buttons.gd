extends Node
## Bot (H7): the mouse buttons and the jam's held-button trap. A mouse button is two declared actions (left: shoot and
## cross; right: pass and check); a real button presses both on the same frame, so this bot does too.
## Drill held_buttons: the puck slides into b0's reach from behind (he takes it about frame 30), r0 pokes it off him at
## frame 60. The bot holds a button from frame 4 (before the take: a press without the puck, so a cross-check or a check is
## tried then, as it should be) to frame 90, then presses it again at frame 96. Counted from frame 7: shots, passes, and
## the checks and cross-checks b0 tried (state hits.tries, whiffs included).
##   left held:  gaining the puck must not shoot (row: no-puck -> puck), losing it must not cross-check (row: puck -> no-puck);
##               pressed again without the puck: the cross-check is tried
##   right held: gaining must not pass (row), losing must not body-check (row); pressed again: the check is tried
## ok: the four rows hold, and each re-press acted.

var ctx
var s: Dictionary = {}
const BUTTONS: Array = [["left", &"shoot", &"cross"], ["right", &"pass", &"check"]]
var b: int = 0
var t0: int = -1
var shots0: int = 0
var passes0: int = 0
var given0: int = 0
var got_puck: int = -1
var lost_puck: int = -1
var acted_while_held: Array = []
var reacted: bool = false
var rows: Array = []
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _given() -> int:
	return int(s["hits"]["tries"].get("b0", 0))      # checks and cross-checks b0 tried, whiffs included


func _bot_tick(frame: int) -> void:
	s = ctx.pack_state()
	if str(s.get("mode", "base")) != "base":
		ctx.input.tap(&"mode_base")
		return
	if str(s.get("level", "none")) != "none":
		ctx.input.tap(&"level_none")
		return
	if done:
		return
	if b >= BUTTONS.size():
		done = true
		return
	var bt: Array = BUTTONS[b]
	if t0 < 0:
		ctx.input.tap(&"drill_held_buttons")
		t0 = frame
		got_puck = -1
		lost_puck = -1
		acted_while_held = []
		reacted = false
		return
	var age: int = frame - t0
	var h: String = str(s["puck"].get("holder", ""))
	if age == 7:
		shots0 = int(s["shots"].get("b0", 0))
		passes0 = int(s["possession"]["passes"].get("b0", 0))
		given0 = _given()
	if age == 4:
		ctx.input.press(bt[1])          # the button goes down: both of its actions
		ctx.input.press(bt[2])
	if age > 7 and age < 90:
		if h == "b0" and got_puck < 0:
			got_puck = age
		if got_puck >= 0 and h != "b0" and lost_puck < 0:
			lost_puck = age
		if int(s["shots"].get("b0", 0)) != shots0:
			acted_while_held.append("shot@%d" % age)
		if int(s["possession"]["passes"].get("b0", 0)) != passes0:
			acted_while_held.append("pass@%d" % age)
		if _given() != given0:
			acted_while_held.append("%s@%d" % [str(bt[2]), age])
	if age == 90:
		ctx.input.release(bt[1])
		ctx.input.release(bt[2])
	if age == 96:
		ctx.input.press(bt[1])
		ctx.input.press(bt[2])
	if age > 96 and age <= 100 and _given() > given0:
		reacted = true
	if age == 101:
		ctx.input.release(bt[1])
		ctx.input.release(bt[2])
		var clean: bool = acted_while_held.is_empty()
		rows.append({"button": bt[0], "took_at": got_puck, "lost_at": lost_puck, "gain_row": got_puck > 0 and clean, "lose_row": lost_puck > 0 and clean,
			"acted_while_held": acted_while_held.duplicate(), "repress_acted": reacted})
		b += 1
		t0 = -1


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and rows.size() == 2
	var parts: Array = []
	for r: Dictionary in rows:
		ok = ok and bool(r["gain_row"]) and bool(r["lose_row"]) and bool(r["repress_acted"])
		var verb_gain: String = "shoot" if r["button"] == "left" else "pass"
		var verb_lose: String = "cross-check" if r["button"] == "left" else "body check"
		parts.append("%s button held: took the puck at %d without a %s (%s); lost it at %d without a %s (%s); acted while held %s; pressed again: %s tried %s" % [
			r["button"], int(r["took_at"]), verb_gain, "ok" if r["gain_row"] else "MISS", int(r["lost_at"]), verb_lose, "ok" if r["lose_row"] else "MISS",
			str(r["acted_while_held"]), verb_lose, "yes" if r["repress_acted"] else "NO"])
	return {"ok": ok, "summary": " | ".join(parts), "rows": rows}
