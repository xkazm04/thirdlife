# Windowed regression for the cloud seam, near rail, player, far meadow, flight and contact shadow.
if [ -z "$FILTER" ] || [[ "style.frame.pixels" == *"$FILTER"* ]]; then
  frame_engine="$(cd "$HERE/.." && pwd)"
  frame_script="$OUT/frame_571.gd"
  cat > "$frame_script" <<'GDSCRIPT'
extends SceneTree

class Visitor extends Node3D:
	var flying := false

func _initialize() -> void:
	call_deferred("test")

func photo() -> Image:
	for i in 8:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func difference(a: Color, b: Color) -> int:
	return maxi(absi(a.r8-b.r8), maxi(absi(a.g8-b.g8), absi(a.b8-b.b8)))

# The original sky wrapped its longitude at due west. Compare that join to
# two nearby columns in the same image, including the cloud silhouettes.
func edge_p99(im: Image, x: int) -> int:
	var edges := PackedInt32Array()
	for y in range(0, im.get_height()*2/3):
		edges.append(difference(im.get_pixel(x-1,y), im.get_pixel(x,y)))
	edges.sort()
	return edges[floori((edges.size()-1)*0.99)]

func contrast(im: Image, centre: float, row := 0.5) -> float:
	var x := roundi(centre*im.get_width())
	var half_width := roundi(im.get_width()*0.08)
	var y := roundi(im.get_height()*row)
	var sum := 0.0
	var squares := 0.0
	for dx in range(-half_width, half_width):
		var red := im.get_pixel(x+dx,y).r
		sum += red
		squares += red*red
	var count := half_width*2.0
	return sqrt(maxf(0.0, squares/count - pow(sum/count, 2)))

func panels(host: Node3D, cam: Camera3D) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	render_mode unshaded, fog_disabled, cull_disabled;
	void fragment() {
		float wave = cos(UV.x*6.283185*28.0);
		ALBEDO = mix(vec3(0.035), vec3(0.79), smoothstep(-0.25, 0.25, wave));
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var aspect := root.size.x/float(root.size.y)
	for i in 3:
		var depth: float = [2.0, 8.0, 70.0][i]
		var height := depth*2.0*tan(deg_to_rad(cam.fov*0.5))
		var quad := QuadMesh.new()
		quad.size = Vector2(height*aspect*0.25, height*0.46)
		var panel := MeshInstance3D.new()
		panel.mesh = quad
		panel.material_override = material
		host.add_child(panel)
		panel.position = Vector3((i-1)*0.32*height*aspect, 0.0, -depth)

func add_block(host: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var block := MeshInstance3D.new()
	block.mesh = box
	block.material_override = material
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(block)
	block.position = pos

func chart_ratio(im: Image, clear: Image, point: Vector2) -> float:
	var ref := contrast(clear,point.x,point.y)
	return contrast(im,point.x,point.y)/ref if ref > 0.12 else -1.0

# At parkour's 33 degree pitch, the low ground is optically farther than
# the athlete. A tilt defined on the tabletop still puts it in front of focus.
func pitched_cards() -> PackedFloat32Array:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"ink": false, "grade": false})
	var target := Node3D.new()
	host.add_child(target)
	var cam := TLOrbitCam.new()
	host.add_child(cam)
	cam.setup(target, {"distance": 6.0, "pitch": 33.0, "look_height": 0.0, "fov": 57.0})
	cam.make_current()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	render_mode unshaded, fog_disabled, cull_disabled;
	void fragment() { ALBEDO=vec3(0.42+0.36*cos(FRAGCOORD.x*1.55)); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for point: Vector3 in [Vector3(0.29,0.56,6.1), Vector3(0.7,0.40,7.0), Vector3(0.50,0.95,7.4)]:
		var half_height := point.z*tan(deg_to_rad(cam.fov*0.5))
		var half_width := half_height*root.size.x/float(root.size.y)
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(3.15,0.53)
		panel.mesh = quad
		panel.material_override = mat
		cam.add_child(panel)
		panel.position = Vector3((2.0*point.x-1.0)*half_width,(1.0-2.0*point.y)*half_height,-point.z)
	var focused := await photo()
	cam.attributes = CameraAttributesPractical.new()
	var clear := await photo()
	var vista := Camera3D.new()
	host.add_child(vista)
	vista.fov = cam.fov
	vista.global_transform = cam.global_transform
	vista.make_current()
	var scenic := await photo()
	var ratios := PackedFloat32Array()
	for point: Vector2 in [Vector2(0.29,0.56),Vector2(0.7,0.40),Vector2(0.5,0.95)]:
		ratios.append(chart_ratio(focused,clear,point))
	for point: Vector2 in [Vector2(0.29,0.56),Vector2(0.5,0.95)]:
		ratios.append(chart_ratio(scenic,clear,point))
	host.free()
	return ratios

func shade_at(cam: Camera3D, a: Image, b: Image, p: Vector3) -> float:
	var pixel := Vector2i(cam.unproject_position(p).round())
	var delta := 0.0
	for dx in range(-1,2):
		for dy in range(-1,2):
			var at := pixel+Vector2i(dx,dy)
			var change := b.get_pixelv(at)-a.get_pixelv(at)
			delta += (change.r+change.g+change.b)*255.0/27.0
	return delta

# Look down the road with the key behind the camera. A cream roll still
# needs highlight detail here, including after the visitor's optical pass.
func cotton_highlights() -> Vector2i:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"ink": false})
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.fov = 60
	var pitch := deg_to_rad(-12.6)
	cam.look_at(Vector3(cos(pitch),sin(pitch),0))
	var optics := CameraAttributesPractical.new()
	optics.dof_blur_far_enabled = true
	optics.dof_blur_far_distance = 13
	optics.dof_blur_far_transition = 39
	optics.dof_blur_amount = 0.023
	cam.attributes = optics
	cam.make_current()
	var wool := await photo()
	var world: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	world.environment.sky.sky_material.set_shader_parameter("cloud_scale", 0.0)
	var backing := await photo()
	var counts := Vector2i.ZERO
	for y in range(0,wool.get_height()/5,2):
		for x in range(wool.get_width()/5,4*wool.get_width()/5,2):
			var color := wool.get_pixel(x,y)
			if difference(color,backing.get_pixel(x,y)) > 16:
				counts.x += 1
				if color.r8 >= 254 and color.g8 >= 254:
					counts.y += 1
	host.free()
	return counts

