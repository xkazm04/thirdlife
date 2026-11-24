extends RefCounted
## thirdjam's distance badges (UpdateMarker cpp:1724-1805, UpdateOwnMarker cpp:1952-2000, ApplyOwnLabelRule HUDOneLine.cpp:32-59,
## UpdatePuckMarker cpp:1306-1368), the edge-slot rule (ResolveEdgeSlots cpp:1374-1465) and the label plates
## (UpdateLabelPlates cpp:1284-1304, one look HUDOneLook.cpp:95-98). Groups are dictionaries; build() places, paint() draws.

const R := preload("rules.gd")

var hud                       # hud.gd (its layer, its rink and team colours, its `shown`)
var lay
var puck_alpha: float = 0.0
var puck_last_frame: int = -1


func _init(owner) -> void:
	hud = owner
	lay = owner.lay


func col(team: int) -> Color:
	return hud.col(team)


# ---------------------------------------------------------------- the markers: each a group {parts...}
func build(snap: Dictionary, phase: String, hpos: Vector2, attack: float, carrier: int, puck_pos: Vector2, vw: float, vh: float,
		panel_top: float, covered: bool, paused: bool, advanced: bool, f: int) -> Array:
	var groups: Array = []
	var badges: bool = R.show_net_badges(phase)
	# ---- the far net (UpdateMarker cpp:1724-1805), 1.2 m over the crossbar
	var net2 := Vector2(attack * (hud.length_m * 0.5 - R.NET_INSET_M), 0.0)
	var net3 := Vector3(net2.x, R.NET_CROSSBAR_M + R.NET_BADGE_LIFT_M, net2.y)
	var text := "%d m" % roundi(hpos.distance_to(net2))
	var far: Dictionary = _place_badge(net3, vw, vh, true)
	if far["proj_ok"]:
		var bar: Vector3 = lay.project(Vector3(net2.x, R.NET_CROSSBAR_M, net2.y))
		if bar.z > 0.0:
			far["sp"].y = minf(far["sp"].y, bar.y - R.NET_BADGE_GAP_PX)
	far["on_screen"] = not far["behind"] and _inside(far["sp"], vw, vh)
	var pos: Vector2 = R.clamp_marker(far["sp"], vw, vh, 44.0, 120.0, 64.0)
	pos = R.keep_off_panel(pos, vh, panel_top, 40.0, R.EDGE_PX)
	var left_side: bool = pos.x > vw - 200.0
	var g_far := {"kind": "far", "diamond": pos, "diamond_size": 22.0, "text": text, "text_at": pos + Vector2(-24.0 if left_side else 24.0, 0),
		"text_align": Vector2(1.0 if left_side else 0.0, 0.5), "arrow": _arrow(far["sp"], pos, far["behind"], vw, 22.0), "arrow_size": 22.0,
		"colour": R.YELLOW, "show": badges, "label": badges, "text_half": Vector2.ZERO}
	if badges and far["on_screen"]:
		var lw: float = 12.0 * text.length() + 2.0 * R.LABEL_PLATE_PAD_X
		var lmin := Vector2(pos.x + (-24.0 - lw if left_side else 24.0), pos.y - 15.0)
		if R.in_middle_third(lmin, lmin + Vector2(lw, 30.0), vw, vh):
			g_far["label"] = false
	# ---- the own net (UpdateOwnMarker cpp:1952-2000; ApplyOwnLabelRule HUDOneLine.cpp:32-59)
	var own2 := Vector2(-attack * (hud.length_m * 0.5 - R.NET_INSET_M), 0.0)
	var own: Dictionary = _place_badge(Vector3(own2.x, 1.5, own2.y), vw, vh, false)
	own["on_screen"] = not own["behind"] and _inside(own["sp"], vw, vh)
	var opos: Vector2 = R.clamp_marker(own["sp"], vw, vh, 40.0, 150.0, 56.0)
	# jam.hud.ClearEdges 0 (default): no KeepOffRadar here (cpp:1983)
	opos = R.keep_off_panel(opos, vh, panel_top, 40.0, R.EDGE_PX)
	var otext := R.own_label_text(roundi(hpos.distance_to(own2)))
	var obadge: bool = badges and R.show_own_marker(own["on_screen"])
	var g_own := {"kind": "own", "diamond": opos, "diamond_size": 12.0, "text": otext, "text_at": opos + Vector2(0, 10), "text_align": Vector2(0.5, 0.0),
		"arrow": _arrow(own["sp"], opos, own["behind"], vw, 16.0), "arrow_size": 16.0, "colour": R.MUTED, "show": obadge, "label": obadge}
	if obadge and own["on_screen"]:
		var olw: float = 10.0 * otext.length() + 2.0 * R.LABEL_PLATE_PAD_X
		var olmin := Vector2(opos.x - olw * 0.5, opos.y + 10.0)
		if R.in_middle_third(olmin, olmin + Vector2(olw, 28.0), vw, vh):
			g_own["label"] = false
	var hide_own: bool = not R.in_own_third(hpos.x, attack, hud.length_m)
	if not hide_own:
		var ot: Rect2 = _text_box(otext, g_own["text_at"], g_own["text_align"])
		var corner := Rect2(Vector2(vw - R.CORNER_FURNITURE_W, vh - R.CORNER_FURNITURE_H), Vector2(R.CORNER_FURNITURE_W, R.CORNER_FURNITURE_H))
		if ot.grow(4.0).intersects(corner):
			hide_own = true
	if hide_own:
		g_own["show"] = false
	# ---- the puck off the frame (UpdatePuckMarker cpp:1306-1368; jam.hud.PuckLabelOnScreen 0, HUDOneLine.cpp:34-47)
	if f < puck_last_frame or paused:
		puck_alpha = 0.0
	puck_last_frame = f
	var want: bool = false
	var g_puck := {"kind": "puck", "show": false}
	if phase == "play" and not covered and not paused:
		var pk := Vector3(puck_pos.x, 0.1, puck_pos.y)
		var pp: Vector3 = lay.project(pk)
		var sp := Vector2(vw * 0.5, vh * 0.5)
		var front: bool = pp.z > 0.01
		var dir: Vector2
		if not front:
			var loc: Vector3 = lay.camera_local(pk)          # Unreal's Local: (ahead, right, up) = (-z, x, y)
			dir = Vector2(loc.x, -loc.y)
			if absf(dir.x) < 0.01 and absf(dir.y) < 0.01:
				dir = Vector2(1.0 if loc.x >= 0.0 else -1.0, 0.5)
		else:
			sp = Vector2(pp.x, pp.y)
			dir = sp - Vector2(vw * 0.5, vh * 0.5)
		want = not front or R.outside_inner_frame(sp, vw, vh)
		if want:
			dir = dir.normalized()
			var p: Vector2 = R.puck_marker_edge_point(dir, vw, vh, 64.0, vw - 64.0, 150.0, vh - 170.0)
			if p.x > vw - 330.0 and p.y > vh - 200.0:
				p.y = vh - 200.0
			if panel_top > 0.0 and p.x < R.EDGE_PX + R.PANEL_MAX_W + 40.0 and p.y > vh - panel_top - 40.0:
				p.y = vh - panel_top - 40.0
			var ang: float = rad_to_deg(atan2(-dir.x, dir.y))
			var pc: Color = col(int((snap["Skaters"][carrier] as Dictionary)["Team"])) if carrier >= 0 else R.LOOSE_GREY
			g_puck = {"kind": "puck", "arrow": p, "arrow_angle": ang, "arrow_size": 28.0, "colour": pc, "text": "%d m" % roundi(hpos.distance_to(puck_pos)),
				"text_at": p - dir * Vector2(62.0, 34.0), "text_align": Vector2(0.5, 0.5), "show": true, "label": true}
		# jam.hud.PuckLabelOnScreen 0: not while the puck is on the screen (24 px in)
		var on3: Vector3 = lay.project(Vector3(puck_pos.x, 0.05, puck_pos.y))
		if on3.z > 0.0 and on3.x > 24.0 and on3.y > 24.0 and on3.x < vw - 24.0 and on3.y < vh - 24.0:
			g_puck["show"] = false
			g_puck["hidden_on_screen"] = true
	if advanced or puck_alpha <= 0.0:
		puck_alpha = clampf(puck_alpha + (1.0 if want else -1.0) / float(R.PUCK_MARKER_FADE_FRAMES), 0.0, 1.0)
	g_puck["alpha"] = puck_alpha
	if puck_alpha <= 0.0:
		g_puck["show"] = false
	groups = [g_puck, g_far, g_own]
	_resolve_edge_slots(groups, vw, vh)
	return groups


