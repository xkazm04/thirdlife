extends RefCounted
## What the player sees and hears: the HUD (health, stamina and posture bars, rounds, clock, the rival's name and line),
## banners for the big moments (PARRY, GUARD BREAK, WALL SPLAT, CLASH, COUNTER, K.O.), the charged heavy's red flash,
## cues that teach in the first round, effects, sounds and shake, and the cameras. Drawing only: nothing here is read
## by the rules or the state hash.

const BAR: int = 16

var g
var hud: TLHud
var banner_left: int = 0
var cue_left: int = 0
var hint_left: int = 0
var rally_told: bool = false             ## RALLY explained once a match (round 8)
var tag_left: int = 0                   ## frames the tag over the rival still shows
var tag_st: String = ""                 ## the state the tag lasts through ("" = by time)
var cam_pos: Vector3 = Vector3.ZERO
var cam_look: Vector3 = Vector3.ZERO
var views: Array = [&"duel", &"side", &"arena"]
var view_i: int = 0
var side_sign: float = 1.0
var flames: Array = []                 ## [node, frames left]
var ko_left: int = 0                    ## frames the KO camera still holds
var ko_body = null                     ## the fighter who fell
var ko_prev: StringName = &"duel"


func setup(main) -> void:
	g = main
	hud = TLHud.create()
	g.ctx.root.add_child(hud)
	hud.font_size = 21
	hud.add_label(&"you", "", &"top_left")
	hud.add_label(&"rival", "", &"top_right")
	hud.set_align(&"rival", &"right")
	hud.add_label(&"round", "", &"top")
	hud.set_align(&"round", &"center")
	hud.font_size = 44
	hud.add_label(&"banner", "", &"center")
	hud.font_size = 20
	hud.set_align(&"banner", &"center")
	hud.set_plate(&"banner", true)               # a coloured word on the sand needs its plate (round 7)
	hud.font_size = 30                          # the cue teaches: it must read at a glance (round 1 of N2's loop)
	hud.add_label(&"cue", "", &"bottom")
	hud.set_align(&"cue", &"center")
	hud.set_plate(&"cue", true)
	hud.font_size = 26
	hud.add_tag(&"tag", g.rival.body, "", Vector3(0, 2.45, 0))   # what he is about to do, over his head (E4)
	hud.set_plate(&"tag", true)
	hud.font_size = 20
	hud.add_label(&"keys", "", &"bottom")
	hud.set_align(&"keys", &"center")
	for id: StringName in [&"you", &"rival", &"round"]:
		hud.set_plate(id, true)
	var c: Dictionary = g.tune["camera"]
	g.ctx.cameras.add_view(&"duel", Vector3(0, 3, 9), Vector3(0, 1, 0), float(c["fov"]))
	g.ctx.cameras.add_view(&"side", Vector3(8, 2, 0), Vector3(0, 1, 0), 50.0)
	g.ctx.cameras.add_view(&"arena", Vector3(0, 15, 15), Vector3(0, 0, 0), 55.0)
	g.ctx.cameras.add_view(&"ko", Vector3(4, 1.2, 0), Vector3(0, 0.7, 0), 44.0)
	g.ctx.cameras.activate(&"duel")
	hint_left = int(g.tune["hand_hint"]) if g.tune.has("hand_hint") else 1500


func bar(v: float, top: float) -> String:
	var n: int = clampi(roundi(v / maxf(top, 1.0) * BAR), 0, BAR)
	return "█".repeat(n) + "░".repeat(BAR - n)


func _side(f, title: String) -> String:
	var tags: String = ""
	if f.exhausted:
		tags += "  EXHAUSTED"
	if f.rally():
		tags += "  RALLY"
	if f.st == "BROKEN":
		tags += "  BROKEN"
	return "%s%s\nHP %s %d\nST %s\nPO %s%s" % [title, tags, bar(f.hp, f.hp_max), ceili(f.hp), bar(f.stamina, 100.0),
		bar(f.posture, 100.0), "  ★%d" % f.stars if f.stars > 0 else ""]


