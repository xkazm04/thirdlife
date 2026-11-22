extends RefCounted
## Poke windows and recovery use the same frame clock as puck possession.

var rng: RandomNumberGenerator
var actions := {}
var ready := {}
var whiff_until := {}

func reset() -> void:
	actions.clear()
	ready.clear()
	whiff_until.clear()

func eligible(a, id: String) -> bool:
	var vic: String = a.carrier
	return vic != "" and not a.goalies.has(vic) and not a.goalies.has(id) and a.teams[id] != a.teams[vic] \
		and a.hits.can_act(id) and a.can_strip(id, vic)

func in_cone(a, id: String) -> bool:
	var to: Vector3 = a.puck_pos() - a.pos_of(id)
	return to.length_squared() <= a.poke_reach * a.poke_reach and a.stick_of(id).dot(to) >= a.poke_cone_dot * to.length()

func odds(a, id: String) -> float:
	if not eligible(a, id) or not in_cone(a, id):
		return 0.0
	var c: Dictionary = a.carry.c
	var toward: Vector3 = a.pos_of(id) - a.pos_of(a.carrier)
	var angle: float = rad_to_deg(a.fwd_of(a.carrier).angle_to(toward))
	var factor: float = c.poke_front if angle <= c.poke_front_deg else (c.poke_back if angle > c.poke_back_deg else c.poke_side)
	return c.poke_chance * factor * (float(c.poke_cut_mult) if a.carry.cut else 1.0)

func start(a, id: String) -> bool:
	if a._now < int(ready.get(id, 0)) or not eligible(a, id):
		return false
	actions[id] = {"start": a._now, "target": a.carrier, "since": a.carry_since, "resolved": false}
	ready[id] = a._now + int(a.carry.c.poke_cooldown_frames)
	a.poke_tries[id] += 1
	a.events.append(["poke_try", id])
	if not a.headless:
		var rig = a.skaters[id].rig
		if rig != null:
			a._clip(id, &"poke" if rig.clips().has("poke") else &"pass")
	return true

func tick(a) -> void:
	var c: Dictionary = a.carry.c
	for id: String in actions.keys():
		var act: Dictionary = actions[id]
		var age: int = a._now - int(act.start)
		if age >= int(c.poke_frames):
			actions.erase(id)
			continue
		if act.resolved or age < int(c.poke_first):
			continue
		var p := 0.0
		if age <= int(c.poke_last) and a.carrier == act.target and a.carry_since == act.since:
			p = odds(a, id)
		if p == 0.0 and age < int(c.poke_last):
			continue
		act.resolved = true
		if p > 0.0 and rng.randf() < p:
			var vel: Vector3 = a.stick_of(id) * float(c.poke_speed) + a.carry.velocity(a, a.carrier) * float(c.poke_carry_share)
			a._release("poked", a.carrier, vel)
			a.pokes[id] += 1
			a.events.append(["poke", id])
		else:
			whiff_until[id] = a._now + int(c.whiff_frames)
			a.events.append(["whiff", id])