func _place_badge(world: Vector3, vw: float, vh: float, far: bool) -> Dictionary:
	var p: Vector3 = lay.project(world)
	var proj_ok: bool = p.z > 0.0
	var sp := Vector2(p.x, p.y) if proj_ok else Vector2(vw * 0.5, vh * 0.5)
	var behind: bool = not proj_ok
	var loc: Vector3 = lay.camera_local(world)
	if -loc.z <= 0.01:                                   # Local.X <= 1 cm: behind us, parked on the side edge towards the net
		behind = true
		sp = Vector2(vw if loc.x >= 0.0 else 0.0, vh * 0.5)
	return {"sp": sp, "behind": behind, "proj_ok": proj_ok and not behind}


static func _inside(sp: Vector2, vw: float, vh: float) -> bool:
	return sp.x >= 0 and sp.x <= vw and sp.y >= 0 and sp.y <= vh


## PlaceMarkerArrow (cpp:1708-1722): {at, angle} or {} when the marker was not clamped.
static func _arrow(raw: Vector2, clamped: Vector2, behind: bool, vw: float, _size: float) -> Dictionary:
	var d: Vector2 = raw - clamped
	if not behind and absf(d.x) <= 0.5 and absf(d.y) <= 0.5:
		return {}
	var angle: float = 0.0
	var off := Vector2(0, 22)
	if behind or absf(d.x) >= absf(d.y):
		var right: bool = clamped.x > vw * 0.5 if behind else d.x > 0
		angle = -90.0 if right else 90.0
		off = Vector2(22 if right else -22, 0)
	elif d.y < 0:
		angle = 180.0
		off = Vector2(0, -22)
	return {"at": clamped + off, "angle": angle}


