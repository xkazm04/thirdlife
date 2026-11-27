extends RefCounted
## SEAM M6 (rules and runs, 27 Nov 2026): the shapes of the ops `zone`, `unzone`, `rule` and `unrule` and of their
## saved forms (contracts/BUILD.md "Milestone 6"), checked word for word, and the canonical form every one is journaled
## and saved in (keys in the contract's order, numbers as ints). Static, no state: rules_layer.gd asks it, and so may
## the rules tool (lane T) and a case. The rules that read the Home (ids free, zones there, the counter cap, the
## protected areas) are the layer's (`can_apply`). `describe` is the readable line the tool and the LLM's note share.

const OpUtil := preload("res://kernel/world/build/op_util.gd")

const ZONE_KEYS := ["v", "op", "id", "box", "look", "name", "author", "batch"]
const ZONE_ORDER := ["v", "op", "id", "box", "look", "name"]
const ZONE_SAVED := ["id", "box", "look", "name"]
const RULE_KEYS := ["v", "op", "id", "when", "if", "do", "author", "batch"]
const RULE_ORDER := ["v", "op", "id", "when", "if", "do"]
const RULE_SAVED := ["id", "when", "if", "do"]
const LOOKS := ["none", "pad", "coin", "flag"]
const SIDE_MAX := 64                     # cells a side of a zone's box
const XZ_MAX := 100000                   # |x|, |z| of a cell (100 km, as paths)
const Y_MIN := -16                       # the block grid's y (blocks.gd)
const Y_MAX := 111
const NAME_MAX := 24
const TEXT_MAX := 60
const ZONES_MAX := 512
const RULES_MAX := 512
const COUNTERS_MAX := 8
const COUNTER_MAX := 999                 # counters are clamped to 0..999
const DO_MAX := 8
const IF_MAX := 8                        # not in the contract: the seam's cap (REPORT question Q2)
## Each trigger's keys besides "on", in the contract's order.
const TRIGGERS := {"enter": ["zone"], "leave": ["zone"], "use": ["zone"], "every": ["frames"], "count": ["counter", "at"],
	"start": [], "finish": []}
## Each effect's keys besides "do", in the contract's order.
const EFFECTS := {"start": ["run"], "checkpoint": ["zone"], "finish": [], "respawn": [], "add": ["counter", "by"],
	"take": ["zone"], "open": ["zone"], "close": ["zone"], "toggle": ["zone"], "launch": ["up_cm", "fwd_cm"],
	"teleport": ["zone"], "say": ["text", "frames"]}


# ------------------------------------------------------------------ the ops
## "" or why `op` is not a well-formed zone, unzone, rule or unrule op (op_util.gd `head` first, `tail` last).
static func malformed(op: Variant, strict := false) -> String:
	if typeof(op) != TYPE_DICTIONARY:
		return "an operation is a JSON object"
	var kind := str((op as Dictionary).get("op", ""))
	if kind == "zone" or kind == "unzone":
		return zone_malformed(op, strict)
	if kind == "rule" or kind == "unrule":
		return rule_malformed(op, strict)
	return "op must be \"zone\", \"unzone\", \"rule\" or \"unrule\""


static func zone_malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, ZONE_KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	for k: String in ["id", "box", "look"]:
		if not d.has(k):
			return "%s is missing" % k
	if OpUtil.int_of(d.id) == null or int(d.id) < 1:
		return "id must be a positive integer"
	why = box_error(d.box)
	if why != "":
		return why
	if typeof(d.look) != TYPE_STRING or not (str(d.look) in LOOKS):
		return "look must be one of %s" % ", ".join(LOOKS)
	if d.has("name") and not printable(d.name, NAME_MAX):
		return "name must be 1-%d printable characters" % NAME_MAX
	return OpUtil.tail(d, strict)


