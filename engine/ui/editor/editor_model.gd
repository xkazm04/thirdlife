extends RefCounted
## E1 (night of 19 Nov): the workbench's one model. Everything the "New game" workbench shows is a projection of this
## object: the player's sentence (kept verbatim), the recipe (a card's interview or the editor's none.json), the
## answers (each with who gave it: the player, the sentence, or nobody yet = the proposal stands), the placement on the
## village map, and what is derived from them: the request "Build it" sends, the footprint, the lot's radius, the gate,
## the checks. No screen keeps an answer of its own; nothing is written until commit (`draft()` is what is written).

const Scorer = preload("res://ui/editor/lot_scorer.gd")
const NONE_INTERVIEW: String = "res://ui/interview/none.json"
const CARDS_DIR: String = "res://cards"
const VILLAGE: String = "res://boot/village.json"
const WALKER_M: float = 2.0          # the walking figure, as the brief measures him
const RUN_MPS: float = 4.5           # his run, for "seconds to cross" (walker-feel, 18 Nov: 4.5 m/s)
const ROAD_HALF_M: float = 4.0       # the road's half width for the "on the road" check
const RING_GAP_M := 2.0              # clearance from the lot edge to the riverbank
# The entrance rails stand this far beyond the radius of each lot.
const LOT_EDGE_M := 3.6
const LOT_GAP_M := 2.0
const ROAD_GAP_M := 1.0
const FIT_EPS_M := 0.00002           # Vector2 coordinates are single precision
const FAR_FROM_ROAD_M: float = 40.0  # a path longer than this is a warning
const YAW_STEP: float = PI / 12.0    # 15 degrees
const NONE_AFTER_WORDS: int = 4      # how many words before "no recipe fits" is said

var walker_m: float = WALKER_M       # the constants, readable through an untyped reference
var road_half_m: float = ROAD_HALF_M
var interviews: Dictionary = {}      # name -> interview (Dictionary)
var interview_order: PackedStringArray = []   # card interviews first (file order), "none" last
var cards: Dictionary = {}           # card id -> card json (title, summary)
var load_errors: PackedStringArray = []

var sentence: String = ""
var recipe: String = ""              # interview name ("team_possession", ..., "none"); "" = nothing chosen yet
var recipe_by: String = ""           # "match" (from the sentence) or "player"
var matches: Array = []              # [{name, score, words}], best first, score > 0 only
var answers: Dictionary = {}         # key -> {id, by: "player" | "sentence", words?}

# village
var village_ok: bool = false
var plots: Array = []                # [{id, label, at: Vector2, r: float, kind: "plot" | "site"}]
var road: PackedVector2Array = PackedVector2Array()
var river: PackedVector2Array = PackedVector2Array()   # E6: the village's river (landscape.river.path)
var river_half_m: float = 0.0
var bounds: Rect2 = Rect2()
var at: Vector2 = Vector2.ZERO
var yaw: float = 0.0                 # Turns the footprint in the editor. The world still faces its gate to the road.
var land: RefCounted
var heights: Callable
var road_samples := PackedVector2Array()
var river_samples := PackedVector2Array()
var proposal_reason := ""
var place_calls: Array = []           # each "Find a place" model call: {adapter, model, durationMs, tokensIn?, tokensOut?} (foreman new --place-calls)
var placed: bool = false
var placed_by: String = ""           # "auto" (the workbench's first free spot, follows the size) or "player"
var auto_key := ""                   # recipe and size of the last automatic placement (roadside or measured)
var no_free: bool = false            # the last first_free() found no place by the road for this size
var auto_far: bool = false           # ... and took the best measured place further back instead (Day 19 Nov)


