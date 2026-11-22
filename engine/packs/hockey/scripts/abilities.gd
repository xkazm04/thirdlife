## Created by the hockey pack to resolve abilities in physics-frame order. Legacy modes leave the hooks idle.
extends RefCounted
var on := false
var boosts
var kinds := {}
var slots := {}
var used := {}
var flight := {}
var excepted: Array[TLBiped] = []
var hot_slug: Node3D
var hot_trail: Node3D
var drill_actions := {}
var fallen_goalies := {}
var shotgun_downs := 0
var hip_checks := 0
var now := 0
var hud_text := ""
var hud_bound := false
var game_ref: WeakRef

## Load the package catalogue. A legacy match registers no ability or drill controls.
func setup_pack(g) -> void:
	game_ref = weakref(g)
	boosts = g.ctx.load_script("scripts/boosts.gd").new()
	boosts.setup(g)

## Reset this match and equip each outfield skater with the selected mode's starting ability.
func build(g, mode: Dictionary) -> void:
	var was_on := on
	if on:
		end_flight(g)
		boosts.reset_puck(g)
		g.api.apply_speeds()
	on = mode.has("pickups") or mode.has("abilities")
	if on != was_on:
		g.ctx.input.declare(&"ability", [KEY_F] if on else [])
	fallen_goalies.clear()
	slots.clear()
	kinds.clear()
	used.clear()
	shotgun_downs = 0
	hip_checks = 0
	hud_text = ""
	hud_bound = false
	if not on:
		return
	if drill_actions.is_empty():
		for id in boosts.drills:
			var action := StringName("crazy_" + id)
			g.ctx.input.declare(action, [])
			drill_actions[action] = boosts.drills[id]
	now = g.ctx.frame
	boosts.build(g, mode)
	for rule: Dictionary in mode.get("abilities",[]):
		kinds[rule.kind] = rule
	for id in g.order:
		if g.api.goalies.has(id):
			continue
		slots[id] = {}
		for k in kinds:
			if kinds[k].trigger == "mode":
				grant(id,k)

## End loose-puck modifiers at the drop. Packages still on the ice remain available.
func faceoff(g) -> void:
	if on:
		end_flight(g)
		boosts.reset_puck(g)

## A skater may collect a timed boost with a full slot. An ability needs a free slot.
func accepts(id: String, kind: String) -> bool:
	if not kind in ["shotgun","shield","hip_check","slow_puck"]:
		return true
	if not kinds.has(kind) or kinds[kind].trigger != "pickup":
		return false
	var slot: Dictionary = slots[id]
	return not (slot.has("held") or slot.has("armed") or slot.has("shield_until"))

## Fill a slot from the mode rule, including an optional finite charge count.
func grant(id: String, kind: String) -> void:
	if not slots.has(id) or not kinds.has(kind):
		return
	var slot: Dictionary = slots[id]
	slot.held = kind
	slot.ready = now
	if kinds[kind].has("charges") or kinds[kind].trigger == "pickup":
		slot.charges = int(kinds[kind].get("charges",1))

## Only the F action can spend an ability. Return whether it consumed the check press.
func use_key(g) -> bool:
	return on and g.ctx.input.just_pressed(&"ability") and activate(g,"b0")

## Spend the charge, then start a shield or wait for the specified release or contact.
func activate(g, id: String) -> bool:
	var slot: Dictionary = slots[id]
	if not slot.has("held") or slot.has("armed") or slot.has("shield_until") or now < int(slot.ready) or not g.hits.can_act(id):
		return false
	var k: String = slot.held
	if k == "hip_check" and not g.hits.enabled:
		return false
	slot.ready = now + int(kinds[k].get("cooldown_frames",1200))
	if slot.has("charges"):
		slot.charges -= 1
		if slot.charges <= 0:
			slot.erase("charges")
			slot.erase("held")
			slot.erase("ready")
	if k == "shield":
		slot.shield_until = now + duration(k)
		g.hits.immune[id] = true
	else:
		slot.armed = k
		if k == "hip_check":
			slot.arm_until = now + duration(k)
	used[k] = int(used.get(k,0)) + 1
	return true