func _text_box(text: String, at: Vector2, align: Vector2) -> Rect2:
	var sz: Vector2 = lay.measure(text, R.LINE_PT, "bold_condensed")
	return Rect2(at - sz * align, sz)


## ResolveEdgeSlots (cpp:1374-1465): puck first (fixed), far net, own net; a group too near a placed one slides along its edge.
func _resolve_edge_slots(groups: Array, vw: float, vh: float) -> void:
	var boxes: Array = []
	var anchors: Array = []
	var active: Array = []
	for g: Dictionary in groups:
		var m: Array = _measure_group(g, Vector2.ZERO)
		boxes.append(m[0])
		anchors.append(m[1])
		active.append(m[2])
	for i: int in [1, 2]:
		var g: Dictionary = groups[i]
		if not active[i]:
			continue
		var hit: int = -1
		for j: int in range(i):
			if hit < 0 and _conflicts(boxes[i], anchors[i], active[i], boxes[j], anchors[j], active[j]):
				hit = j
		if hit < 0:
			continue
		var ap: Vector2 = anchors[i]
		var side: bool = minf(ap.x, vw - ap.x) <= minf(ap.y, vh - ap.y)
		var axis := Vector2(0, 1) if side else Vector2(1, 0)
		var here: float = ap.y if side else ap.x
		var lo: float = 130.0 if side else 100.0
		var hi: float = vh - 200.0 if side else vw - 100.0
		var away: float = 1.0 if here >= ((anchors[hit] as Vector2).y if side else (anchors[hit] as Vector2).x) else -1.0
		var done: bool = false
		for k: int in range(1, 13):
			if done:
				break
			for sgn: float in [away, -away]:
				var to: float = here + sgn * R.EDGE_SLOT_PX * 0.5 * k
				if to < lo or to > hi:
					continue
				var delta: Vector2 = axis * (to - here)
				var m: Array = _measure_group(g, delta)
				var free: bool = true
				for j: int in range(i):
					if free and _conflicts(m[0], m[1], m[2], boxes[j], anchors[j], active[j]):
						free = false
				if not free:
					continue
				_shift_group(g, delta)
				boxes[i] = m[0]
				anchors[i] = m[1]
				done = true
				break


func _conflicts(a_box: Rect2, a_anchor: Vector2, a_act: bool, b_box: Rect2, b_anchor: Vector2, b_act: bool) -> bool:
	if a_box.size == Vector2.ZERO or b_box.size == Vector2.ZERO:
		return false
	if a_act and b_act and a_anchor.distance_to(b_anchor) < R.EDGE_SLOT_PX:
		return true
	return a_box.grow(4.0).intersects(b_box)


