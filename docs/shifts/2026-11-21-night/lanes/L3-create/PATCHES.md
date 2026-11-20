# L3 create-screen: patches for files outside the L3 column

## P1. `engine/kernel/world/site/draw.gd` (L1's column): the sign shows the phase

BRIEF: "The village site sign shows phases (`phase n of m: <title>`) where it showed packages." The data side is in
L3's `engine/kernel/world/site.gd`: when the job's plan has `phases`, `view_of(k)` carries `phase_line`
("phase 2 of 3: Rivals and cracks", the first phase not passed; absent before a phased plan and after the last pass),
and the `[site]` report carries it as `phase` (proved in a world by selftest `create_site.phase`). The sign itself is
drawn by `draw.gd`, so two small edits there:

1. In `_key(v)` (so the sign is rebuilt when the phase moves), after `parts.append(str(v.get("yaw_deg", 0.0)))`:

```gdscript
	parts.append(str(v.get("phase_line", "")))
```

2. In `_sign(v, arrived)`, between the `arrived` branch and the `total > 0` branch:

```gdscript
	elif arrived:
		line = "Ready. Walk in and press E to play."
	elif v.has("phase_line"):
		var pl: String = str(v["phase_line"])
		line = pl.substr(0, 1).to_upper() + pl.substr(1)      # "Phase 2 of 3: Rivals and cracks"
	elif int(v["total"]) > 0:
		line = "%d of %d built" % [int(v["built"]), int(v["total"])]
```

A job without phases (every job before 2026-11-20) has no `phase_line` and keeps "N of M built". Nothing else moves.