## Use a mode's duration override or the catalogue's physics-frame duration.
func duration(k: String) -> int:
	return int(kinds[k].get("duration_frames",boosts.effects[k].frames))

## Use a mode's strength override or the catalogue value.
func magnitude(k: String) -> float:
	return float(kinds[k].get("magnitude",boosts.effects[k].magnitude))

## Remove flight-only collision exceptions, the trail and the speed-limit multiplier.
func end_flight(g) -> void:
	if is_instance_valid(hot_slug):
		hot_slug.queue_free()
		hot_slug = null
	if is_instance_valid(hot_trail):
		hot_trail.queue_free()
		hot_trail = null
	for sk in excepted:
		g.puck.remove_collision_exception_with(sk)
	excepted.clear()
	flight.clear()
	boosts.speed_cap(g,1.0)

## Resolve expiries, packages and swept hits before the keeper or a stick can take the puck.
func pre(g) -> void:
	if not on:
		return
	now = g.ctx.frame
	for id in slots:
		var slot: Dictionary = slots[id]
		if slot.has("shield_until") and now >= int(slot.shield_until):
			slot.erase("shield_until")
			g.hits.immune.erase(id)
		if slot.has("arm_until") and now >= int(slot.arm_until):
			slot.erase("armed")
			slot.erase("arm_until")
	for team in fallen_goalies.keys():
		var id: String = fallen_goalies[team]
		if not g.hits.is_down(id):
			g.keeper.ids[team] = id
			fallen_goalies.erase(team)
	boosts.tick(g,self)
	# The ordinary check or poke can dislodge the opposing carrier later in this tick.
	if g.drill_id == "":
		for id in slots:
			if slots[id].get("held") == "hip_check" and (id != "b0" or g.autopilot):
				bot(g,id)
				if slots[id].get("armed") == "hip_check":
					hip(g,id)
	boosts.speed_cap(g,magnitude("shotgun") if flight.get("kind") == "shotgun" else 1.0)
	if not flight.is_empty():
		step_flight(g)

## Wake a slow puck on expiry or floor standing skaters along the last shotgun step.
func step_flight(g) -> void:
	if g.api.carrier != "":
		end_flight(g)
		return
	if flight.kind == "slow_puck":
		if now >= int(flight.until):
			g.api.set_puck_velocity((g.puck.linear_velocity / magnitude("slow_puck")).limit_length(g.puck.max_speed))
			end_flight(g)
		return
	if now > int(flight.until):
		end_flight(g)
		return
	var cfg: Dictionary = boosts.effects.shotgun
	if g.puck.speed() < float(cfg.min_speed):
		end_flight(g)
		return
	if is_instance_valid(hot_slug):
		point_slug(g)
	for id in g.order:
		var sk: TLBiped = g.skaters[id]
		if id == flight.by or g.hits.immune.has(id) or sk.is_down():
			continue
		if g.api.dist_to_puck(id) > float(cfg.path_margin) + sk.body_radius():
			continue
		TLHit.down(sk,int(cfg.down_frames),-g.puck.linear_velocity.normalized())
		if not g.ctx.headless:
			var contact := sk.global_position + Vector3.UP
			burst(g, "ice_spray", contact, 3.8)
			burst(g, "debris", contact, 2.2)
			TLAudio.play("hit_wood", contact)
			if g.tune.fun.shake and sk.position.distance_to(g.skaters.b0.position) <= float(g.tune.fun.stop_radius):
				g.ctx.cameras.shake(float(g.tune.fun.shake_max), 14)
		g.api.knock_loose(id,g.puck.linear_velocity)
		if not excepted.has(sk):
			g.puck.add_collision_exception_with(sk)
			excepted.append(sk)
		if g.api.goalies.has(id):
			# A standing goalie is positioned by keeper.move. While down, let TLBiped run its fall and rise.
			var team: String = g.teams[id]
			g.keeper.ids.erase(team)
			fallen_goalies[team] = id
			sk.set_physics_process(true)
		shotgun_downs += 1
	if now == int(flight.until):
		end_flight(g)

