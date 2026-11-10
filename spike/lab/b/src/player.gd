class_name Player
extends Node3D
## Third-person avatar controller + chase camera. Camera-relative WASD (move_* actions), mouse orbit (cam_orbit):
## yaw free, pitch clamped to 30..60 degrees looking down, distance 5..8 m (mouse wheel). Walks on the terrain height.
## Hold Shift to run. Esc releases the mouse.

const WALK: float = 2.3
const RUN: float = 6.0

var terrain: Terrain
var model: Node3D
var ap: AnimationPlayer
var cam: Camera3D
var yaw: float = 0.0
var pitch: float = 34.0
var dist: float = 6.5
var active: bool = false
var facing: float = 0.0
var cur: String = ""
var auto_move: Vector3 = Vector3.ZERO   # scripted movement for the movie (world direction * speed)
var blockers: Array = []                 # {c: Vector2, r: float} from the world: the avatar slides around them
var test_mode: bool = false             # play_test: accept injected mouse motion without a captured cursor
const PITCH0: float = 34.0
const DIST0: float = 6.5
var force_anim: String = ""             # capture helper: hold one clip (--anim=walk)
const TEST_DEVICE: int = 77            # device id of mouse motion injected by the play test
var mood: float = 1.0                   # face parameter: 0 focused .. 1 happy (KitBiped.set_face)
var face_t: float = 0.0
var face_fixed: Vector2 = Vector2(-1, -1)   # capture helper: --face=<mood>,<blink> holds the face


func setup(t: Terrain, c: Camera3D) -> void:
	terrain = t
	cam = c
	model = KitBiped.build(true)
	add_child(model)
	ap = model.get_node("AnimationPlayer")
	position = Vector3(0, terrain.h(0, 0), 0)
	_play("idle")


func _play(n: String) -> void:
	if cur != n:
		cur = n
		ap.play(n, 0.18)


func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseMotion and InputMap.has_action("cam_orbit") and (test_mode or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		var mm: InputEventMouseMotion = ev
		# pass 4: the play test takes only its own injected motion (device TEST_DEVICE). Before this, the real pointer
		# crossing the test window added to the orbit and failed two assertions in one acceptance run.
		if test_mode and mm.device != TEST_DEVICE:
			return
		yaw -= mm.relative.x * 0.2
		pitch = clampf(pitch + mm.relative.y * 0.15, 30.0, 60.0)
	elif ev is InputEventMouseButton and ev.pressed:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(5.0, dist - 0.4)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(8.0, dist + 0.4)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventKey and ev.pressed and (ev as InputEventKey).physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	# face: blinks every 3.4 s; happy while standing with the tablet, focused while running
	face_t += dt
	var ph: float = fmod(face_t, 3.4)
	var blink: float = sin(ph / 0.14 * PI) if ph < 0.14 else 0.0
	mood = move_toward(mood, 0.0 if cur == "run" else 1.0, dt * 3.0)
	if face_fixed.x >= 0.0:
		KitBiped.set_face(model, face_fixed.x, face_fixed.y)
	else:
		KitBiped.set_face(model, mood, blink)
	var dir: Vector3 = Vector3.ZERO
	var speed: float = 0.0
	if active:
		var iv: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if iv.length() > 0.1:
			var yb: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
			dir = (yb * Vector3(iv.x, 0, iv.y)).normalized()
			speed = RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	if auto_move.length() > 0.01:
		dir = auto_move.normalized()
		speed = auto_move.length()
	if force_anim != "":
		_play(force_anim)
	elif speed > 0.0:
		position += dir * speed * dt
		for b: Dictionary in blockers:
			var c: Vector2 = b["c"]
			var d: Vector2 = Vector2(position.x, position.z) - c
			var rr: float = float(b["r"]) + 0.35
			if d.length() < rr:
				d = d.normalized() * rr if d.length() > 0.001 else Vector2(rr, 0)
				position.x = c.x + d.x
				position.z = c.y + d.y
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, dt * 9.0))
		_play("run" if speed > 4.0 else "walk")
	else:
		_play("idle")
	position.y = lerpf(position.y, terrain.h(position.x, position.z), minf(1.0, dt * 14.0))
	model.rotation.y = facing
	if active:
		var tgt: Vector3 = position + Vector3(0, 1.35, 0)
		var pr: float = deg_to_rad(pitch)
		var yr: float = deg_to_rad(yaw)
		var off: Vector3 = Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr)) * dist
		var cp: Vector3 = tgt + off
		cp.y = maxf(cp.y, terrain.h(cp.x, cp.z) + 0.6)
		cam.position = cp
		cam.look_at(tgt + Vector3(0, 0.5, 0), Vector3.UP)


func reset() -> void:
	position = Vector3(0, terrain.h(0, 0), 0)
	facing = 0.0
	yaw = 0.0
	pitch = PITCH0
	dist = DIST0
