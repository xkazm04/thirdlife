extends "res://ui/drive.gd"
## Windowed recording take. Only mouse events change the layout or write the selected game.
func start(the_host: Control, _what: String, shots_dir: String) -> void:
	host = the_host
	shots = shots_dir
	t0 = Time.get_unix_time_from_system()
	slow = true
	DirAccess.make_dir_recursive_absolute(shots)
	var desk = host.get("hud_workshop")
	if desk == null or desk.read_only or desk.model.catalog.is_empty():
		note("read", "Open an editable Timber Run pack with --hud-pack.")
		get_tree().quit(1)
		return
	var proof_view = desk._proof
	if not proof_view.sheet.cards.has("next"):
		note("read", "This take uses Timber Run's next-move widget.")
		get_tree().quit(1)
		return
	await frames(30)
	var cue: Control = proof_view.sheet.cards.next
	var end: Vector2 = proof_view.get_global_transform() * (proof_view.size * Vector2(0.50, 0.88))
	await drag(cue.get_global_rect().get_center(), end, "the next move to bottom centre")
	await frames(15)
	await click("Size_large", "large next move")
	await frames(15)
	await click("Theme_relay", "Relay blue ink")
	await frames(20)
	await click("Visible_controls", "hide the control legend")
	await frames(12)
	await click("SaveLayout", "save the layout with Timber Run")
	var actual: Dictionary = proof_view.sheet.settings
	var ok: bool = actual.next.anchor == "bottom" and actual.next.size == "large" and not actual.controls.visible \
		and desk.model.saved.get("theme") == "relay" and not desk.model.dirty() and not failed
	note("read", "saved take: " + ("PASS" if ok else "FAIL"))
	await frames(30)
	get_tree().quit(0 if ok else 1)