## [box, anchor position, active]: the parts that show (puck: arrow 16 and its text 12 a char x 26; far: diamond 12, arrow 12, text 12 x 26;
## own: diamond 8, arrow 10, text 10 x 22).
func _measure_group(g: Dictionary, delta: Vector2) -> Array:
	if not g.get("show", false):
		return [Rect2(), Vector2.ZERO, false]
	var k: String = g["kind"]
	var box := Rect2()
	var first := true
	var parts: Array = []
	var per: float = 10.0 if k == "own" else 12.0
	var th: float = 22.0 if k == "own" else 26.0
	if k != "puck":
		var dh: float = 8.0 if k == "own" else 12.0
		parts.append(Rect2(g["diamond"] + delta - Vector2(dh, dh), Vector2(dh, dh) * 2))
	var arr: Dictionary = g.get("arrow", {}) if k != "puck" else {"at": g["arrow"]}
	var ah: float = 16.0 if k == "puck" else (10.0 if k == "own" else 12.0)
	if not arr.is_empty():
		parts.append(Rect2(arr["at"] + delta - Vector2(ah, ah), Vector2(ah, ah) * 2))
	if g.get("label", false):
		var tex := Vector2(per * String(g["text"]).length(), th)
		var al: Vector2 = g["text_align"]
		parts.append(Rect2(g["text_at"] + delta - tex * al, tex))
	for r: Rect2 in parts:
		box = r if first else box.merge(r)
		first = false
	var anchor_ok: bool = not arr.is_empty()
	return [box, (arr["at"] + delta) if anchor_ok else Vector2.ZERO, anchor_ok]


static func _shift_group(g: Dictionary, delta: Vector2) -> void:
	for key: String in ["diamond", "text_at"]:
		if g.has(key):
			g[key] = (g[key] as Vector2) + delta
	if g["kind"] == "puck":
		g["arrow"] = (g["arrow"] as Vector2) + delta
	elif not (g.get("arrow", {}) as Dictionary).is_empty():
		g["arrow"]["at"] = (g["arrow"]["at"] as Vector2) + delta


var label_boxes: Array = []      # this frame's distance labels' plates (the caption yields to them, HUDOneLine.cpp:88-114)


func paint(groups: Array) -> void:
	label_boxes = []
	# canvas order: far diamond, far plate, far text, far arrow, own diamond, own plate, own text, own arrow, puck arrow, puck plate, puck text
	for g: Dictionary in [groups[1], groups[2], groups[0]]:
		if not g.get("show", false):
			continue
		var k: String = g["kind"]
		var a: float = float(g.get("alpha", 1.0))
		var c: Color = g["colour"]
		c.a *= a
		if k != "puck":
			var ds: float = g["diamond_size"]
			# MakeDiamond: Rounded(fill, 3, ink 0.9, outline) turned 45 degrees
			lay.box(g["diamond"] - Vector2(ds, ds) * 0.5, Vector2(ds, ds), c, 3.0, Color(0, 0, 0, 0.9), 2.0 if k == "far" else 1.5, 45.0)
		if g.get("label", false):
			var t: String = g["text"]
			var al: Vector2 = g["text_align"]
			var sz: Vector2 = lay.measure(t, R.LINE_PT, "bold_condensed")
			var tl: Vector2 = g["text_at"] - sz * al
			# the plate (UpdateLabelPlates cpp:1284-1304; one look fill at 0.62 + 0.18, no edge)
			var pc := R.ML_PANEL
			pc.a = (R.LABEL_PLATE_OPACITY + 0.18) * a
			var plate_at: Vector2 = R.label_plate_pos(g["text_at"], al)
			var psz: Vector2 = sz + Vector2(2.0 * R.LABEL_PLATE_PAD_X, 2.0 * R.LABEL_PLATE_PAD_Y)
			lay.box(plate_at - psz * al, psz, pc, 4.0)
			lay.text(tl, t, R.LINE_PT, R.ML_TEXT, {"face": "bold_condensed", "alpha": a, "shadow": Vector2(0, 1), "shadow_color": Color(0, 0, 0, 0.45)})
			hud.shown[k + "_label"] = t
			label_boxes.append(Rect2(plate_at - psz * al, psz))
		if k == "puck":
			lay.chevron(g["arrow"], g["arrow_size"], c, Color(0, 0, 0, 0.9), 1.5, g["arrow_angle"])
			hud.shown["puck_arrow"] = true
		elif not (g.get("arrow", {}) as Dictionary).is_empty():
			lay.chevron(g["arrow"]["at"], g["arrow_size"], c, Color(0, 0, 0, 0.9), 1.5, g["arrow"]["angle"])
			hud.shown[k + "_arrow"] = true
		hud.shown[k + "_badge"] = true


