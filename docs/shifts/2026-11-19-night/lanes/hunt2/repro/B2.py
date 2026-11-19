# python docs/shifts/2026-11-19-night/lanes/hunt2/repro/B2.py
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

root = Path.cwd()
fixture = root / "engine/kernel/world/site/fixtures/site_arrive.json"
godot = os.getenv("TL_GODOT", "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe")

with TemporaryDirectory(dir=Path(__file__).resolve().parent) as tmp:
    base = Path(tmp)
    walk = json.loads(fixture.read_text())
    lot = walk["landscape"]["lots"][0]
    lot.update(radius=45, replay={"ticks_per_event": 1})
    walk.update(ticks=240, player=[[0, [40, 0, 4]], [40, [40, 0, 4]], [45, [105, 0, 0]], [240, [105, 0, 0]]], events=[])
    walk["tiers"]["dwell_ticks"] = 1
    path = base / "walk.json"
    path.write_text(json.dumps(walk))
    results = []
    for run in range(2):
        cmd = [godot, "--headless", "--fixed-fps", "60", "--path", str(root / "engine"), "--log-file",
               str(base / "godot.log"), "res://kernel/host/host.tscn", "--", "world", "--child=true",
               "--load=step", "--walk=" + str(path)]
        p = subprocess.run(cmd, env=dict(os.environ, TL_CACHE_DIR=tmp, APPDATA=tmp), capture_output=True, text=True, timeout=180)
        if p.returncode or "SCRIPT ERROR:" in p.stderr:
            raise RuntimeError(p.stdout + p.stderr)
        rows = [json.loads(s) for s in p.stdout.splitlines() if s.startswith("{")]
        site = next(json.loads(s[7:])["sites"][0] for s in p.stdout.splitlines() if s.startswith("[site] {"))
        pack = next(r for r in rows if r.get("kind") == "pack" and r.get("plot") == "site_0")
        assert site["events"] == 21 and site["arrived_at"] == 19 and (base / "site_extent.json").is_file()
        results.append((pack["frames"], pack["state_hash"], site["radius_before"]))
    cold, warm = results
    failed = cold[:2] != warm[:2]
    if failed:
        print(f"REPRO B2: FAIL 240 world ticks, lot radius {cold[2]:g}/{warm[2]:g} m, pack ticks {cold[0]}/{warm[0]}, hashes {cold[1]}/{warm[1]}")
    else:
        print("REPRO B2: PASS")
    raise SystemExit(int(failed))
