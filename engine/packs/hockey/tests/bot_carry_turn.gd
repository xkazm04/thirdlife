extends Node
## L4 director (21 Nov 11:45): the blade distance is thirdjam's rule scaled to this figure: thirdjam carries at (0.4 + 1.2) x 0.75 = 1.2 m
## for a 0.4 m body; the drawn blade base is 0.66 m (rig scale 2.2), so (0.66 + 1.98) x 0.75 = 1.98 m walking, 2.64 m sprinting.
## At 1.2 m the 4.4 m figure hid the puck under its own chest in a window (clip r1_skate); at 1.98 m it sits at the drawn blade.
## One take on open ice. D into S makes a skating turn while the cursor sweeps
## across both sides. Shift extends the blade on the straight after the turn.

var ctx
var t0 := -1
var done := false
var kept := true
var close_max := 0.0
var sprint_max := 0.0
var close_dist := 0.0
var sprint_dist := 0.0
var shield := 0
var sprint_shield := 0
var turned := false
var left := false
var right := false
var old_stick := Vector2.ZERO


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(frame: int) -> void:
	var s: Dictionary = ctx.pack_state()
	if t0 < 0:
		ctx.input.tap(&"drill_carry_alone")
		t0 = frame
		return
	var age := frame - t0
	var me: Dictionary = s["skaters"][0]
	var p := Vector2(me.pos[0], me.pos[1])
	var puck := Vector2(s.puck.pos[0], s.puck.pos[1])
	var distance := p.distance_to(puck)
	kept = kept and s.puck.get("holder", "") == "b0"
	if age > 6 and age <= 85:
		close_max = maxf(close_max, distance)
	if age == 85:
		close_dist = distance
	if age > 85:
		sprint_max = maxf(sprint_max, distance)
	var st: Array = s.get("stick", [])
	if not st.is_empty():
		var dir := Vector2(st[0], st[1])
		if old_stick != Vector2.ZERO and age <= 85:
			var deg := rad_to_deg(old_stick.angle_to(dir))
			left = left or deg < -6
			right = right or deg > 6
		old_stick = dir
	if age <= 85:
		shield = maxi(shield, int(s.possession.get("shield_left", 0)))
	elif age > 98:
		sprint_shield = maxi(sprint_shield, int(s.possession.get("shield_left", 0)))
	turned = turned or (me.facing[1] > 0.9 and me.speed > 2.0)
	if age == 130:
		sprint_dist = distance
		done = true
		return
	ctx.input.set_axis(&"left", &"right", 1.0 if age < 40 else 0.0)
	ctx.input.set_axis(&"up", &"down", 0.0 if age < 40 else 1.0)
	var aim := Vector3.RIGHT
	if age >= 22 and age < 37:
		aim = Vector3.FORWARD
	elif age >= 37 and age < 61:
		aim = Vector3(0.5, 0, 1).normalized()
	elif age >= 101:
		aim = Vector3.BACK
	ctx.input.set_aim(&"aim", Vector3(p.x, 0, p.y) + aim * 12.0)
	if age >= 85:
		ctx.input.press(&"sprint")


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok := done and kept and turned and left and right and close_max <= 2.05 and absf(close_dist - 1.98) <= 0.1 \
		and absf(sprint_dist - 2.64) <= 0.1 and shield == 12 and sprint_shield == 6
	return {"ok": ok, "summary": "kept %s, turn %s, sweeps %s/%s, normal max %.3f m, settled %.3f m, sprint max %.3f m, settled %.3f m, shields %d/%d" % [kept, turned, left, right, close_max, close_dist, sprint_max, sprint_dist, shield, sprint_shield]}

