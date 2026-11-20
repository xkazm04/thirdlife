extends SceneTree
## Diorama night (20 Nov 2026), selftest block 590: the biped of the loaded style, headless, ticks only.
## Prints one line `FIGURE ok=<bool> ...` and exits 0 / 1. `-- --expect=toy|classic` says which figure the style must give.
##   rails    metrics height 2.0, radius 0.3, eye height 1.765; at most 12000 triangles for the walker, the
##            walker with the backpack, the skater and the hammer; the 29 bones of the classic figure by name, no other;
##            every clip name is there; the seven sockets answer;
##   classic  29 bones, 10296 triangles with the backpack, no feel layer, the model's scale stays 1 through a jump;
##   toy      two builds hash the same; a run, a jump and a stop: two runs give the same bones at every tick; the bun
##            moves (over 3 degrees) and is at rest again 90 ticks after the stop; the figure stretches at the take-off
##            and squashes at the landing and is back at scale 1; the bones stay finite.

const CLIPS: Array = ["idle", "walk", "run", "skate", "skate_stop", "shoot", "pass", "cheer", "fall", "carry", "work", "jump", "land", "slide",
	"slope_slide", "air", "fly", "hang", "mantle", "swing"]
const SOCKETS: Array = ["hand_r", "hand_l", "head", "back", "foot_r", "foot_l", "stick_blade"]

var _n: int = 0


func _process(_d: float) -> bool:
	_n += 1
	if _n != 2:
		return false
	var expect: String = "toy"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--expect="):
			expect = a.trim_prefix("--expect=")
	var why: PackedStringArray = PackedStringArray()
	var toy: bool = expect == "toy"
	var note: String = ""
	for p: Dictionary in [{"backpack": false}, {}, {"mode": "skate", "backpack": false}, {"prop": "hammer"}]:
		var r: Node3D = TLRigs.build("biped", p)
		var m: Dictionary = r.call("metrics")
		if (r.get("_feel") != null) != toy:
			why.append("%s: toy=%s, the style should give %s" % [str(p), str(r.get("_feel") != null), expect])
		if not is_equal_approx(float(m["height"]), 2.0) or not is_equal_approx(float(m["radius"]), 0.3) or not is_equal_approx(float(m["eye_height"]), 1.765):
			why.append("%s: metrics moved: %s" % [str(p), str(m)])
		if int(m["triangles"]) > 12000 or int(m["bones"]) > 30 or int(m["triangles"]) != TLKit.triangles(r):
			why.append("%s: budget: %d triangles (kit counts %d), %d bones" % [str(p), int(m["triangles"]), TLKit.triangles(r), int(m["bones"])])
		var sk: Skeleton3D = r.find_child("Skeleton3D", true, false)
		for b: Array in TLRigBipedMesh.BONES:
			if sk.find_bone(String(b[0])) < 0:
				why.append("%s: bone %s is gone" % [str(p), b[0]])
		if sk.get_bone_count() != TLRigBipedMesh.BONES.size():
			why.append("%s: %d bones, the classic figure has %d" % [str(p), sk.get_bone_count(), TLRigBipedMesh.BONES.size()])
		for c: String in CLIPS:
			if not (r.call("clips") as PackedStringArray).has(c):
				why.append("%s: clip %s is gone" % [str(p), c])
		for s: String in SOCKETS:
			if r.call("socket", StringName(s)) == null:
				why.append("%s: socket %s is gone" % [str(p), s])
		note += " %s=%d tris/%d bones" % ["pack" if p.is_empty() else str(p.values()[0]), int(m["triangles"]), int(m["bones"])]
		if not toy and p.is_empty() and (int(m["bones"]) != 29 or int(m["triangles"]) != 10296):
			why.append("classic figure changed: %d bones, %d triangles (29, 10296)" % [int(m["bones"]), int(m["triangles"])])
		var r2: Node3D = TLRigs.build("biped", p)
		if TLKit.hash(r) != TLKit.hash(r2):
			why.append("%s: two builds hash differently" % str(p))
		r.free()
		r2.free()
	var a: Dictionary = _run()
	var b: Dictionary = _run()
	if a["trace"] != b["trace"]:
		why.append("two runs of the same calls give different bones")
	if not bool(a["finite"]):
		why.append("a bone pose is not finite")
	if toy:
		if float(a["tuft"]) < 3.0:
			why.append("the bun never moves (max %.2f deg)" % float(a["tuft"]))
		if float(a["tuft_end"]) > 0.5:
			why.append("the bun is not at rest 90 ticks after the stop (%.2f deg)" % float(a["tuft_end"]))
		if float(a["stretch"]) > -0.02 or float(a["squash"]) < 0.02:
			why.append("no stretch at the take-off or no squash at the landing (%.3f, %.3f)" % [float(a["stretch"]), float(a["squash"])])
		if absf(float(a["scale_end"]) - 1.0) > 0.002:
			why.append("the figure does not come back to scale 1 (%.4f)" % float(a["scale_end"]))
		note += " bun_max_deg=%.1f bun_end_deg=%.2f stretch=%.3f squash=%.3f" % [float(a["tuft"]), float(a["tuft_end"]), float(a["stretch"]), float(a["squash"])]
	else:
		if bool(a["feel"]) or absf(float(a["scale_min"]) - 1.0) > 0.00001 or absf(float(a["scale_max"]) - 1.0) > 0.00001:
			why.append("the classic figure has the toy's feel layer (scale %.4f..%.4f)" % [float(a["scale_min"]), float(a["scale_max"])])
	print("FIGURE ok=%s figure=%s%s%s" % [why.is_empty(), expect, note, "" if why.is_empty() else " | " + "; ".join(why)])
	quit(0 if why.is_empty() else 1)
	return false


