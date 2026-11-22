extends SceneTree
## Selftest block 719 (H1, loop round 3, night of 22 Nov 2026), headless. Prints `GAIN <case> ok=true|false ...`:
##   cut      a 60 kg block slid at 24 m/s into a resting puck: without set_max_gain the puck
##            leaves far faster than 14 m/s; with set_max_gain(4, 10) no frame's planar speed exceeds
##            max(the speed a frame before, 10) + 4, and it never passes 14 m/s on its first frame of motion
##   declared shoot_at(25 m/s), set_velocity(30 m/s), release(18 m/s) and an impulse with shoot() are never cut;
##            a raw `linear_velocity =` write of 30 m/s is cut back (use set_velocity)
##   same     two processes give the same capped speeds frame by frame (block 719 compares the `GAIN seq` lines; two
##            runs in ONE process differ by a few mm/s when the block catches the puck again: the physics engine's
##            contact cache, not this kernel code)
##   off      a puck without set_max_gain behaves exactly as before (same speeds as a puck from before the change: the
##            paddle run without the call equals the paddle run with set_max_gain(0))

const DT: float = 1.0 / 60.0


## Reads the puck after every other node of the frame (after TLBall's own _physics_process): the speed the step uses.
class Probe extends Node:
	var puck: TLBall
	var speeds: Array = []

	func _init() -> void:
		process_physics_priority = 5000

	func _physics_process(_d: float) -> void:
		if is_instance_valid(puck):
			speeds.append(snappedf(Vector2(puck.linear_velocity.x, puck.linear_velocity.z).length(), 0.001))


func _initialize() -> void:
	run.call_deferred()


func say(name: String, ok: bool, note: String) -> void:
	print("GAIN %s ok=%s %s" % [name, "true" if ok else "false", note])


func floor_body() -> StaticBody3D:
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	cs.position.y = -0.5
	fl.add_child(cs)
	TLLaws.apply(fl, "ice")
	return fl


## The paddle sweep: returns the puck's planar speed for 40 frames. gain < 0: no set_max_gain call at all.
func sweep(gain: float) -> Array:
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(floor_body())
	var puck := TLBall.create({"kind": &"puck", "radius": 0.12, "height": 0.05, "planar": true, "material": "rubber",
		"position": Vector3(0, 0.03, 0)})
	holder.add_child(puck)
	if gain >= 0.0:
		puck.set_max_gain(gain, 10.0)
	var paddle := RigidBody3D.new()                  # a heavy body run into the puck (a skater's sled, a crate)
	var pcs := CollisionShape3D.new()
	var pbx := BoxShape3D.new()
	pbx.size = Vector3(1.0, 0.3, 1.2)
	pcs.shape = pbx
	paddle.add_child(pcs)
	paddle.mass = 60.0
	paddle.continuous_cd = true
	paddle.axis_lock_angular_x = true
	paddle.axis_lock_angular_y = true
	paddle.axis_lock_angular_z = true
	paddle.position = Vector3(-2.0, 0.16, 0)
	holder.add_child(paddle)
	paddle.linear_velocity = Vector3(24, 0, 0)
	var probe := Probe.new()
	probe.puck = puck
	holder.add_child(probe)
	for f in 40:
		await physics_frame
	var speeds: Array = probe.speeds.duplicate()
	holder.queue_free()
	await process_frame
	return speeds


## The run from its first moving frame, 30 frames long.
static func moving(a: Array) -> Array:
	var i := 0
	while i < a.size() and float(a[i]) <= 0.05:
		i += 1
	return a.slice(i, i + 30)


func run() -> void:
	var free_run: Array = await sweep(-1.0)
	var zero: Array = await sweep(0.0)
	var free2: Array = await sweep(-1.0)
	var capped: Array = await sweep(4.0)
	# the first frames of a run wait for the block to arrive; where a run starts in the tree's frame is not the test
	free_run = moving(free_run)
	free2 = moving(free2)
	zero = moving(zero)
	capped = moving(capped)
	var peak_free: float = free_run.max()
	var ok := peak_free > 14.0
	var why := ""
	var prev := 0.0
	var first := -1.0
	for i in capped.size():
		var s: float = capped[i]
		if s > maxf(prev, 10.0) + 4.0 + 0.002:
			ok = false
			why = "frame %d: %.3f after %.3f" % [i, s, prev]
		if first < 0.0 and s > 0.05:
			first = s
		prev = s
	if first > 14.002:
		ok = false
		why = "first moving frame at %.3f m/s" % first
	if why == "" and not ok:
		why = "free run peak only %.2f m/s: %s" % [peak_free, str(free_run)]
	say("cut", ok, why if not ok else "free peak %.2f m/s; capped peak %.2f, first moving frame %.2f (cap max(prev,10)+4)" % [peak_free, capped.max(), first])
	print("GAIN seq %s" % str(capped).sha1_text().substr(0, 16))   # block 719 compares two processes (same seed, same frames)
	say("off", zero == free2 and free2 == free_run, "max_gain 0 = no call, %d moving frames: %s" % [zero.size(), "equal" if zero == free2 and free2 == free_run else "DIFFER"])
	# declared writes
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(floor_body())
	var p := TLBall.create({"kind": &"puck", "radius": 0.12, "planar": true, "position": Vector3(0, 0.03, 0)})
	holder.add_child(p)
	p.set_max_gain(4.0, 10.0)
	await physics_frame
	var got: Dictionary = {}
	p.shoot_at(Vector3(30, 0.03, 0), 25.0)
	await physics_frame
	await physics_frame
	got["shoot_at"] = Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	p.place(Vector3(0, 0.03, 0))
	await physics_frame
	p.set_velocity(Vector3(0, 0, -30))
	await physics_frame
	await physics_frame
	got["set_velocity"] = Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	p.place(Vector3(0, 0.03, 0))
	await physics_frame
	var hand := Node3D.new()
	holder.add_child(hand)
	p.hold(hand)
	await physics_frame
	p.release(Vector3(18, 0, 0))
	await physics_frame
	await physics_frame
	got["release"] = Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	p.place(Vector3(0, 0.03, 0))
	await physics_frame
	p.shoot(Vector3(0, 0, 20.0) * p.mass)
	await physics_frame
	await physics_frame
	got["shoot"] = Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	p.place(Vector3(0, 0.03, 0))
	await physics_frame
	await physics_frame
	p.linear_velocity = Vector3(30, 0, 0)
	await physics_frame
	await physics_frame
	got["raw"] = Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	var dok: bool = got["shoot_at"] > 24.0 and got["set_velocity"] > 29.0 and got["release"] > 17.0 and got["shoot"] > 19.0 and got["raw"] < 14.01
	say("declared", dok, "shoot_at %.2f, set_velocity %.2f, release %.2f, shoot %.2f kept; raw write cut to %.2f" % [got["shoot_at"], got["set_velocity"], got["release"], got["shoot"], got["raw"]])
	holder.queue_free()
	quit()
