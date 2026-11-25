extends RefCounted
# Rink core: the scripted raw hand of rink_rawhand.gd and rink_rawtrace.gd (one place, so the recorded sample and the selftest
# play the same hand). raw_at(frame, snapshot) is what RinkCore.set_raw_input takes for that frame.

# The hand: skate forward and turn by the camera, LMB held 20 frames every 3 s, RMB tapped every 4 s and held 20 frames
# every 7 s (a saucer), sprint 2 s of every 5, poke every 2.5 s, spin and ability now and then, signals 1 and 3.
static func raw_at(f: int, s: Dictionary) -> Dictionary:
	var down: PackedStringArray = []
	var pressed: PackedStringArray = []
	var hold := func(key: String, on: bool, start: bool) -> void:
		if on:
			down.append(key)
		if start:
			pressed.append(key)
	hold.call("LeftMouseButton", f % 180 < 20, f % 180 == 0)
	hold.call("RightMouseButton", (f % 240 < 2) or (f % 420 >= 100 and f % 420 < 120), f % 240 == 0 or f % 420 == 100)
	hold.call("LeftShift", f % 300 < 120, f % 300 == 0)
	hold.call("SpaceBar", f % 150 == 75, f % 150 == 75)
	hold.call("E", f % 900 == 450, f % 900 == 450)
	hold.call("F", f % 1200 == 600, f % 1200 == 600)
	hold.call("One", f % 1000 == 300, f % 1000 == 300)
	hold.call("Three", f % 1000 == 800, f % 1000 == 800)
	var me: Dictionary = s["Skaters"][int(s["HumanIndex"])] if s.has("Skaters") else {}
	var yaw: float = float(me.get("Yaw", 0.0))
	var pos: Vector2 = me.get("Pos", Vector2.ZERO)
	var axis := Vector2(sin(f * 0.01) * 0.6, 1.0 if f % 600 < 500 else -1.0)
	var aim := pos + Vector2(cos(yaw + 0.4 * sin(f * 0.05)), sin(yaw + 0.4 * sin(f * 0.05))) * 2.5
	return {"Down": down, "Pressed": pressed, "Axis": axis, "CameraYaw": yaw, "CursorOnIce": true,
		"CursorPx": Vector2(640 + 100 * sin(f * 0.05), 360), "CursorHitM": aim, "MouseDeltaPx": Vector2.ZERO, "StickAxis": Vector2.ZERO}
