# Shipping diorama optics at 1080p. Compare the same chart, camera and light
# with and without the lens. A bright wire tests colour bleed at a depth step.
if [ -z "$FILTER" ] || [[ "style.diorama.aperture" == *"$FILTER"* ]]; then
  aperture_script="$OUT/aperture_620.gd"
  cat > "$aperture_script" <<'GDSCRIPT'
extends SceneTree

class RulerCamera extends Camera3D:
	var focus := Vector2(8.0, 0.0)
	func _miniature_focus() -> Vector2:
		return focus

var cam := RulerCamera.new()

func _initialize() -> void:
	call_deferred("test")

func photo() -> Image:
	for i in 5:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

# Express card sizes in image pixels so every depth presents the same pattern.
func card(x: float, y: float, w: float, h: float, depth: float, paint: Material) -> void:
	var span := 2.0*depth*tan(deg_to_rad(cam.fov*0.5))/root.size.y
	var q := QuadMesh.new()
	q.size = Vector2(w,h)*span
	var panel := MeshInstance3D.new()
	panel.mesh = q
	panel.material_override = paint
	cam.add_child(panel)
	panel.position = Vector3((x-root.size.x*0.5)*span,(root.size.y*0.5-y)*span,-depth)

func paint(expression: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; void fragment(){ ALBEDO = " + expression + "; }"
	return m

func contrast(im: Image, x: int) -> float:
	var sum := 0.0
	for dx in range(-64,64):
		sum += absf(im.get_pixel(x+dx,540).r - im.get_pixel(x+dx+2,540).r)
	return sum / 128.0

func max_delta(a: Image, b: Image, rect: Rect2i) -> int:
	var worst := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			worst = maxi(worst,maxi(absi(p.r8-q.r8),maxi(absi(p.g8-q.g8),absi(p.b8-q.b8))))
	return worst

func test() -> void:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"grade":false,"ink":false})
	var we: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	we.environment.glow_enabled = false
	we.environment.fog_enabled = false
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.12,0.12,0.12)
	host.add_child(cam)
	cam.far = 900.0
	cam.make_current()
	var stripes := paint("vec3(0.40+0.30*cos(FRAGCOORD.x*1.5707963))")
	var depths := [2.0,8.0,55.0,195.0,360.0]
	for i in depths.size():
		card(192+i*384,540,210,200,depths[i],stripes)
	card(960,790,220,100,430.0,paint("vec3(0.04,0.09,0.24)"))
	card(960,790,2,120,300.0,paint("vec3(0.93,0.64,0.28)"))
	var walk := await photo()
	cam.focus = Vector2(-1,0) # Untracked scenic camera.
	var scenic := await photo()
	cam.focus = Vector2.ZERO # Flight and named play cameras.
	var flight := await photo()
	cam.focus = Vector2(320,0)
	var distant_subject := await photo()
	cam.focus = Vector2(8,0)
	cam.attributes = CameraAttributesPractical.new()
	var clear := await photo()
	var ratios := PackedFloat32Array()
	var ok := clear.get_size() == Vector2i(1920,1080)
	for i in depths.size():
		var x := 192+i*384
		var ref := contrast(clear,x)
		ok = ok and ref > 0.1
		var ratio := contrast(walk,x)/maxf(ref,0.001)
		ratios.append(ratio)
		ok = ok and absf(contrast(scenic,x)/maxf(ref,0.001)-ratio) < 0.01
		ok = ok and max_delta(flight,clear,Rect2i(x-70,536,140,8)) <= 1
		if i < 3:
			ok = ok and max_delta(walk,clear,Rect2i(x-70,536,140,8)) <= 1
	var wire := max_delta(walk,clear,Rect2i(945,745,30,90))
	ok = ok and wire <= 1 and ratios[3] < 0.995 and ratios[3] > ratios[4]
	ok = ok and ratios[4] > 0.82 and ratios[4] < 0.98
	ok = ok and max_delta(distant_subject,clear,Rect2i(1658,536,140,8)) <= 1
	print("APERTURE620 ", "ok" if ok else "FAIL", " depth_m=",depths," contrast=",ratios," wire_delta=",wire)
	host.free()
	quit(0 if ok else 1)
GDSCRIPT
  aperture_engine="$(cd "$HERE/.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    aperture_engine="$(cygpath -m "$aperture_engine")"
    aperture_script="$(cygpath -m "$aperture_script")"
  fi
  aperture_log="$OUT/aperture_620.log"
  aperture_error=""
  (cd "$HERE/../.." && MSYS_NO_PATHCONV=1 TL_STYLE=diorama node --input-type=module - "$aperture_engine" "$aperture_script" <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const [engine, script] = process.argv.slice(2);
const run = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "1920x1080", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", engine, "--script", script, "--quit-after", "120"], {stdio:"inherit", timeout:120000});
const result = process.env.TL_WINDOW_LOCK === "off" ? run() : withWindowLock(run);
process.exitCode = result.status ?? 1;
NODE
  ) > "$aperture_log" 2>&1 || aperture_error="Godot failed"
  aperture_line="$(grep -a '^APERTURE620 ok ' "$aperture_log" | tr -d '\r')"
  if [ -z "$aperture_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$aperture_log"; then
    aperture_error="see $aperture_log"
  fi
  verdict style.diorama.aperture "$aperture_error" "${aperture_line#APERTURE620 ok }"
fi
