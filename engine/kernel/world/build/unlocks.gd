extends RefCounted
## M3 (spark world-sandbox, 26 Nov 2026): what play has unlocked in the Home (contracts/BUILD.md "Unlocks from play").
## The rules ship in res://kernel/world/build/unlocks.json (`tl.unlocks/1`); the results are the Home's trophies
## (trophies.gd). A rule is met when every number its `when` names is reached by the trophies of its `pack`; the
## pack "*" means every pack together (plays and wins summed, the best of any). What a met rule grants is free; what
## any rule grants and no met rule does is locked; everything no rule names is free, and M1's shapes 1-8 and
## materials 1-9 can never be locked (a rule naming them is refused when the file is read).
## Locks are asked by the hand tools (pieces, blocks' materials, stamps): a locked slot shows the lock and the
## condition ("win Ice hockey once") and refuses. The layers never ask: a saved Home, a stamp from a file and an
## accepted LLM answer load whatever they hold.
##   var u = Unlocks.new(dir)      # dir: the Home's folder ("" = no trophies: every rule unmet)
##   u.locked("parts", "house")    # "" or the condition, e.g. "win Parkour once"

const Trophies := preload("res://kernel/world/build/trophies.gd")
const RULES := "res://kernel/world/build/unlocks.json"
const SCHEMA := "tl.unlocks/1"
const KINDS := ["mats", "shapes", "parts", "stamps"]
const WHEN := ["pack", "plays", "wins", "best"]

var rules: Array = []
var errors: Array = []
var packs := {}                         # the trophies: id -> {plays, wins, best?}
var titles := {}                        # pack id -> a short title (from boot/dungeons.json)
var _locks := {}                        # "kind:id" -> the condition of the first unmet rule that grants it


func _init(dir := "", rules_path := RULES) -> void:
	var r := read_rules(rules_path)
	rules = r.rules
	errors = r.errors
	if dir != "":
		var t: Dictionary = Trophies.read(dir)
		packs = t.packs
		if not bool(t.ok):
			errors.append(str(t.reason))
	titles = _titles()
	_settle()


