extends RefCounted
## SEAM M6 (rules and runs, 27 Nov 2026): the `rules` layer of the edit log: the ops `zone`, `unzone`, `rule` and
## `unrule` (contracts/BUILD.md "Milestone 6"), saved as tl.build/4 `zones` and `rules`. Interface: BUILD.md "Layers".
## The shapes are rules_check.gd's; this file holds the Home's rules over them:
##   zone     its id free (`next_zone_id`), at most 512 zones, its box not in a protected area of blocks (protect.gd
##            `refusal_box`: the blocks' reasons, the visitor never: a zone may hold him)
##   unzone   the zone is there as named (it carries the whole zone), and no rule names it (remove the rule first)
##   rule     its id free (`next_rule_id`), at most 512 rules, every zone it names there, at most 8 counters in the Home
##   unrule   the rule is there as named (it carries the whole rule)
## The layer draws nothing: zones in build mode and the ghost are lane T's (`preview_node`), the zones' looks in play
## lane P's (rules_play.gd); the runtime is rules_run.gd, which reads `zones` and `rules` and never writes them.
## `renumber` gives an LLM answer's new zones and rules the next free ids and rewrites its references (home_build.gd
## `expand_input` calls it on the whole answer); `read_region` and `room` are the ask's `zones`, `rules` and
## `rules_room` (lane C writes them into the ask).

const Check := preload("res://kernel/world/build/rules_check.gd")
const OpUtil := preload("res://kernel/world/build/op_util.gd")
const OPS := ["zone", "unzone", "rule", "unrule"]

var id := "rules"
var ctx: Dictionary
var scratch := false                     # a preview's copy
var zones := {}                          # id -> saved form {"id", "box", "look", "name"?}
var rules := {}                          # id -> saved form {"id", "when", "if"?, "do"}
var named_by := {}                       # zone id -> {rule id: true}: the rules that name it
var revision := 0                        # +1 per applied record (rules_run.gd and drawers see a change by it)


## `ctx`: home_build.gd's context (BUILD.md "Layers": blocks, protect, space, root, seed, home).
func _init(c: Dictionary) -> void:
	ctx = c


func ops() -> PackedStringArray:
	return PackedStringArray(OPS)


## The op kinds the LLM may write for this layer (command_ask.gd `ops_now`).
func offers() -> Array:
	return OPS.duplicate()


# ------------------------------------------------------------------ ops
func malformed(op: Variant, strict := false) -> String:
	return Check.malformed(op, strict)


func can_apply(op: Dictionary) -> String:
	match str(op.op):
		"zone":
			var z := Check.zone_of(op)
			if zones.has(z.id):
				return "id %d is taken (the next free id is %d)" % [z.id, next_zone_id()]
			if zones.size() >= Check.ZONES_MAX:
				return "the Home holds %d zones" % Check.ZONES_MAX
			return _protected(z.box)
		"unzone":
			var z := Check.zone_of(op)
			var why := _zone_match(z)
			if why != "":
				return why
			var by: Array = (named_by.get(z.id, {}) as Dictionary).keys()
			if not by.is_empty():
				by.sort()
				return "zone %d is named by rule %d (remove the rule first, in the same batch)" % [z.id, int(by[0])]
			return ""
		"rule":
			var r := Check.rule_of(op)
			if rules.has(r.id):
				return "id %d is taken (the next free id is %d)" % [r.id, next_rule_id()]
			if rules.size() >= Check.RULES_MAX:
				return "the Home holds %d rules" % Check.RULES_MAX
			return _refs(r)
		_:
			return _rule_match(Check.rule_of(op))


## Why the zones and counters rule `r` names do not fit the Home ("" = they do).
func _refs(r: Dictionary) -> String:
	for z: int in Check.zones_named(r):
		if not zones.has(z):
			return "rule %d names zone %d, which is not there" % [r.id, z]
	var have := counters()
	var more := Check.counters_of(r).filter(func(c: String) -> bool: return not have.has(c))
	if have.size() + more.size() > Check.COUNTERS_MAX:
		return "the Home has %d counters (%s): '%s' would pass %d" % [have.size(), ", ".join(have), more[0], Check.COUNTERS_MAX]
	return ""


