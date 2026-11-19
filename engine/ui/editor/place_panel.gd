extends VBoxContainer
## One explicit Find click owns one ask/answer pair. Always judge the answer against today's footprint.
const Scorer = preload("res://ui/editor/lot_scorer.gd")
const Look = preload("res://ui/editor/look.gd")

var wb: Control
var find_button: Button
var why: Label
var status: Label
var rows: VBoxContainer
var scroll: ScrollContainer
var asked_candidates: Array = []
var proposals: Array = []
var ranked: Array = []
var ask_path := ""
var out_path := ""
var number := 0
var measured_for := -1.0                 # round 3: the ring the editor's own three places were measured for (-1 = the Designer's)
var asked_words := PackedStringArray()   # the place words that made Find a place ask the Designer


func setup(workbench: Control, button: Button) -> void:
	wb = workbench
	find_button = button
	find_button.tooltip_text = "Three places for this game. When your words say where (by the river, quiet, next to ...), the Designer is asked: that calls the model."
	find_button.pressed.connect(_find)
	why = wb._label("", 14, false, wb.col.ink, true)
	why.name = "WhyHere"
	add_child(why)
	status = wb._label("", 13, true, wb.col.wood_dark, true)
	status.name = "PlaceStatus"
	add_child(status)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	scroll.hide()


func _ready() -> void:
	set_process(false)


func _message(words: String) -> void:
	status.text = words
	status.visible = not words.is_empty()


## Round 2 (19 Nov): the Designer is asked only when the player's words say something about the place. On a
## neutral request it picked the scorer's top three every time (9 of 9 real runs), so the editor offers its own three
## best measured places, worded from their facts, and calls no model.
const PLACE_WORDS: Array = ["quiet", "calm", "peaceful", "secluded", "hidden", "busy", "lively", "river", "riverside",
	"water", "stream", "bank", "lake", "near", "next to", "beside", "close to", "far from", "away from", "by the",
	"along", "view", "hill", "hilltop", "slope", "valley", "flat", "centre", "center", "middle", "edge", "outskirts",
	"corner", "north", "south", "east", "west", "behind", "opposite", "entrance", "square"]


## The phrases of `sentence` that name something about the place (whole words, lower case); empty = none.
static func place_words(sentence: String) -> PackedStringArray:
	var text := " "
	for ch in sentence.to_lower():
		text += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else " "
	text = " " + " ".join(text.split(" ", false)) + " "
	var found := PackedStringArray()
	for w: String in PLACE_WORDS:
		if text.contains(" " + w + " "):
			found.append(w)
	return found


## The editor's own three best measured places as proposals, each reason built from its measured facts.
static func measured_proposals(m) -> Array:
	var out: Array = []
	for c: Dictionary in Scorer.candidates(m, m.heights, 3):
		var parts: PackedStringArray = []
		for f: String in c.facts:
			if f.contains(" m walk from"):      # not "next to walker"
				parts.append(f)
		for f: String in c.facts:
			if f.begins_with("next to"):
				parts.append(f)
				break
		var reason := "; ".join(parts).left(118)
		out.append({"candidate": c.id, "at": c.at, "yaw_deg": 0.0, "reason": reason[0].to_upper() + reason.substr(1)})
	return out


func _find() -> void:
	proposals = []
	var words := place_words(str(wb.model.sentence))
	measured_for = -1.0
	if words.is_empty():
		proposals = measured_proposals(wb.model)
		measured_for = wb.model.lot_radius()
		if proposals.is_empty():
			_fallback("No measured free place fits.")
			return
		_rescore()
		_message("Measured by the editor, no model call: your words name no place. Say where you want it (\"by the river\", \"quiet\", \"next to the hockey\") and the Designer is asked.")
		wb.set_map_zoom(false)
		wb.refresh()
		return
	asked_words = words
	var root := str(wb.jobs_root)
	var dir := root.path_join("_editor/place") if not root.is_empty() else ProjectSettings.globalize_path("user://editor/place")
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		_fallback("Cannot open the placement folder.")
		return
	var slug := str(wb.model.sentence).to_lower().replace(" ", "-").validate_filename().left(36)
	while true:
		number += 1
		var stem := dir.path_join("%s-%d" % [slug, OS.get_process_id() * 1000000 + number])
		ask_path = stem + ".ask.json"
		out_path = stem + ".answer.json"
		if not FileAccess.file_exists(ask_path) and not FileAccess.file_exists(out_path):
			break
	var file := FileAccess.open(ask_path, FileAccess.WRITE)
	if file == null:
		_fallback("Cannot write the placement request.")
		return
	var ask: Dictionary = wb.model.place_ask()
	asked_candidates = ask.get("candidates", [])
	file.store_line(JSON.stringify(ask))
	file.close()
	var error := "Foreman unavailable" if wb.door == null else str(wb.door.place(ask_path, out_path))
	if not error.is_empty():
		_fallback("The Designer could not be asked: " + error)
		return
	_message("Asking the Designer for places…")
	refresh()
	set_process(true)


