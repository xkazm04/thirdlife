extends Node
## Conservative, level-to-level reach: the parity fixture measured 33 airborne samples at full speed.
## This test examines dimensions fed to the kit builders. bot_course independently traverses the colliders.
var ctx: TLContext
var result: Dictionary


func _bot_setup(c: TLContext) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	var s := ctx.pack_state()
	var reach := float(s.run_mps) * 33.0 / 60.0
	var notes: PackedStringArray = []
	var spans := [float(s.first_land) - float(s.first_lip), float(s.chain_land) - float(s.chain_lip)]
	for i: int in spans.size():
		if spans[i] <= 0.0 or spans[i] > reach:
			notes.append("gap %d is %.2f m (running jump reach %.2f m)" % [i + 1, spans[i], reach])
	if s.clearance <= TLBiped.WALKER_SLIDE_HEIGHT or s.clearance >= TLBiped.WALKER_HEIGHT:
		notes.append("bar clearance %.2f m must lie between slide %.2f and standing %.2f m" % [
			s.clearance, TLBiped.WALKER_SLIDE_HEIGHT, TLBiped.WALKER_HEIGHT])
	if s.chute_degrees <= 55 or s.chute_degrees >= 90:
		notes.append("chute %.1f degrees must be steeper than 55 and below vertical" % s.chute_degrees)
	result = {"ok": notes.is_empty(), "summary": "gaps %.2f / %.2f m, reach %.2f m, bar %.2f m, chute %.0f deg%s" % [
		spans[0], spans[1], reach, s.clearance, s.chute_degrees, "" if notes.is_empty() else " | " + ", ".join(notes)]}


func _bot_done() -> bool:
	return not result.is_empty()


func _bot_result() -> Dictionary:
	return result
