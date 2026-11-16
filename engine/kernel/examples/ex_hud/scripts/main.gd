extends Node
## Primitive example (K5): HUD text over a busy picture. A kit rink (lines, circles, boards) with skaters, seen from the
## hockey pack's play camera (0, 52, 14), fov 55. On the right a three-line panel on a plate with its lines centred
## (TLHud.set_plate, set_align); on the left the same three lines without a plate, as every HUD had them; at the bottom
## a plated note whose text grows by a line every 40 frames up to four lines: it grows upwards, its bottom edge stays.

const PANEL: String = "RULE DIAL\n> Skate speed +0\nA/D choose   W/S one step   T close"
var ctx
var hud: TLHud
var ticks: int = 0


func _pack_setup(c) -> void:
	ctx = c
	ctx.root.add_child(TLKit.build("rink", {"length": 60, "width": 30}))
	for i: int in 6:
		var sk: TLBiped = TLBiped.create({"mode": "skate", "position": Vector3(-20.0 + float(i) * 8.0, 0.1, -8.0 + float(i % 3) * 8.0),
			"name": "Skater%d" % i, "facing": float(i)})
		ctx.root.add_child(sk)
	ctx.cameras.add_view(&"play", Vector3(0, 52, 14), Vector3(0, 0, 0), 55.0)
	hud = TLHud.create()
	ctx.root.add_child(hud)
	hud.add_label(&"bare", PANEL, &"left")
	hud.add_label(&"panel", PANEL, &"right")
	hud.set_plate(&"panel")
	hud.set_align(&"panel", &"center")
	hud.add_bound(&"note", _note, &"bottom")
	hud.set_plate(&"note")
	hud.set_align(&"note", &"center")


func _note() -> String:
	var lines: PackedStringArray = PackedStringArray(["Level: Classic | Mode: Three against three"])
	for i: int in mini(3, ticks / 40):
		lines.append("a longer note, line %d" % (i + 2))
	return "\n".join(lines)


func _pack_start() -> void:
	pass


func _pack_tick(_frame: int) -> void:
	ticks += 1


func _pack_state() -> Dictionary:
	return {"ticks": ticks, "note": hud.text_of(&"note"), "panel": hud.text_of(&"panel")}