func _process(_delta: float) -> void:
	if ask_path.is_empty():
		set_process(false)
		return
	# The runner writes the complete answer atomically. The panel also polls this door.
	if not FileAccess.file_exists(out_path) and not wb.door.busy(ask_path).is_empty():
		wb.door.tick()
		return
	set_process(false)
	var response: Variant = null
	if FileAccess.file_exists(out_path):
		response = JSON.parse_string(FileAccess.get_file_as_string(out_path))
	var error: String = wb.door.last_error(ask_path)
	ask_path = ""
	if response is Dictionary and response.get("schema") == "tl.place-answer/1":
		record_call(wb.model, response)
		if response.size() == 2 and response.get("error") is String:
			error = response.error
		elif valid_answer(response) and match_candidates(response.proposals, asked_candidates):
			proposals = response.proposals
			_rescore()
			if ranked[0].valid:
				_message("The Designer chose these for \"%s\" in your words." % "\", \"".join(asked_words))
				wb.set_map_zoom(false)
				wb.refresh()
				return
			error = "None of the suggested places fits."
	_fallback(error if not error.is_empty() else "The Designer returned no usable places.")


## Round 2 (19 Nov): a model call costs tokens; Build it hands every call's figures to `foreman new --place-calls`,
## which logs each as a job-level builder_run (tl ledger counts it). An answer without usage figures records nothing.
static func record_call(m, response: Dictionary) -> void:
	if not (response.get("adapter") is String and response.get("model") is String and (response.get("durationMs") is float or response.get("durationMs") is int)):
		return
	var c := {"adapter": response.adapter, "model": response.model, "durationMs": int(response.durationMs)}
	for k in ["tokensIn", "tokensOut"]:
		if response.get(k) is float or response.get(k) is int:
			c[k] = int(response[k])
	m.place_calls.append(c)


static func match_candidates(picks: Array, candidates: Array) -> bool:
	for p: Dictionary in picks:
		if not p.has("candidate"):
			continue
		var matched := false
		for c: Dictionary in candidates:
			if c.id == p.candidate:
				matched = Vector2(p.at[0], p.at[1]).distance_to(Vector2(c.at[0], c.at[1])) <= 0.5
				break
		if not matched:
			return false
	return true


static func valid_answer(response: Dictionary) -> bool:
	for key in response:
		if key not in ["schema", "proposals", "adapter", "model", "durationMs", "tokensIn", "tokensOut"]:
			return false
	for key in ["adapter", "model"]:
		if not response.get(key) is String or response[key].strip_edges().is_empty():
			return false
	for key in ["durationMs", "tokensIn", "tokensOut"]:
		if key == "durationMs" or response.has(key):
			var n: Variant = response.get(key)
			if not (n is int or n is float) or not is_finite(n) or n < 0:
				return false
	var value: Variant = response.get("proposals")
	if not value is Array or value.size() < 2 or value.size() > 3:
		return false
	for p: Variant in value:
		if not p is Dictionary or not p.get("reason") is String or p.reason.strip_edges().is_empty():
			return false
		for key in p:
			if key not in ["candidate", "at", "yaw_deg", "reason"]:
				return false
		if p.has("candidate") and (not p.candidate is String or p.candidate.length() != 1 or p.candidate < "A" or p.candidate > "Z"):
			return false
		if not p.get("at") is Array or p.at.size() != 2:
			return false
		for n: Variant in [p.at[0], p.at[1], p.get("yaw_deg")]:
			if not (n is int or n is float) or not is_finite(n):
				return false
		if absf(p.yaw_deg) > 360 or p.reason.length() >= 120 or "\n" in p.reason or "\r" in p.reason or "\u2028" in p.reason or "\u2029" in p.reason:
			return false
	return true


