extends RefCounted
## tl.land/1. Coordinates and indices refer to the terrain lattice, including partial edge chunks.
const KEYS := ["schema", "chunk", "origin_m", "cell_m", "cells", "base", "split",
	"h_zero_m", "h_step_m", "heights", "materials", "water"]
const MATERIALS := {1: "grass", 2: "dirt", 3: "rock", 4: "sand", 5: "cliff"}
const SIZE := 32

static func make_record(t, cx: int, cz: int) -> Dictionary:
	var start := Vector2i(cx, cz) * SIZE
	return {"schema": "tl.land/1", "chunk": [cx, cz],
		"origin_m": [t.x0 + start.x * t.cell, t.z0 + start.y * t.cell], "cell_m": t.cell,
		"cells": [mini(SIZE, t.nx - start.x), mini(SIZE, t.nz - start.y)],
		"base": {"kind": "village", "seed": t.base_seed}, "split": "alternate"}


static func number(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(v)


static func integer(v: Variant) -> bool:
	return number(v) and (v is int or v == int(v))


static func _keys(obj: Variant, allowed: Array, required: Array) -> String:
	if not obj is Dictionary:
		return "expected an object"
	for key in obj:
		if key not in allowed:
			return "unknown key %s" % key
		if obj[key] == null:
			return "null value for %s" % key
	for key in required:
		if not obj.has(key):
			return "missing %s" % key
	return ""


static func _pair(v: Variant) -> bool:
	return v is Array and v.size() == 2


static func validate(r: Variant) -> String:
	var error := _keys(r, KEYS, KEYS.slice(0, 7))
	if error != "":
		return error
	if r.schema != "tl.land/1":
		return "bad land schema"
	for key in ["chunk", "cells"]:
		if not _pair(r[key]) or not integer(r[key][0]) or not integer(r[key][1]):
			return "%s must be a pair of integers" % key
	for size in r.cells:
		if size < 1 or size > SIZE:
			return "cells outside 1..32"
	if not _pair(r.origin_m) or not number(r.origin_m[0]) or not number(r.origin_m[1]):
		return "invalid origin_m"
	if not number(r.cell_m) or r.cell_m != 3:
		return "cell_m must be 3"
	error = _keys(r.base, ["kind", "seed"], ["kind", "seed"])
	if error != "":
		return "base: " + error
	if not r.base.kind is String or not integer(r.base.seed):
		return "invalid base kind or seed"
	if r.split not in ["alternate", "fixed"]:
		return "invalid split"
	if r.has("heights") != r.has("h_zero_m") or r.has("heights") != r.has("h_step_m"):
		return "heights require both quantisation fields"
	if r.has("heights") and (not number(r.h_zero_m) or not number(r.h_step_m) or r.h_step_m <= 0):
		return "invalid height quantisation"
	var cells := int(r.cells[0]) * int(r.cells[1])
	var vertices := (int(r.cells[0]) + 1) * (int(r.cells[1]) + 1)
	for key in ["heights", "materials"]:
		if not r.get(key, []) is Array:
			return "%s must be a list" % key
		var previous := -1
		var limit := vertices if key == "heights" else cells
		for pair in r.get(key, []):
			if not _pair(pair) or not integer(pair[0]) or not integer(pair[1]):
				return "invalid %s pair" % key
			if pair[0] <= previous or pair[0] >= limit:
				return "%s index out of range, repeated or unsorted" % key
			previous = int(pair[0])
			if key == "heights" and (pair[1] < 0 or pair[1] > 65535):
				return "height q outside u16"
			if key == "materials" and not MATERIALS.has(int(pair[1])):
				return "unknown material id"
	if not r.get("water", []) is Array:
		return "water must be a list"
	var wet := {}
	for group in r.get("water", []):
		error = _keys(group, ["level_m", "cells"], ["level_m", "cells"])
		if error != "":
			return "water: " + error
		if not number(group.level_m) or not group.cells is Array:
			return "invalid water level or cells"
		for c in group.cells:
			if not integer(c) or c < 0 or c >= cells or wet.has(int(c)):
				return "invalid or repeated water cell"
			wet[int(c)] = true
	return ""


static func decode(source: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {"ok": false, "record": {}, "error": parser.get_error_message()}
	var error := validate(parser.data)
	if error != "":
		return {"ok": false, "record": {}, "error": error}
	# Godot parses all JSON numbers as floats. Restore the integer fields of the schema.
	var r: Dictionary = parser.data
	r.chunk = [int(r.chunk[0]), int(r.chunk[1])]
	r.cells = [int(r.cells[0]), int(r.cells[1])]
	r.base.seed = int(r.base.seed)
	for key in ["heights", "materials"]:
		for pair in r.get(key, []):
			pair[0] = int(pair[0])
			pair[1] = int(pair[1])
	for group in r.get("water", []):
		for i in group.cells.size():
			group.cells[i] = int(group.cells[i])
	return {"ok": true, "record": r, "error": ""}


static func _json(v: Variant) -> String:
	if v is float:
		if integer(v):
			return str(int(v))
		var short := JSON.stringify(v)
		return short if short.to_float() == v else JSON.stringify(v, "", false, true)
	if v is Array:
		var entries := PackedStringArray()
		for item in v:
			entries.append(_json(item))
		return "[" + ",".join(entries) + "]"
	if v is Dictionary:
		var entries := PackedStringArray()
		var order := KEYS if v.has("schema") else (["kind", "seed"] if v.has("kind") else ["level_m", "cells"])
		for key in order:
			if v.has(key):
				entries.append(JSON.stringify(key) + ":" + _json(v[key]))
		return "{" + ",".join(entries) + "}"
	return JSON.stringify(v)


static func encode(record: Dictionary) -> String:
	var error := validate(record)
	if error != "":
		push_error(error)
		return ""
	return _json(record)