## "" when `box` is two cells [[x0, y0, z0], [x1, y1, z1]], low corner first, at most 64 cells a side, in the grid.
static func box_error(box: Variant) -> String:
	if typeof(box) != TYPE_ARRAY or (box as Array).size() != 2:
		return "box must be [[x0, y0, z0], [x1, y1, z1]]"
	for c: Variant in box:
		if typeof(c) != TYPE_ARRAY or (c as Array).size() != 3 or (c as Array).any(func(q: Variant) -> bool: return OpUtil.int_of(q) == null):
			return "box: each corner is [x, y, z] of integers"
	var lo := OpUtil.cell(box[0])
	var hi := OpUtil.cell(box[1])
	if lo.x > hi.x or lo.y > hi.y or lo.z > hi.z:
		return "box: x0 <= x1, y0 <= y1 and z0 <= z1"
	var side := hi - lo + Vector3i.ONE
	if side.x > SIDE_MAX or side.y > SIDE_MAX or side.z > SIDE_MAX:
		return "box: at most %d cells a side (%d x %d x %d)" % [SIDE_MAX, side.x, side.y, side.z]
	if lo.y < Y_MIN or hi.y > Y_MAX:
		return "box: out of range (y %d..%d)" % [Y_MIN, Y_MAX]
	if absi(lo.x) > XZ_MAX or absi(hi.x) > XZ_MAX or absi(lo.z) > XZ_MAX or absi(hi.z) > XZ_MAX:
		return "box: outside the Home"
	return ""


static func rule_malformed(op: Variant, strict := false) -> String:
	var why := OpUtil.head(op, RULE_KEYS)
	if why != "":
		return why
	var d: Dictionary = op
	for k: String in ["id", "when", "do"]:
		if not d.has(k):
			return "%s is missing" % k
	if OpUtil.int_of(d.id) == null or int(d.id) < 1:
		return "id must be a positive integer"
	why = trigger_error(d.when)
	if why != "":
		return "when: " + why
	if d.has("if"):
		why = conditions_error(d.get("if"))
		if why != "":
			return why
	why = effects_error(d.do)
	if why != "":
		return why
	return OpUtil.tail(d, strict)


static func trigger_error(w: Variant) -> String:
	if typeof(w) != TYPE_DICTIONARY:
		return "a trigger is an object {\"on\": ...}"
	var d: Dictionary = w
	if typeof(d.get("on")) != TYPE_STRING or not TRIGGERS.has(str(d.get("on"))):
		return "on must be one of %s" % ", ".join(TRIGGERS.keys())
	var keys: Array = TRIGGERS[str(d.on)]
	for k: Variant in d:
		if k != "on" and not keys.has(k):
			return "unknown key '%s'" % str(k)
	for k: String in keys:
		if not d.has(k):
			return "%s is missing" % k
	match str(d.on):
		"enter", "leave", "use":
			return _zone_ref(d.zone)
		"every":
			return "" if _int_in(d.frames, 60, 36000) else "frames must be an integer 60..36000"
		"count":
			if not counter_ok(d.counter):
				return "counter must be 1-16 of a-z and _"
			return "" if _int_in(d.at, 1, COUNTER_MAX) else "at must be an integer 1..%d" % COUNTER_MAX
	return ""


static func conditions_error(list: Variant) -> String:
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		return "if must be a non-empty list (omit it when empty)"
	if (list as Array).size() > IF_MAX:
		return "if: at most %d conditions" % IF_MAX
	for c: Variant in list:
		if typeof(c) != TYPE_DICTIONARY:
			return "if: every condition is an object"
		var d: Dictionary = c
		if d.has("running"):
			if d.size() != 1:
				return "if: {\"running\": true|false} stands alone"
			if typeof(d.running) != TYPE_BOOL:
				return "if: running must be true or false"
			continue
		for k: Variant in d:
			if not (k in ["counter", "min", "max"]):
				return "if: unknown key '%s'" % str(k)
		if not d.has("counter"):
			return "if: a condition is {\"running\": ...} or {\"counter\": ..., \"min\" and/or \"max\"}"
		if not counter_ok(d.counter):
			return "if: counter must be 1-16 of a-z and _"
		if not d.has("min") and not d.has("max"):
			return "if: counter %s needs min or max" % str(d.counter)
		for k: String in ["min", "max"]:
			if d.has(k) and not _int_in(d[k], 0, COUNTER_MAX):
				return "if: %s must be an integer 0..%d" % [k, COUNTER_MAX]
		if d.has("min") and d.has("max") and int(d.min) > int(d.max):
			return "if: min is above max (it never holds)"
	return ""


