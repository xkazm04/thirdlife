# Exercise the installed rig, including switching a live host back to classic.
# The dummy renderer supplies resource properties. Pixel checks use a real window.
if [ -z "$FILTER" ] || [[ "style.frame.rig" == *"$FILTER"* || "style.frame.focus" == *"$FILTER"* ]]; then
  frame_engine="$(cd "$HERE/.." && pwd)"
  frame_script="$OUT/frame_570.gd"
  cat > "$frame_script" <<'GDSCRIPT'
extends SceneTree

class VisitorTarget extends Node3D:
	var flying := false

func _initialize() -> void:
	call_deferred("test")

func test() -> void:
	TLStyle.set_headless(false)
	var host := Node3D.new()
	root.add_child(host)
	var issues := TLStyle.load_style("res://style/style_diorama.json")
	# This case exercises the tracked tilt prescription, including live style switches.
	# Keep testing those optics after the day style moved to a distant-only aperture.
	TLStyle.data.env.miniature_lens = {"amount": 0.023, "tilt_deg": -15.0, "near_px": 5.0, "far_px": 1.5,
		"vista_near": 27.0, "vista_far": 125.0, "vista_transition": 180.0, "vista_amount": 0.013}
	TLStyle.install(host)
	var we: WorldEnvironment = host.get_node("TLStyleRig/WorldEnvironment")
	var sun: DirectionalLight3D = host.get_node("TLStyleRig/Sun")
	var post: MeshInstance3D = host.get_node("TLStyleRig/InkPost")
	var lens := we.get_node("MiniatureLens") as TLStyleFx.MiniatureLens
	var installed := issues.is_empty() and sun.light_angular_distance > 0.0
	installed = installed and we.environment.sky.sky_material.shader.resource_path.ends_with("/sky_cotton.gdshader")
	installed = installed and post.material_override.shader.resource_path.ends_with("/ink_post_contact.gdshader")
	installed = installed and we.camera_attributes == lens.optics
	installed = installed and lens.aperture.shader.resource_path.ends_with("/dof_tilt.gdshader")
	TLStyle.install(host)
	installed = installed and lens == we.get_node("MiniatureLens") and we.get_child_count() == 1

	var actor := VisitorTarget.new()
	host.add_child(actor)
	var chase := preload("res://kernel/world/terrain/crown_camera.gd").new()
	host.add_child(chase)
	chase.setup(actor, {"distance": 8.0, "height": 3.0})
	chase.make_current()
	lens._process(0)
	var optics := lens.optics
	var depth := chase._miniature_focus().x
	var focus := depth > 7.0 and lens.visible and optics.dof_blur_near_enabled and optics.dof_blur_far_enabled
	focus = focus and optics.dof_blur_near_distance < depth and optics.dof_blur_far_distance > depth + 2.0
	var long_near := optics.dof_blur_near_distance
	# Simulate a wall pull on the same camera, keeping its nominal arm length.
	chase.global_position = actor.global_position + Vector3(0, 1.5, 2.5)
	lens._process(0)
	focus = focus and optics.dof_blur_near_distance < long_near - 2.0
	actor.flying = true
	lens._process(0)
	focus = focus and not lens.visible and not optics.dof_blur_near_enabled and not optics.dof_blur_far_enabled
	actor.flying = false
	lens._process(0)
	focus = focus and optics.dof_blur_near_enabled and optics.dof_blur_far_enabled

	var orbit := TLOrbitCam.new()
	host.add_child(orbit)
	orbit.setup(actor, {"distance": 5.5})
	orbit.make_current()
	lens._process(0)
	focus = focus and is_equal_approx(orbit._miniature_focus().x, 5.5)
	focus = focus and optics.dof_blur_near_distance < 5.5 and optics.dof_blur_far_distance > 8.5
	orbit.attributes = CameraAttributesPractical.new()
	lens._process(0)
	focus = focus and not lens.visible
	var overview := Camera3D.new()
	host.add_child(overview)
	overview.make_current()
	lens._process(0)
	focus = focus and not optics.dof_blur_near_enabled and optics.dof_blur_far_distance >= 85.0
	focus = focus and optics.dof_blur_amount < float(lens.settings["amount"])
	var views := TLCameras.new()
	host.add_child(views)
	views.add_view(&"arena", Vector3(0,45,6), Vector3.ZERO)
	views.set_subject(&"arena", actor)
	views.activate(&"arena")
	lens._process(0)
	focus = focus and not optics.dof_blur_near_enabled and not optics.dof_blur_far_enabled
	print("FRAME570 focus ", "ok" if focus else "FAIL")

	# The table light follows the fixed view independently of the lens. A
	# side view restores the real cast; a reviewer's shadows-off stays off.
	TLStyle.data.env.erase("miniature_lens")
	TLStyle.install(host)
	installed = installed and not we.has_node("MiniatureLens") and not sun.shadow_enabled
	installed = installed and bool(post.material_override.get_shader_parameter(&"tabletop"))
	var reach: float = TLStyle.data.ink.tabletop_reach
	TLStyle.data.ink.tabletop_opacity = 0.25
	TLStyle.install(host)
	installed = installed and is_equal_approx(post.material_override.get_shader_parameter(&"tabletop_opacity"),0.25)
	TLStyle.data.ink.erase("tabletop_opacity")
	TLStyle.data.ink.erase("tabletop_reach")
	TLStyle.install(host)
	installed = installed and sun.shadow_enabled and not bool(post.material_override.get_shader_parameter(&"tabletop"))
	installed = installed and is_equal_approx(post.material_override.get_shader_parameter(&"tabletop_opacity"),0.47)
	TLStyle.data.ink.tabletop_reach = reach
	TLStyle.install(host)
	installed = installed and not sun.shadow_enabled
	views.add_view(&"bench", Vector3(0, 3, 15), Vector3.ZERO)
	views.activate(&"bench")
	post.call("_process", 0)
	installed = installed and sun.shadow_enabled and not bool(post.material_override.get_shader_parameter(&"tabletop"))
	sun.shadow_enabled = false
	post.call("_process", 0)
	installed = installed and not sun.shadow_enabled
	views.activate(&"arena")
	TLStyle.install(host)
	installed = installed and not sun.shadow_enabled
	TLStyle.load_style("res://style/style.json")
	TLStyle.install(host)
	var classic := we.camera_attributes == null and not we.has_node("MiniatureLens")
	classic = classic and is_zero_approx(sun.light_angular_distance) and is_equal_approx(sun.shadow_normal_bias, 1.4)
	classic = classic and we.environment.sky.sky_material.shader.resource_path.ends_with("/sky.gdshader")
	classic = classic and post.material_override.shader.resource_path.ends_with("/ink_post.gdshader")
	classic = classic and sun.shadow_enabled and not post.is_processing()
	print("FRAME570 rig ", "ok" if installed and classic else "FAIL")
	host.free()
	quit(0 if installed and classic and focus else 1)
GDSCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    frame_engine="$(cygpath -m "$frame_engine")"
    frame_script="$(cygpath -m "$frame_script")"
  fi
  frame_log="$OUT/frame_570.log"
  frame_status=0
  MSYS_NO_PATHCONV=1 timeout 90 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
    --headless --path "$frame_engine" --script "$frame_script" > "$frame_log" 2>&1 || frame_status=$?
  for frame_case in focus rig; do
    frame_error=""
    grep -aq "^FRAME570 $frame_case ok" "$frame_log" || frame_error="no passing $frame_case line"
    if [ "$frame_status" != 0 ] || grep -aEq 'SCRIPT ERROR|^ERROR:' "$frame_log"; then
      frame_error="engine exit $frame_status; see $frame_log"
    fi
    verdict "style.frame.$frame_case" "$frame_error"
  done
fi