## Notify the hockey FX hook and play the take or release cue at its world position.
func flash(g, event: String, pos: Vector3, id: String) -> void:
	g._event(event,pos,g.teams[id])
	TLAudio.play("nitro" if event == "shotgun" else "beep",pos)
	if not g.ctx.headless:
		if event == "shotgun":
			burst(g, "goal_flash", pos + Vector3.UP * 0.5, 2.8)
			burst(g, "sparks", pos + Vector3.UP * 0.5, 4.6)
		else:
			burst(g, "sparks", pos, 0.58)

## A local anchor puts the first interpolated frame at the blade or at the victim.
func burst(g, preset: String, pos: Vector3, scale_factor: float) -> void:
	var at := Node3D.new()
	at.position = g.arena.to_local(pos)
	g.arena.add_child(at)
	TLVfx.burst(preset, at.global_position, at, {"scale":scale_factor})
	at.child_exiting_tree.connect(func(_child): at.queue_free(), CONNECT_ONE_SHOT)

## Apply aim assistance and armed modifiers to the velocity set by this release.
func released(g, id: String, event: String) -> void:
	if not flight.is_empty():
		end_flight(g)
	if event == "shot":
		boosts.aim(g,id)
	var slot: Dictionary = slots.get(id,{})
	# A one-timer can take and release between the two hooks. Its release proves possession.
	if g.drill_id == "" and (id != "b0" or g.autopilot) and not slot.has("armed"):
		var held := str(slot.get("held",""))
		if held == "slow_puck" or (held == "shotgun" and event == "shot"):
			activate(g,id)
	var k := str(slot.get("armed",""))
	if k != "slow_puck" and not (k == "shotgun" and event == "shot"):
		return
	slot.erase("armed")
	flight = {"kind":k,"by":id,"until":now + duration(k)}
	g.api.set_puck_velocity(g.puck.linear_velocity * magnitude(k))
	if k == "shotgun":
		boosts.speed_cap(g,magnitude(k))
		flash(g,"shotgun",g.puck.global_position,id)
		if not g.ctx.headless:
			hot_slug = boosts.draw.slug(g.puck)
			point_slug(g)
			hot_trail = TLVfx.trail(g.puck, {"color":"tail_light","frames":23,"width":1.10,"offset":Vector3.UP * 0.4})

## Point the short ember along the current shot, including after a rebound.
func point_slug(g) -> void:
	var direction: Vector3 = g.puck.global_basis.inverse() * g.puck.linear_velocity
	hot_slug.quaternion = Quaternion(Vector3.RIGHT, direction.normalized())

## Land the armed check in the ordinary check cone, including at zero closing speed.
func hip(g, id: String) -> void:
	if not g.hits.can_act(id):
		return
	# L4 merge: the check reaches its gap beyond the two bodies (hits.gd target); the old 2 m/s loose push is the old tuning's
	var victim: String = g.hits.target(id, g.hits.check_gap, g.hits.check_cone_deg)
	if victim == "":
		return
	var sk: TLBiped = g.skaters[victim]
	var away: Vector3 = (g.api.pos_of(victim)-g.api.pos_of(id)).normalized()
	TLHit.down(sk,roundi(float(boosts.effects.hip_check.down_frames) * magnitude("hip_check")),-away)
	# On his edges the downed skater brakes linearly. Across them his slip decays geometrically.
	# Choose the two components of the impulse for the same travel at either angle.
	var travel: Vector3 = away * float(boosts.effects.hip_check.shove_m)
	var forward: Vector3 = g.api.fwd_of(victim)
	var along := travel.dot(forward)
	var friction := float(TLLaws.pair(sk.blade_material,"ice").friction)
	var brake := sk.skate_brake + 9.8 * friction
	var grip := sk.skate_lateral_grip + sk.skate_brake * 0.5
	var slide := (travel - forward * along) * grip / (1.0 - grip / 60.0)
	slide += forward * signf(along) * sqrt(2.0 * brake * absf(along))
	sk.shove((slide - Vector3(sk.velocity.x,0,sk.velocity.z)) * sk.body_mass)
	g.api.knock_loose(victim,away * 2.0)
	var rig = (g.skaters[id] as TLBiped).rig      # the hitter shows it: L2's body_check clip where the rig has it (RIGS.md)
	if rig != null and rig.has_method("clips") and (rig.clips() as PackedStringArray).has("body_check"):
		rig.play(&"body_check")
	slots[id].erase("armed")
	slots[id].erase("arm_until")
	hip_checks += 1
	g._event("hip_check",sk.global_position,g.teams[id])
	TLAudio.play("hit_wood",sk.global_position)

