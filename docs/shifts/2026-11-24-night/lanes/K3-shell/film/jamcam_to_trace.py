#!/usr/bin/env python3
"""K3 round 2: thirdjam's JAMCAM lines (jam.camera.Log 1, CameraFollow.cpp:1286 of the t5 build) and JAMKICK lines of one
run -> engine/packs/hokej/data/tj_trace_regular_pro.json (read by tests/bot_tj_replay.gd).
usage: python jamcam_to_trace.py <game.log> <out.json>"""
import json, re, sys
log = open(sys.argv[1], encoding='utf8', errors='replace').read()
rows = []
for l in log.splitlines():
    if 'JAMCAM frame=' not in l:
        continue
    d = dict(re.findall(r'(\w+)=(-?[\d.]+)', l.split('JAMCAM ')[1]))
    rows.append([int(d['frame'])] + [float(d[k]) for k in ('px', 'py', 'hyaw', 'fcx', 'fcy', 'fh', 'fpitch', 'fyaw', 'bw')])
kicks = [[int(a), int(b)] for a, b in re.findall(r'JAMKICK frame=(\d+) \S+ strength=\S+ dir=\([^)]*\) cm=\S+ frames=(\d+)', log)]
note = ("thirdjam's own run (K3 round 2): the t5 build (.tl/tj-run, H39-H44), cut hockey.regular, level pro, its measured hand "
        "jam.ScriptHuman 2, jam.camera.Log 1, 1280x720. One row per JAMCAM line (one UJamFollowCamera::StepSimFrame; frames held by "
        "a hit-stop are absent): [sim frame, human px, py (m), hyaw (deg), camera fcx, fcy, fh (m), fpitch, fyaw (deg), boards weight]. "
        "Read by tests/bot_tj_replay.gd: the human's path is fed to our camera and its pose compared with thirdjam's. 'kicks': "
        "[sim frame, frames] of each JAMKICK line of the same log (UJamFollowCamera's contact kick, CameraFollow.cpp:1269-1287, "
        "stair step 3): the camera there is the step plus the kick.")
json.dump({"note": note, "source_log": "docs/shifts/2026-11-24-night/lanes/K3-shell/film/run_tj.sh", "rows": rows, "kicks": kicks},
          open(sys.argv[2], 'w'), separators=(',', ':'))
print(len(rows), 'rows', len(kicks), 'kicks')
