extends SceneTree
## Lane K (spark world-sandbox M5, 27 Nov 2026): the visitor climbs real steps (selftest block 766). Headless, ticks
## only, every course in a world space of its own (world_space.gd), the walker driven one call per frame toward -z.
## Prints `WALKSTEP <course> ok|fail <detail>` per course, then `WALKSTEP ok` (or `WALKSTEP fail`) and `WALKSTEP DONE`.
##   stair    two Home stair blocks (blocks.gd STAIR, eight 0.25 m steps, as block_mesh.gd collides them) onto a 2 m
##            platform: `drive` at 4.5 and 9 m/s and `walk` at 4.5 reach the top, the feet never go down on the way up
##            (largest dip under 1 mm) and stay level on the platform (no frame moves them more than BOB, 3 mm)
##   boxes    the same profile from eight 0.25 x 0.25 m boxes tagged "home blocks" (real risers, whatever
##            block_mesh.gd does): the same
##   down     (every course above) from the top back down toward +z, `drive` at 4.5 and 9, `walk` at 4.5: he reaches
##            the floor with no frame in the air (no fall per step; off a 0.5 m riser (ledge, halfstep) a run may leave the ground,
##            counted, not decided on) and his feet never go up on the way down
##   stop     (every course above) the key let go for 40 frames as the foot first rises on a riser: he stays (no dip)
##            and goes on up when it is pressed again
##   ledge    a row of Home slabs (one 0.5 m ledge): climbed the same way
##   halfstep a slab in front of a row of cubes (0.5 m, then 0.5 m more): climbed onto the 1 m top
##   kerb     a 0.25 m box kerb: climbed
##   wall     a row of Home cubes (a 1 m block): NOT climbed (the feet never rise 5 cm), he stops against it
##   bush     the kerb's 0.25 m box tagged "bush" (not a Home block): the visitor walks it exactly as the seam's code
##            did (SHA-1 of the per-frame feet, measured at 5bf91b05; that code climbed it at 9 m/s and with `walk` and
##            hopped at its edge at 4.5): only the Home's blocks are stepped the new way (harden.bush_block)
##   packs    the same boxes and ledge courses walked by world_body.gd with its defaults (a pack's TLBiped: no
##            `step_risers`): the SHA-1 of the per-frame feet equals the one the seam's code (5bf91b05) gave, measured
##            before the change: a pack's walker is byte for byte what it was.

const Space := preload("res://kernel/world/terrain/world_space.gd")
const Mover := preload("res://kernel/world/terrain/world_body.gd")
const Blocks := preload("res://kernel/world/build/blocks.gd")
const BlockMesh := preload("res://kernel/world/build/block_mesh.gd")
const O := Vector3(10.0, 0.0, 20.0)          # the courses' corner (cells stay positive)
const FRAMES := 420
## A level floor already moves the feet in a 1.6 mm sawtooth (the probe's 3 cm margin recovers every 9 ticks, before
## any riser as well): "level" is no frame moving them more than BOB.
const BOB := 0.003
## The seam's walker (world_body.gd at 5bf91b05, no step_risers), 240 frames at 4.5 m/s on the boxes and the ledge.
## The seam's visitor (5bf91b05) on the bush course, 240 frames each.
const BUSH_SHA := {"drive 4.5": "664ebd8754f95afd06444c36b43a109a40ae6383", "drive 9.0": "3d32ad3ec47c85bb0347a4a32245ab9badd5c4e4",
	"walk 4.5": "5437490afb0502160af5bec500cb552ab3e2d294"}
const PACK_SHA := {"boxes": "0e33961f81043b9571523021b83e0c7f6ca19f49", "ledge": "f305e96db95fbd49621114464abcb4f6b6311b52"}

var ok_all := true
var _frames := 0
var _keep: RefCounted = null                  # the course's block_mesh.gd (its shapes) while it is walked


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		run()
		print("WALKSTEP %s" % ("ok" if ok_all else "fail"))
		print("WALKSTEP DONE")
		quit(0 if ok_all else 1)
	return false


func say(name: String, ok: bool, detail: String) -> void:
	ok_all = ok_all and ok
	print("WALKSTEP %s %s %s" % [name, "ok" if ok else "fail", detail])