# Isolate contact by disabling cast shadows. Measure the actual receiving
# ground, 6 cm in front of the post and again 1.38 m from its face.
func contact() -> Vector4:
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"grade": false})
	var world: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	world.environment.glow_enabled = false
	world.environment.fog_enabled = false
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.67, 0.58, 0.48)
	add_block(host,Vector3(0,-0.1,0),Vector3(25,0.2,25),clay)
	add_block(host,Vector3(0,0.8,0),Vector3(0.85,1.6,0.85),clay)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.fov = 41
	cam.look_at_from_position(Vector3(2.6,2.3,5.4),Vector3(0,0.5,0))
	cam.attributes = CameraAttributesPractical.new()
	cam.make_current()
	var shaded := await photo()
	host.get_node("TLStyleRig/InkPost").material_override.set_shader_parameter("ao_k",0.0)
	var control := await photo()
	var delta := Vector4(shade_at(cam,shaded,control,Vector3(0,0,0.485)),shade_at(cam,shaded,control,Vector3(0,0,1.8)),0,0)
	var views := TLCameras.new()
	host.add_child(views)
	var top := views.add_view(&"table",Vector3(0,14,1.2),Vector3.ZERO,45)
	views.activate(&"table")
	var on_table := await photo()
	host.get_node("TLStyleRig/InkPost").material_override.set_shader_parameter(&"tabletop_opacity",0.0)
	var bare := await photo()
	delta.z = shade_at(top,on_table,bare,Vector3(0.7,0,0))
	delta.w = shade_at(top,on_table,bare,Vector3(4.2,0,0))
	host.free()
	return delta

