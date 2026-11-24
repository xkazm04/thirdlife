#!/usr/bin/env python3
"""thirdjam's own event lines of one run of its game (the editor or game log: `JAMEVENT <name> who= where= strength=
frame= kind= [outcome=]`, JamEventBus.cpp:75, and the binder's `JAMFX goal scorer_team= human_team= variant=`,
EffectsBinder.cpp:422) -> a JSON list a headless test feeds to the core's sound rules.
usage: python tj_events.py <game.log> <out.json> [note]"""
import json
import re
import sys

rows = []
goals = []
last_frame = 0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.search(r"JAMEVENT (\w+) who=(-?\d+) where=\(([-\d.]+),([-\d.]+),([-\d.]+)\) strength=([-\d.]+) frame=(\d+) kind=(\w+)(?: outcome=(\w+))?", line)
    if m:
        last_frame = int(m.group(7))
        rows.append([last_frame, m.group(1), int(m.group(2)), float(m.group(6)), "" if m.group(8) == "none" else m.group(8), m.group(9) or ""])
        continue
    g = re.search(r"JAMFX goal scorer_team=(-?\d+) human_team=(-?\d+) variant=(\d+)", line)
    if g:
        goals.append([last_frame, int(g.group(1)), int(g.group(2)), int(g.group(3))])
json.dump({"note": sys.argv[3] if len(sys.argv) > 3 else "", "columns": ["frame", "name", "who", "strength", "kind", "outcome"],
           "events": rows, "goals_columns": ["frame", "scorer_team", "human_team", "variant"], "goals": goals},
          open(sys.argv[2], "w", encoding="utf-8"), separators=(",", ":"))
names = {}
for r in rows:
    names[r[1]] = names.get(r[1], 0) + 1
print(len(rows), "events", len(goals), "goals", json.dumps(names, sort_keys=True))