func run() -> void:
	for course: String in ["stair", "boxes", "ledge", "halfstep", "kerb"]:
		var top: float = {"stair": 2.0, "boxes": 2.0, "ledge": 0.5, "halfstep": 1.0, "kerb": 0.25}[course]
		var parts: Array = []
		var ok := true
		for how: Array in [["drive", 4.5], ["drive", 9.0], ["walk", 4.5], ["stop", 4.5]]:
			var r: Dictionary = walker(course, how[0], how[1], false)
			var climbed: bool = r.on_top >= 0 and r.dip < 0.001 and r.bob == 0 and absf(r.high - top) < 0.01
			ok = ok and climbed
			parts.append("%s %.1f: top %.2f at frame %d, dip %.4f, bob %d, %d air frames, %.0f us/frame" % [
				how[0], how[1], r.high, r.on_top, r.dip, r.bob, r.air, r.usec])
		for how: Array in [["drive", 4.5], ["drive", 9.0], ["walk", 4.5]]:
			var r: Dictionary = walker(course, how[0], how[1], true)
			var went: bool = r.on_top >= 0 and r.dip < 0.002 and (r.air == 0 or course in ["ledge", "halfstep"])
			ok = ok and went
			parts.append("down %s %.1f: floor at frame %d, rise %.4f, largest one-frame drop %.3f, %d air frames" % [
				how[0], how[1], r.on_top, r.dip, r.drop, r.air])
		say(course, ok, "; ".join(parts))
	var wparts: Array = []
	var wok := true
	for how: Array in [["drive", 4.5], ["drive", 9.0], ["walk", 4.5]]:
		var r: Dictionary = walker("wall", how[0], how[1], false)
		wok = wok and r.high < 0.05 and r.stopped >= 0
		wparts.append("%s %.1f: highest feet %.3f, stopped at frame %d" % [how[0], how[1], r.high, r.stopped])
	say("wall", wok, "; ".join(wparts))
	var bparts: Array = []
	var bok := true
	for how: Array in [["drive", 4.5], ["drive", 9.0], ["walk", 4.5]]:
		var r: Dictionary = walker("bush", how[0], how[1], false)
		var want: String = BUSH_SHA.get("%s %.1f" % [how[0], how[1]], "")
		bok = bok and r.sha == want
		bparts.append("%s %.1f: sha %s (%s), highest feet %.3f" % [how[0], how[1], r.sha, "as the seam" if r.sha == want else "seam " + want, r.high])
	say("bush", bok, "; ".join(bparts))
	var pparts: Array = []
	var pok := true
	for course: String in ["boxes", "ledge"]:
		var r: Dictionary = walker(course, "pack", 4.5, false)
		var want: String = PACK_SHA[course]
		pok = pok and (want == "" or r.sha == want)
		pparts.append("%s: sha %s (%s), highest feet %.3f" % [course, r.sha, "as the seam" if r.sha == want else "seam " + want.left(12), r.high])
	say("packs", pok and PACK_SHA.boxes != "", "; ".join(pparts))


## A world space holding the ground (y 0) and one course across x 9..13 from z = O.z - 3 back to O.z - 16.
func course_space(kind: String) -> Object:
	var ws: Object = Space.new()
	ws.add_box(Transform3D(Basis(), O + Vector3(0.0, -0.5, -5.0)), Vector3(40.0, 1.0, 40.0))
	var z0 := O.z - 2.0                       # the first riser's face
	ws.tag = "bush" if kind == "bush" else "home blocks"     # walker_riser.gd steps only the Home's blocks' risers
	match kind:
		"boxes":
			for i: int in 8:
				var back := O.z - 16.0
				var front := z0 - 0.25 * i
				ws.add_box(Transform3D(Basis(), Vector3(O.x, 0.25 * i + 0.125, (front + back) * 0.5)), Vector3(4.0, 0.25, front - back))
		"kerb", "bush":
			ws.add_box(Transform3D(Basis(), Vector3(O.x, 0.125, (z0 + O.z - 16.0) * 0.5)), Vector3(4.0, 0.25, z0 - O.z + 16.0))
		_:
			var store: RefCounted = Blocks.new()
			var cube := Blocks.code(Blocks.CUBE, 7)
			for x: int in range(int(O.x) - 1, int(O.x) + 2):
				match kind:
					"stair":
						store.put(Vector3i(x, 0, int(z0) - 1), Blocks.code(Blocks.STAIR, 1, 0))
						store.put(Vector3i(x, 0, int(z0) - 2), cube)
						store.put(Vector3i(x, 1, int(z0) - 2), Blocks.code(Blocks.STAIR, 1, 0))
						for z: int in range(int(z0) - 14, int(z0) - 2):
							store.put(Vector3i(x, 0, z), cube)
							store.put(Vector3i(x, 1, z), cube)
					"ledge":
						for z: int in range(int(z0) - 14, int(z0)):
							store.put(Vector3i(x, 0, z), Blocks.code(Blocks.SLAB, 7))
					"halfstep":
						store.put(Vector3i(x, 0, int(z0) - 1), Blocks.code(Blocks.SLAB, 7))
						for z: int in range(int(z0) - 14, int(z0) - 1):
							store.put(Vector3i(x, 0, z), cube)
					"wall":
						for z: int in range(int(z0) - 14, int(z0)):
							store.put(Vector3i(x, 0, z), cube)
			var bm: RefCounted = BlockMesh.new(store, null, ws)
			bm.step(64)
			_keep = bm
	ws.finish()
	return ws


