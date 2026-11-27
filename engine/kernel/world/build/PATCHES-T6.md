# PATCHES-T6: changes lane T (M6 tool) asks the Director to make in files it does not own

## T6-1 BUILD.md (frozen): the rules tool's row in the build-mode file table

Replace the row

```
| `tools/rules_tool.gd` | M6 (rules layer): a stub until lane T lands ("Rules: coming in M6"), after plants and before command in the strip |
```

with

```
| `tools/rules_tool.gd` | M6 (rules layer, lane T): 1-8 a preset (Start, Checkpoint, Finish, Coin, Door, Jump pad, Hazard, Message): armed, each click or drag places one; or drag a box first (the wheel its top), then 1-8. Each preset is one batch of a zone and its rules (`rules_tool_presets.gd`); the first Start asks the run's name, a Message its text (a field, as the stamp name). With nothing armed a click on a zone selects it: the side card (`rules_tool_card.gd`) lists its rules as `describe` sentences and its knobs ([ ], Shift+[ ], G), Delete or Backspace removes it and its rules (one batch); 0 stops. Zones show in build mode in every tool (`zone_draw.gd`), never in play; the rules layer's `preview_node` is the ghost of a preset and of an LLM answer |
```

and add `rules_tool_presets.gd`, `rules_tool_card.gd`, `zone_draw.gd`, `rules_tool_case.gd` (775) to the M6 file list
where the seam keeps it.

## T6-2 rules_check.gd (frozen): a counter condition with min == max

`describe` reads `{"counter": "door_a", "min": 1, "max": 1}` as "door_a is 1-1". The timed door uses exactly that
condition ("every 1 s if door_a is 1-1: close Door 1, take 1 from door_a"). Suggested, in `describe`'s conditions:

```gdscript
		elif c.has("min") and c.has("max"):
			conds.append("%s is %d" % [str(c.counter), int(c.min)] if int(c.min) == int(c.max) else "%s is %d-%d" % [str(c.counter), int(c.min), int(c.max)])
```

No test of 773 reads that line (checked: rules_case.gd describes no min == max condition); 775 does not either.

## T6-3 kernel/runner/visit.gd (not lane T's): C with Ctrl held while building is the stamp tool's, not the visitor's

Ctrl+C in the stamp tool (copy a stamp's share code) also reaches the visit: `steer` reads `slide` (KEY_C, ACTIONS)
for the walker's slide (`input.just_pressed(&"slide")`) and for the flight's descent (`input.axis(&"slide", &"jump")`),
so Ctrl+C held while flying in build mode sinks him (and on foot while running starts a slide). Fix in `steer`, the
`wish` call (around line 205); `_building()` is already there (non-null only while build mode is on, so a replay or
a visit without the Home is unchanged; the raw Ctrl read happens only then):

```gdscript
	if vis.get("space") != null:
		# T6-3: while building, C with Ctrl held is a tool's (the stamp tool's Ctrl+C): it neither slides nor sinks him
		var c_tool: bool = _building() != null and Input.is_physical_key_pressed(KEY_CTRL)
		var climb: float = input.strength(&"jump") if c_tool else input.axis(&"slide", &"jump")
		vis.call("wish", want, input.just_pressed(&"jump") and not in_flight and not toggle_fly,
			input.just_pressed(&"slide") and not in_flight and not toggle_fly and not c_tool, toggle_fly, climb)
```

replacing

```gdscript
	if vis.get("space") != null:
		vis.call("wish", want, input.just_pressed(&"jump") and not in_flight and not toggle_fly,
			input.just_pressed(&"slide") and not in_flight and not toggle_fly, toggle_fly, input.axis(&"slide", &"jump"))
```

(`TLInput.strength(action)` exists, line 101 of kernel/api/tl_input.gd; `axis(neg, pos)` is strength(pos) -
strength(neg), so with C ignored the climb is the jump's strength alone.) Ctrl+V needs nothing: V is no visit action.
The world gate stays 9/9 (no pack's input path changes). How to see it: fly (F), hold Ctrl+C in the stamp tool: he
holds his height.
