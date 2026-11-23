#!/usr/bin/env python3
"""K3 round 5: the raw device stream the pack sent to the core (bot_match_hand's result, metrics.raw.devices; vectors and
the camera yaw as integers x 2^50, exact) written as a rink_rawtrace.gd stream, run through K1's tool, and its per-frame
core hash compared with the pack's (metrics.raw.hashes).
usage: python rawtrace_compare.py <bot report.json> <godot> <engine dir> <work dir> [seed] [difficulty]"""
import json, subprocess, sys, os, re
rep, godot, engine, work = sys.argv[1:5]
seed = sys.argv[5] if len(sys.argv) > 5 else "1"; diff = sys.argv[6] if len(sys.argv) > 6 else "pro"
E = 2.0 ** 50
raw = json.load(open(rep))["bot"]["result"]["metrics"]["raw"]
stream = []
for d in raw["devices"]:
    o = {}
    for k, v in d.items():
        if isinstance(v, list) and k in ("Axis", "CursorPx", "CursorHitM", "StickAxis", "MouseDeltaPx"): o[k] = [v[0] / E, v[1] / E]
        elif k == "CameraYaw": o[k] = v / E
        elif k == "CursorOnIce": o[k] = bool(v)
        else: o[k] = v
    stream.append(o)
sp = os.path.join(work, "pack_raw_stream.json"); op = os.path.join(work, "pack_raw_trace.txt")
json.dump(stream, open(sp, "w"))
subprocess.run([godot, "--headless", "--path", engine, "--script", "res://cores/rink/tools/rink_rawtrace.gd", "--", f"--stream={sp}", f"--out={op}",
                f"--seed={seed}", f"--difficulty={diff}"], capture_output=True)
lines = [l for l in open(op).read().splitlines() if l.startswith("f=")]
hashes = [re.search(r"hash=(\w+)", l).group(1) for l in lines]
pack = raw["hashes"]
n = min(len(hashes), len(pack))
first = next((i for i in range(n) if hashes[i] != pack[i]), None)
ok = first is None and len(hashes) == len(pack) == len(stream)
print(f"{'PASS' if ok else 'FAIL'} rawtrace: {len(stream)} frames of the pack's raw devices through rink_rawtrace.gd: "
      + (f"the core hash equals the pack's on all {n}" if first is None else f"first differing frame {first + 1} (tool {hashes[first]}, pack {pack[first]})")
      + (f"; lines {len(hashes)} for {len(pack)} frames" if len(hashes) != len(pack) else ""))
sys.exit(0 if ok else 1)
