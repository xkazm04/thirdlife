extends SceneTree
## Run with block 718. Only the deliberately misspelled palette key should log an error.

var failed := false


func _initialize() -> void:
	run.call_deferred()


func check(id: String, ok: bool) -> void:
	print("HUD %s %s" % [id, "PASS" if ok else "FAIL"])
	failed = failed or not ok


func run() -> void:
	var ctx := TLContext.new()
	ctx.manifest = {"capabilities": ["ui", "camera"]}
	ctx.cameras = TLCameras.new()
	root.add_child(ctx.cameras)
	var previous := TLContext.enter(ctx)
	var camera := ctx.cameras.add_view(&"front", Vector3.ZERO, Vector3.FORWARD)
	var hud := TLHud.create()
	root.add_child(hud)
	TLContext.leave(previous)
	var target := Node3D.new()
	root.add_child(target)
	target.rotation.y = PI / 2
	var offset := Vector3(0.5, 1.2, 0.75)
	target.position = Vector3(0, 0, -8) - target.basis * offset
	hud.add_label(&"note", "Guard")
	var note := hud.get_node("note") as Label
	hud.set_color(&"note", Color.CORAL)
	check("color_direct", note.get_theme_color("font_color") == Color.CORAL)
	hud.add_tag(&"cue", target, "HEAVY", offset)
	var cue := hud.get_node("cue") as Label
	hud.set_plate(&"cue")
	hud.set_color(&"cue", &"car_red")
	var red := TLStyle.color("car_red")
	check("color_palette", cue.get_theme_color("font_color") == red)
	hud.set_color(&"cue", "r4_missing_ink")
	check("color_bad", cue.get_theme_color("font_color") == red)
	var catalog := [{"id": "next", "title": "Next", "form": "cue", "anchor": "top", "sample": {"value": "Swing"}}]
	var configured := hud.configure_widgets(catalog, {"theme": "relay"})
	check("color_theme", configured and cue.get_theme_color("font_color") == red and note.get_theme_color("font_color") == Color.CORAL)
	hud.set_color(&"cue", &"")
	check("color_reset", cue.get_theme_color("font_color") == hud._stock.colors("relay").paper)
	hud._physics_process(0)
	hud._process(0)
	var centre := root.get_visible_rect().get_center()
	var box := cue.get_global_rect()
	check("tag_front", cue.visible and absf(box.get_center().x - centre.x) <= 1 and absf(box.end.y - centre.y) <= 1)
	target.position.x = 50
	hud._process(0)
	check("tag_offscreen", not cue.visible)
	target.position = Vector3.BACK * 4.0
	hud._process(0)
	check("tag_behind", not cue.visible)
	ctx.cameras.add_view(&"reverse", Vector3.ZERO, Vector3.BACK)
	ctx.cameras.activate(&"reverse")
	camera.current = true   # The viewport's camera differs from the pack's selected view.
	hud.set_text(&"cue", "PARRY")
	hud._process(0)
	check("tag_view", cue.visible and hud.text_of(&"cue") == "PARRY" and cue.has_theme_stylebox_override("normal"))
	TLHud.hide_all(ctx)
	hud._process(0)
	check("tag_offstage", not cue.is_visible_in_tree())
	hud.visible = true
	target.free()
	hud._process(0)
	check("tag_freed", not cue.visible)
	hud.remove_widget(&"cue")
	hud.remove_widget(&"note")
	check("tag_remove", not hud.has_node("cue") and not hud.has_node("note") and hud.text_of(&"cue").is_empty())
	quit(1 if failed else 0)
