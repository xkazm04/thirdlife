extends RefCounted
## SEAM M5 + M6 (spark world-sandbox): the lists the frozen cases hold the Home to, in one place (754 seam_case.gd, 757
## command_case.gd). A lane that builds a stub changes no list and no case: a stub is told from a built layer by its
## `offers()` (a stub offers nothing) and a stub tool from a built one by its base script (tools/stub_tool.gd).
## Changing a list here is the Director's (a new layer, op kind or tool), with the contract (contracts/BUILD.md).

## The layers home_build.gd registers, in order, and the op kinds each owns (edit_log.gd `register`).
const LAYERS := ["blocks", "land", "pieces", "water", "paths", "plants", "rules"]
const OPS := {"blocks": ["place", "remove"], "land": ["land", "paint"], "pieces": ["put", "lift"],
	"water": ["flood", "drain"], "paths": ["path", "unpath"], "plants": ["plant"], "rules": ["zone", "unzone", "rule", "unrule"]}
## Ops an LLM answer may carry that are never journaled: a layer's `expand_input` turns them into ops (home_build.gd).
const INPUT_OPS := {"pour": "water"}
## The tools of build mode's strip, in order (build_mode.gd TOOLS), and each one's hotbar line while it is a stub.
const TOOLS := ["blocks", "sculpt", "paint", "piece", "stamp", "water", "path", "plant", "rules", "command"]
const STUB_LINES := {"sculpt": "Sculpt: coming in M2", "paint": "Paint: coming in M2", "piece": "Pieces: coming in M3",
	"stamp": "Stamps: coming in M3", "water": "Water: coming in M5", "path": "Paths: coming in M5",
	"plant": "Plants: coming in M5", "rules": "Rules: coming in M6", "command": "Command: coming in M4"}
## One well-formed op of every M5 kind (754 `seam.stubs`): a stub refuses it "not built yet"; a built layer may apply
## it or refuse it with its own reason.
const M5_EXAMPLES := {
	"flood": {"op": "flood", "cells": [[1, 2, 150]]},
	"drain": {"op": "drain", "cells": [[1, 2, 150]]},
	"path": {"op": "path", "id": 1, "pts": [[100, 100], [700, 100]], "width_cm": 300, "paint": "dirt"},
	"unpath": {"op": "unpath", "id": 1, "pts": [[100, 100], [700, 100]], "width_cm": 300, "paint": "dirt"},
	"plant": {"op": "plant", "cells": [[1, 2, "valley", "meadow"]]}}
## One well-formed op of every M6 kind (773 rules_case.gd): zone 1, a rule naming it, and their removals.
const M6_EXAMPLES := {
	"zone": {"op": "zone", "id": 1, "box": [[0, 5, 0], [2, 7, 2]], "look": "pad", "name": "Pad"},
	"rule": {"op": "rule", "id": 1, "when": {"on": "enter", "zone": 1}, "do": [{"do": "launch", "up_cm": 900, "fwd_cm": 0}]},
	"unrule": {"op": "unrule", "id": 1, "when": {"on": "enter", "zone": 1}, "do": [{"do": "launch", "up_cm": 900, "fwd_cm": 0}]},
	"unzone": {"op": "unzone", "id": 1, "box": [[0, 5, 0], [2, 7, 2]], "look": "pad", "name": "Pad"}}


## Every op kind, in the layers' order.
static func all_ops() -> Array:
	var out := []
	for l: String in LAYERS:
		out.append_array(OPS[l])
	return out


## Every op kind an ask's `ops` may name: the layers' and the input-only ones.
static func ask_ops() -> Array:
	return all_ops() + INPUT_OPS.keys()


## The layer that owns op kind `op` ("" none).
static func layer_of(op: String) -> String:
	for l: String in LAYERS:
		if (OPS[l] as Array).has(op):
			return l
	return str(INPUT_OPS.get(op, ""))


## A layer is a stub while it offers nothing (stub_layer.gd, and the M2/M3 stubs before them).
static func is_stub_layer(l: RefCounted) -> bool:
	return l == null or not l.has_method("offers") or (l.call("offers") as Array).is_empty()


static func is_stub_tool(t: RefCounted) -> bool:
	var sc: Script = t.get_script() if t != null else null
	return sc != null and (sc as GDScript).get_base_script() == preload("res://kernel/world/build/tools/stub_tool.gd")