func load_all() -> void:
	interviews.clear()
	interview_order.clear()
	load_errors.clear()
	cards.clear()
	var files := DirAccess.get_files_at(CARDS_DIR)
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var card: Variant = _read(CARDS_DIR.path_join(file))
		if not card is Dictionary:
			load_errors.append("cannot read card %s" % file)
			continue
		if not card.has("interview"):
			continue
		var cid: String = card.id
		var name := file.get_basename()
		cards[cid] = card
		var interview: Dictionary = card.interview.duplicate()
		interview["schema"] = "tl.ui-interview/1"
		interview["card"] = cid
		if card.has("footprint"):
			interview["footprint"] = card.footprint
		interviews[name] = interview
		interview_order.append(name)
	var none: Variant = _read(NONE_INTERVIEW)
	if none is Dictionary and none.get("schema") == "tl.ui-interview/1":
		interviews["none"] = none
		interview_order.append("none")
	else:
		load_errors.append("none interview is not tl.ui-interview/1")
	_load_village()


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_village() -> void:
	village_ok = false
	plots.clear()
	road = PackedVector2Array()
	var v: Variant = _read(VILLAGE)
	if not (v is Dictionary):
		return
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for d: Dictionary in v.get("plots", []):
		var o: Array = d.get("origin", [0, 0, 0])
		var e: Dictionary = {"id": str(d.get("id", "")), "label": str(d.get("id", "")), "pack": str(d.get("pack", "")),
			"at": Vector2(float(o[0]), float(o[2])), "r": float(d.get("radius", 20)), "kind": "plot"}
		var footprint: Array = d.get("footprint", {}).get("size_m", [])
		if footprint.size() == 2:
			e.pad_size = Vector2(footprint[0], footprint[1])
		e.yaw = -deg_to_rad(float(d.get("yaw", 0.0))) # Godot +Y rotation in the map's x/z plane
		plots.append(e)
	var land: Dictionary = (v as Dictionary).get("landscape", {})
	var k: int = 0
	for d: Dictionary in land.get("lots", []):
		var a: Array = d.get("at", [0, 0])
		var job: String = str(d.get("job", "")).get_file()
		plots.append({"id": "site_%d" % k, "label": _job_label(job), "pack": "", "at": Vector2(float(a[0]), float(a[1])),
			"r": float(d.get("radius", 20)), "kind": "site"})
		k += 1
	river = PackedVector2Array()
	var rv: Variant = land.get("river", {})
	if typeof(rv) == TYPE_DICTIONARY:
		for q: Variant in (rv as Dictionary).get("path", []):
			river.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
		river_half_m = float((rv as Dictionary).get("half_m", 6.0))
	for q: Variant in (v as Dictionary).get("road", []):
		road.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	for e: Dictionary in plots:
		var c: Vector2 = e["at"]
		var r: float = e["r"]
		lo = Vector2(minf(lo.x, c.x - r), minf(lo.y, c.y - r))
		hi = Vector2(maxf(hi.x, c.x + r), maxf(hi.y, c.y + r))
	for q: Vector2 in road:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if plots.is_empty():
		return
	# the landscape is drawn this far beyond its plots and road (village.json landscape.margin_m), half of it is ground
	# a lot may take; a lot further out is outside the village
	var mg: float = float(land.get("margin_m", 60.0)) * 0.5
	bounds = Rect2(lo - Vector2(mg, mg), hi - lo + Vector2(mg, mg) * 2.0)
	road_half_m = float(land.get("road_half_m", 2.6))
	prepare_terrain(land)


func prepare_terrain(cfg: Dictionary) -> void:
	road_samples = TLKitPath.new(Array(road), false, 2.0).pts if road.size() >= 2 else PackedVector2Array()
	river_samples = TLKitPath.new(Array(river), false, 4.0).pts if river.size() >= 2 else PackedVector2Array()
	self.land = Scorer.terrain(self, cfg)
	heights = Callable(self.land, "base_h")
	village_ok = true


## "topple-tower-crates-three-20261118-1" -> "topple tower crates three"
static func _job_label(job: String) -> String:
	var parts: PackedStringArray = job.split("-")
	while parts.size() > 1 and (parts[parts.size() - 1].is_valid_int()):
		parts.remove_at(parts.size() - 1)
	return " ".join(parts)


# ---------------------------------------------------------------- the sentence and the recipe

static func _norm(text: String) -> String:
	var s: String = " " + text.to_lower() + " "
	for ch: String in [",", ".", "!", "?", ";", ":", "(", ")", "\"", "'"]:
		s = s.replace(ch, " ")
	while s.find("  ") != -1:
		s = s.replace("  ", " ")
	return s


static func _has(norm: String, phrase: String) -> bool:
	return norm.find(" " + phrase.to_lower() + " ") != -1


func set_sentence(text: String) -> void:
	sentence = text.strip_edges()
	var norm: String = _norm(sentence)
	matches.clear()
	if sentence.split(" ", false).size() >= 2:
		for n: String in interview_order:
			if n == "none":
				continue
			var words: PackedStringArray = []
			var score: int = 0
			for w: Variant in (interviews[n] as Dictionary).get("match", []):
				if _has(norm, str(w)):
					words.append(str(w))
					score += str(w).split(" ", false).size()
			if score > 0:
				matches.append({"name": n, "score": score, "words": words})
		matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["score"]) > int(b["score"]) or (int(a["score"]) == int(b["score"]) and str(a["name"]) < str(b["name"])))
	if recipe_by != "player":
		# "none" is said only once the idea has a few words: no flash of "no recipe" while the first words are typed
		var want: String = str(matches[0]["name"]) if not matches.is_empty() else ("none" if sentence.split(" ", false).size() >= NONE_AFTER_WORDS else "")
		if want != recipe:
			recipe = want
			recipe_by = "match"
			_drop_answers_not_in_recipe()
	_read_answers_from_sentence()