## A stand, a run, a jump, a landing, a stop: 420 ticks. Returns the bones at every tick and what the feel layer did.
func _run() -> Dictionary:
	var r: Node3D = TLRigs.build("biped", {"backpack": false})
	root.add_child(r)
	var sk: Skeleton3D = r.find_child("Skeleton3D", true, false)
	var model: Node3D = r.get_node("Model")
	var feel: Variant = r.get("_feel")
	var trace: Array = []
	var vy: float = 0.0
	var air: bool = false
	var y: float = 0.0
	var out: Dictionary = {"finite": true, "tuft": 0.0, "tuft_end": 0.0, "stretch": 0.0, "squash": 0.0, "scale_min": 1.0, "scale_max": 1.0, "feel": feel != null}
	for t: int in 420:
		var v: float = 0.0 if t < 30 else (4.5 if t < 300 else 0.0)
		if t == 120:
			vy = 8.5
			air = true
			r.call("play", &"jump")
		var landed: bool = false
		if air:
			vy -= 24.0 / 60.0
			y += vy / 60.0
			if y <= 0.0:
				y = 0.0
				air = false
				landed = true
		r.call("set_locomotion", Vector3(0, vy if (air or landed) else 0.0, -v), not air)
		if landed:
			r.call("play", &"land")
			vy = 0.0
		r.call("tick", t + 1)
		var row: Array = [model.scale]
		for bi: int in sk.get_bone_count():
			var q: Quaternion = sk.get_bone_pose_rotation(bi)
			var p: Vector3 = sk.get_bone_pose_position(bi)
			out["finite"] = bool(out["finite"]) and q.is_finite() and p.is_finite()
			row.append(q)
			row.append(p)
		trace.append(row)
		out["scale_min"] = minf(float(out["scale_min"]), model.scale.y)
		out["scale_max"] = maxf(float(out["scale_max"]), model.scale.y)
		if feel != null:
			var tf: Vector2 = feel.get("tuft")
			out["tuft"] = maxf(float(out["tuft"]), tf.length())
			out["stretch"] = minf(float(out["stretch"]), float(feel.get("sq")))
			out["squash"] = maxf(float(out["squash"]), float(feel.get("sq")))
			if t >= 390:
				out["tuft_end"] = maxf(float(out["tuft_end"]), tf.length())
	out["scale_end"] = model.scale.y
	out["trace"] = trace
	r.queue_free()
	return out
