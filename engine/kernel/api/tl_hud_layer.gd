class_name TLHudLayer
extends Control
## K5 (API 1.20): a painter for a sports HUD, made with `TLHud.add_layer(id)`. A pack lays out its screen furniture every
## frame in LAYOUT UNITS: the screen is `unit_h` units high (1080 by default) at any resolution, so a layout written for
## 1920 x 1080 holds at 1280 x 720 (two thirds of the pixels) and 2560 x 1440 (four thirds), as Unreal's DPI curve does.
## Call `clear()` once a frame, then queue shapes; the layer draws them in the order queued (the first queued is the
## lowest). Presentation only: nothing here touches the simulation or the state hash.
##
##   var lay := hud.add_layer(&"screen")
##   lay.clear()
##   lay.box(Vector2(860, 14), Vector2(200, 90), Color("#141821e6"), 4.0, Color(1, 1, 1, 0.12), 1.0)
##   lay.text(Vector2(960, 40), "PERIOD 1", 14, Color("#a3abb8"), {"face": "bold_condensed", "align": Vector2(0.5, 0.5), "tracking": 60})
##   var r: Rect2 = lay.ground_ring(Vector3(px, 0.03, py), 1.1)           # a circle on the ground, as its screen box (units)
##   if r.size != Vector2.ZERO: lay.ring(r, Color("#1d4ed8"))
##
## Type sizes are Unreal points (the HUD source's numbers): drawn at pt x 4/3 units, as Slate draws a point at 96 dpi.
## Faces: regular, bold, bold_condensed, black (the style's `hud/faces.gd`; the engine's fallback font without it).

const _FACES_PATH := "res://style/hud/faces.gd"

var unit_h: float = 1080.0
var _ops: Array = []
var _cameras: TLCameras
var _faces: GDScript
var _boxes: Dictionary = {}
var _images: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(_FACES_PATH):
		_faces = load(_FACES_PATH)


## Pixels per layout unit now.
func unit() -> float:
	var h: float = get_viewport_rect().size.y if is_inside_tree() else unit_h
	return maxf(h, 1.0) / unit_h


## The screen in layout units (1920 x 1080 at 16:9).
func extent() -> Vector2:
	var s: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(unit_h * 16.0 / 9.0, unit_h)
	return s / unit()


## Forget last frame's shapes (call once a frame before queueing).
func clear() -> void:
	_ops.clear()
	queue_redraw()


## A box at `pos` (top left) of `size`, filled, with rounded corners and an edge drawn inside it. `angle_deg` turns it
## about its centre (clockwise on the screen).
func box(pos: Vector2, size_u: Vector2, fill: Color, radius: float = 0.0, edge: Color = Color(0, 0, 0, 0), edge_w: float = 0.0, angle_deg: float = 0.0) -> void:
	_ops.append([0, pos, size_u, fill, radius, edge, edge_w, angle_deg])
	queue_redraw()


## Text with its box placed so that `align` (0..1 on each axis) of the box stands at `pos`. Returns the box (units).
## opts: face ("bold"), tracking (1/1000 em), outline (units) and outline_color, shadow (Vector2 units) and shadow_color,
## alpha (multiplies every colour).
func text(pos: Vector2, s: String, pt: float, color: Color, opts: Dictionary = {}) -> Rect2:
	var sz: Vector2 = measure(s, pt, String(opts.get("face", "bold")), int(opts.get("tracking", 0)))
	var al: Vector2 = opts.get("align", Vector2.ZERO)
	var r := Rect2(pos - sz * al, sz)
	_ops.append([1, r, s, pt, color, opts])
	queue_redraw()
	return r


## The box a text takes (units): its advance and the face's line height.
func measure(s: String, pt: float, face: String = "bold", tracking: int = 0) -> Vector2:
	var px: float = pt * 4.0 / 3.0
	var f: Font = _font(face, 0)
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(px * 8.0))).x / 8.0
	w += px * float(tracking) / 1000.0 * s.length()
	return Vector2(w, f.get_height(int(round(px * 8.0))) / 8.0)


## A ring drawn as a stretched image of a round band: the band is `band` of the box's size thick (each axis its own,
## as a ring texture stretched into an ellipse), with an ink edge `edge` of the box's size on both sides.
func ring(r: Rect2, color: Color, band: float = 0.082, edge: float = 0.0086, edge_color: Color = Color(0.078, 0.078, 0.13, 1.0)) -> void:
	_ops.append([2, r, color, band, edge, edge_color])
	queue_redraw()


