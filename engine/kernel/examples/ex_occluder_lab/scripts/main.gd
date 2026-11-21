extends Node
## The walker pauses behind the post. Both stills use the same pose, camera,
## and geometry. At frame 96 the play camera begins its standard eight-tick fade.
const FADE_AT := 96
var ctx
var walker: TLBiped
var pillar: PhysicsBody3D
var mesh: GeometryInstance3D
var windows := {}
var done := false


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLBodies.ground(Vector2(12, 9), "concrete"))
	pillar = TLBodies.make(&"box", Vector3(1.2, 2.9, 0.8), "concrete",
		{"name": "Pillar", "position": Vector3(0, 1.45, 1.8)})
	ctx.root.add_child(pillar)
	mesh = pillar.find_children("*", "GeometryInstance3D", true, false)[0]
	walker = TLBiped.create({"name": "Walker", "position": Vector3(-2.45, 0.01, 0),
		"mode": "walk", "rig_params": {"backpack": false, "colors": {"top": "car_red", "legs": "bot_dark"}}})
	ctx.root.add_child(walker)
	ctx.cameras.add_view(&"play", Vector3(0, 1.65, 7), Vector3(0, 1.15, 0), 34.0)
	ctx.cameras.set_subject(&"play", walker)


func _pack_start() -> void:
	ctx.cameras.fade_occluders(false)


func _pack_tick(frame: int) -> void:
	if done:
		return
	walker.move(Vector3.RIGHT if frame < 64 or (frame >= 130 and frame < 198) else Vector3.ZERO)
	if frame == FADE_AT:
		ctx.cameras.fade_occluders(true)
	if frame in range(80, 91):
		_sample("behind_off")
	elif frame in range(110, 121):
		_sample("behind_on")
	elif frame in range(200, 211):
		_sample("clear_on")
	done = frame >= 211


func _sample(key: String) -> void:
	var blockers: Array = ctx.cameras.faded()
	if not windows.has(key):
		windows[key] = {"samples": 0, "min_count": blockers.size(), "max_count": blockers.size(),
			"pillar_samples": 0, "min_alpha_loss": mesh.transparency, "max_alpha_loss": mesh.transparency,
			"min_x": walker.position.x, "max_x": walker.position.x}
	var s: Dictionary = windows[key]
	s.samples += 1
	s.min_count = mini(s.min_count, blockers.size())
	s.max_count = maxi(s.max_count, blockers.size())
	s.pillar_samples += int(blockers.has(pillar))
	s.min_alpha_loss = minf(s.min_alpha_loss, mesh.transparency)
	s.max_alpha_loss = maxf(s.max_alpha_loss, mesh.transparency)
	s.min_x = minf(s.min_x, walker.position.x)
	s.max_x = maxf(s.max_x, walker.position.x)


func _pack_state() -> Dictionary:
	return {"done": done, "windows": windows}
