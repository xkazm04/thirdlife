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
	# Project the two rotated rectangular decks onto the direction of travel.
	var projected := float(s.pad_length) * cos(deg_to_rad(s.pad_yaw)) + float(s.pad_width) * sin(deg_to_rad(s.pad_yaw))
	var half_z := (float(s.pad_width) * cos(deg_to_rad(s.pad_yaw)) + float(s.pad_length) * sin(deg_to_rad(s.pad_yaw))) / 2
	var dz := maxf(0.0, maxf(s.pad_z[0] - half_z - s.corner_far_z, s.corner_near_z - (s.pad_z[0] + half_z)))
	var corner_gap := Vector2(maxf(0.0, s.pad_one - projected / 2 - s.corner_end), dz).length()
	if corner_gap > reach:
		notes.append("offset first pad is at least %.2f m from the corner, running reach %.2f m" % [corner_gap, reach])
	var pad_gap := float(s.pad_two) - float(s.pad_one) - projected
	var beam_gap := float(s.beam_start) - float(s.pad_two) - projected / 2
	if pad_gap > reach or pad_gap <= 0:
		notes.append("angled pad gap %.2f m, running reach %.2f m" % [pad_gap, reach])
	if beam_gap > reach or beam_gap <= 0:
		notes.append("balance beam entry gap %.2f m, running reach %.2f m" % [beam_gap, reach])
	# At maximum swing the near corner of the counterweight must clear a standing runner on the centre line.
	var angle := deg_to_rad(float(s.swing_degrees))
	var opening := (float(s.swing_arm) - float(s.weight_height) / 2) * sin(angle) - float(s.weight_width) / 2 * cos(angle)
	var body_radius := 0.35
	if opening <= body_radius + s.contact_skin:
		notes.append("swing opens only %.2f m from centre, walker radius 0.35 m" % opening)
	# Upper bound: even a fully open half-cycle must allow the weight's depth and one capsule diameter to cross.
	var crossing_ticks := ceili(60 * (float(s.weight_depth) + 2 * (body_radius + float(s.contact_skin))) / float(s.run_mps))
	if s.swing_period / 2.0 < crossing_ticks:
		notes.append("swing half-cycle %.1f ticks, crossing needs at least %d ticks" % [s.swing_period / 2.0, crossing_ticks])
	# The walker rises one metre from a level lip. Integrate the descending branch of its unassisted arc.
	var crest_rise := float(s.crest_y) - float(s.wall_top)
	var apex := 6.93 * 6.93 / (2 * 24.0)
	if crest_rise <= 0 or crest_rise >= apex:
		notes.append("run-up wall crest rises %.2f m above the lip, walker apex %.2f m" % [crest_rise, apex])
	else:
		var raised_reach := float(s.run_mps) * (6.93 + sqrt(6.93 * 6.93 - 48 * crest_rise)) / 24
		var walking_reach := raised_reach * 4.5 / float(s.run_mps)
		if s.crest - s.wall_lip <= walking_reach + 0.7:
			notes.append("run-up gap fits a walk jump including both 0.35 m capsule edges")
		if s.crest - s.wall_lip > raised_reach:
			notes.append("run-up gap exceeds raised landing reach %.2f m" % raised_reach)
	if s.tier_rise <= 0.55 or s.tier_rise >= apex:
		notes.append("tower terrace rise %.2f m must require a jump and fit the %.2f m apex" % [s.tier_rise, apex])
	if s.ledge_rise <= apex or s.ledge_rise > 2.8 + apex:
		notes.append("headwall rise %.2f m must exceed a jump and fit the 3.80 m maximum catch" % s.ledge_rise)
	var hands_rise := float(s.first_bar_y) - float(s.rim_y)
	if hands_rise <= 2.2 + 0.35 or hands_rise > 2.2 + apex + 0.35:
		notes.append("blue bar %.2f m above runway must need a jump and fit the airborne hands" % hands_rise)
	var transfer := float(s.second_bar) - float(s.first_bar)
	var transfer_bound := _swing_reach(float(s.red_rise) - 2.2 - 0.35, s.run_mps) + 0.35
	if transfer <= 0.0 or transfer > transfer_bound:
		notes.append("bar spacing %.2f m exceeds the running transfer envelope %.2f m" % [transfer, transfer_bound])
	var landing := float(s.landing_z) - float(s.second_bar)
	var landing_bound := _swing_reach(float(s.landing_y) - float(s.first_bar_y) - float(s.red_rise), s.run_mps) + 0.35
	if landing <= 0.0 or landing > landing_bound:
		notes.append("landing %.2f m from red exceeds the release envelope %.2f m" % [landing, landing_bound])
	result = {"ok": notes.is_empty(), "summary": "gaps %.2f / %.2f m, reach %.2f m, bar %.2f m, chute %.0f deg%s" % [
		spans[0], spans[1], reach, s.clearance, s.chute_degrees, "" if notes.is_empty() else " | " + ", ".join(notes)]}


# Optimistic first outbound swing with a running entry, full forward pump and no damping.
# Test every release degree against the descending ballistic arc. The runner still has to hit the actual cylinder.
func _swing_reach(target_y: float, run_mps: float) -> float:
	var best := 0.0
	for degrees: int in 101:
		var angle := deg_to_rad(degrees)
		var omega_sq := pow(run_mps / 1.1, 2) - 2.0 * 24.0 / 1.1 * (1.0 - cos(angle)) + 10.0 * angle
		var up := 2.0 + sqrt(maxf(0.0, omega_sq)) * 1.1 * sin(angle)
		var disc := up * up - 48.0 * (target_y + 2.2 * cos(angle))
		if disc >= 0.0:
			best = maxf(best, 2.2 * sin(angle) + run_mps * (up + sqrt(disc)) / 24.0)
	return best


func _bot_done() -> bool:
	return not result.is_empty()


func _bot_result() -> Dictionary:
	return result
