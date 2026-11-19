extends Control
## Same instrument tree in the running game and on the workbench proof.
const Layout = preload("res://style/hud/layout.gd")
const Stock = preload("res://style/hud/stock.gd")
const Ticket = preload("res://style/hud/ticket.gd")
const ALIGN := {"top_left": Vector2(0,0), "top": Vector2(0.5,0), "top_right": Vector2(1,0),
	"left": Vector2(0,0.5), "center": Vector2(0.5,0.5), "right": Vector2(1,0.5),
	"bottom_left": Vector2(0,1), "bottom": Vector2(0.5,1), "bottom_right": Vector2(1,1)}
var catalog: Array
var cards := {}
var settings := {}
var phase := "run"
var vertical_clearance := Vector2.ZERO # Minimum top and bottom margins supplied by the host, in viewport pixels.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(arrange)

func install(specs: Array, profile: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	cards.clear()
	catalog = specs
	var colors := Stock.colors(profile.get("theme", "signal"))
	for spec: Dictionary in specs:
		var ticket := Ticket.new()
		ticket.setup(spec, colors)
		add_child(ticket)
		cards[spec.id] = ticket
	apply(profile)

func apply(profile: Dictionary) -> void:
	settings = Layout.resolved(catalog, profile)
	var colors := Stock.colors(profile.get("theme", "signal"))
	for ticket: Ticket in cards.values():
		ticket.inks = colors
		ticket.queue_redraw()
	arrange()

func set_phase(next: String) -> void:
	if phase != next:
		phase = next
		arrange()

func set_reading(id: StringName, reading: Dictionary) -> void:
	var ticket: Ticket = cards[id]
	var old := ticket.size
	var was_empty := ticket.reading.is_empty()
	ticket.update_reading(reading)
	if old != ticket.size or was_empty != reading.is_empty():
		arrange()

func arrange() -> void:
	if size.x < 1 or size.y < 1:
		return
	var ratio := minf(size.x / 1280.0, size.y / 720.0)
	var inset := Vector2(22, 19) * ratio
	var room := size - 2 * inset
	var lower_margin := maxf(inset.y, vertical_clearance.y)
	inset.y = maxf(inset.y, vertical_clearance.x)
	room.y = size.y - inset.y - lower_margin
	var groups := {}
	for spec: Dictionary in catalog:
		var t: Ticket = cards[spec.id]
		var opt: Dictionary = settings[spec.id]
		t.visible = opt.visible and spec.get("phase", "run") in [phase, "both"] and not t.reading.is_empty()
		if t.visible:
			var anchor: String = opt.anchor
			if not groups.has(anchor):
				groups[anchor] = []
			t.scale = Vector2.ONE * ratio * float(Layout.SIZES[opt.size])
			groups[anchor].append(t)
	for anchor: String in groups:
		var group: Array = groups[anchor]
		var align: Vector2 = ALIGN[anchor]
		var gap := 4.0 * ratio
		var height := gap * (group.size() - 1)
		var width := 1.0
		for t: Ticket in group:
			height += t.size.y * t.scale.y
			width = maxf(width, t.size.x * t.scale.x)
		var fit := minf(1.0, minf(room.y / maxf(1, height), room.x / width))
		var y := inset.y + (room.y - height * fit) * align.y
		for t: Ticket in group:
			t.scale *= fit
			t.position = Vector2(inset.x + (room.x - t.size.x * t.scale.x) * align.x, y).round()
			y += t.size.y * t.scale.y + gap * fit