func _fallback(error: String) -> void:
	ask_path = ""
	set_process(false)
	var m = wb.model
	var measured := Scorer.candidates(m, m.heights, 1)
	var action := "No measured free place fits."
	if not measured.is_empty():
		var centre: Array = measured[0].at
		m.place(Vector2(centre[0], centre[1]), "auto")
		m.no_free = false
		action = "The best measured free place is taken."
	_message("%s. %s" % [error.get_slice("\n", 0).strip_edges().trim_suffix("."), action])
	wb.refresh()


func _lines(lines: Array) -> String:
	var parts := PackedStringArray()
	for line: Dictionary in lines:
		var cost := float(line.points)
		parts.append(str(line.text) + (" (−%.1f)" % cost if cost > 0 else ""))
	return "  ·  ".join(parts)


func refresh() -> void:
	var m = wb.model
	find_button.disabled = not ask_path.is_empty() or m.recipe.is_empty() or not m.village_ok
	why.visible = m.placed and not m.recipe.is_empty()
	if why.visible:
		var current := Scorer.score(m, m.at, m.yaw, m.heights)
		var title := "Why here   %s" % ("%.1f / 100" % current.score if current.valid else "Refused")
		if m.placed_by == "proposal":
			title += "    “%s”" % m.proposal_reason
		why.text = title + "\n" + _lines(current.lines)
	status.visible = not status.text.is_empty()
	var had_places := not ranked.is_empty() and bool(ranked[0].valid)
	# Round 3: the editor's own places follow the requirements: an answer that changes the ring measures them again
	# (free: no model call). The Designer's places stay as it chose them and are judged again below.
	if measured_for > 0.0 and not is_equal_approx(m.lot_radius(), measured_for):
		proposals = measured_proposals(m)
		measured_for = m.lot_radius()
		if proposals.is_empty():
			ranked = []
			_rescore()
			_fallback("No measured free place fits the new size.")
			return
	_rescore()
	if had_places and not ranked.is_empty() and not ranked[0].valid:
		_fallback("The new footprint rules out every suggested place.")
		return
	for i in ranked.size():
		if ranked[i].valid:
			var take := rows.find_child("TakePlace%d" % (i+1), true, false) as Button
			var chosen: bool = m.placed_by == "proposal" and m.at == ranked[i].at and m.yaw == ranked[i].yaw
			take.text = "Chosen" if chosen else "Take this place"
			take.disabled = chosen


func _rescore() -> void:
	var next := Scorer.rank(wb.model, proposals, wb.model.heights)
	if next == ranked:
		return
	ranked = next
	wb._map.proposals = ranked
	wb._map.highlight = -1
	wb._map.queue_redraw()
	wb._clear(rows)
	scroll.visible = not ranked.is_empty()
	wb._strip.visible = ranked.is_empty()
	for i in ranked.size():
		_row(i)
	# Leave enough map above the scrollable rows to locate their numbers at 720p.
	scroll.custom_minimum_size.y = minf(minf(205, wb.size.y * 0.20), rows.get_combined_minimum_size().y + 6)


func _highlight(i: int) -> void:
	wb._map.highlight = i
	wb._map.queue_redraw()


func _row(i: int) -> void:
	var r: Dictionary = ranked[i]
	var panel := PanelContainer.new()
	panel.name = "PlaceRow%d" % (i+1)
	panel.add_theme_stylebox_override("panel", Look.sb(wb.col.card, wb.col.rule, 1, 3, 8, 3))
	rows.add_child(panel)
	panel.mouse_entered.connect(_highlight.bind(i))
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_highlight(i))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(h)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	h.add_child(body)
	var verdict := "%.1f / 100" % r.score if r.valid else "Refused · 0 / 100"
	var origin := str(r.get("candidate", "the Designer's own place"))
	body.add_child(wb._label("%d   %s · %s   ·   %s" % [i+1, origin, verdict, r.reason], 14, true, wb.col.ink, true))
	body.add_child(wb._label(_lines(r.lines), 13, false, wb.col.dim if r.valid else wb.col.hazard, true))
	if r.valid:
		var take: Button = wb._chip("TakePlace%d" % (i+1), "Take this place", "")
		take.mouse_entered.connect(_highlight.bind(i))
		take.pressed.connect(func() -> void:
			var checked := Scorer.score(wb.model, r.at, r.yaw, wb.model.heights)
			if checked.valid:
				wb.model.yaw = r.yaw
				wb.model.place(r.at, "proposal", r.reason)
				wb.set_map_zoom(true)
			wb.refresh())
		h.add_child(take)
