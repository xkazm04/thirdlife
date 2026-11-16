extends RefCounted
## Helper for shooting: reach, facing and cooldown checks. Created by main.gd, no class_name.

var puck: TLBall
var skaters: Dictionary = {}
var reach: float = 1.5
var speed: float = 18.0
var cooldown_frames: int = 24
var front_dot: float = 0.5
var shots: Dictionary = {}
var events: Array = []                 # [id] of every successful shot since main last drained it
var _now: int = 0
var _ready_at: Dictionary = {}


func setup(tune: Dictionary, p: TLBall, sk: Dictionary) -> void:
	var s: Dictionary = tune["shoot"]
	reach = float(s["reach"])
	speed = float(s["speed"])
	front_dot = float(s["front_dot"])
	cooldown_frames = int(round(float(s["cooldown_s"]) * 60.0))
	puck = p
	skaters = sk
	for id: String in skaters:
		shots[id] = 0
		_ready_at[id] = 0


func tick(frame: int) -> void:
	_now = frame


func _to_puck(id: String) -> Vector3:
	var d: Vector3 = puck.global_position - (skaters[id] as Node3D).global_position
	d.y = 0.0
	return d


func in_reach(id: String) -> bool:
	var d: Vector3 = _to_puck(id)
	if d.length() > reach:
		return false
	var f: Vector3 = (skaters[id] as TLBiped).forward()
	f.y = 0.0
	f = f.normalized()
	return d.length() < 0.05 or f.dot(d.normalized()) >= front_dot


func can_shoot(id: String) -> bool:
	return _now >= int(_ready_at[id]) and in_reach(id)


func try_shoot(id: String) -> bool:
	if not can_shoot(id):
		return false
	var f: Vector3 = (skaters[id] as TLBiped).forward()
	f.y = 0.0
	f = f.normalized()
	puck.shoot(f * puck.mass * speed)
	_ready_at[id] = _now + cooldown_frames
	shots[id] = int(shots[id]) + 1
	events.append(id)
	return true
