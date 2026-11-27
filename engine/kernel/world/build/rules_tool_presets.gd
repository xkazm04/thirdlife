extends RefCounted
## M6 lane T (27 Nov 2026): the Rules tool's presets, its knobs and its delete, as ops (contracts/BUILD.md
## "Milestone 6"). Static, no state: it reads the rules layer (rules_layer.gd `zones`, `rules`, `named_by`,
## `next_zone_id`, `next_rule_id`) and answers the ops of ONE batch; the tool previews and applies them. The presets
## (each a zone and its rules, a look that says what it is, a name that reads in `describe`):
##   start       pad   when you enter Start: start the run <run>
##   checkpoint  pad   when you enter Checkpoint N if a run is going: checkpoint at Checkpoint N, say "Checkpoint"
##   finish      flag  when you enter Finish if a run is going: finish the run
##   coin        coin  when you enter Coin N: take Coin N, add 1 to coins                       knob: value (by)
##   door        none  the box is grown one cell through the wall (front and back), so he stands in it:
##                     seconds 0 (the default): when you press E in Door N: open; when you leave Door N: close
##                     seconds S: when you press E in Door N if door_<id> is at most 0: open, add S to door_<id>;
##                     every 1 s if door_<id> is 1-1: close, take 1; every 1 s if door_<id> >= 2: open (it is: the
##                     rule names the door, so Delete finds it), take 1                                   knob: seconds
##   pad         pad   when you enter Jump pad N: launch 10 m/s up, 4 m/s forward           knobs: up, forward
##   hazard      none  when you enter Hazard N: back to the respawn
##   message     none  when you enter Message N: say "<text>" (3 s)                            knobs: text, seconds
## A knob's change is ONE batch: the rule's `unrule` and its new `rule` with the same id (the door's seconds may
## change how many rules it has). Delete: the zone's rules (`unrule` each) and the zone (`unzone`), one batch.

const Check := preload("res://kernel/world/build/rules_check.gd")

const KINDS := ["start", "checkpoint", "finish", "coin", "door", "pad", "hazard", "message"]
const TITLES := {"start": "Start", "checkpoint": "Checkpoint", "finish": "Finish", "coin": "Coin", "door": "Door",
	"pad": "Jump pad", "hazard": "Hazard", "message": "Message", "custom": "Zone"}
const LOOKS := {"start": "pad", "checkpoint": "pad", "finish": "flag", "coin": "coin", "door": "none", "pad": "pad",
	"hazard": "none", "message": "none"}
## Cells a zone stands at least (a box drawn lower is raised to it): the feet stay in it over a small hop.
const HIGH := {"start": 2, "checkpoint": 2, "finish": 2, "coin": 2, "door": 1, "pad": 1, "hazard": 1, "message": 2}
const COINS := "coins"
const UP_CM := 1000
const FWD_CM := 400
const SAY_FRAMES := 180
const TEXT := "Hello!"
const RUN := "Run 1"


## The ops of preset `kind` on the cell box lo..hi (as drawn; raised to HIGH unless "exact", a door grown through its
## wall), as one batch: the zone, then its rules, with the layer's next free ids. `opt`: "run" (start), "text"
## (message), "seconds" (door), "thin" (door: 0 x, 2 z, the axis to grow; -1 the thinner of x and z), "exact" (true:
## the wheel set the top, keep the height drawn).
static func ops(layer: RefCounted, kind: String, lo: Vector3i, hi: Vector3i, opt := {}) -> Array:
	var b := box_for(kind, lo, hi, int(opt.get("thin", -1)), bool(opt.get("exact", false)))
	var z: int = layer.next_zone_id()
	var r: int = layer.next_rule_id()
	var zone := {"op": "zone", "id": z, "box": [[b[0].x, b[0].y, b[0].z], [b[1].x, b[1].y, b[1].z]], "look": LOOKS[kind],
		"name": next_name(layer, kind)}
	var out := [zone]
	var rule_ids := []
	for i in 3:
		rule_ids.append(r + i)
	out.append_array(rules_of(kind, z, rule_ids, opt))
	return out


## The box a preset takes for a drawn box: at least HIGH cells; a door grown one cell each way along its thin axis.
static func box_for(kind: String, lo: Vector3i, hi: Vector3i, thin := -1, exact := false) -> Array:
	var a := lo
	var b := hi
	if not exact:
		b.y = maxi(b.y, a.y + int(HIGH.get(kind, 1)) - 1)
	if kind == "door":
		var ax := thin
		if ax != 0 and ax != 2:
			ax = 0 if (b.x - a.x) <= (b.z - a.z) else 2
		a[ax] -= 1
		b[ax] += 1
	for k in 3:
		if b[k] - a[k] + 1 > Check.SIDE_MAX:
			b[k] = a[k] + Check.SIDE_MAX - 1
	return [a, b]