## A chevron (a V of two rounded bars, pointing down at angle 0) in a `size` square whose `align` point stands at `pos`;
## `angle_deg` turns it about the square's centre. Bars are max(3, size x 0.2) wide, size x 0.78 long, leaning 40 degrees.
func chevron(pos: Vector2, size_u: float, color: Color, edge: Color = Color(0, 0, 0, 0.9), edge_w: float = 1.5, angle_deg: float = 0.0, align: Vector2 = Vector2(0.5, 0.5)) -> void:
	_ops.append([3, pos - Vector2(size_u, size_u) * align, size_u, color, edge, edge_w, angle_deg])
	queue_redraw()


## K5 (1.22). A picture of the pack (a .png path relative to the pack, never outside it), loaded once; null with an error
## when it is missing or not a PNG. Pictures are inert data: the pack's own art, drawn with image() and nine().
func image_of(rel: String) -> Texture2D:
	if _images.has(rel):
		return _images[rel]
	var p: String = rel.replace("\\", "/")
	var ctx: TLContext = TLContext.current
	if p.contains("..") or p.contains("://") or p.is_absolute_path() or p.get_extension().to_lower() != "png" or ctx == null:
		push_error("TLHudLayer.image_of('%s'): a .png path relative to the pack" % rel)
		return null
	var img := Image.load_from_file(ctx.pack_dir + "/" + p)
	if img == null or img.is_empty():
		push_error("TLHudLayer.image_of('%s'): not found or not a PNG" % rel)
		return null
	var tex := ImageTexture.create_from_image(img)
	_images[rel] = tex
	return tex


## K5 (1.22). A picture stretched into `rect` (units), multiplied by `tint` (as a tinted Unreal image brush), scaled by
## `scale` about the rect's centre.
func image(tex: Texture2D, rect: Rect2, tint: Color = Color.WHITE, scale_k: float = 1.0) -> void:
	if tex == null:
		return
	if scale_k != 1.0:
		var s2: Vector2 = rect.size * scale_k
		rect = Rect2(rect.get_center() - s2 * 0.5, s2)
	_ops.append([6, tex, rect, tint])
	queue_redraw()


