# Exercise direct down() after a shove, the fourth direction, and custom rise windows.
# Use both shipped skins. The shared bot separately exercises normal world physics and signals.
for fa_style in crisp classic; do
  fa_name="falls.authored_$fa_style"
  if [ -n "$FILTER" ] && [[ "$fa_name" != *"$FILTER"* ]]; then continue; fi
  fa_dir="$(mktemp -d "$OUT/$fa_name.XXXXXX")"
  cat > "$fa_dir/check.gd" <<'GDSCRIPT'
extends SceneTree

var failures: Array[String] = []
var signals_seen := Vector2i.ZERO


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)


# Same 40-frame lie and same call as the lab. Only the preceding impulse differs.
func measure_fall(away: Vector3, strength: float) -> Dictionary:
	var b := TLBiped.new()
	var rig := TLRigs.build("biped", {"backpack": false}) as TLRigBiped
	b.rig = rig
	b.add_child(rig)
	root.add_child(b)
	b.set_physics_process(false)
	rig.set_locomotion(Vector3.ZERO, true)
	rig.tick(0)
	var head := rig._sk.find_bone("Head")
	var start := rig._sk.get_bone_global_pose(head).origin
	b.shove(away * strength * 1.8 * b.body_mass)
	TLHit.down(b, 40, -away)
	var samples: Array[Vector3] = []
	for frame in range(1, 36):
		TLHit._step_down(b)
		rig.tick(frame)
		var pos := rig._sk.get_bone_global_pose(head).origin
		var hip_y := rig._sk.get_bone_global_pose(rig._root_bone).origin.y
		samples.append(Vector3((pos - start).dot(away), pos.y, hip_y))
	var lie := samples[29]
	var land := 0
	while samples[land].y > lie.y + .02:
		land += 1
	var bounce := Vector3.ZERO
	for i in range(land, samples.size()):
		bounce = bounce.max(samples[i] - samples[land])
	b.free()
	return {"at6": samples[5].x, "lie": lie.x, "land": land + 1, "head_bounce": bounce.y, "hip_bounce": bounce.z}


func run() -> void:
	var b := TLBiped.new()
	var rig := TLRigs.build("biped", {"backpack": false}) as TLRigBiped
	b.rig = rig
	b.add_child(rig)
	root.add_child(b)
	b.set_physics_process(false)
	b.rotation.y = 1.13
	b.downed.connect(func() -> void: signals_seen.x += 1)
	b.got_up.connect(func() -> void: signals_seen.y += 1)
	var skull := rig._sk.find_bone("Head")
	var hips := rig._sk.find_bone("Hips")
	var directions := {"back": Vector3.BACK, "front": Vector3.FORWARD, "left": Vector3.LEFT, "right": Vector3.RIGHT}
	var windows := [9, 1, 63, 24]
	for side: String in directions:
		b.get_up_frames = windows[signals_seen.x]
		b.velocity = Vector3.ZERO
		# Below threshold the small backward shove still gives the old forward fall.
		var shove: Vector3 = Vector3.BACK * .49 if side == "front" else directions[side] * 4.0
		b.shove(b.basis * shove * b.body_mass)
		b.down(20)
		expect(rig.clip == StringName("fall_" + side), "wrong inferred fall " + side)
		b.down(30)
		expect(b.down_frames_left() == 30 + b.get_up_frames, "longer down failed to extend the lie")
		for i in 29:
			if i == 1:
				TLHit.down(b, 3, Vector3.RIGHT)
				expect(b.down_frames_left() == 29 + b.get_up_frames, "shorter down restarted the fall")
			TLHit._step_down(b)
			rig.tick(i)
		var axis := rig._sk.get_bone_global_pose(skull).origin - rig._sk.get_bone_global_pose(hips).origin
		expect(axis.dot(directions[side]) > .43, "head on wrong side of hips " + side)
		expect(b.is_down(), "stood early")
		for i in b.get_up_frames:
			TLHit._step_down(b)
			rig.tick(29 + i)
		expect(b.is_down(), "released control before last rise tick")
		expect(rig._sk.get_bone_global_pose(skull).origin.y > 1.49, "rise exceeded window " + side)
		TLHit._step_down(b)
		rig.tick(29 + b.get_up_frames)
		expect(not b.is_down(), "held past configured rise")
	expect(signals_seen == Vector2i(4,4), "unexpected signals %s" % signals_seen)
	b.free()
	for side: String in directions:
		var ordinary := measure_fall(directions[side], 1.2)
		var hard := measure_fall(directions[side], 2.0)
		expect(hard.at6 > ordinary.at6 + .35, "hard hit needs a faster departure " + side)
		expect(hard.land <= ordinary.land - 4, "hard hit needs an earlier landing " + side)
		expect(hard.lie > ordinary.lie + .25, "hard hit needs more travel " + side)
		expect(hard.head_bounce > ordinary.head_bounce + .08, "hard landing needs head recoil " + side)
		expect(hard.hip_bounce > ordinary.hip_bounce + .04, "hard landing needs hip recoil " + side)
		print("STRENGTH ", side, " 1.2 ", JSON.stringify(ordinary), " 2.0 ", JSON.stringify(hard))
	if failures.is_empty():
		print("AUTHORED OK: four shove directions, 1.2/2.0 landings, lie extension and 1/9/24/63-tick rises")
	else:
		for reason in failures:
			print("AUTHORED FAIL ", reason)
	quit(0 if failures.is_empty() else 1)
GDSCRIPT
  fa_engine="$(cd "$HERE/.." && pwd)"
  fa_script="$fa_dir/check.gd"
  if command -v cygpath >/dev/null 2>&1; then
    fa_engine="$(cygpath -am "$fa_engine")"
    fa_script="$(cygpath -am "$fa_script")"
  fi
  fa_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  fa_why=""
  TL_STYLE="$fa_style" MSYS_NO_PATHCONV=1 timeout 60 "$fa_godot" --headless --path "$fa_engine" --script "$fa_script" > "$fa_dir/output" 2>&1 || fa_why="Godot failed in $fa_dir/output"
  grep -aq '^AUTHORED OK' "$fa_dir/output" || fa_why="missing success result in $fa_dir/output"
  if grep -aqE 'SCRIPT ERROR|^ERROR:' "$fa_dir/output"; then fa_why="script or engine error in $fa_dir/output"; fi
  verdict "$fa_name" "$fa_why" "fall direction relative to rotated hips and get-up within the pack's window"
done
