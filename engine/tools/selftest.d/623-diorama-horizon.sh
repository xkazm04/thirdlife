# Verify the production resolve on two depths and the first frame after a camera cut.
if [[ -z "$FILTER" || "style.diorama.horizon" == *"$FILTER"* ]]; then
  horizon_script="$OUT/horizon_623.gd"
  cat > "$horizon_script" <<'GDSCRIPT'
extends SceneTree

var camera: Camera3D
var paint := StandardMaterial3D.new()

func _initialize() -> void:
	call_deferred("check")

func card(host: Node3D, distance: float, side: float, offset: float) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.36) * distance
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = paint
	node.position = Vector3(offset + side * distance * 0.37, 0, -distance)
	host.add_child(node)

func sample() -> Vector2i:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var near_px := camera.unproject_position(Vector3(camera.position.x - 2.96, 0, -8))
	var far_px := camera.unproject_position(Vector3(camera.position.x + 33.3, 0, -90))
	return Vector2i(img.get_pixelv(Vector2i(near_px)).r8, img.get_pixelv(Vector2i(far_px)).r8)

func alternate() -> Vector2i:
	var low: Vector2i
	var high: Vector2i
	for i in 18:
		var v := 0.65 if i%2 else 0.48
		paint.albedo_color = Color(v, v, v)
		var reading := await sample()
		if i%2: high = reading
		else: low = reading
	return high-low

func check() -> void:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"ink": false, "grade": false})
	var we := host.get_node("TLStyleRig/WorldEnvironment") as WorldEnvironment
	var authored := we.compositor
	var ok := authored != null
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for offset: float in [0.0, 700.0]:
		card(host, 8, -1, offset)
		card(host, 90, 1, offset)
	camera = Camera3D.new()
	host.add_child(camera)
	camera.make_current()
	we.compositor = null
	for i in 4: await RenderingServer.frame_post_draw
	var clear := await alternate()
	we.compositor = authored
	for i in 4: await RenderingServer.frame_post_draw
	var held := await alternate()
	ok = ok and clear.x > 16 and clear.y > 16 and absi(clear.x-held.x) <= 1
	ok = ok and held.y >= 0 and held.y < clear.y*0.70
	# A 45 m/s flight at 60 Hz must retain the current native ground sample.
	paint.albedo_color = Color(0.54, 0.54, 0.54)
	camera.position.x = 0.75
	var fast := await sample()
	we.compositor = null
	var fresh := await sample()
	ok = ok and (fast-fresh).abs().x <= 1 and (fast-fresh).abs().y <= 1
	we.compositor = authored
	for i in 4: await RenderingServer.frame_post_draw
	# Both cards are identically painted. A cut across the table must use fresh colour.
	paint.albedo_color = Color(0.60, 0.60, 0.60)
	camera.position.x = 700.0
	var cut := await sample()
	we.compositor = null
	var control := await sample()
	ok = ok and (cut-control).abs().x <= 1 and (cut-control).abs().y <= 1
	we.compositor = authored
	TLStyle.load_style("res://style/style.json")
	TLStyle.install(host, {"ink": false, "grade": false})
	ok = ok and we.compositor == null
	print("HORIZON623 ", "ok" if ok else "FAIL", " near/far swing clear=", clear, " resolved=", held, " flight delta=", fast-fresh, " cut delta=", cut-control)
	host.free()
	quit(0 if ok else 1)
GDSCRIPT
  horizon_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    horizon_engine="$(cygpath -m "$horizon_engine")"
    horizon_script="$(cygpath -m "$horizon_script")"
  fi
  horizon_log="$OUT/horizon_623.log"
  horizon_error=""
  (cd "$HERE/../.." && MSYS_NO_PATHCONV=1 TL_STYLE=diorama TL_EXE_AA= node --input-type=module - "$horizon_engine" "$horizon_script" <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const [engine, script] = process.argv.slice(2);
const run = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "640x360", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", engine, "--script", script, "--quit-after", "180"], {stdio:"inherit", timeout:120000});
const result = process.env.TL_WINDOW_LOCK === "off" ? run() : withWindowLock(run);
process.exitCode = result.status ?? 1;
NODE
  ) > "$horizon_log" 2>&1 || horizon_error="Godot failed"
  horizon_line="$(grep -a '^HORIZON623 ok ' "$horizon_log" | tr -d '\r')"
  if [ -z "$horizon_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$horizon_log"; then
    horizon_error="see $horizon_log"
  fi
  verdict style.diorama.horizon "$horizon_error" "${horizon_line#HORIZON623 ok }"
fi
