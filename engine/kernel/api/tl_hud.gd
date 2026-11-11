class_name TLHud
extends CanvasLayer
## HUD widgets: score, clock, speed and free labels, bound to live sources and refreshed every frame.
## Stand-in look (plain labels) until the style layer provides one. Capability: `ui`.
##
##   var hud := TLHud.create()
##   ctx.root.add_child(hud)
##   hud.add_score(rules, "home", &"top_left")
##   hud.add_clock(rules, &"top")
##   hud.add_speed(car.speed_kmh, "km/h", &"bottom_right")
##   hud.add_label(&"hint", "Space: nitro", &"bottom")
##
## Anchors: top_left, top, top_right, left, center, right, bottom_left, bottom, bottom_right.

const ANCHORS: Dictionary = {
	&"top_left": [Control.PRESET_TOP_LEFT, Vector2(24, 16)], &"top": [Control.PRESET_CENTER_TOP, Vector2(0, 16)],
	&"top_right": [Control.PRESET_TOP_RIGHT, Vector2(-24, 16)], &"left": [Control.PRESET_CENTER_LEFT, Vector2(24, 0)],
	&"center": [Control.PRESET_CENTER, Vector2(0, 0)], &"right": [Control.PRESET_CENTER_RIGHT, Vector2(-24, 0)],
	&"bottom_left": [Control.PRESET_BOTTOM_LEFT, Vector2(24, -16)], &"bottom": [Control.PRESET_CENTER_BOTTOM, Vector2(0, -16)],
	&"bottom_right": [Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -16)],
}

# N2: no static list any more; a pack's HUD layers are in its context (`ctx.huds`).

var font_size: int = 36
var _widgets: Dictionary = {}      # id -> {label: Label, source: Callable or null}
var _stacks: Dictionary = {}       # anchor -> count (widgets on one anchor stack up)


static func create() -> TLHud:
	TLContext.require("ui", "TLHud")
	var h: TLHud = TLHud.new()
	h.name = "TLHud"
	if TLContext.current != null:
		TLContext.current.huds.append(h)
		h.visible = TLContext.current.on_stage      # N7 (N5b patch 2): in a world only the stage pack's HUD is shown
	return h


## Hides every HUD of one pack (the kernel does this for captures); without an argument, of the pack being called.
static func hide_all(of_pack: TLContext = null) -> void:
	var ctx: TLContext = of_pack if of_pack != null else TLContext.current
	if ctx == null:
		return
	for h: Variant in ctx.huds:
		if is_instance_valid(h):
			(h as TLHud).visible = false


func _make(id: StringName, anchor: StringName, source: Callable) -> Label:
	if not ANCHORS.has(anchor):
		push_error("TLHud: unknown anchor '%s' (anchors: %s)" % [anchor, ", ".join(PackedStringArray(ANCHORS.keys()))])
		anchor = &"top_left"
	if _widgets.has(id):
		(_widgets[id] as Dictionary)["source"] = source
		return (_widgets[id] as Dictionary)["label"]
	var label: Label = Label.new()
	label.name = String(id)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var stack: int = int(_stacks.get(anchor, 0))
	_stacks[anchor] = stack + 1
	var a: Array = ANCHORS[anchor]
	var down: float = -1.0 if String(anchor).begins_with("bottom") else 1.0
	label.set_anchors_and_offsets_preset(a[0], Control.PRESET_MODE_KEEP_SIZE)
	label.position += (a[1] as Vector2) + Vector2(0, float(stack) * float(font_size + 10) * down)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if String(anchor) in ["top", "center", "bottom"] else (
		Control.GROW_DIRECTION_BEGIN if String(anchor).ends_with("right") else Control.GROW_DIRECTION_END)
	_widgets[id] = {"label": label, "source": source}
	return label


## A free label. Change it later with `set_text(id, text)`.
func add_label(id: StringName, text: String, anchor: StringName = &"top_left") -> void:
	_make(id, anchor, Callable()).text = text


func set_text(id: StringName, text: String) -> void:
	if _widgets.has(id):
		((_widgets[id] as Dictionary)["label"] as Label).text = text
	else:
		push_error("TLHud.set_text: no widget '%s'" % id)


## The text a widget shows right now (bots and tests can read the HUD).
func text_of(id: StringName) -> String:
	return ((_widgets[id] as Dictionary)["label"] as Label).text if _widgets.has(id) else ""


## The score of one side of a TLRules, kept up to date. Widget id: "score_<side>".
func add_score(rules: TLRules, side: String, anchor: StringName = &"top_left", caption: String = "") -> void:
	var shown: String = caption if not caption.is_empty() else side
	_make(StringName("score_" + side), anchor, func() -> String: return "%s %d" % [shown, rules.score(side)])


## The clock of a TLRules as MM:SS (time left in the period, or time played when there is no period clock). Id "clock".
func add_clock(rules: TLRules, anchor: StringName = &"top") -> void:
	_make(&"clock", anchor, func() -> String:
		return rules.clock_text() + ("  P%d" % rules.period if rules.periods > 1 else ""))


## A speed read-out from any Callable that returns a number (`car.speed_kmh`, `skater.speed`). Id "speed".
func add_speed(source: Callable, unit: String = "km/h", anchor: StringName = &"bottom_right") -> void:
	_make(&"speed", anchor, func() -> String: return "%d %s" % [int(round(float(source.call()))), unit])


## Any text from a Callable that returns a String, refreshed every frame.
func add_bound(id: StringName, source: Callable, anchor: StringName = &"top_left") -> void:
	_make(id, anchor, source)


func _physics_process(_delta: float) -> void:
	for w: Dictionary in _widgets.values():
		var source: Callable = w["source"]
		if source.is_valid():
			(w["label"] as Label).text = str(source.call())
