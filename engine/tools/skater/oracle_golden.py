"""Cuts a tracked golden out of an oracle run (tools/skater/driver_oracle.py, schema tl.skater.oracle/2): the named
skaters only, every frame, centimetres rounded to 0.01.
  python oracle_golden.py <oracle.json> <golden.json> <skater,skater,...>
The gym compares its figures with it (cores/rink/view/verb_gym.gd --oracle=<golden.json>)."""
import json
import sys

src, dst, keep = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(",")]
o = json.load(open(src, encoding="utf-8"))
out = {"schema": "tl.skater.oracle.golden/2", "points": o["points"], "skaters_kept": keep, "skaters": o["skaters"],
       "frames": [[[round(v, 2) for v in fr[i]] for i in keep] for fr in o["frames"]]}
json.dump(out, open(dst, "w", encoding="utf-8"), separators=(",", ":"))
print("frames %d skaters %s" % (len(out["frames"]), keep))