## {"rules", "errors"} of a tl.unlocks/1 file. Unknown keys and absent values are errors; M1's content may not be granted.
static func read_rules(path: String) -> Dictionary:
	var j := JSON.new()
	if not FileAccess.file_exists(path) or j.parse(FileAccess.get_file_as_string(path)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {"rules": [], "errors": ["%s is not a JSON object" % path]}
	var d: Dictionary = j.data
	var errs := []
	for k: Variant in d:
		if not str(k) in ["schema", "rules"]:
			errs.append("unknown key '%s'" % str(k))
	if str(d.get("schema", "")) != SCHEMA or typeof(d.get("rules")) != TYPE_ARRAY:
		return {"rules": [], "errors": ["not %s with a list of rules" % SCHEMA]}
	var out := []
	for i: int in (d.rules as Array).size():
		var why := _rule_error(d.rules[i])
		if why != "":
			errs.append("rules[%d]: %s" % [i, why])
		else:
			out.append(d.rules[i])
	return {"rules": out, "errors": errs}


static func _rule_error(r: Variant) -> String:
	if typeof(r) != TYPE_DICTIONARY:
		return "not an object"
	for k: Variant in r:
		if not str(k) in ["id", "when", "grant"]:
			return "unknown key '%s'" % str(k)
	if typeof(r.get("id")) != TYPE_STRING or typeof(r.get("when")) != TYPE_DICTIONARY or typeof(r.get("grant")) != TYPE_DICTIONARY:
		return "id, when and grant are required"
	for k: Variant in r.when:
		if not WHEN.has(k):
			return "when: unknown key '%s'" % str(k)
		if k != "pack" and (not (r.when[k] is float or r.when[k] is int) or float(r.when[k]) < 1.0):
			return "when.%s must be a count of at least 1" % str(k)
	if typeof(r.when.get("pack")) != TYPE_STRING or (r.when as Dictionary).size() < 2:
		return "when names a pack and at least one number"
	for k: Variant in r.grant:
		if not KINDS.has(k) or typeof(r.grant[k]) != TYPE_ARRAY or (r.grant[k] as Array).is_empty():
			return "grant: '%s' is not a non-empty list of mats, shapes, parts or stamps" % str(k)
		for v: Variant in r.grant[k]:
			if k == "mats" and (not (v is float or v is int) or int(v) <= 9):
				return "grant.mats: %s (materials 1-9 are M1's and never locked)" % str(v)
			if k == "shapes" and (not (v is float or v is int) or int(v) <= 8):
				return "grant.shapes: %s (shapes 1-8 are M1's and never locked)" % str(v)
			if k == "parts" and not TLKit.PARTS.has(str(v)):
				return "grant.parts: '%s' is not a kit part" % str(v)
	return ""


## The pack ids of boot/dungeons.json with a short title each ("Ice hockey" of "Ice hockey, three against three").
static func _titles() -> Dictionary:
	var out := {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://boot/dungeons.json")) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return out
	for e: Variant in (j.data as Dictionary).get("dungeons", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var m := JSON.new()
		if m.parse(FileAccess.get_file_as_string("res://%s/pack.json" % str(e.get("pack", "")))) != OK or typeof(m.data) != TYPE_DICTIONARY:
			continue
		var t := str(e.get("title", ""))
		for cut: String in [":", ",", " |"]:
			t = t.get_slice(cut, 0)
		out[str((m.data as Dictionary).get("id", ""))] = t.strip_edges()
	return out


## The trophies of `pack` ("*": every pack together).
func of(pack: String) -> Dictionary:
	if pack != "*":
		return packs.get(pack, {"plays": 0, "wins": 0})
	var t := {"plays": 0, "wins": 0}
	for id: String in packs:
		t.plays += int(packs[id].plays)
		t.wins += int(packs[id].wins)
		if packs[id].has("best"):
			t["best"] = maxi(int(t.get("best", 0)), int(packs[id].best))
	return t


func met(rule: Dictionary) -> bool:
	var t := of(str(rule.when.pack))
	for k: String in ["plays", "wins", "best"]:
		if rule.when.has(k) and int(t.get(k, 0)) < int(rule.when[k]):
			return false
	return true


## The condition a person reads: "win Ice hockey once", "play any dungeon 3 times", "score 5 in Paddle court".
func condition(rule: Dictionary) -> String:
	var w: Dictionary = rule.when
	var p := str(w.pack)
	var name: String = "any dungeon" if p == "*" else str(titles.get(p, p))
	var parts := PackedStringArray()
	if w.has("wins"):
		parts.append("win %s %s" % [name, _times(int(w.wins))])
	if w.has("best"):
		parts.append("score %d in %s" % [int(w.best), name])
	if w.has("plays"):
		parts.append("play %s %s" % [name, _times(int(w.plays))])
	return " and ".join(parts)


static func _times(n: int) -> String:
	return "once" if n == 1 else ("twice" if n == 2 else "%d times" % n)


func _settle() -> void:
	_locks.clear()
	var free := {}
	for r: Dictionary in rules:
		var ok := met(r)
		for k: String in r.grant:
			for v: Variant in r.grant[k]:
				var key := "%s:%s" % [k, str(int(v)) if v is float or v is int else str(v)]
				if ok:
					free[key] = true
				elif not _locks.has(key):
					_locks[key] = condition(r)
	for key: String in free:
		_locks.erase(key)


## "" when `id` of `kind` ("mats", "shapes", "parts", "stamps") may be used now, else the condition that unlocks it.
func locked(kind: String, id: Variant) -> String:
	if kind == "mats" and int(id) <= 9 or kind == "shapes" and int(id) <= 8:
		return ""
	return str(_locks.get("%s:%s" % [kind, str(int(id)) if id is float or id is int else str(id)], ""))


## Everything locked now: {"kind:id": condition}.
func locks() -> Dictionary:
	return _locks.duplicate()