func choose_recipe(name: String) -> void:
	if not interviews.has(name):
		return
	recipe = name
	recipe_by = "player"
	_drop_answers_not_in_recipe()
	_read_answers_from_sentence()


func _drop_answers_not_in_recipe() -> void:
	var keep: Dictionary = {}
	for q: Dictionary in questions():
		if answers.has(q["key"]):
			keep[q["key"]] = answers[q["key"]]
	answers = keep


## An option whose `from_words` occur in the sentence answers its question "by the sentence" (the longest phrase wins);
## an answer the player gave is never overwritten by the sentence.
func _read_answers_from_sentence() -> void:
	var norm: String = _norm(sentence)
	for q: Dictionary in questions():
		var key: String = q["key"]
		if answers.has(key) and str((answers[key] as Dictionary)["by"]) == "player":
			continue
		var best: String = ""
		var best_len: int = 0
		var best_words: String = ""
		for o: Dictionary in q["options"]:
			for w: Variant in o.get("from_words", []):
				if _has(norm, str(w)) and str(w).length() > best_len:
					best = str(o["id"])
					best_len = str(w).length()
					best_words = str(w)
		if best.is_empty():
			answers.erase(key)
		else:
			answers[key] = {"id": best, "by": "sentence", "words": best_words}


func interview() -> Dictionary:
	return interviews.get(recipe, {}) if not recipe.is_empty() else {}


func card() -> Dictionary:
	return cards.get(str(interview().get("card", "")), {})


func has_card() -> bool:
	return not recipe.is_empty() and recipe != "none"


func questions() -> Array:
	return interview().get("questions", [])


func question(key: String) -> Dictionary:
	for q: Dictionary in questions():
		if q["key"] == key:
			return q
	return {}


func option(q: Dictionary, id: String) -> Dictionary:
	for o: Dictionary in q.get("options", []):
		if str(o["id"]) == id:
			return o
	return {}


# ---------------------------------------------------------------- answers

func answer(key: String, id: String) -> void:
	var q: Dictionary = question(key)
	if q.is_empty() or option(q, id).is_empty():
		return
	answers[key] = {"id": id, "by": "player"}


## What the question stands at: the answer when there is one, else the proposal. {id, by: player|sentence|proposal}
func value(key: String) -> Dictionary:
	if answers.has(key):
		return answers[key]
	var q: Dictionary = question(key)
	return {"id": str(q.get("propose", "")), "by": "proposal"}


func take_proposals() -> int:
	var n: int = 0
	for q: Dictionary in questions():
		if not answers.has(q["key"]):
			answers[q["key"]] = {"id": str(q["propose"]), "by": "player", "took": "proposal"}
			n += 1
	return n


func apply_variant(index: int) -> void:
	var vs: Array = interview().get("variants", [])
	if index < 0 or index >= vs.size():
		return
	var set: Dictionary = (vs[index] as Dictionary).get("set", {})
	for key: String in set:
		answer(key, str(set[key]))


func decided_count() -> int:
	var n: int = 0
	for q: Dictionary in questions():
		if answers.has(q["key"]):
			n += 1
	return n


# ---------------------------------------------------------------- size

## [x, z, h] in metres: the interview's base footprint, then each question's chosen (or proposed) option: `set`
## replaces the size and `scale` multiplies it in question order, then `add` grows it.
func footprint() -> Vector3:
	var fp: Dictionary = interview().get("footprint", {})
	var s: Array = fp.get("size_m", [40, 40])
	var size: Vector3 = Vector3(float(s[0]), float(s[1]), float(fp.get("height_m", 4)))
	var adds: Vector3 = Vector3.ZERO
	for q: Dictionary in questions():
		var o: Dictionary = option(q, str(value(q["key"])["id"]))
		var sz: Dictionary = o.get("size", {})
		if sz.has("set"):
			var a: Array = sz["set"]
			size = Vector3(float(a[0]), float(a[1]), float(a[2]))
		if sz.has("scale"):
			size *= float(sz["scale"])
		if sz.has("add"):
			var a: Array = sz["add"]
			adds += Vector3(float(a[0]), float(a[1]), float(a[2]))
	return size + adds