## The rules of preset `kind` on zone `z`, with ids taken from `ids` in order.
static func rules_of(kind: String, z: int, ids: Array, opt := {}) -> Array:
	var running := [{"running": true}]
	match kind:
		"start":
			return [_rule(ids[0], {"on": "enter", "zone": z}, [], [{"do": "start", "run": str(opt.get("run", RUN))}])]
		"checkpoint":
			return [_rule(ids[0], {"on": "enter", "zone": z}, running, [{"do": "checkpoint", "zone": z},
				{"do": "say", "text": "Checkpoint", "frames": 90}])]
		"finish":
			return [_rule(ids[0], {"on": "enter", "zone": z}, running, [{"do": "finish"}])]
		"coin":
			return [_rule(ids[0], {"on": "enter", "zone": z}, [], [{"do": "take", "zone": z},
				{"do": "add", "counter": COINS, "by": int(opt.get("value", 1))}])]
		"door":
			var s := int(opt.get("seconds", 0))
			if s <= 0:
				return [_rule(ids[0], {"on": "use", "zone": z}, [], [{"do": "open", "zone": z}]),
					_rule(ids[1], {"on": "leave", "zone": z}, [], [{"do": "close", "zone": z}])]
			var c := door_counter(z)
			return [_rule(ids[0], {"on": "use", "zone": z}, [{"counter": c, "max": 0}], [{"do": "open", "zone": z}, {"do": "add", "counter": c, "by": s}]),
				_rule(ids[1], {"on": "every", "frames": 60}, [{"counter": c, "min": 1, "max": 1}], [{"do": "close", "zone": z}, {"do": "add", "counter": c, "by": -1}]),
				_rule(ids[2], {"on": "every", "frames": 60}, [{"counter": c, "min": 2}], [{"do": "open", "zone": z}, {"do": "add", "counter": c, "by": -1}])]
		"pad":
			return [_rule(ids[0], {"on": "enter", "zone": z}, [], [{"do": "launch", "up_cm": int(opt.get("up_cm", UP_CM)),
				"fwd_cm": int(opt.get("fwd_cm", FWD_CM))}])]
		"hazard":
			return [_rule(ids[0], {"on": "enter", "zone": z}, [], [{"do": "respawn"}])]
		"message":
			return [_rule(ids[0], {"on": "enter", "zone": z}, [], [{"do": "say", "text": str(opt.get("text", TEXT)),
				"frames": int(opt.get("frames", SAY_FRAMES))}])]
	return []


static func _rule(n: int, when: Dictionary, conds: Array, effects: Array) -> Dictionary:
	var out := {"op": "rule", "id": int(n), "when": when}
	if not conds.is_empty():
		out["if"] = conds
	out["do"] = effects
	return out


## A timed door's counter: "door_" and the zone's id in letters (counters are a-z and _): 1 a, 26 z, 27 aa.
static func door_counter(z: int) -> String:
	var s := ""
	var n := z
	while n > 0:
		n -= 1
		s = char(97 + n % 26) + s
		n /= 26
	return "door_" + s


## "Coin 3": the preset's title and the next number free among the Home's zone names ("Start", "Finish" alone first).
static func next_name(layer: RefCounted, kind: String) -> String:
	var t: String = TITLES[kind]
	var taken := {}
	for zid: int in layer.get("zones"):
		taken[str((layer.get("zones")[zid] as Dictionary).get("name", ""))] = true
	if kind in ["start", "finish"] and not taken.has(t):
		return t
	var n := 1
	while taken.has("%s %d" % [t, n]):
		n += 1
	return ("%s %d" % [t, n]).left(Check.NAME_MAX)


# ------------------------------------------------------------------ reading a zone back
## The rules that name zone `zid`, ascending ids (saved forms).
static func rules_naming(layer: RefCounted, zid: int) -> Array:
	var out := []
	var by: Dictionary = (layer.get("named_by") as Dictionary).get(zid, {})
	var ids: Array = by.keys()
	ids.sort()
	for rid: int in ids:
		out.append(layer.get("rules")[rid])
	return out


## What zone `zid` is, read from its rules: one of KINDS, or "custom" (an LLM's or a changed one).
static func kind_of(layer: RefCounted, zid: int) -> String:
	var rs := rules_naming(layer, zid)
	if rs.is_empty() or not (layer.get("zones") as Dictionary).has(zid):
		return "custom"
	var effects := []
	for r: Dictionary in rs:
		for e: Dictionary in r.do:
			effects.append(str(e.do))
	var first: Dictionary = rs[0]
	if effects.has("start"):
		return "start"
	if effects.has("checkpoint"):
		return "checkpoint"
	if effects.has("finish"):
		return "finish"
	if effects.has("take"):
		return "coin"
	if str(first.when.on) == "use" and effects.has("open"):
		return "door"
	if effects.has("launch"):
		return "pad"
	if effects.has("respawn"):
		return "hazard"
	if effects.has("say"):
		return "message"
	return "custom"


## The run name the Home's first start rule names, or "" (no start yet: the tool asks for one).
static func run_name(layer: RefCounted) -> String:
	var rules: Dictionary = layer.get("rules")
	var ids: Array = rules.keys()
	ids.sort()
	for rid: int in ids:
		for e: Dictionary in rules[rid].do:
			if str(e.do) == "start":
				return str(e.run)
	return ""


