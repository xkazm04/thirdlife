extends RefCounted
## F2 (27 Nov 2026 day, the newcomer's playtest #3 and #7): where can I build. Read-only over protect.gd and the land
## layer (nothing here refuses or allows anything: the layers still decide). Build mode holds one and asks it each
## drawn frame with the current tool's id, the cursor's hit and the tool's reason:
##   - `cells` (for refusal_tint.gd): the 3 m ground cells round the cursor that the tool's kind of edit is refused on,
##     with their reason ("too close" is left out: it is the visitor's own feet and moves with him);
##   - `line()`: what the hotbar's where line says: the reason as a sentence a newcomer can act on and, while the
##     cursor itself stands on refused ground, the way to the nearest buildable ground ("buildable ground 120 m
##     south-east"), found by rings of samples round the cursor spread over frames (SAMPLES a frame, so a search to
##     350 m takes about a second and costs no frame more than about a millisecond).
## What each tool edits (WHAT): sculpt and water the land ("land"), paint "paint", plants "plant", paths "path" (the
## area rules of protect.gd `refusal_area`); blocks and stamps "blocks": the game lots only (protect.gd's circles,
## rects and boxes, as `refusal` reads them for a block: the village's land takes blocks). Other tools: nothing.
## North is -z, east +x (the Home's compass: the village is north of the river's bend).

const LATTICE := 3.0
const WHAT := {"sculpt": "land", "water": "land", "paint": "paint", "plant": "plant", "path": "path",
	"blocks": "blocks", "stamp": "blocks"}
const TINT_CELLS := 6                   # cells (of 3 m) round the cursor's cell the tint covers: 18 m
const RETINT_FRAMES := 20               # the tint is asked again this often while the cursor stays in one cell
const SEARCH_MAX := 800.0               # metres: farther than this, "no buildable ground within 800 m"
const RING := 9.0                       # metres between search rings
const RING_MAX := 96                    # samples on a ring at most (the far rings are sparser)
const SAMPLES := 48                     # search samples a frame
const MOVE := 12.0                      # metres the cursor moves before the search starts again
const SENTENCES := {
	"village": "the village's land stays as it is",
	"game lot": "a game's lot: kept free for its game",
	"river": "the river's banks stay as they are",
	"lane": "a lane: the way stays clear",
	"field": "a ploughed field: its furrows cannot follow",
	"outside the Home": "outside the Home",
	"blocks": "blocks stand on this ground",
	"tree": "a tree stands here",
	"too close": "you stand there: step aside",
	"height limit": "the ground goes no further than 24 m from its own height",
}

var cells := []                         # [[Vector2i cell, reason], ...] of the last `update`
var free := {}                          # Vector2i -> true: the cells round the cursor asked and buildable
var tint_key := ""                      # what the cells were worked out for (refusal_tint.gd redraws on a change)
var what := ""                          # the current tool's kind of edit ("" none)
var refused_here := false               # the cursor's own ground is refused for `what`
var found: Variant = null               # Vector2: the nearest buildable ground found from `origin`, or null
var origin := Vector2(INF, INF)         # where the search started
var searching := false
var asked := 0                          # samples asked by the search now (figures)
var size := Vector2(2 * LATTICE, 2 * LATTICE)   # metres: the ground the search asks to be free (a stamp's footprint)
var _ring := 0
var _k := 0
var _tint_at := Vector2i(1 << 30, 0)
var _tint_frame := -1000
var _search_key := ""


## Each drawn frame: `id` the tool's id, `h` the cursor's hit ({} none), `reason` the tool's reason now, `frame` the
## host's frame, `foot` (metres x, z) the ground the tool's edit takes (a stamp's turned size; Vector2.ZERO: a cell).
func update(pr: RefCounted, land: RefCounted, id: String, h: Dictionary, reason: String, frame: int, foot := Vector2.ZERO) -> void:
	what = str(WHAT.get(id, ""))
	if what == "" or pr == null or not h.has("pos"):
		_clear()
		return
	var p: Vector3 = h.pos
	var at := Vector2(p.x, p.z)
	size = Vector2(maxf(foot.x, 2 * LATTICE), maxf(foot.y, 2 * LATTICE))
	var c := Vector2i(floori(p.x / LATTICE), floori(p.z / LATTICE))
	if c != _tint_at or frame - _tint_frame >= RETINT_FRAMES or not tint_key.begins_with(what + "|"):
		_tint_at = c
		_tint_frame = frame
		_tint(pr, land, c)
	refused_here = reason != "" and not free_at(pr, land, at)
	var key := "%s|%s" % [what, str(size)]
	if not refused_here:
		searching = false
		found = null
		origin = Vector2(INF, INF)
		_search_key = ""
		return
	if key != _search_key or at.distance_to(origin) > MOVE:
		_search_key = key
		origin = at
		found = null
		searching = true
		_ring = 1
		_k = 0
		asked = 0
	if searching:
		_search(pr, land)


func _clear() -> void:
	if not cells.is_empty() or tint_key != "":
		cells = []
		free = {}
		tint_key = ""
	_tint_at = Vector2i(1 << 30, 0)
	refused_here = false
	searching = false
	found = null
	_search_key = ""