## How the footprint is drawn from above: the interview's shape, unless the chosen (or proposed) option of a question
## names its own; `stands` when an answer puts stands along the long sides.
func shape() -> Dictionary:
	var out: Dictionary = {"shape": str(interview().get("footprint", {}).get("shape", "yard")), "stands": false}
	for q: Dictionary in questions():
		var o: Dictionary = option(q, str(value(q["key"])["id"]))
		if o.has("shape"):
			out["shape"] = str(o["shape"])
		if bool(o.get("stands", false)):
			out["stands"] = true
	return out


## The site's own rule (kernel/world/WORLD.md, S3): half the footprint's diagonal + 4 m, at least 12 m.
func lot_radius() -> float:
	var f: Vector3 = footprint()
	return maxf(12.0, ceilf(Vector2(f.x, f.y).length() * 0.5 + 4.0))


static func edge_radius(radius: float) -> float:
	return radius + LOT_EDGE_M


static func lot_gap(at_pos: Vector2, radius: float, lot: Dictionary) -> float:
	return at_pos.distance_to(lot.at) - edge_radius(radius) - edge_radius(lot.r)


func lot_inside(centre: Vector2, radius: float) -> bool:
	var inset := bounds.grow(-edge_radius(radius))
	return (centre.x >= inset.position.x - FIT_EPS_M and centre.x <= inset.end.x + FIT_EPS_M
		and centre.y >= inset.position.y - FIT_EPS_M and centre.y <= inset.end.y + FIT_EPS_M)


func yaw_note() -> String:
	if yaw == 0.0:
		return ""
	return "Turned %s°: the game stands turned on its lot; its gate still faces the road." % str(rad_to_deg(yaw)).trim_suffix(".0")


func seconds_across() -> float:
	var f: Vector3 = footprint()
	return maxf(f.x, f.y) / RUN_MPS


# ---------------------------------------------------------------- place

func placement_key() -> String:
	return "%s|%s" % [recipe, str(footprint())]


func place(p: Vector2, by: String = "player", reason := "") -> void:
	if by == "auto":
		auto_key = placement_key()
	proposal_reason = reason
	at = p
	placed = true
	placed_by = by


func turn(steps: int) -> void:
	yaw = wrapf(yaw + YAW_STEP * steps, -PI, PI)


## A free spot to start from: along the road, the first place whose checks have no error (deterministic).
func roadside_positions(r: float) -> PackedVector2Array:
	var positions := PackedVector2Array()
	# Try the nearest lot setback first, then work farther from the road.
	for back: float in [6.0, 14.0, 24.0, 40.0]:
		for side: float in [1.0, -1.0]:
			for i: int in range(road.size() - 1):
				var a: Vector2 = road[i]
				var b: Vector2 = road[i + 1]
				for t: float in [0.5, 0.3, 0.7, 0.1, 0.9]:
					var p: Vector2 = a.lerp(b, t)
					var n: Vector2 = (b - a).orthogonal().normalized() * side
					var c: Vector2 = p + n * (edge_radius(r) + road_half_m + back)
					positions.append(c)
	return positions


func first_free() -> Vector2:
	var r := lot_radius()
	auto_far = false
	for c: Vector2 in roadside_positions(r):
		if _errors_at(c, r).is_empty():
			no_free = false
			return c
	# Day 19 Nov: nothing by the road: the best measured free place anywhere in the village (lot_scorer.candidates),
	# rather than a refused ghost in the middle of the map; checks() says so.
	if heights.is_valid():
		var far: Array = Scorer.candidates(self, heights, 1)
		if not far.is_empty():
			no_free = false
			auto_far = true
			var centre: Variant = far[0].at
			return centre if centre is Vector2 else Vector2(float(centre[0]), float(centre[1]))
	no_free = true
	return bounds.get_center()


## landscape.gd uses the nearest 2 m road sample for the end of the spur.
func road_point(p: Vector2) -> Vector2:
	var best := p
	var distance := INF
	for q in road_samples:
		var d := q.distance_squared_to(p)
		if d < distance:
			distance = d
			best = q
	return best


func gate() -> Vector2:
	return Scorer.spur(self, at, lot_radius()).from


func path_m() -> float:
	return Scorer.spur(self, at, lot_radius()).length_m


func _errors_at(c: Vector2, r: float) -> Array:
	return Scorer.errors(self, c, r, Scorer.spur(self, c, r))


