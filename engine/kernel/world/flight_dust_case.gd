extends SceneTree
## Lane flight round 2 (19 Nov 2026): the take-off and landing dust (selftest block 532). WINDOWED (a puff is a style
## particle effect and draws nothing headless), counted in frames. A visitor in a small world space of its own: F (take
## off), a climb, C down to the floor (landing). Prints `FLIGHTDUST ok=<bool> ...`: exactly one puff (the style's
## `dust` preset, CPUParticles3D `Fx_dust`) appears on the take-off tick and one on the landing tick, at the feet (within
## 0.2 m), each emitting, each freed by FlightWings.DUST_FRAMES + 10 frames later; nothing else spawns a puff.

const Space = preload("res://kernel/world/terrain/world_space.gd")
const Visitor = preload("res://kernel/world/visitor.gd")
const Wings = preload("res://kernel/world/flight_wings.gd")

var land: Node3D
var v: Node3D
var t: int = 0
var puffs: Array = []           # [tick born, node, at feet]
var seen: Dictionary = {}       # instance id -> true
var takeoff_t: int = -1
var land_t: int = -1
var freed_ok: bool = true
var log: Array = []


func _initialize() -> void:
	TLStyle.install(root, {})
	land = Node3D.new()
	root.add_child(land)
	var sp: RefCounted = Space.new()
	sp.add_box(Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(60, 1, 60))
	sp.call("finish")
	land.set_meta(&"tl_space", sp)
	v = Visitor.new()
	land.add_child(v)
	v.setup(Vector3.ZERO, Vector3.FORWARD)
	v.steer_on()
	(v.get("cam") as Camera3D).make_current()
	physics_frame.connect(_tick)


func _tick() -> void:
	t += 1
	var fly: bool = t == 30
	var climb: float = 1.0 if t > 40 and t < 80 else (-1.0 if t > 140 else 0.0)
	var was: String = v.mode
	v.wish(Vector3.ZERO, false, false, fly, climb)
	v.step(v.feet, t)
	if was != "fly" and v.mode == "fly":
		takeoff_t = t
	if was == "fly" and v.mode == "ground":
		land_t = t
	for n: Node in land.get_children():
		if n is CPUParticles3D and n.name.begins_with("Fx_dust") and not seen.has(n.get_instance_id()):
			seen[n.get_instance_id()] = true
			var p: CPUParticles3D = n
			puffs.append([t, weakref(p), p.global_position.distance_to(v.feet) <= 0.2 and p.emitting])
	for pf: Array in puffs:
		var alive: bool = (pf[1] as WeakRef).get_ref() != null and is_instance_valid((pf[1] as WeakRef).get_ref())
		if alive and t > int(pf[0]) + Wings.DUST_FRAMES + 12:
			freed_ok = false
	if t >= 420 or (land_t > 0 and t > land_t + Wings.DUST_FRAMES + 14):
		var born: Array = puffs.map(func(p: Array) -> int: return int(p[0]))
		var at_feet: bool = puffs.all(func(p: Array) -> bool: return bool(p[2]))
		var ok: bool = takeoff_t > 0 and land_t > 0 and puffs.size() == 2 and born == [takeoff_t, land_t] and at_feet and freed_ok
		print("FLIGHTDUST ok=%s takeoff_tick=%d landing_tick=%d puffs=%d born=%s at_feet_emitting=%s freed_in_time=%s" % [
			ok, takeoff_t, land_t, puffs.size(), str(born), at_feet, freed_ok])
		quit(0 if ok else 1)
