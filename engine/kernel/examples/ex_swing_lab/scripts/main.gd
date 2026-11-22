extends Node

const PERIOD := 75
const SWING := 12
const NOTES := ["Light swing", "Heavy swing", "Heavy swing into guard"]

var ctx
var swinger: TLBiped
var rival: TLBiped
var hud: TLHud
var trail: Node3D
var started := -1
var lifetimes: Array[int] = []
var freeze := 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(20, 16), "concrete"))
	swinger = _fighter("Swinger", -0.85, -PI / 2, "car_red", true)
	rival = _fighter("Guard", 0.95, PI / 2, "car_blue", false)
	ctx.cameras.add_view(&"play", Vector3(1.7, 2.8, 6.1), Vector3(0, 1.22, 0), 32)
	ctx.cameras.set_subject(&"play", swinger)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.font_size = 30
	hud.add_tag(&"tag", swinger.rig.socket(&"head"), "", Vector3(0, 0.18, 0))
	hud.set_color(&"tag", &"car_red")
	hud.set_plate(&"tag")
	hud.add_label(&"move", "", &"bottom")
	hud.set_plate(&"move")
	hud.set_color(&"move", Color("#ffe6a0"))


func _fighter(id: String, x: float, yaw: float, shirt: String, stick: bool) -> TLBiped:
	var b := TLBiped.create({"name": id, "position": Vector3(x, 0.01, 0), "facing": yaw,
		"rig_params": {"stick": stick, "backpack": false, "colors": {"top": shirt, "legs": "bot_dark"}}})
	ctx.root.add_child(b)
	return b


func _pack_start() -> void:
	pass


func _pack_tick(frame: int) -> void:
	if started >= 0 and not is_instance_valid(trail):
		lifetimes.append(frame - started)
		started = -1
	var take := floori(frame / float(PERIOD)) % 3
	var beat := frame % PERIOD
	if beat == 0:
		if take == 0:
			lifetimes.clear()
			freeze = 0
			swinger.place(Vector3(-0.85, 0.01, 0), -PI / 2)
			rival.place(Vector3(0.95, 0.01, 0), PI / 2)
		hud.set_text(&"tag", "LIGHT" if take == 0 else "HEAVY")
		hud.set_text(&"move", NOTES[take])
	if beat == SWING:
		started = frame
		if take == 0:
			swinger.play_clip(&"strike")
			trail = TLHit.swing_trail(swinger, 0.0, 20)
		else:
			# Give the chop enough samples to see the tip turn through its arc.
			swinger.play_clip(&"strike_heavy", [[0, 0], [9, 9], [24, 15], [39, 30]])
			trail = TLHit.swing_trail(swinger, 1.0, 40)
	if take == 2 and beat == SWING + 20:
		TLHit.blocked(swinger, rival, true)
	if TLHit.stop_left(swinger) > 0:
		freeze += 1


func _pack_state() -> Dictionary:
	var tag := hud.get_node("tag") as Label
	var state := {"trail_alive": is_instance_valid(trail), "lifetimes": lifetimes.duplicate(), "freeze": freeze,
		"tag_text": hud.text_of(&"tag"), "tag_color": tag.get_theme_color("font_color").to_html(false)}
	if not ctx.headless:
		state["tag_visible"] = tag.is_visible_in_tree()
		state["tag_xy"] = [tag.position.x, tag.position.y]
	return state
