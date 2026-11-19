extends SceneTree
## Score a saved exchange against its village geometry and this engine's terrain and recipe data.
const Model = preload("res://ui/editor/editor_model.gd")
const PanelScript = preload("res://ui/editor/place_panel.gd")
const Scorer = preload("res://ui/editor/lot_scorer.gd")


func _initialize() -> void:
	var paths := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() != 2 or pair[0] not in ["--ask", "--answer"] or paths.has(pair[0]):
			break
		paths[pair[0]] = pair[1]
	if paths.size() != 2 or OS.get_cmdline_user_args().size() != 2:
		printerr("rank needs --ask=<file> and --answer=<file>")
		quit(2)
		return
	var ask: Variant = Model._read(paths["--ask"])
	var answer: Variant = Model._read(paths["--answer"])
	var model := Model.new()
	model.load_all()
	if not ask is Dictionary or not _restore(model, ask):
		printerr("Cannot read placement ask or reproduce its footprint: ", paths["--ask"])
		quit(2)
		return
	if not answer is Dictionary or answer.get("schema") != "tl.place-answer/1" or not PanelScript.valid_answer(answer):
		printerr("Cannot read placement proposals: ", paths["--answer"])
		quit(2)
		return
	var ranked := Scorer.rank(model, answer.proposals, model.heights)
	var valid := 0
	var total := 0.0
	for i in ranked.size():
		var r: Dictionary = ranked[i]
		var lines := PackedStringArray()
		for line: Dictionary in r.lines:
			lines.append(line.text + (" (−%.1f)" % line.points if line.points > 0 else ""))
		print("%d | %s | %.1f | %s | %s | %s | %s" % [i+1, r.valid, r.score, r.get("candidate", "own"), r.at, r.reason, " · ".join(lines)])
		if r.valid:
			valid += 1
			total += r.score
	print(JSON.stringify({"schema":"tl.place-rank/1", "valid":valid, "of":ranked.size(), "best":ranked[0].score,
		"mean_valid":snappedf(total / valid, 0.01) if valid else 0.0}, "", false))
	quit(0)


static func _shape(value: Variant, required: Array, optional: Array = []) -> bool:
	if not value is Dictionary or not value.has_all(required):
		return false
	for key in value:
		if key not in required and key not in optional:
			return false
	return true


static func _candidates(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > 12:
		return false
	var seen := {}
	for c in value:
		if not _shape(c, ["id", "at", "score", "facts"]) or not _numbers(c.at, 2) or not _numbers([c.score], 1):
			return false
		if not c.id is String or c.id.length() != 1 or c.id < "A" or c.id > "Z" or seen.has(c.id):
			return false
		if c.score < 0 or c.score > 100 or not c.facts is Array or c.facts.is_empty():
			return false
		for fact in c.facts:
			if not fact is String or fact.strip_edges().is_empty():
				return false
		seen[c.id] = true
	return true


static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for n in value:
		if not (n is int or n is float) or not is_finite(n):
			return false
	return true


static func _polyline(value: Variant) -> PackedVector2Array:
	var points := PackedVector2Array()
	if value is Array and value.size() >= 2:
		for pair in value:
			if not _numbers(pair, 2):
				return PackedVector2Array()
			points.append(Vector2(pair[0], pair[1]))
	return points


static func _restore(model: Model, ask: Dictionary) -> bool:
	if not _shape(ask, ["schema", "sentence", "answers", "footprint", "radius", "village"], ["card", "candidates"]):
		return false
	if ask.has("candidates") and not _candidates(ask.candidates):
		return false
	if ask.get("schema") != "tl.place-ask/1" or not ask.get("sentence") is String or not ask.get("answers") is Dictionary:
		return false
	model.set_sentence(ask.sentence)
	var card: Variant = ask.get("card", "")
	if not card is String or (ask.has("card") and not model.cards.has(card)):
		return false
	model.choose_recipe(card.trim_prefix("card.") if ask.has("card") else "none")
	for key in ask.answers:
		if not ask.answers[key] is String or model.option(model.question(key), ask.answers[key]).is_empty():
			return false
		model.answer(key, ask.answers[key])
	var f := model.footprint()
	var fp: Variant = ask.get("footprint")
	if not _shape(fp, ["size_m", "height_m", "shape"], ["stands"]):
		return false
	if fp.shape != model.shape().shape or fp.get("stands", false) != model.shape().stands:
		return false
	if fp.get("size_m") != [f.x, f.y] or fp.get("height_m") != f.z or ask.get("radius") != model.lot_radius():
		return false
	var village: Variant = ask.get("village")
	if not _shape(village, ["plots", "bounds", "road", "road_half_m"], ["river"]):
		return false
	if not _numbers(village.bounds, 4) or not village.plots is Array:
		return false
	var b: Array = village.bounds
	model.bounds = Rect2(b[0], b[1], b[2]-b[0], b[3]-b[1])
	if not model.bounds.has_area():
		return false
	model.plots.clear()
	for lot in village.plots:
		if not _shape(lot, ["id", "label", "kind", "at", "r"]) or not _numbers(lot.at, 2) or not _numbers([lot.r], 1) or lot.r <= 0:
			return false
		if not lot.get("id") is String or not lot.get("label") is String or not lot.get("kind") is String:
			return false
		var copy: Dictionary = lot.duplicate()
		copy.at = Vector2(lot.at[0], lot.at[1])
		model.plots.append(copy)
	model.road = _polyline(village.get("road"))
	if model.road.is_empty() or not _numbers([village.road_half_m], 1) or village.road_half_m <= 0:
		return false
	model.road_half_m = village.road_half_m
	model.river.clear()
	if village.has("river"):
		var river: Variant = village.river
		if not _shape(river, ["half_m", "path"]) or not _numbers([river.half_m], 1) or river.half_m <= 0:
			return false
		model.river = _polyline(river.get("path"))
		if model.river.is_empty():
			return false
		model.river_half_m = river.half_m
	var boot: Variant = Model._read(model.VILLAGE)
	if not boot is Dictionary:
		return false
	model.prepare_terrain(boot.get("landscape", {}))
	return true