static func effects_error(list: Variant) -> String:
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty() or (list as Array).size() > DO_MAX:
		return "do must be 1-%d effects" % DO_MAX
	for i: int in (list as Array).size():
		var e: Variant = list[i]
		if typeof(e) != TYPE_DICTIONARY:
			return "do: every effect is an object {\"do\": ...}"
		var d: Dictionary = e
		var kind := str(d.get("do", ""))
		if typeof(d.get("do")) != TYPE_STRING or not EFFECTS.has(kind):
			return "do: '%s' is not an effect (%s)" % [kind, ", ".join(EFFECTS.keys())]
		var why := _effect_error(d, EFFECTS[kind])
		if why != "":
			return "do[%d] %s: %s" % [i, kind, why]
	return ""


static func _effect_error(d: Dictionary, keys: Array) -> String:
	for k: Variant in d:
		if k != "do" and not keys.has(k):
			return "unknown key '%s'" % str(k)
	for k: String in keys:
		if not d.has(k):
			return "%s is missing" % k
	match str(d.do):
		"start":
			return "" if printable(d.run, NAME_MAX) else "run must be 1-%d printable characters" % NAME_MAX
		"checkpoint", "take", "open", "close", "toggle", "teleport":
			return _zone_ref(d.zone)
		"add":
			if not counter_ok(d.counter):
				return "counter must be 1-16 of a-z and _"
			return "" if _int_in(d.by, -99, 99) and int(d.by) != 0 else "by must be an integer -99..99, not 0"
		"launch":
			for k: String in ["up_cm", "fwd_cm"]:
				if not _int_in(d[k], 0, 3000):
					return "%s must be an integer 0..3000" % k
		"say":
			if not printable(d.text, TEXT_MAX):
				return "text must be 1-%d printable characters" % TEXT_MAX
			return "" if _int_in(d.frames, 30, 600) else "frames must be an integer 30..600"
	return ""


static func _zone_ref(z: Variant) -> String:
	return "" if OpUtil.int_of(z) != null and int(z) >= 1 else "zone must be a positive integer (a zone's id)"


static func _int_in(x: Variant, lo: int, hi: int) -> bool:
	return OpUtil.int_of(x) != null and int(x) >= lo and int(x) <= hi


## A counter's name: 1-16 of a-z and _.
static func counter_ok(c: Variant) -> bool:
	if typeof(c) != TYPE_STRING or (c as String).length() < 1 or (c as String).length() > 16:
		return false
	for ch: String in (c as String):
		if not (ch == "_" or (ch >= "a" and ch <= "z")):
			return false
	return true


## 1-`most` characters, none of them a control character (C0, DEL, C1).
static func printable(s: Variant, most: int) -> bool:
	if typeof(s) != TYPE_STRING or (s as String).length() < 1 or (s as String).length() > most:
		return false
	for i: int in (s as String).length():
		var u := (s as String).unicode_at(i)
		if u < 32 or (u >= 127 and u < 160):
			return false
	return true


# ------------------------------------------------------------------ canonical forms
## A zone's saved form from an op or a file entry: {"id", "box", "look", "name"?}, numbers as ints.
static func zone_of(d: Dictionary) -> Dictionary:
	var out := {"id": int(d.id), "box": [_cell(d.box[0]), _cell(d.box[1])], "look": str(d.look)}
	if d.has("name"):
		out["name"] = str(d.name)
	return out


## A rule's saved form: {"id", "when", "if"?, "do"}, each part's keys in the contract's order, numbers as ints.
static func rule_of(d: Dictionary) -> Dictionary:
	var w: Dictionary = d.when
	var when := {"on": str(w.on)}
	for k: String in TRIGGERS[str(w.on)]:
		when[k] = str(w[k]) if k == "counter" else int(w[k])
	var out := {"id": int(d.id), "when": when}
	if d.has("if"):
		var conds := []
		for c: Dictionary in d.get("if"):
			if c.has("running"):
				conds.append({"running": bool(c.running)})
			else:
				var o := {"counter": str(c.counter)}
				for k: String in ["min", "max"]:
					if c.has(k):
						o[k] = int(c[k])
				conds.append(o)
		out["if"] = conds
	var effects := []
	for e: Dictionary in d.do:
		var o := {"do": str(e.do)}
		for k: String in EFFECTS[str(e.do)]:
			o[k] = str(e[k]) if k in ["run", "counter", "text"] else int(e[k])
		effects.append(o)
	out["do"] = effects
	return out


static func _cell(c: Array) -> Array:
	return [int(c[0]), int(c[1]), int(c[2])]