func _pips(n: int) -> String:
	return "●".repeat(n) + "○".repeat(maxi(0, int(g.tune["rules"]["score_to_win"]) - n))


## Colours carry the meaning (E3): red is a threat you cannot block, gold a win of timing (a parry), the accent a
## call to act; "" is the theme's paper.
func banner(text: String, frames: int = 50, color: String = "") -> void:
	hud.set_text(&"banner", text)
	hud.set_color(&"banner", color)
	banner_left = frames


func cue(text: String, frames: int = 100, color: String = "") -> void:
	hud.set_text(&"cue", text)
	hud.set_color(&"cue", color)
	cue_left = frames


## A word over the rival's head while he does it (For Honor's indicator sits on the attacker): HEAVY, BASH, the red
## UNBLOCKABLE, OPEN in the Wall's breath. Kept through `st` (his state) or for `frames`.
func tag(text: String, color: String, frames: int, st: String = "") -> void:
	if g.rival == null or g.rival.body == null:
		return
	hud.add_tag(&"tag", g.rival.body, text, Vector3(0, 2.45, 0))
	hud.set_color(&"tag", color)
	tag_left = frames
	tag_st = st


func _tag_tick() -> void:
	if tag_left <= 0:
		return
	tag_left -= 1
	if tag_left == 0 or (tag_st != "" and g.rival.st != tag_st and g.rival.st != "ACTIVE"):
		tag_left = 0
		hud.set_text(&"tag", "")


## Every frame (also in a hit-stop): the HUD and the camera.
func tick() -> void:
	var you = g.you
	var rv = g.rival
	hud.set_text(&"you", _side(you, "YOU"))
	hud.set_text(&"rival", _side(rv, rv.name))
	var w: Dictionary = g.wins
	var time_text: String = g.round_rules.clock_text() if g.round_rules != null else ""
	hud.set_text(&"round", "ROUND %d   %s  %s  %s   %s
CROWD %s" % [g.round_no, _pips(int(w["you"])), time_text,
		_pips(int(w["rival"])), g.rung_name(), "▮".repeat(clampi(int(g.crowd_level), 0, 12))])
	if banner_left > 0:
		banner_left -= 1
		if banner_left == 0:
			hud.set_text(&"banner", "")
	if cue_left > 0:
		cue_left -= 1
		if cue_left == 0:
			hud.set_text(&"cue", "")
	if hint_left > 0:
		hint_left -= 1
		hud.set_text(&"keys", "WASD move    LMB / J light    RMB / K heavy (hold = unblockable)    SPACE block (tap = parry)    SHIFT roll    E bash" if hint_left > 0 else "")
	_glint(rv)
	_tag_tick()
	if not rally_told and g.phase == "fight" and you.rally():
		rally_told = true                       # the HUD word RALLY, told the first time it is yours
		cue("RALLY: under 35 % health your stamina comes back faster. Press him!", 120, "yellow")
	for i in range(flames.size() - 1, -1, -1):
		flames[i][1] -= 1
		if flames[i][1] <= 0:
			if is_instance_valid(flames[i][0]):
				(flames[i][0] as Node).queue_free()
			flames.remove_at(i)
	_camera()
	_ko_camera()


## The glint (Sekiro's, For Honor's indicator): a flash on the rival's weapon 16 frames before a light or heavy lands,
## the moment a person who reacts to it (about 15 frames) presses block in time to parry. Drawing only.
func _glint(rv) -> void:
	if rv.st != "WINDUP" or not (rv.mv in ["light", "heavy"]) or rv.windup - rv.mf != 16 or rv.tip == null or g.feel.stop_left(rv) > 0:
		return
	var root: Node3D = g.ctx.root
	TLVfx.burst(&"goal_flash", rv.tip.global_position, root, {"scale": 0.35, "color": Color(1.0, 1.0, 0.92)})
	TLVfx.burst(&"sparks", rv.tip.global_position, root, {"scale": 0.6, "color": Color(1.0, 1.0, 0.9)})
	TLAudio.play(&"beep", root.to_global(rv.pos()), -10.0)


