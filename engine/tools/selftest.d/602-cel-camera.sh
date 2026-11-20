# The visitor changes framing before obstruction tests, and recovers the normal flight and classic views.
if [ -z "$FILTER" ] || [[ "style.cel.camera" == *"$FILTER"* ]]; then
  cel_engine="$(cd "$HERE/.." && pwd)"
  cel_script="$OUT/cel-camera.gd"
  cat > "$cel_script" <<'GDSCRIPT'
extends SceneTree

class Visitor extends Node3D:
	var flying := false

func _initialize() -> void:
	call_deferred("test")

func test() -> void:
	var target := Visitor.new()
	root.add_child(target)
	var camera := preload("res://kernel/world/terrain/crown_camera.gd").new()
	root.add_child(camera)
	TLStyle.load_style("res://style/style_crisp.json")
	var opts := {"distance":8.5,"height":3.6,"look_height":1.7,"anchor_follow":1.0}
	camera.setup(target,opts)
	camera.set_physics_process(false)
	var near_eye := camera.position
	var near_aim := camera._look
	target.flying = true
	var previous := near_eye
	var max_step := 0.0
	for i in 30:
		camera._physics_process(1.0/60.0)
		max_step = maxf(max_step,previous.distance_to(camera.position))
		previous = camera.position
	var flight := camera.position
	target.flying = false
	for i in 30:
		camera._physics_process(1.0/60.0)
	var landing := camera.position
	TLStyle.load_style(TLStyle.DEFAULT_PATH)
	camera._physics_process(1.0/60.0)
	var classic := camera.position
	var expected := Vector3(0,opts.height,opts.distance)
	var ok := near_eye.z > 3.5 and near_eye.z < 5.6 and near_aim.y > 2.0
	ok = ok and flight.is_equal_approx(expected) and max_step < .23
	ok = ok and landing.is_equal_approx(near_eye) and classic.is_equal_approx(expected)
	ok = ok and is_equal_approx(camera._look.y,float(opts.look_height))
	print("CEL_CAMERA ok=",ok," ground_eye=",near_eye," aim=",near_aim," flight=",flight," max_step=",max_step," classic=",classic)
	camera.free()
	target.free()
	quit(0 if ok else 1)
GDSCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    cel_engine="$(cygpath -m "$cel_engine")"; cel_script="$(cygpath -m "$cel_script")"
  fi
  cel_log="$OUT/cel-camera.log"
  cel_why=""
  MSYS_NO_PATHCONV=1 timeout 60 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --path "$cel_engine" --script "$cel_script" > "$cel_log" 2>&1 || cel_why="exit $?"
  cel_line="$(tr -d '\r' < "$cel_log" | grep -a '^CEL_CAMERA ok=true ')"
  if [ -z "$cel_line" ] || grep -aEq 'SCRIPT ERROR|^ERROR:' "$cel_log"; then cel_why="see $cel_log"; fi
  verdict style.cel.camera "$cel_why" "${cel_line#CEL_CAMERA ok=true }"
fi