## The knobs of zone `zid`: [{"name", "label", "value", "step", "min", "max", "text"?: true}], in key order:
## the first is [ and ], the second Shift+[ and ], a text knob is G.
static func knobs(layer: RefCounted, zid: int) -> Array:
	var out := []
	var rs := rules_naming(layer, zid)
	var opt := options(layer, zid)
	if opt.is_empty():
		return out
	match kind_of(layer, zid):
		"start":
			out.append({"name": "run", "label": "run name", "value": _effect(rs, "start").get("run", RUN), "text": true})
		"coin":
			out.append({"name": "value", "label": "value", "value": int(_effect(rs, "add").get("by", 1)), "step": 1, "min": 1, "max": 99})
		"door":
			out.append({"name": "seconds", "label": "closes after (s; 0: when you walk out)", "value": door_seconds(rs), "step": 1, "min": 0, "max": 30})
		"pad":
			var e := _effect(rs, "launch")
			out.append({"name": "up_cm", "label": "up (m/s)", "value": int(e.get("up_cm", UP_CM)), "step": 100, "min": 0, "max": 3000})
			out.append({"name": "fwd_cm", "label": "forward (m/s)", "value": int(e.get("fwd_cm", FWD_CM)), "step": 100, "min": 0, "max": 3000})
		"message":
			var e := _effect(rs, "say")
			out.append({"name": "frames", "label": "shown (s)", "value": int(e.get("frames", SAY_FRAMES)), "step": 60, "min": 60, "max": 600})
			out.append({"name": "text", "label": "text", "value": str(e.get("text", TEXT)), "text": true})
	return out


static func _effect(rs: Array, kind: String) -> Dictionary:
	for r: Dictionary in rs:
		for e: Dictionary in r.do:
			if str(e.do) == kind:
				return e
	return {}


static func door_seconds(rs: Array) -> int:
	for r: Dictionary in rs:
		if str(r.when.on) == "use":
			for e: Dictionary in r.do:
				if str(e.do) == "add":
					return int(e.by)
	return 0


## The preset options zone `zid`'s rules hold now (its kind's), or {} when the zone is not exactly a preset's (an
## LLM's rule, a rule changed by hand: then it has no knobs, only Delete).
static func options(layer: RefCounted, zid: int) -> Dictionary:
	var kind := kind_of(layer, zid)
	var rs := rules_naming(layer, zid)
	var opt := {}
	match kind:
		"start": opt = {"run": str(_effect(rs, "start").get("run", RUN))}
		"coin": opt = {"value": int(_effect(rs, "add").get("by", 1))}
		"door": opt = {"seconds": door_seconds(rs)}
		"pad":
			var e := _effect(rs, "launch")
			opt = {"up_cm": int(e.get("up_cm", UP_CM)), "fwd_cm": int(e.get("fwd_cm", FWD_CM))}
		"message":
			var e := _effect(rs, "say")
			opt = {"text": str(e.get("text", TEXT)), "frames": int(e.get("frames", SAY_FRAMES))}
		"checkpoint", "finish", "hazard":
			pass
		_:
			return {}
	var ids := []
	for r: Dictionary in rs:
		ids.append(int(r.id))
	while ids.size() < 3:
		ids.append(0)
	var again := rules_of(kind, zid, ids, opt)
	if again.size() != rs.size():
		return {}
	for i: int in rs.size():
		if str(Check.rule_of(again[i])) != str(rs[i]):
			return {}
	return opt


## The ops (one batch) that set knob `name` of zone `zid` to `value`: every rule of the zone removed and made again
## with its old ids (a door going from 0 to S seconds takes a new id). [] when the zone has no such knob.
static func knob_ops(layer: RefCounted, zid: int, name: String, value: Variant) -> Array:
	var opt := options(layer, zid)
	if not opt.has(name):
		return []
	opt[name] = value
	var rs := rules_naming(layer, zid)
	var ids := []
	for r: Dictionary in rs:
		ids.append(int(r.id))
	var next: int = layer.next_rule_id()
	while ids.size() < 3:
		ids.append(next)
		next += 1
	var out := []
	for r: Dictionary in rs:
		out.append(_un(r))
	out.append_array(rules_of(kind_of(layer, zid), zid, ids, opt))
	return out


static func _un(r: Dictionary) -> Dictionary:
	var u := r.duplicate(true)
	u["op"] = "unrule"
	return u


## The ops (one batch) that remove zone `zid`: every rule that names it, then the zone.
static func delete_ops(layer: RefCounted, zid: int) -> Array:
	var zones: Dictionary = layer.get("zones")
	if not zones.has(zid):
		return []
	var out := []
	for r: Dictionary in rules_naming(layer, zid):
		out.append(_un(r))
	var u: Dictionary = (zones[zid] as Dictionary).duplicate(true)
	u["op"] = "unzone"
	out.append(u)
	return out