## One walker from (O.x + 0.5, 0, O.z) toward -z for FRAMES frames (`down`: from the top at O.z - 6.5 toward +z, the
## "dip" is then the largest rise and "on_top" the frame he stands on the floor): `drive` (the visitor's body with
## weight), `walk` (world_space.gd's kinematic step) or `pack` (world_body.gd as a pack's TLBiped makes it: no flags).
func walker(kind: String, how: String, speed: float, down: bool) -> Dictionary:
	var ws: Object = course_space(kind)
	var top: float = {"stair": 2.0, "boxes": 2.0, "ledge": 0.5, "halfstep": 1.0, "kerb": 0.25, "wall": 1.0, "bush": 0.25}[kind]
	var pos := Vector3(O.x + 0.5, top, O.z - 6.5) if down else Vector3(O.x + 0.5, 0.0, O.z)
	var sgn := -1.0 if down else 1.0
	var drop := 0.0
	ws.call("place", pos)
	var mover: RefCounted = null
	if how == "pack":
		mover = Mover.new(ws)
	else:
		ws.call("rest")
	var trace := PackedVector3Array()
	var on_top := -1
	var stopped := -1
	var still := 0
	var dip := 0.0
	var bob := 0
	var air := 0
	var high := pos.y
	var usec := 0
	var n := 0
	var pause := -1
	for f: int in FRAMES:
		n += 1
		var d: Dictionary
		var t0 := Time.get_ticks_usec()
		if how == "walk":
			d = ws.call("walk", pos, Vector3(0.0, 0.0, -sgn * speed / 60.0))
		elif how == "pack":
			d = mover.drive(pos, Vector3(0.0, 0.0, -sgn * speed), false, false)
			ws.call("place", d.pos)
		else:
			if how == "stop" and pos.y > 0.02 and pause < 0:
				pause = 40                        # let go of the key with the foot on the riser's edge, then walk on
			var wish := Vector3(0.0, 0.0, -sgn * speed) if pause <= 0 else Vector3.ZERO
			pause -= 1 if pause > 0 else 0
			d = ws.call("drive", pos, wish, false, false)
		usec += Time.get_ticks_usec() - t0
		var np: Vector3 = d.pos
		if OS.get_environment("TL_STEP_TRACE") == "1" and f < 80:
			print("[trace] %s %s f%d %s %s blocked=%s" % [kind, how, f, str(np), d.get("mode", ""), d.get("blocked", "")])
		if f < 240:
			trace.append(np)
		if str(d.get("mode", "ground")) == "air":
			air += 1
		if on_top < 0:
			dip = maxf(dip, sgn * (pos.y - np.y))
			drop = maxf(drop, pos.y - np.y)
			if (np.y < 0.001) if down else (np.y > top - 0.001):
				on_top = f
		elif f <= on_top + 60 and absf(np.y - pos.y) > BOB:
			bob += 1
		if stopped < 0:
			still = still + 1 if absf(np.z - pos.z) < 0.001 else 0
			if still >= 10:
				stopped = f - 9
		high = maxf(high, np.y)
		pos = np
		if on_top >= 0 and f > on_top + 60:
			break
	ws.call("free_all")
	_keep = null
	var sha := HashingContext.new()
	sha.start(HashingContext.HASH_SHA1)
	sha.update(trace.to_byte_array())
	return {"on_top": on_top, "stopped": stopped, "dip": dip, "drop": drop, "bob": bob, "air": air, "high": high,
		"usec": float(usec) / float(n), "sha": sha.finish().hex_encode()}
