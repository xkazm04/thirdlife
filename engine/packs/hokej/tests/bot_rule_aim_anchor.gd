extends Node
## Rule: thirdjam's aim anchor (FJamAimAnchor::Step, S/JamGame/Private/InputMapping.cpp:1113-1127; jam.ctrl.AimAnchor 1,
## AimAnchorSpeed 0.3): while the cursor's PIXEL has not moved half a pixel and the skater stands (under 0.3 m/s), the
## aimed point keeps its offset from him, whatever the camera does to the cursor's point on the ice; a moving pixel, a
## skating skater, or no pixel at all re-project every step. Kernel 1.17's aim pixel (`set_aim`'s `pixel`) plays the hand.
##   A 0..29     pixel (600, 300), point 2 m ahead (+x)                      -> the stick points +x
##   B 30..59    the same pixel, the point moved to 2 m +y (a camera turn)   -> anchored: the stick still points +x
##   C 60..89    the pixel moves to (610, 300), the point stays +y            -> re-projected: the stick points +y
##   D 90..119   no pixel (a constant (-1, -1) to the core), the point 2 m -y  -> re-projected on the change: the stick points -y
##   E 120..179  W held (he skates), the pixel still, the point +x of him     -> not anchored once he moves 0.3 m/s

var ctx
var fails: Array = []
var seen: Dictionary = {}
var done: bool = false


func _bot_setup(c) -> void:
	ctx = c


func _check(tag: String, s: Dictionary, want: Vector2, anchored: bool) -> void:
	var st: Vector2 = Vector2(float(s["stick_x"]), float(s["stick_y"]))
	var ok: bool = st.length() > 0.4 and st.normalized().dot(want) > 0.999   # `anchored`: shown by the direction itself (B holds +x)
	seen[tag] = int(seen.get(tag, 0)) + 1
	if not ok:
		fails.append("%s f%d stick (%.3f, %.3f)" % [tag, int(s["frame"]), st.x, st.y])


func _bot_tick(frame: int) -> void:
	if frame == 0:
		ctx.input.press(&"gym")          # the control rules are tested on the gym (one skater, empty ice)
		return                           # no cursor yet: the gym places him at the drop on this frame (a point read now would be stale)
	var s: Dictionary = ctx.pack_state()
	var me := Vector3(float(s["x"]), 0.0, float(s["y"]))
	# what the game showed after the last frame: the stick of frame - 1
	var f: int = frame - 1
	if f >= 5 and f < 30:
		_check("A", s, Vector2(1, 0), true)
	elif f >= 31 and f < 60:
		_check("B", s, Vector2(1, 0), true)
	elif f >= 60 and f < 90:
		_check("C", s, Vector2(0, 1), f > 60)
	elif f >= 90 and f < 120:
		_check("D", s, Vector2(0, -1), false)
	elif f >= 150 and f < 180:
		if float(s["speed"]) >= 0.3:
			_check("E", s, Vector2(1, 0), false)
	ctx.input.release(&"k_w")
	if frame < 30:
		ctx.input.set_aim(&"aim", me + Vector3(2, 0, 0), Vector2(600, 300))
	elif frame < 60:
		ctx.input.set_aim(&"aim", me + Vector3(0, 0, 2), Vector2(600, 300))
	elif frame < 90:
		ctx.input.set_aim(&"aim", me + Vector3(0, 0, 2), Vector2(610, 300))
	elif frame < 120:
		ctx.input.set_aim(&"aim", me + Vector3(0, 0, -2))
	elif frame < 180:
		ctx.input.press(&"k_w")
		ctx.input.set_aim(&"aim", me + Vector3(2, 0, 0), Vector2(610, 300))
	done = frame >= 180


func _bot_done() -> bool:
	return done


func _bot_result() -> Dictionary:
	var ok: bool = done and fails.is_empty() and seen.size() == 5
	return {"ok": ok, "summary": "phases checked %s%s" % [str(seen), "" if fails.is_empty() else "; " + ", ".join(fails.slice(0, 6))], "frames": ctx.frame}