## Every check of the current placement, errors first: {level: error|warn, what, text}.
func checks() -> Array:
	if not village_ok:
		return [{"level": "error", "what": "map", "text": "the village map could not be read (boot/village.json)"}]
	if not placed:
		return [{"level": "error", "what": "unplaced", "text": "no place chosen on the map yet"}]
	var out: Array = _errors_at(at, lot_radius())
	if no_free and placed_by == "auto" and not out.is_empty():
		out.push_front({"level": "error", "what": "no_room", "text": "no free place by the road fits a lot of radius %d m: make it smaller, or drag it where you want it" % int(lot_radius())})
	if out.is_empty() and auto_far and placed_by == "auto":
		out.append({"level": "warn", "what": "no_roadside", "text": "no place by the road fits a lot of radius %d m: the best measured place further back is taken" % int(lot_radius())})
	if out.is_empty() and path_m() > FAR_FROM_ROAD_M:
		out.append({"level": "warn", "what": "far", "text": "a %d m walk from the road" % int(path_m())})
	return out


func fits() -> bool:
	for c: Dictionary in checks():
		if c["level"] == "error":
			return false
	return true


## The plot of the village whose pack is the recipe's worked example, for "as big as" (or {}).
func neighbour_like() -> Dictionary:
	var c: Dictionary = card()
	var want: String = str(c.get("pack", c.get("seed", "")))
	if want.is_empty():
		return {}
	if want == "hockey":
		want = "ice_hockey_three_against"
	for e: Dictionary in plots:
		if e["pack"] == want:
			return e
	return {}


# ---------------------------------------------------------------- what is sent

func request() -> String:
	var says: PackedStringArray = []
	for q: Dictionary in questions():
		var o: Dictionary = option(q, str(value(q["key"])["id"]))
		if not o.is_empty():
			says.append(str(o.get("say", o.get("label", ""))))
	var s: String = sentence.strip_edges().trim_suffix(".")
	if says.is_empty():
		return s
	return "%s. Decided: %s." % [s, "; ".join(says)]


func left_to_proposal() -> PackedStringArray:
	var out: PackedStringArray = []
	for q: Dictionary in questions():
		if not answers.has(q["key"]):
			out.append(str(q["key"]))
	return out


## What blocks "Build it", in words ("" = nothing).
func blocker() -> String:
	if sentence.split(" ", false).size() < 2:
		return "say in a few words what you want to play"
	if recipe.is_empty():
		return "choose a recipe, or None of these"
	var errs: PackedStringArray = []
	for c: Dictionary in checks():
		if c["level"] == "error":
			errs.append(str(c["text"]))
	if errs.is_empty():
		return ""
	return "the place: " + errs[0] + ("" if errs.size() == 1 else " (and %d more)" % (errs.size() - 1))


func answer_ids() -> Dictionary:
	var ids := {}
	for q: Dictionary in questions():
		ids[q.key] = value(q.key).id
	return ids


static func _coords(points: PackedVector2Array) -> Array:
	var coords := []
	for p in points:
		coords.append([p.x, p.y])
	return coords


func place_ask() -> Dictionary:
	var village := {"plots": [], "road": _coords(road), "road_half_m": road_half_m,
		"bounds": [bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]}
	for p: Dictionary in plots:
		village.plots.append({"id": p.id, "label": p.label, "kind": p.kind, "at": [p.at.x, p.at.y], "r": p.r})
	if not river.is_empty():
		village.river = {"path": _coords(river), "half_m": river_half_m}
	var f := footprint()
	var fp := {"size_m": [f.x, f.y], "height_m": f.z, "shape": shape().shape}
	if shape().stands:
		fp.stands = true
	var ask := {"schema": "tl.place-ask/1", "sentence": sentence, "answers": answer_ids(), "footprint": fp,
		"radius": lot_radius(), "village": village}
	var measured := Scorer.candidates(self, heights)
	if not measured.is_empty():
		ask.candidates = measured
	if has_card():
		ask.card = card().id
	return ask


func draft() -> Dictionary:
	var f: Vector3 = footprint()
	var d: Dictionary = {"schema": "tl.editor-draft/1", "sentence": sentence, "request": request(),
		"answers": answers.duplicate(true),
		"footprint": {"size_m": [f.x, f.y], "height_m": f.z, "estimate": true},
		"lot": {"at": [at.x, at.y], "yaw_deg": snappedf(rad_to_deg(yaw), 0.1), "radius": lot_radius()}}
	if placed:
		d["placed_by"] = placed_by
		d["why"] = Scorer.score(self, at, yaw, heights).lines
		if placed_by == "proposal":
			d.lot.yaw_deg = rad_to_deg(yaw)
			d.why.push_front({"text": proposal_reason, "points": 0})
	if has_card():
		d["card"] = str(interview().get("card", ""))
	if not place_calls.is_empty():
		d["place_calls"] = place_calls.duplicate(true)
	var left: PackedStringArray = left_to_proposal()
	if not left.is_empty():
		d["left_to_proposal"] = Array(left)
	return d