## The zone ids rule `r` (a saved form) names: its trigger's and its effects', each once, in order.
static func zones_named(r: Dictionary) -> Array:
	var out := []
	if (r.when as Dictionary).has("zone"):
		out.append(int(r.when.zone))
	for e: Dictionary in r.do:
		if e.has("zone") and not out.has(int(e.zone)):
			out.append(int(e.zone))
	return out


## The counters rule `r` uses (trigger, conditions, effects), each once.
static func counters_of(r: Dictionary) -> Array:
	var out := []
	if (r.when as Dictionary).has("counter"):
		out.append(str(r.when.counter))
	for c: Dictionary in r.get("if", []):
		if c.has("counter") and not out.has(str(c.counter)):
			out.append(str(c.counter))
	for e: Dictionary in r.do:
		if e.has("counter") and not out.has(str(e.counter)):
			out.append(str(e.counter))
	return out


## A zone's floor centre in world metres: the middle of its box in x and z, the bottom of its lowest cell in y.
static func floor_centre(box: Array) -> Vector3:
	return Vector3((float(box[0][0]) + float(box[1][0]) + 1.0) * 0.5, float(box[0][1]), (float(box[0][2]) + float(box[1][2]) + 1.0) * 0.5)


static func box_has(box: Array, c: Vector3i) -> bool:
	return c.x >= int(box[0][0]) and c.x <= int(box[1][0]) and c.y >= int(box[0][1]) and c.y <= int(box[1][1]) \
		and c.z >= int(box[0][2]) and c.z <= int(box[1][2])


# ------------------------------------------------------------------ the readable line
## Rule `r` (a saved form) as one line, e.g. "when you enter Door: open Door". `names`: zone id -> its name (a zone
## without one reads "zone <id>").
static func describe(r: Dictionary, names: Dictionary = {}) -> String:
	var z := func(id: Variant) -> String: return str(names.get(int(id), "zone %d" % int(id)))
	var w: Dictionary = r.when
	var head := ""
	match str(w.on):
		"enter": head = "when you enter %s" % z.call(w.zone)
		"leave": head = "when you leave %s" % z.call(w.zone)
		"use": head = "when you press E in %s" % z.call(w.zone)
		"every": head = "every %s" % _span(int(w.frames))
		"count": head = "when %s reaches %d" % [str(w.counter), int(w.at)]
		"start": head = "when a run starts"
		"finish": head = "when a run is finished"
	var conds := []
	for c: Dictionary in r.get("if", []):
		if c.has("running"):
			conds.append("a run is going" if bool(c.running) else "no run is going")
		elif c.has("min") and c.has("max"):
			conds.append("%s is %d" % [str(c.counter), int(c.min)] if int(c.min) == int(c.max) else "%s is %d-%d" % [str(c.counter), int(c.min), int(c.max)])
		elif c.has("min"):
			conds.append("%s is at least %d" % [str(c.counter), int(c.min)])
		else:
			conds.append("%s is at most %d" % [str(c.counter), int(c.max)])
	if not conds.is_empty():
		head += " if " + " and ".join(conds)
	var parts := []
	for e: Dictionary in r.do:
		match str(e.do):
			"start": parts.append("start the run %s" % str(e.run))
			"checkpoint": parts.append("checkpoint at %s" % z.call(e.zone))
			"finish": parts.append("finish the run")
			"respawn": parts.append("back to the respawn")
			"add": parts.append("add %d to %s" % [int(e.by), str(e.counter)] if int(e.by) > 0 else "take %d from %s" % [-int(e.by), str(e.counter)])
			"take": parts.append("take %s" % z.call(e.zone))
			"open": parts.append("open %s" % z.call(e.zone))
			"close": parts.append("close %s" % z.call(e.zone))
			"toggle": parts.append("open or close %s" % z.call(e.zone))
			"launch": parts.append("launch %s m/s up, %s m/s forward" % [_mps(int(e.up_cm)), _mps(int(e.fwd_cm))])
			"teleport": parts.append("go to %s" % z.call(e.zone))
			"say": parts.append("say \"%s\"" % str(e.text))
	return "%s: %s" % [head, ", ".join(parts)]


static func _span(frames: int) -> String:
	return "%d s" % (frames / 60) if frames % 60 == 0 else "%d frames" % frames


static func _mps(cm: int) -> String:
	return str(cm / 100) if cm % 100 == 0 else "%.2f" % (cm / 100.0)
