# Drive a real pack biped through lift, touchdown, an airborne release and an
# interrupted summon. Compare every mesh transform and drawing command on two runs.

if [[ -z "$FILTER" || "flight.wings_summon" == *"$FILTER"* ]]; then
  wings_summon_case() {
    local dir="$OUT/wings-summon" engine="$HERE/.." godot rc line why=""
    mkdir -p "$dir"
    if command -v cygpath >/dev/null 2>&1; then
      dir="$(cygpath -am "$dir")"
      engine="$(cygpath -am "$engine")"
    fi
    cat > "$dir/case.gd" <<'GDSCRIPT'
extends SceneTree

var problems: Array[String] = []

func check(value: bool, reason: String) -> void:
	if not value and not problems.has(reason):
		problems.append(reason)

func _initialize() -> void:
	physics_frame.connect(run, CONNECT_ONE_SHOT)

func run() -> void:
	var village := Node3D.new()
	root.add_child(village)
	var visitor := preload("res://kernel/world/visitor.gd").new()
	village.add_child(visitor)
	visitor.setup(Vector3.ZERO)
	for i in 10:
		visitor.step(Vector3(0, 0, -i * 0.075), i)
	check(visitor.wings != null and drawn(visitor.rig.call("socket", &"back")) == 0,
		"visitor drew wings before F")
	check(not visitor.rig.params.backpack, "visitor wore backpack")
	village.free()
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 2, 20)
	collider.shape = box
	collider.position.y = -1.0
	floor_body.add_child(collider)
	root.add_child(floor_body)
	await physics_frame
	var first := record()
	var second := record()
	check(first == second, "poses or drawing commands differed")
	var ok := problems.is_empty()
	print("SUMMON ", "PASS" if ok else "FAIL", " frames=", first.size(),
		" summon=36 land_fold=36 land_dismiss=36 air_dismiss=36 errors=", problems)
	quit(0 if ok else 1)

func drawn(node: Node3D) -> int:
	var count := 0
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		count += int(m.is_visible_in_tree())
	return count

func snapshot(w: RefCounted) -> Array:
	var glyph := w._sigil as MeshInstance3D
	var paint := glyph.material_override as ShaderMaterial
	var row := [glyph.is_visible_in_tree(), paint.get_shader_parameter("phase"),
		paint.get_shader_parameter("spread")]
	for m: MeshInstance3D in w.root.find_children("*", "MeshInstance3D", true, false):
		row.append([m.global_transform, m.is_visible_in_tree(), m.material_override != null,
			m.get_instance_shader_parameter("wing_radius")])
	return row

func record() -> Array:
	var b := TLBiped.create({"feel":"walker"})
	root.add_child(b)
	b.set_physics_process(false)
	var dt := 1.0 / 60.0
	var frames := []
	for i in 10:
		b._physics_process(dt)
	var back: Node3D = b.rig.call("socket", &"back")
	check(back != null and drawn(back) == 0 and not b.rig.params.backpack, "gear before fly")
	b.fly(true)
	b._physics_process(dt)
	var w: RefCounted = b.get("_wings")
	if w == null or w._sigil == null:
		check(false, "no summoned wings or style")
		b.free()
		return frames
	check(b.is_flying() and w.root.get_parent() == back, "take-off or socket")
	for age in range(1, 37):
		if age > 1:
			b._physics_process(dt)
		frames.append(snapshot(w))
		check(w._sigil.is_visible_in_tree() == (age < 36), "summon glyph")
		check(is_equal_approx(frames.back()[1], age / 36.0), "summon phase")
		if age == 2: check(drawn(w.root) == 0, "metal before first stroke")
		if age == 8: check(drawn(w.root) == 3, "expected plate and inner spars")
		if age == 18: check(drawn(w.root) > 3 and drawn(w.root) < 17, "missing feather ripple")
		if age == 36: check(drawn(w.root) == 17 and drawn(back) == 17 and w.k == 1.0, "incomplete wings")
	# Let the actual body decide the touchdown tick.
	for i in 240:
		b.climb(-1)
		b._physics_process(dt)
		if not b.is_flying(): break
	check(b.grounded and not b.is_flying(), "did not land")
	for off in range(1, 73):
		if off > 1: b._physics_process(dt)
		frames.append(snapshot(w))
		if off <= 36:
			check(drawn(back) == 17 and not w._sigil.visible, "vanished during landing fold")
		else:
			check(w.k == 0.0, "dismiss before fold")
			check(is_equal_approx(frames.back()[1], (72 - off) / 36.0), "dismiss phase")
			check(w._sigil.is_visible_in_tree() == (off < 72), "dismiss glyph")
	check(drawn(back) == 0, "drawn after dismiss")
	b.fly(true)
	for i in 48:
		b.climb(1)
		b._physics_process(dt)
	b.fly(false)
	for off in range(1, 37):
		b._physics_process(dt)
		frames.append(snapshot(w))
		check(not b.is_flying() and is_equal_approx(frames.back()[1], (36 - off) / 36.0), "air release")
	check(drawn(back) == 0, "drawn after air release")
	b.fly(true)
	for i in 14: b._physics_process(dt)
	b.fly(false)
	for i in 5: b._physics_process(dt)
	b.fly(true)
	b._physics_process(dt)
	check(w._cast_tick == 10 and drawn(w.root) == 3, "interrupted cast restarted or jumped")
	b.free()
	return frames
GDSCRIPT
    godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
    MSYS_NO_PATHCONV=1 timeout 120 "$godot" --headless --fixed-fps 60 --path "$engine" \
      --log-file "$dir/godot.log" --script "$dir/case.gd" > "$dir/run.log" 2>&1
    rc=$?
    line="$(tr -d '\r' < "$dir/run.log" | grep -a '^SUMMON ')"
    if [[ "$line" != "SUMMON PASS "* ]]; then why="${line:-missing measurement (exit $rc, $dir/run.log)}"
    elif (( rc != 0 )); then why="process exited $rc"
    elif grep -aEq '^(SCRIPT ERROR|ERROR):' "$dir/run.log"; then why="engine error in $dir/run.log"; fi
    verdict flight.wings_summon "$why" "${line#SUMMON PASS }"
  }
  wings_summon_case
fi