func _zone_match(z: Dictionary) -> String:
	if not zones.has(z.id):
		return "no zone %d" % z.id
	return "" if str(zones[z.id]) == str(z) else "zone %d is another zone (unzone carries the whole zone)" % z.id


func _rule_match(r: Dictionary) -> String:
	if not rules.has(r.id):
		return "no rule %d" % r.id
	return "" if str(rules[r.id]) == str(r) else "rule %d is another rule (unrule carries the whole rule)" % r.id


func _protected(box: Array) -> String:
	var pr: RefCounted = ctx.get("protect")
	return "" if pr == null or not pr.has_method("refusal_box") else str(pr.refusal_box(OpUtil.cell(box[0]), OpUtil.cell(box[1])))


## The op as journaled: keys in the contract's order, numbers as ints.
func raw(op: Dictionary) -> Dictionary:
	var out := {"v": 1, "op": str(op.op)}
	var s := saved_of(op)
	for k: Variant in s:
		out[k] = s[k]
	return out


func saved_of(op: Dictionary) -> Dictionary:
	return Check.zone_of(op) if str(op.op) in ["zone", "unzone"] else Check.rule_of(op)


## A complete record fits when the store is as it was when it was made (undo, redo, a replayed journal).
func fits(rec: Dictionary) -> String:
	var s := saved_of(rec)
	match str(rec.op):
		"zone":
			return "zone id %d is taken" % s.id if zones.has(s.id) else ""
		"unzone":
			var why := _zone_match(s)
			return why if why != "" or not named_by.has(s.id) else "zone %d is named by a rule" % s.id
		"rule":
			return "rule id %d is taken" % s.id if rules.has(s.id) else _refs(s)
		_:
			return _rule_match(s)


func apply(rec: Dictionary) -> void:
	var s := saved_of(rec)
	match str(rec.op):
		"zone":
			zones[s.id] = s
		"unzone":
			zones.erase(s.id)
		"rule":
			rules[s.id] = s
			for z: int in Check.zones_named(s):
				if not named_by.has(z):
					named_by[z] = {}
				(named_by[z] as Dictionary)[s.id] = true
		_:
			_drop_rule(int(s.id))
	revision += 1


func _drop_rule(n: int) -> void:
	if not rules.has(n):
		return
	for z: int in Check.zones_named(rules[n]):
		if named_by.has(z):
			(named_by[z] as Dictionary).erase(n)
			if (named_by[z] as Dictionary).is_empty():
				named_by.erase(z)
	rules.erase(n)


func invert(rec: Dictionary) -> Dictionary:
	var out := OpUtil.ordered(rec, Check.ZONE_ORDER if str(rec.op) in ["zone", "unzone"] else Check.RULE_ORDER)
	out["op"] = {"zone": "unzone", "unzone": "zone", "rule": "unrule", "unrule": "rule"}[str(rec.op)]
	return out


## A zone's world box (so a drawer redraws it); a rule changes no space.
func dirty_regions(rec: Dictionary) -> Array:
	if not (str(rec.op) in ["zone", "unzone"]):
		return []
	var b: Array = Check.zone_of(rec).box
	return [AABB(Vector3(b[0][0], b[0][1], b[0][2]), Vector3(int(b[1][0]) - int(b[0][0]) + 1, int(b[1][1]) - int(b[0][1]) + 1, int(b[1][2]) - int(b[0][2]) + 1))]


func next_zone_id() -> int:
	var n := 0
	for k: int in zones:
		n = maxi(n, k)
	return n + 1


func next_rule_id() -> int:
	var n := 0
	for k: int in rules:
		n = maxi(n, k)
	return n + 1


## The counters the Home's rules use, sorted.
func counters() -> Array:
	var out := []
	for n: int in rules:
		for c: String in Check.counters_of(rules[n]):
			if not out.has(c):
				out.append(c)
	out.sort()
	return out


