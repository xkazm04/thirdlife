extends Node
## Both freeze on every call. Hits, counters, mixed clash and bashes cost the
## attacker the freeze only. A light block also pushes him, a heavy block
## recoils him, parries stun him, and equal clashes rebound both. Defenders
## must show the named stun, including the parrier's short recovery.
## Each row: label, call, stop, attacker stun/frames, defender stun/frames.
const EXPECT := [
	["Light hit", "hit", 5, "", 0, "hitstun", 18],
	["Heavy hit", "hit", 9, "", 0, "hitstun", 40],
	["Heavy counter-hit", "hit", 11, "", 0, "hitstun", 50],
	["Light blocked", "blocked", 3, "", 0, "blockstun", 14],
	["Heavy blocked", "blocked", 6, "recoil", 40, "blockstun", 18],
	["Light parried", "parried", 10, "parried", 52, "recover", 8],
	["Heavy parried", "parried", 10, "parried", 36, "recover", 8],
	["Light clash", "clash", 8, "rebound", 20, "rebound", 20],
	["Heavy clash", "clash", 8, "rebound", 30, "rebound", 30],
	["Heavy vs light", "clash", 9, "", 0, "hitstun", 40],
	["Open bash", "guard_break", 6, "", 0, "guardbroken", 30],
	["Bash near wall", "guard_break", 12, "", 0, "wallsplat", 60],
	["Heavy into wall", "hit", 9, "", 0, "hitstun", 40],
]

var ctx
var state: Dictionary = {}


func _bot_setup(c) -> void:
	ctx = c


func _bot_tick(_frame: int) -> void:
	state = ctx.pack_state()


func _bot_done() -> bool:
	return state.get("done", false)


func _bot_result() -> Dictionary:
	var cases: Array = state.get("cases", [])
	var contacts: Array = []
	var errors := PackedStringArray()
	var radius: float = state.get("radii_sum", 0.0)
	for group: Dictionary in cases:
		if group.contacts.size() != (2 if group.name == "Same-class clash" else 1):
			errors.append(group.name)
		contacts.append_array(group.contacts)
	if not _bot_done() or cases.size() != 12 or contacts.size() != EXPECT.size():
		errors.append("incomplete schedule")
	for i in mini(contacts.size(), EXPECT.size()):
		var c: Dictionary = contacts[i]
		var e: Array = EXPECT[i]
		var res: Dictionary = c.result
		var ok: bool = c.name == e[0] and res.contact == e[1] and res.stop == e[2]
		ok = ok and res.attacker == e[3] and res.attacker_frames == e[4]
		ok = ok and res.defender == e[5] and res.defender_frames == e[6]
		for side in 2:
			var stun: String = e[3 + side * 2]
			var count: int = e[4 + side * 2]
			for t in 2:
				var sample: Dictionary = c["call" if t == 0 else "next"][side]
				ok = ok and sample.stop == int(e[2]) - t and sample.stun == stun and sample.left == count
			ok = ok and c.max_busy[side] >= int(e[2]) + count
		ok = ok and c.min_centres >= radius - 0.001
		if i == 3:
			ok = ok and c.travel[0] > 0.1
		if i == 11:
			ok = ok and c.splat.get("frame", -1) == c.frame
		elif i == 12:
			ok = ok and c.splat.get("frame", -1) > int(c.frame) + int(e[2])
			ok = ok and c.splat.get("stop", 0) == 8 and c.splat.get("left", 0) == 40
			ok = ok and absf(c.splat.get("wall_gap", 1.0)) < 0.02
		else:
			ok = ok and c.splat.is_empty()
		if not ok:
			errors.append(e[0])
	return {"ok": errors.is_empty(), "summary": "checked %d contacts" % contacts.size(), "failed_cases": errors,
		"case_count": cases.size(), "contact_count": contacts.size(), "cases": cases,
		"radii_sum": radius, "pose_digest": state.get("pose_digest", 0)}
