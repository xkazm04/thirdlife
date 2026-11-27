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