## K5 (1.22). A nine-slice picture (an Unreal box brush): `margin` is each edge's unscaled share of the picture
## (left, top, right, bottom as fractions of its size), drawn at `px_per_unit` texture pixels a unit.
func nine(tex: Texture2D, rect: Rect2, margin: Vector4, px_per_unit: float = 1.0, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	_ops.append([7, tex, rect, margin, px_per_unit, tint])
	queue_redraw()


## A filled polygon (units).
func polygon(points: PackedVector2Array, color: Color) -> void:
	_ops.append([4, points, color])
	queue_redraw()


## A straight line (units), `width` units wide.
func line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	_ops.append([5, a, b, color, width])
	queue_redraw()


## A bar: `back` over the whole box, `fill` over the first `frac` of its width.
func bar(pos: Vector2, size_u: Vector2, frac: float, fill: Color, back: Color = Color(0, 0, 0, 0.55), radius: float = 0.0) -> void:
	if back.a > 0.0:
		box(pos, size_u, back, radius)
	box(pos, Vector2(size_u.x * clampf(frac, 0.0, 1.0), size_u.y), fill, radius)


## A minimap: a box of `size` at `pos` for a field of `field` (metres, centred on the origin): dots is an Array of
## {"at": Vector2 (field metres), "size": units, "color": Color, "mark": "dot"|"square"|"hollow"|"x"}; drawn in order.
func minimap(pos: Vector2, size_u: Vector2, field: Vector2, dots: Array) -> void:
	for d: Dictionary in dots:
		var at: Vector2 = d["at"]
		var p := pos + Vector2((at.x + field.x * 0.5) / maxf(field.x, 0.001) * size_u.x, (at.y + field.y * 0.5) / maxf(field.y, 0.001) * size_u.y)
		var s: float = float(d.get("size", 9.0))
		var c: Color = d.get("color", Color.WHITE)
		match String(d.get("mark", "dot")):
			"hollow":
				box(p - Vector2(s, s) * 0.5, Vector2(s, 2), c)
				box(p + Vector2(-s * 0.5, s * 0.5 - 2), Vector2(s, 2), c)
				box(p - Vector2(s, s) * 0.5, Vector2(2, s), c)
				box(p + Vector2(s * 0.5 - 2, -s * 0.5), Vector2(2, s), c)
			"x":
				line(p + Vector2(-s, -s) * 0.5, p + Vector2(s, s) * 0.5, c, 2.5)
				line(p + Vector2(-s, s) * 0.5, p + Vector2(s, -s) * 0.5, c, 2.5)
			_:
				box(p - Vector2(s, s) * 0.5, Vector2(s, s), c)


## A world point on the screen of the pack's active view: Vector3(x, y) in units and z = its depth in front of the
## camera (metres; <= 0 behind it, where x and y mean nothing). It projects through the camera's pose of THIS frame (its
## transform as last set, not the physics-interpolated one the renderer is drawing), as a HUD widget of Unreal reads its
## player camera manager's pose of the frame.
func project(world: Vector3) -> Vector3:
	var cam: Camera3D = _camera()
	if cam == null or not cam.is_inside_tree() or not is_inside_tree() or get_viewport_rect().size.y < 1.0:
		return Vector3(0, 0, -1)
	var local: Vector3 = cam.global_transform.affine_inverse() * world
	var depth: float = -local.z
	if depth <= 0.001:
		return Vector3(0, 0, minf(depth, 0.0))
	var clip: Vector4 = cam.get_camera_projection() * Vector4(local.x, local.y, local.z, 1.0)
	if absf(clip.w) < 1e-9:
		return Vector3(0, 0, -1)
	var vp: Vector2 = get_viewport_rect().size
	var px := Vector2((clip.x / clip.w * 0.5 + 0.5) * vp.x, (0.5 - clip.y / clip.w * 0.5) * vp.y)
	var p: Vector2 = px / unit()
	return Vector3(p.x, p.y, depth)


## The point in camera space (x right, y up, z towards the viewer: Unreal's Local with -z ahead), for behind-the-camera
## directions; Vector3.ZERO without a camera.
func camera_local(world: Vector3) -> Vector3:
	var cam: Camera3D = _camera()
	return cam.global_transform.affine_inverse() * world if cam != null else Vector3.ZERO


## The camera's eye (world); Vector3.ZERO without one.
func eye() -> Vector3:
	var cam: Camera3D = _camera()
	return cam.global_position if cam != null else Vector3.ZERO


## A circle of `radius` (metres) lying on the ground round `center`, as the screen box (units) of its four compass points
## and its centre; Rect2() when the centre is within `near` metres of the camera plane or any point is behind the camera.
func ground_ring(center: Vector3, radius: float, near: float = 0.5) -> Rect2:
	var c: Vector3 = project(center)
	if c.z <= near:
		return Rect2()
	var lo := Vector2(c.x, c.y)
	var hi := lo
	for off: Vector3 in [Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
		var p: Vector3 = project(center + off)
		if p.z <= 0.0:
			return Rect2()
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	var mid := (lo + hi) * 0.5
	var size_u := Vector2(maxf(hi.x - lo.x, 8.0), maxf(hi.y - lo.y, 4.0))
	return Rect2(mid - size_u * 0.5, size_u)


func _camera() -> Camera3D:
	if _cameras == null and TLContext.current != null:
		_cameras = TLContext.current.cameras
	return _cameras.active if is_instance_valid(_cameras) and is_instance_valid(_cameras.active) else null


func _font(face: String, spacing_px: int) -> Font:
	if _faces != null:
		return _faces.font(face, spacing_px)
	return ThemeDB.fallback_font


func _style(fill: Color, radius: float, edge: Color, edge_w: float, k: float) -> StyleBoxFlat:
	var key := [fill, radius, edge, edge_w, k]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(round(radius * k)))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if edge_w > 0.0 and edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(maxi(1, int(round(edge_w * k))))
	if _boxes.size() > 512:
		_boxes.clear()
	_boxes[key] = sb
	return sb


func _draw() -> void:
	var k: float = unit()
	for op: Array in _ops:
		match int(op[0]):
			0:
				var pos: Vector2 = op[1] * k
				var sz: Vector2 = op[2] * k
				var ang: float = deg_to_rad(float(op[7]))
				if ang != 0.0:
					var cen := pos + sz * 0.5
					draw_set_transform(cen, ang, Vector2.ONE)
					pos = -sz * 0.5
				draw_style_box(_style(op[3], float(op[4]), op[5], float(op[6]), k), Rect2(pos, sz))
				if ang != 0.0:
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			1:
				_draw_text(op[1], op[2], float(op[3]), op[4], op[5], k)
			2:
				_draw_ring(op[1], op[2], float(op[3]), float(op[4]), op[5], k)
			3:
				_draw_chevron(op[1], float(op[2]), op[3], op[4], float(op[5]), float(op[6]), k)
			4:
				var pts: PackedVector2Array = op[1]
				var scaled := PackedVector2Array()
				for p: Vector2 in pts:
					scaled.append(p * k)
				if scaled.size() >= 3:
					draw_colored_polygon(scaled, op[2])
			5:
				draw_line(op[1] * k, op[2] * k, op[3], maxf(1.0, float(op[4]) * k), true)
			6:
				var r6: Rect2 = op[2]
				draw_texture_rect(op[1], Rect2(r6.position * k, r6.size * k), false, op[3])
			7:
				_draw_nine(op[1], op[2], op[3], float(op[4]), op[5], k)


func _draw_text(r: Rect2, s: String, pt: float, color: Color, opts: Dictionary, k: float) -> void:
	var px: float = pt * 4.0 / 3.0 * k
	var size_px := int(round(px))
	var face: String = String(opts.get("face", "bold"))
	var spacing := int(round(px * float(opts.get("tracking", 0)) / 1000.0))
	var f: Font = _font(face, spacing)
	var alpha: float = float(opts.get("alpha", 1.0))
	var base := Vector2(r.position.x * k, r.position.y * k + f.get_ascent(size_px))
	var sh: Vector2 = opts.get("shadow", Vector2.ZERO)
	if sh != Vector2.ZERO:
		var sc: Color = opts.get("shadow_color", Color(0, 0, 0, 0.6))
		sc.a *= alpha * color.a
		draw_string(f, base + sh * k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, sc)
	var ow: float = float(opts.get("outline", 0.0))
	if ow > 0.0:
		var oc: Color = opts.get("outline_color", Color(0, 0, 0, 0.9))
		oc.a *= alpha * color.a
		draw_string_outline(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, maxi(1, int(round(ow * 2.0 * k))), oc)
	var c := color
	c.a *= alpha
	draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)


