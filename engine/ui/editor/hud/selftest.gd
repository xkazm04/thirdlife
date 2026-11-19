extends SceneTree
## Exercised by block 550 on a scratch copy of the pack.
const Workshop = preload("res://ui/editor/hud/workshop.gd")
const Model = preload("res://ui/editor/hud/model.gd")
const Layout = preload("res://style/hud/layout.gd")
const Stock = preload("res://style/hud/stock.gd")
var failed := 0
var viewport := SubViewport.new()

func _initialize() -> void:
	_run.call_deferred()

func _case(id: String, ok: bool) -> void:
	print("HUDCASE %s %s" % [id, "PASS" if ok else "FAIL"])
	if not ok:
		failed += 1

func _mouse(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	viewport.push_input(e, true)

func _click(screen: Control, id: String) -> void:
	var b := screen.find_child(id, true, false) as Button
	var pos := b.get_global_rect().get_center()
	_mouse(pos, true)
	_mouse(pos, false)
	await process_frame

func _run() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	viewport.size = Vector2i(1280,720)
	root.add_child(viewport)
	var screen := Workshop.new()
	screen.setup([{"dir": dir, "title": "Timber Run", "id": "game.parkour"}], false)
	viewport.add_child(screen)
	for i: int in 3:
		await process_frame
	var proof = screen._proof
	var card: Control = proof.sheet.cards.next
	var start := card.get_global_rect().get_center()
	var end: Vector2 = proof.get_global_transform() * (proof.size * Vector2(0.50, 0.9))
	_mouse(start, true)
	var drag := InputEventMouseMotion.new()
	drag.position = end
	drag.relative = end - start
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(drag, true)
	_mouse(end, false)
	await process_frame
	var dragged: bool = proof.sheet.settings.next.anchor == "bottom"
	await _click(screen, "Size_large")
	await _click(screen, "Theme_relay")
	await _click(screen, "Visible_controls")
	await _click(screen, "SaveLayout")
	var reopened := Model.new()
	var error := reopened.open_game(dir)
	var settings := Layout.resolved(reopened.catalog, reopened.profile)
	var saved: bool = error == "" and dragged and not screen.model.dirty() and reopened.profile.get("theme") == "relay" \
		and settings.next.size == "large" and settings.next.anchor == "bottom" and not settings.controls.visible
	if not saved:
		print("HUD editor: window=%s proof=%s drag=%s -> %s, moved=%s, selected=%s, draft=%s, disk=%s, status=%s" %
			[viewport.size, proof.get_global_rect(), start, end, dragged, screen.selected, screen.model.profile, reopened.profile, screen._message.text])
	_case("editor_save", saved)

	await _click(screen, "Phase_finish")
	var at_finish: bool = proof.sheet.cards.finish.visible and not proof.sheet.cards.next.visible
	await _click(screen, "Anchor_right")
	await _click(screen, "Phase_run")
	var unsaved: bool = screen.model.dirty() and reopened.profile != screen.model.profile
	screen.queue_free()
	await process_frame

	var strict := true
	for bad: Variant in [{"colour": "red"}, {"widgets": [{"id": "stage", "opacity": 1}]},
			{"widgets": [{"id": "nowhere"}]}, {"widgets": [{"id": "split"}, {"id": "split"}]},
			{"widgets": [{"id": "finish", "visible": 1}]}, {"theme": "unknown"},
			{"widgets": [{"id": "next", "anchor": "under"}]}, {"widgets": [{"id": "stage", "size": null}]}]:
		strict = strict and Layout.check_profile(bad, reopened.catalog) != ""
	var bad_specs := reopened.catalog.duplicate(true)
	bad_specs[0].sample.typo = "bad"
	_case("strict_data", strict and Layout.check_catalog(bad_specs) != "")

	var hud := TLHud.new()
	viewport.add_child(hud)
	var applied := hud.configure_widgets(reopened.catalog, reopened.profile)
	for spec: Dictionary in reopened.catalog:
		hud.set_readout(spec.id, spec.sample)
	var sheet = hud._sheet
	var placed := applied and at_finish and unsaved
	for extent: Vector2 in [Vector2(1280,720), Vector2(1920,1080)]:
		sheet.size = extent
		sheet.arrange()
		var cue: Control = sheet.cards.next
		var box := Rect2(cue.position, cue.size * cue.scale)
		var k := extent.y / 720.0
		placed = placed and absf(box.get_center().x - extent.x / 2) < 1 \
			and absf(extent.y - box.end.y - 19 * k) <= 1 and is_equal_approx(cue.scale.x, 1.22 * k) \
			and cue.inks.accent == Stock.colors("relay").accent and not sheet.cards.controls.visible
	hud.set_phase(&"finish")
	_case("layout_applies", placed and sheet.cards.finish.visible and not sheet.cards.next.visible)
	hud.queue_free()
	await process_frame
	var context := TLContext.new()
	context.instance = "parkour"
	context.manifest = {"capabilities": ["ui"]}
	var previous := TLContext.enter(context)
	var world_hud := TLHud.create()
	TLContext.enter(previous)
	viewport.add_child(world_hud)
	world_hud.configure_widgets(reopened.catalog, reopened.profile)
	for spec: Dictionary in reopened.catalog:
		world_hud.set_readout(spec.id, spec.sample)
	world_hud.add_label(&"score", "Blue 1", &"top_right")
	world_hud.add_label(&"hint", "Ready", &"bottom_left")
	world_hud._physics_process(0)
	var split: Control = world_hud._sheet.cards.split
	var progress: Control = world_hud._sheet.cards.checkpoints
	var score: Label = world_hud.get_node("score")
	var hint: Label = world_hud.get_node("hint")
	var lower_edge := float(viewport.size.y - 64)
	_case("village_clearance", split.position.y >= 36 and progress.position.y + progress.size.y * progress.scale.y <= lower_edge
		and score.position.y >= 36 and hint.position.y + hint.size.y * hint.scale.y <= lower_edge)
	world_hud.queue_free()
	await process_frame
	quit(1 if failed else 0)