## The zones whose box holds cell `c`, by id ascending.
func zones_at(c: Vector3i) -> Array:
	var out := []
	for n: int in sorted_ids(zones):
		if Check.box_has(zones[n].box, c):
			out.append(n)
	return out


## Rule `n` as one readable line ("when you enter Door: open Door"); "" when there is no rule `n`.
func describe(n: int) -> String:
	return Check.describe(rules[n], names()) if rules.has(n) else ""


## zone id -> its name, for the zones that have one.
func names() -> Dictionary:
	var out := {}
	for n: int in zones:
		if (zones[n] as Dictionary).has("name"):
			out[n] = zones[n].name
	return out


static func sorted_ids(d: Dictionary) -> Array:
	var ids: Array = d.keys()
	ids.sort()
	return ids


# ------------------------------------------------------------------ files (tl.build/4 `zones`, `rules`)
func save_part() -> Dictionary:
	var out := {}
	if not zones.is_empty():
		out["zones"] = sorted_ids(zones).map(func(k: int) -> Dictionary: return (zones[k] as Dictionary).duplicate(true))
	if not rules.is_empty():
		out["rules"] = sorted_ids(rules).map(func(k: int) -> Dictionary: return (rules[k] as Dictionary).duplicate(true))
	return out


## Reads `zones`, then `rules` (absent: none): every entry exactly its saved keys, well-formed, ids unique and sorted
## as written, the caps held, every zone a rule names there.
func load_part(doc: Dictionary) -> String:
	for key: String in ["zones", "rules"]:
		if not doc.has(key):
			continue
		var list: Variant = doc[key]
		if typeof(list) != TYPE_ARRAY:
			return "%s must be a list" % key
		var cap := Check.ZONES_MAX if key == "zones" else Check.RULES_MAX
		if (list as Array).size() > cap:
			return "%s: at most %d" % [key, cap]
		var keys: Array = Check.ZONE_SAVED if key == "zones" else Check.RULE_SAVED
		var last := 0
		for e: Variant in list:
			if typeof(e) != TYPE_DICTIONARY:
				return "%s: every entry is an object" % key
			for k: Variant in e:
				if not keys.has(k):
					return "%s: unknown key '%s'" % [key, str(k)]
			var op := (e as Dictionary).duplicate(true)
			op["op"] = "zone" if key == "zones" else "rule"
			var why := Check.malformed(op)
			if why != "":
				return "%s: %s" % [key, why]
			var s := saved_of(op)
			if int(s.id) <= last:
				return "%s: ids are unique and sorted (%d after %d)" % [key, int(s.id), last]
			last = int(s.id)
			if key == "rules":
				why = _refs(s)
				if why != "":
					return "rules: %s" % why
			apply(op)
	return ""


func clear() -> void:
	zones.clear()
	rules.clear()
	named_by.clear()
	revision += 1


func size() -> int:
	return zones.size() + rules.size()


func content_hash() -> String:
	return "" if size() == 0 else JSON.stringify(save_part(), "", false).sha256_text()


# ------------------------------------------------------------------ drawing, copies
func step(_budget: int) -> int:
	return 0


func pending() -> int:
	return 0


func copy() -> RefCounted:
	var c: RefCounted = (get_script() as GDScript).new(ctx)
	c.scratch = true
	for n: int in zones:
		c.apply({"op": "zone"}.merged(zones[n], true))
	for n: int in rules:
		c.apply({"op": "rule"}.merged(rules[n], true))
	return c


## The ghost of this layer's part of a dry run: lane T draws it (tools/rules_tool.gd's zone look in holo). The seam
## shows nothing.
func preview_node(_sc: Variant) -> Node3D:
	return null


func free_all() -> void:
	pass