func _ellipse_band(c: Vector2, rad: Vector2, f0: float, f1: float, color: Color) -> void:
	# the band between f0 and f1 of the radius (1 = the outer edge), as one triangle array
	var n := 72
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i: int in range(n):
		var t: float = TAU * float(i) / float(n)
		var d := Vector2(cos(t), sin(t))
		pts.append(c + d * rad * f1)
		pts.append(c + d * rad * f0)
		cols.append(color)
		cols.append(color)
	for i: int in range(n):
		var a: int = i * 2
		var b: int = ((i + 1) % n) * 2
		idx.append_array([a, a + 1, b, b, a + 1, b + 1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


func _draw_ring(r: Rect2, color: Color, band: float, edge: float, edge_color: Color, k: float) -> void:
	var c: Vector2 = r.get_center() * k
	var rad: Vector2 = r.size * 0.5 * k
	var b: float = band * 2.0
	var e: float = edge * 2.0
	var ec := edge_color
	ec.a *= color.a
	_ellipse_band(c, rad, 1.0 - e, 1.0, ec)
	_ellipse_band(c, rad, 1.0 - b + e, 1.0 - e, color)
	_ellipse_band(c, rad, 1.0 - b, 1.0 - b + e, ec)


func _draw_chevron(top_left: Vector2, s: float, color: Color, edge: Color, edge_w: float, angle_deg: float, k: float) -> void:
	var bw: float = maxf(3.0, s * 0.2)
	var bh: float = s * 0.78
	var cen: Vector2 = (top_left + Vector2(s, s) * 0.5) * k
	var whole: float = deg_to_rad(angle_deg)
	var ec := edge
	ec.a *= color.a
	for i: int in range(2):
		var lean: float = deg_to_rad(-40.0 if i == 0 else 40.0)
		var slide := Vector2((-1.0 if i == 0 else 1.0) * bh * 0.5 * 0.643, 0.0)
		# the bar's centre in the square (turned with the square), then the bar turned about its own centre
		var bc: Vector2 = cen + slide.rotated(whole) * k
		draw_set_transform(bc, whole + lean, Vector2.ONE)
		draw_style_box(_style(color, bw * 0.5, ec, edge_w, k), Rect2(Vector2(-bw, -bh) * 0.5 * k, Vector2(bw, bh) * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_nine(tex: Texture2D, r: Rect2, m: Vector4, ppu: float, tint: Color, k: float) -> void:
	var ts: Vector2 = tex.get_size()
	var src_x := [0.0, ts.x * m.x, ts.x * (1.0 - m.z), ts.x]
	var src_y := [0.0, ts.y * m.y, ts.y * (1.0 - m.w), ts.y]
	var l: float = ts.x * m.x / ppu
	var t: float = ts.y * m.y / ppu
	var rr: float = ts.x * m.z / ppu
	var b: float = ts.y * m.w / ppu
	var dst_x := [r.position.x, r.position.x + l, r.end.x - rr, r.end.x]
	var dst_y := [r.position.y, r.position.y + t, r.end.y - b, r.end.y]
	for j: int in 3:
		for i: int in 3:
			var src := Rect2(src_x[i], src_y[j], src_x[i + 1] - src_x[i], src_y[j + 1] - src_y[j])
			var dst := Rect2(Vector2(dst_x[i], dst_y[j]) * k, Vector2(dst_x[i + 1] - dst_x[i], dst_y[j + 1] - dst_y[j]) * k)
			if dst.size.x > 0.0 and dst.size.y > 0.0 and src.size.x > 0.0 and src.size.y > 0.0:
				draw_texture_rect_region(tex, dst, src, tint)