## Why the ground `rect` (metres) refuses `kind` ("blocks" or an area kind of protect.gd), "" when it does not.
static func refusal_of(pr: RefCounted, land: RefCounted, rect: Rect2, kind: String) -> String:
	if kind == "blocks":
		return lot_refusal(pr, rect)
	if land != null:
		land.begin_asking(rect.grow(LATTICE))
	var why := str(pr.refusal_area(rect, kind))
	if land != null:
		land.end_asking()
	return why


## protect.gd's own circles, rects and boxes over a ground rect, as `refusal` reads them for a block (no rule, no
## space): the game lots. Read only.
static func lot_refusal(pr: RefCounted, rect: Rect2) -> String:
	for c: Array in pr.get("circles"):
		var q: Vector2 = (c[0] as Vector2).clamp(rect.position, rect.end)
		if q.distance_to(c[0]) <= float(c[1]):
			return c[2]
	var reach := rect.size.length() * 0.5
	for r: Array in pr.get("rects"):
		var local := (rect.get_center() - (r[0] as Vector2)).rotated(float(r[2]))
		var half: Vector2 = r[1]
		if absf(local.x) <= half.x + reach and absf(local.y) <= half.y + reach:
			return r[3]
	for b: Array in pr.get("boxes"):
		var a: AABB = b[0]
		if Rect2(a.position.x, a.position.z, a.size.x, a.size.z).intersects(rect):
			return b[1]
	return ""


## True when the ground of `size` centred on `at` takes the current kind of edit (the visitor standing there does not
## count: he can step aside).
func free_at(pr: RefCounted, land: RefCounted, at: Vector2) -> bool:
	var why := refusal_of(pr, land, Rect2(at - size * 0.5, size), what)
	return why == "" or why == "too close"


func _tint(pr: RefCounted, land: RefCounted, c: Vector2i) -> void:
	cells = []
	free = {}
	if land != null and what != "blocks":
		land.begin_asking(Rect2((Vector2(c) - Vector2.ONE * (TINT_CELLS + 2)) * LATTICE, Vector2.ONE * (2 * TINT_CELLS + 5) * LATTICE))
	for j: int in range(-TINT_CELLS, TINT_CELLS + 1):
		for i: int in range(-TINT_CELLS, TINT_CELLS + 1):
			if i * i + j * j > TINT_CELLS * TINT_CELLS:
				continue
			var cell := c + Vector2i(i, j)
			var rect := Rect2(Vector2(cell) * LATTICE, Vector2.ONE * LATTICE)
			var why := lot_refusal(pr, rect) if what == "blocks" else str(pr.refusal_area(rect, what))
			if why != "" and why != "too close":
				cells.append([cell, why])
			else:
				free[cell] = true
	if land != null and what != "blocks":
		land.end_asking()
	tint_key = "%s|%s|%d|%s" % [what, str(c), cells.size(), str(cells.hash())]


## SAMPLES more points of the rings round `origin`; the first free one is `found` (the rings grow outward, so it is
## the nearest at the rings' spacing).
func _search(pr: RefCounted, land: RefCounted) -> void:
	var n := 0
	while n < SAMPLES:
		var r := _ring * RING
		if r > SEARCH_MAX:
			searching = false
			return
		var count := clampi(ceili(TAU * r / RING), 8, RING_MAX)
		if _k >= count:
			_ring += 1
			_k = 0
			continue
		var q := origin + Vector2.from_angle(TAU * float(_k) / count - PI * 0.5) * r
		_k += 1
		n += 1
		asked += 1
		if free_at(pr, land, q):
			found = q
			searching = false
			return


## The hotbar's where line: the reason as a sentence, then the way to buildable ground (or that the search goes on).
func line(reason: String) -> String:
	if what == "" or reason == "":
		return ""
	var out := sentence(reason)
	if refused_here:
		if found != null:
			out += ("   " if out != "" else "") + "buildable ground %s" % way(origin, found)
		elif searching:
			out += ("   " if out != "" else "") + "looking for buildable ground..."
		else:
			out += ("   " if out != "" else "") + "no buildable ground within %d m" % int(SEARCH_MAX)
	return out


## A reason of the layers as a sentence a newcomer can act on ("" when there is none to add).
static func sentence(reason: String) -> String:
	var r := reason
	var cut := r.rfind(": ")                    # "224 of 275 refused: game lot", "Start refused: game lot"
	if cut >= 0 and r.find(" refused") >= 0 and r.find(" refused") < cut:
		r = r.substr(cut + 2)
	if SENTENCES.has(r):
		return SENTENCES[r]
	if r.begins_with("height limit"):
		return SENTENCES["height limit"]
	if r.begins_with("authored structure (") and r.ends_with(")"):
		return "the %s stands here" % r.trim_prefix("authored structure (").trim_suffix(")").replace("_", " ")
	if r.begins_with("river ("):
		return "the river's water would show here"
	return ""


## "120 m south-east" from `a` to `b` (metres x, z; north -z): the distance rounded (5 m under 100 m, else 10 m).
static func way(a: Vector2, b: Vector2) -> String:
	var d := b - a
	var m := d.length()
	var shown := roundi(m / 5.0) * 5 if m < 100.0 else roundi(m / 10.0) * 10
	return "%d m %s" % [maxi(shown, 5), compass(d)]


static func compass(d: Vector2) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := atan2(d.x, -d.y)                   # 0 north, PI/2 east
	return names[posmod(roundi(a / (TAU / 8.0)), 8)]