# ------------------------------------------------------------------ the ask (lane C writes these into it)
## The ask's `zones` (the zones whose box meets the cell box `lo`..`hi`) and `rules` (the rules that name one of them,
## and every rule that names no zone), in the file's shapes, each omitted when there are none.
func read_region(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := {}
	var met := {}
	var zs := []
	for n: int in sorted_ids(zones):
		var b: Array = zones[n].box
		if int(b[0][0]) <= hi.x and int(b[1][0]) >= lo.x and int(b[0][1]) <= hi.y and int(b[1][1]) >= lo.y \
				and int(b[0][2]) <= hi.z and int(b[1][2]) >= lo.z:
			met[n] = true
			zs.append((zones[n] as Dictionary).duplicate(true))
	var rs := []
	for n: int in sorted_ids(rules):
		var named := Check.zones_named(rules[n])
		if named.is_empty() or named.any(func(z: int) -> bool: return met.has(z)):
			rs.append((rules[n] as Dictionary).duplicate(true))
	if not zs.is_empty():
		out["zones"] = zs
	if not rs.is_empty():
		out["rules"] = rs
	return out


## The ask's `rules_room`: {"zones_left", "rules_left", "counters": the counters already used, sorted}.
func room() -> Dictionary:
	return {"zones_left": Check.ZONES_MAX - zones.size(), "rules_left": Check.RULES_MAX - rules.size(), "counters": counters()}


## Every M6 key of the ask for the box: `read_region`'s `zones` and `rules` (when any) and `rules_room` (always).
func ask_part(lo: Vector3i, hi: Vector3i) -> Dictionary:
	var out := read_region(lo, hi)
	out["rules_room"] = room()
	return out


# ------------------------------------------------------------------ an LLM answer's ids
## An answer's ops with every `zone` and `rule` op given the next free id (in the answer's order) and every
## reference to an answer zone (a `rule` op's trigger and effects) rewritten to match. A reference to an id no `zone`
## op of the answer defines names a zone already in the Home and stays; `unzone` and `unrule` name what is there and
## are never renumbered. Every other op passes through. Returns {"ops", "refused": [[index, reason], ...]} (a `zone`
## or `rule` id the answer names twice: the later one is refused and left out).
func renumber(ops: Array) -> Dictionary:
	var zmap := {}
	var rmap := {}
	var nz := next_zone_id()
	var nr := next_rule_id()
	var refused := []
	var drop := {}
	for i: int in ops.size():
		var o: Variant = ops[i]
		if not (o is Dictionary) or OpUtil.int_of((o as Dictionary).get("id")) == null:
			continue
		var kind := str((o as Dictionary).get("op", ""))
		var n := int(o.id)
		if kind == "zone" or kind == "rule":
			var m: Dictionary = zmap if kind == "zone" else rmap
			if m.has(n):
				refused.append([i, "the answer names %s %d twice" % [kind, n]])
				drop[i] = true
			elif kind == "zone":
				zmap[n] = nz
				nz += 1
			else:
				rmap[n] = nr
				nr += 1
	var out := []
	for i: int in ops.size():
		if drop.has(i):
			continue
		var o: Variant = ops[i]
		var kind := str((o as Dictionary).get("op", "")) if o is Dictionary else ""
		if not (kind == "zone" or kind == "rule") or OpUtil.int_of((o as Dictionary).get("id")) == null:
			out.append(o)
			continue
		var d: Dictionary = (o as Dictionary).duplicate(true)
		d["id"] = int(zmap[int(d.id)]) if kind == "zone" else int(rmap[int(d.id)])
		if kind == "rule":
			_rewrite(d, zmap)
		out.append(d)
	return {"ops": out, "refused": refused}


static func _rewrite(d: Dictionary, zmap: Dictionary) -> void:
	var w: Variant = d.get("when")
	if w is Dictionary and OpUtil.int_of((w as Dictionary).get("zone")) != null and zmap.has(int(w.zone)):
		w["zone"] = zmap[int(w.zone)]
	var effects: Variant = d.get("do")
	if effects is Array:
		for e: Variant in effects:
			if e is Dictionary and OpUtil.int_of((e as Dictionary).get("zone")) != null and zmap.has(int(e.zone)):
				e["zone"] = zmap[int(e.zone)]