func test() -> void:
	# The near-rail and pitched-card assertions below measure the original tilt
	# prescription. The shipping small-aperture optics have their own ruler (620).
	TLStyle.ensure()
	TLStyle.data.env.miniature_lens = {"amount": 0.023, "tilt_deg": -15.0, "near_px": 5.0, "far_px": 1.5,
		"vista_near": 27.0, "vista_far": 125.0, "vista_transition": 180.0, "vista_amount": 0.013}
	var host := Node3D.new()
	root.add_child(host)
	TLStyle.install(host, {"ink": false, "grade": false})
	var world: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	var west := Camera3D.new()
	host.add_child(west)
	west.fov = 53
	west.look_at(Vector3(-cos(deg_to_rad(14)), sin(deg_to_rad(14)), 0))
	west.make_current()
	var sky := await photo()
	var middle := sky.get_width()/2
	var seam := edge_p99(sky, middle)
	var nearby := maxi(edge_p99(sky, middle-10), edge_p99(sky, middle+10))
	world.environment.sky.sky_material.set_shader_parameter(&"cloud_scale", 0.0)
	var empty_sky := await photo()
	var cotton := 0
	for y in range(0, sky.get_height(), 4):
		for x in range(0, sky.get_width(), 4):
			if difference(sky.get_pixel(x,y), empty_sky.get_pixel(x,y)) > 10:
				cotton += 1
	var ok := seam <= maxi(12, nearby*2 + 2) and cotton > 100
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.34,0.34,0.34)
	world.environment.fog_enabled = false
	world.environment.glow_enabled = false
	var target := Visitor.new()
	host.add_child(target)
	target.position.z = -8
	var cam := preload("res://kernel/world/terrain/crown_camera.gd").new()
	host.add_child(cam)
	cam.setup(target, {"distance":8.0, "height":0.0, "look_height":0.0})
	cam.set_physics_process(false)
	cam.fov = 60
	cam.make_current()
	panels(host, cam)
	var on_foot := await photo()
	target.flying = true
	var flight := await photo()
	target.flying = false
	cam.attributes = CameraAttributesPractical.new()
	var reference := await photo()
	var ratios := PackedFloat32Array()
	for x: float in [0.18, 0.5, 0.82]:
		var reference_contrast := contrast(reference, x)
		ok = ok and reference_contrast > 0.15
		ratios.append(contrast(on_foot,x)/maxf(0.001, reference_contrast))
	var flight_error := 0
	for y in range(0, reference.get_height(), 4):
		for x in range(0, reference.get_width(), 4):
			flight_error = maxi(flight_error, difference(flight.get_pixel(x,y), reference.get_pixel(x,y)))
	ok = ok and ratios[0] < 0.82 and ratios[2] < 0.82 and absf(ratios[1]-1.0) < 0.025 and flight_error <= 1
	host.free()
	var shade := await contact()
	ok = ok and shade.x > 5.0 and absf(shade.y) <= 1.0
	ok = ok and shade.z > 5.0 and absf(shade.w) <= 1.0
	var pitched := await pitched_cards()
	ok = ok and absf(pitched[0]-1.0)<0.035 and absf(pitched[1]-1.0)<0.035 and pitched[2]>=0.0 and pitched[2]<0.82
	ok = ok and absf(pitched[3]-1.0)<0.035 and pitched[4]>=0.0 and pitched[4]<0.82
	var wool := await cotton_highlights()
	ok = ok and wool.x > 400 and wool.y < wool.x*0.06
	print("FRAME571 ", "ok" if ok else "FAIL", " west_p99=",seam," nearby=",nearby,
		" cloud_samples=",cotton," wool_drawn_clipped=",wool," contrast=",ratios," flight_delta=",flight_error," contact_delta=",shade," pitched=",pitched)
	quit(0 if ok else 1)
GDSCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    frame_engine="$(cygpath -m "$frame_engine")"
    frame_script="$(cygpath -m "$frame_script")"
  fi
  frame_log="$OUT/frame_571.log"
  frame_status=0
  (cd "$frame_engine/.." && MSYS_NO_PATHCONV=1 TL_STYLE=diorama node --input-type=module - "$frame_engine" "$frame_script" <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const [engine, script] = process.argv.slice(2);
const run = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "960x540", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", engine, "--script", script, "--quit-after", "210"], { stdio: "inherit", timeout: 120000 });
const result = process.env.TL_WINDOW_LOCK === "off" ? run() : withWindowLock(run);
process.exitCode = result.status ?? 1;
NODE
  ) > "$frame_log" 2>&1 || frame_status=$?
  frame_line="$(grep -a '^FRAME571 ok ' "$frame_log" | tr -d '\r')"
  frame_error=""
  if [ "$frame_status" != 0 ] || [ -z "$frame_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$frame_log"; then
    frame_error="engine exit $frame_status; see $frame_log"
  fi
  verdict style.frame.pixels "$frame_error" "${frame_line#FRAME571 ok }"
fi