## Use each skater's loaded ability when the play meets its condition.
func bot(g, id: String) -> void:
	var slot: Dictionary = slots[id]
	var carrier: String = g.api.carrier
	match str(slot.get("held","")):
		"shotgun","slow_puck":
			if carrier == id:
				activate(g,id)
		"shield":
			if carrier == id:
				for other in g.order:
					if g.teams[id] != g.teams[other] and g.api.pos_of(id).distance_squared_to(g.api.pos_of(other)) <= 16:
						activate(g,id)
						break
		"hip_check":
			if carrier != "" and g.teams[id] != g.teams[carrier] and not g.api.goalies.has(carrier):
				var to: Vector3 = g.api.pos_of(carrier) - g.api.pos_of(id)
				if g.hits.target(id,g.hits.check_gap,g.hits.check_cone_deg) == carrier:
					activate(g,id)
				elif to.length_squared() <= 36.0 and g.hits.can_act(id):
					g.skate.want(id, to.normalized())

## Assign one nearby free bot per package while the closer puck chaser continues skating.
func chase_packages(g) -> void:
	# The closest off-puck bot can peel off for a nearby package. Leave the puck chaser on the play.
	var claimed := {}
	for e in boosts.packages:
		var nearest := ""
		# Take an isolated package in stride. A crowded wing is worth leaving the play for.
		var best := 2.5 if boosts.packages.size() < 3 else 8.0
		for id in slots:
			if id == g.api.carrier or (id == "b0" and not g.autopilot) or claimed.has(id) or not g.hits.can_act(id) or not accepts(id,e.kind):
				continue
			if slots[id].has("held") or slots[id].has("armed"):
				continue
			var p: Vector3 = boosts.local_pos(g,id)
			var d := p.distance_to(e.pos)
			if d < best and d + 1.25 < g.api.pos_of(id).distance_to(g.api.puck_pos()):
				best = d
				nearest = id
		if nearest != "":
			claimed[nearest] = true
			g.skate.want(nearest, (e.pos - boosts.local_pos(g,nearest)).normalized())

## Resolve releases, AI choices, speed modifiers and visible indicators after ordinary play.
func post(g) -> void:
	if not on:
		return
	if not g.frozen and g.rules.is_running():
		# An injected action names F alone. Physical F latches both actions and was handled by player_input.
		if not g.autopilot and not g.ctx.input.just_pressed(&"check") and g.ctx.input.just_pressed(&"ability"):
			activate(g,"b0")
		for e: Array in g.api.events:
			if e[0] == "take" and not flight.is_empty():
				end_flight(g)
			elif e[0] in ["shot","pass"]:
				released(g,e[1],e[0])
		for id in slots:
			if g.drill_id == "" and (id != "b0" or g.autopilot):
				bot(g,id)
			if slots[id].get("armed") == "hip_check":
				hip(g,id)
		if g.drill_id == "" and not boosts.packages.is_empty():
			chase_packages(g)
		for action: StringName in drill_actions:
			if g.ctx.input.just_pressed(action):
				start_drill(g,drill_actions[action])
	boosts.apply_speed(g)
	if not g.ctx.headless:
		boosts.render(g,slots)
		update_hud(g)