func next_view() -> void:
	view_i = (view_i + 1) % views.size()
	g.ctx.cameras.activate(views[view_i])


func _camera() -> void:
	var c: Dictionary = g.tune["camera"]
	var p: Vector3 = g.you.pos()
	var r: Vector3 = g.rival.pos()
	var fwd: Vector3 = Vector3(r.x - p.x, 0.0, r.z - p.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	# a two-shot (round 2 of N2's loop): the camera stands `angle` degrees off the line between the duellists, behind your
	# right shoulder, far enough back that both bodies, the gap between them and his wind-up are always on screen (the
	# old over-the-shoulder view put your head over his weapon in half the frames)
	var gap: float = Vector2(r.x - p.x, r.z - p.z).length()
	var a: float = deg_to_rad(float(c["angle"]))
	var back_dir: Vector3 = -fwd * cos(a) + right * sin(a)
	var pivot: Vector3 = p.lerp(r, float(c["look_at"]))
	var want: Vector3 = pivot + back_dir * (float(c["dist"]) + gap * float(c["dist_k"])) + Vector3.UP * float(c["up"])
	var flat: float = Vector2(want.x, want.z).length()
	if flat > float(c["max_r"]):                    # never over the stands or into the banners (round 9): pull in, look down steeper
		var over: float = flat - float(c["max_r"])
		want = Vector3(want.x * float(c["max_r"]) / flat, want.y + over * float(c["rise_k"]), want.z * float(c["max_r"]) / flat)
	var look: Vector3 = pivot + Vector3.UP * float(c["look_up"])
	var k: float = float(c["follow"])
	if cam_pos == Vector3.ZERO:
		cam_pos = want
		cam_look = look
	cam_pos = cam_pos.lerp(want, k)
	cam_look = cam_look.lerp(look, k)
	var root: Node3D = g.ctx.root
	g.ctx.cameras.add_view(&"duel", root.to_global(cam_pos), root.to_global(cam_look), float(c["fov"]))
	var mid: Vector3 = p.lerp(r, 0.5)
	var off: Vector3 = right * (4.2 + gap * 0.7) * side_sign
	if (mid + off).length() > (mid - off).length() + 2.5:
		side_sign = -side_sign                       # the side that looks out of the ring, so the wall never cuts the view
		off = -off
	var side_pos: Vector3 = mid + off + Vector3.UP * 1.6
	if Vector2(side_pos.x, side_pos.z).length() > 7.6:
		var k2: float = 7.6 / Vector2(side_pos.x, side_pos.z).length()
		side_pos = Vector3(side_pos.x * k2, side_pos.y + 0.8, side_pos.z * k2)
	g.ctx.cameras.add_view(&"side", root.to_global(side_pos), root.to_global(mid + Vector3.UP * 1.05), 48.0)


func snap_camera() -> void:
	cam_pos = Vector3.ZERO
	if ko_left > 0 or g.ctx.cameras.active == g.ctx.cameras.view(&"ko"):
		ko_left = 0
		g.ctx.cameras.activate(ko_prev)


## The blow that ends a round lands like one (plays-twice items 19 and 28): the longest hit-stop, then a low camera cut
## beside the fallen fighter, the winner over him, dust where he hits the sand, the crowd's roar; back to the play view
## when the next round starts.
func ko_moment(loser) -> void:
	var c: Dictionary = g.tune["ko"]
	if int(c["frames"]) <= 0:
		return                                        # (tuning: the KO moment off, as before round 5)
	ko_body = loser
	ko_left = int(c["frames"])
	ko_prev = views[view_i]
	g.ctx.cameras.activate(&"ko")
	TLAudio.play(&"cheer")
	TLAudio.play(&"horn", g.ctx.root.to_global(loser.pos()), 2.0)


func _ko_camera() -> void:
	if ko_left <= 0 or ko_body == null:
		return
	ko_left -= 1
	var c: Dictionary = g.tune["ko"]
	var l: Vector3 = ko_body.pos()
	var w: Vector3 = ko_body.foe.pos()
	var line: Vector3 = Vector3(w.x - l.x, 0.0, w.z - l.z)
	line = line.normalized() if line.length() > 0.01 else Vector3(0, 0, -1)
	var side := Vector3(-line.z, 0.0, line.x)
	if (l + side * 3.0).length() > (l - side * 3.0).length():
		side = -side                                  # look out of the ring, never into the wall
	var at: Vector3 = l - line * 0.6 + side * float(c["dist"]) + Vector3.UP * float(c["up"])
	var look: Vector3 = l.lerp(w, 0.45) + Vector3.UP * float(c["look_up"])
	var root: Node3D = g.ctx.root
	g.ctx.cameras.add_view(&"ko", root.to_global(at), root.to_global(look), 44.0)
	if ko_left == int(c["frames"]) - 24:              # he meets the sand
		TLVfx.burst(&"dust", root.to_global(l), root, {"scale": 2.2})
		g.ctx.cameras.shake(0.12, 12)


## The tick's events from both fighters: juice and cues.
func on_event(f, e: Array) -> void:
	var name: String = str(e[0])
	var data = e[1]
	var root: Node3D = g.ctx.root
	var mid: Vector3 = f.pos().lerp(f.foe.pos(), 0.5) + Vector3.UP * 1.3
	var is_you: bool = f.id == "you"
	match name:
		"hit":
			var big: bool = str(data["mv"]) != "light"
			TLVfx.burst(&"sparks", root.to_global(f.foe.pos() + Vector3.UP * 1.3), root, {"scale": 1.4 if big else 0.9})
			TLAudio.play(&"hit_metal", root.to_global(mid), 2.0 if big else -2.0)
			g.ctx.cameras.shake(0.14 if big else 0.06, 12 if big else 8)
			var kind: String = str(data["kind"])
			if kind.begins_with("finisher"):
				banner("FINISHER!", 60)
			elif kind.begins_with("knockdown"):
				banner("KNOCKDOWN", 50)
			elif bool(data["counter"]) and is_you:
				banner("COUNTER!", 40)
			if kind == "ko":
				banner("K.O.", 120)
				TLAudio.play(&"cheer")
		"blocked":
			TLVfx.burst(&"sparks", root.to_global(f.pos() + f.forward() * 0.4 + Vector3.UP * 1.3), root, {"scale": 0.6, "color": Color(1, 1, 0.85)})
			TLAudio.play(&"hit_metal", root.to_global(mid), -6.0)
			if is_you and bool(data["heavy"]) == false:
				pass
			if not is_you and bool(data["heavy"]) and g.round_no == 1:
				cue("You hit his guard with a heavy: he bounces off - get out or block.")
			if is_you and bool(data["heavy"]) and g.round_no <= 2:
				cue("You blocked his HEAVY: he is open - LIGHT now!")
		"parry":
			TLVfx.burst(&"goal_flash", root.to_global(mid), root, {"color": Color(1.0, 0.85, 0.3), "scale": 0.8})
			TLAudio.play(&"hit_metal", root.to_global(mid), 4.0)
			g.ctx.cameras.shake(0.1, 10)
			banner("PARRY!" if is_you else "PARRIED", 45, "yellow" if is_you else "hazard_red")
			if is_you:
				cue("Parried his light: a HEAVY is guaranteed." if str(data["mv"]) == "light_parried" else "Parried his heavy: a LIGHT is guaranteed.", 90)
		"clash":
			TLVfx.burst(&"sparks", root.to_global(mid), root, {"scale": 2.0, "color": Color(1.0, 0.95, 0.7)})
			TLAudio.play(&"hit_metal", root.to_global(mid), 6.0)
			g.ctx.cameras.shake(0.12, 12)
			banner("CLASH!", 40)
		"guardbreak":
			TLVfx.burst(&"dust", root.to_global(f.foe.pos() + Vector3.UP * 0.2), root, {"scale": 1.0})
			TLAudio.play(&"hit_wood", root.to_global(mid), 2.0)
			g.ctx.cameras.shake(0.1, 10)
			if is_you:
				banner("GUARD BREAK!", 40)
		"splat":
			var at: Vector3 = f.foe.pos() + (f.foe.pos() - f.pos()).normalized() * 0.4 + Vector3.UP * 1.0
			TLVfx.burst(&"debris", root.to_global(at), root, {"scale": 1.2})
			TLVfx.burst(&"dust", root.to_global(at), root, {"scale": 1.6})
			TLAudio.play(&"hit_stone", root.to_global(at), 6.0)
			g.ctx.cameras.shake(0.26, 18)
			banner("WALL SPLAT!", 55)
			TLAudio.play(&"cheer")
		"charged_flash":
			var hand = f.rig.socket(&"hand_r") if f.rig != null else null
			if hand != null:
				TLVfx.burst(&"goal_flash", hand.global_position, root, {"scale": 0.7, "color": Color(1.0, 0.12, 0.08)})
				TLVfx.burst(&"sparks", hand.global_position, root, {"scale": 2.2, "color": Color(1.0, 0.15, 0.1)})
				g.feel.trail(f, 1.0, f.windup - f.mf + f.active + 10, "hazard_red", 0.42)   # the unblockable's arc is drawn red
				var fl: Node3D = TLVfx.attach(&"nitro_flame", hand, {"color": Color(1.0, 0.2, 0.1), "scale": 0.6})
				if fl != null:
					flames.append([fl, f.windup - f.mf + 6])
			TLAudio.play(&"horn", root.to_global(f.pos()), -4.0)
			if not is_you:
				cue("RED = UNBLOCKABLE: roll, or hit him first.", 80, "hazard_red")
				tag("UNBLOCKABLE", "hazard_red", f.windup - f.mf + 4, "WINDUP")
		"phase2":
			banner("%s ROARS" % f.name, 70, "hazard_red")
			TLAudio.play(&"horn", root.to_global(f.pos()), 4.0)
			TLVfx.burst(&"dust", root.to_global(f.pos()), root, {"scale": 2.0})
			g.ctx.cameras.shake(0.18, 20)
			if str(data) != "":
				cue(str(data), 150)
		"breathe":
			if not is_you and not bool(f.cfg["rhythm"].get("breath_counters", false)):
				tag("OPEN", "flag_b", 90)               # the Wall's breath: he only weathers it (rivals.json rhythm)
		"tell":
			TLVfx.burst(&"sparks", root.to_global(f.pos() + Vector3.UP * 1.9), root, {"scale": 0.7, "color": Color(0.6, 0.9, 1.0)})
			TLAudio.play(&"beep", root.to_global(f.pos()), -6.0)
		"star":
			banner("★ STAR!", 40)
			TLAudio.play(&"cheer")
		"broken":
			banner("POSTURE BROKEN" if f.id != "you" else "YOUR GUARD IS BROKEN", 50, "yellow" if f.id != "you" else "hazard_red")
			if f.id != "you":
				cue("He is BROKEN: a HEAVY now is a finisher.", 90)
		"exhausted":
			if is_you:
				cue("Out of stamina: you are slow, a bash floors you. Back off.", 90)
		"evade":
			TLVfx.burst(&"dust", root.to_global(f.pos()), root, {"scale": 0.7})
		"whiff":
			if not is_you and g.round_no == 1 and g.rung <= 0:
				cue("He missed: hit him while he recovers.", 70)
		"windup":
			if str(data) != "bash":                       # the blade's arc by weight: a light is a thin quick flick, a heavy a broad slow sweep
				g.feel.trail(f, 0.0 if str(data) == "light" else 1.0, f.windup + f.active + 10)
			if not is_you and str(data) == "heavy":
				tag("HEAVY", "yellow", f.windup + 4, "WINDUP")
			elif not is_you and str(data) == "bash":
				tag("BASH", "orange", f.windup + 4, "WINDUP")
			if not is_you and str(data) == "bash" and g.round_no == 1:
				cue("Shoulder dip = BASH coming: roll or hit him first.", 60)