## Place the drill through the shared drill library, then supply its pickups and ability.
func start_drill(g, d: Dictionary) -> void:
	end_flight(g)
	g.drill_lib.start(g,d,now)
	if d.has("grant"):
		grant("b0",d.grant)
	for e in d.get("packages",[]):
		boosts.add(g,e.kind,Vector3(e.pos[0],0,e.pos[1]))

## Show the human's slot and timed effects. A plate exists only while it has text.
func update_hud(g) -> void:
	var rows := PackedStringArray()
	var slot: Dictionary = slots.b0
	var kind := str(slot.get("armed",slot.get("held","")))
	if slot.has("shield_until"):
		rows.append("F  SHIELD  %.1f s" % ((slot.shield_until-now)/60.0))
	elif kind != "":
		var status := "READY"
		if slot.has("armed"):
			status = {"shotgun":"NEXT SHOT","hip_check":"NEXT HIT","slow_puck":"NEXT PASS / SHOT"}[kind]
		elif int(slot.ready) > now:
			status = "%d s" % ceili((slot.ready-now)/60.0)
		rows.append("F  %s  %s" % [kind.replace("_"," ").to_upper(),status])
	var effects := PackedStringArray()
	for k in boosts.active.get("b0",{}):
		effects.append("%s %.1f s" % [k.to_upper(),(boosts.active.b0[k]-now)/60.0])
	if not effects.is_empty():
		rows.append("   ".join(effects))
	for k in boosts.puck_until:
		rows.append("%s %d s" % [k.replace("_"," ").to_upper(),ceili((boosts.puck_until[k]-now)/60.0)])
	var was := hud_text != ""
	hud_text = "\n".join(rows)
	if not hud_bound and hud_text != "":
		g.hud.add_bound(&"ability_slot", func() -> String: return hud_text, &"bottom_right")
		hud_bound = true
	if hud_bound and was != (hud_text != ""):
		g.hud.set_plate(&"ability_slot",hud_text != "")

## Expose deterministic counters and remaining frames. Positions are in rink coordinates.
func state() -> Dictionary:
	var g = game_ref.get_ref()
	var skaters := {}
	for id in slots:
		var s: Dictionary = slots[id].duplicate()
		if s.has("arm_until"):
			s["armed_frames"] = s.arm_until - now
			s.erase("arm_until")
		if s.has("shield_until"):
			s["shield_frames"] = s.shield_until - now
			s.erase("shield_until")
		if boosts.active.has(id):
			s["boosts"] = {}
			for k in boosts.active[id]:
				s.boosts[k] = boosts.active[id][k]-now
		if id == "b0" or boosts.active.get(id,{}).has("speed"):
			s["skate_speed"] = g.skaters[id].skate_speed
			s["skate_accel"] = g.skaters[id].skate_accel
		if not s.is_empty():
			skaters[id] = s
	var puck := {"radius":g.puck.radius,"max_speed":g.puck.max_speed}
	if boosts.puck_shape != null:
		puck["collision_radius"] = boosts.puck_shape.radius
	if g.puck.linear_damp > 0.0:
		puck["drag"] = g.puck.linear_damp
	for k in boosts.puck_until:
		puck[k] = boosts.puck_until[k]-now
	if not flight.is_empty():
		puck[flight.kind] = flight.until-now
		puck["by"] = flight.by
	var out := {"skaters":skaters,"puck":puck,"pickups":boosts.package_state(),"taken":boosts.taken.duplicate(),"used":used.duplicate()}
	if shotgun_downs > 0:
		out["shotgun_downs"] = shotgun_downs
	if hip_checks > 0:
		out["hip_checks"] = hip_checks
	var blocked := 0
	for count: int in g.hits.immune_blocks.values():
		blocked += count
	if blocked > 0:
		out["shield_blocks"] = blocked
	return out
